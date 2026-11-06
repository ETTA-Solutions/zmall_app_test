import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/help/support_chat/service/chat_basket.dart';
import 'package:zmall/help/support_chat/service/chat_spec_pricing.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/location/components/place_service.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/address_validation_service.dart';
import 'package:zmall/services/service.dart';

/// Everything [KifiyaScreen] needs to open the payment step for a chat order.
class ChatCheckoutResult {
  final double price;
  final String orderPaymentId;
  final String orderPaymentUniqueId;
  final String vehicleId;
  final bool onlyCashless;

  const ChatCheckoutResult({
    required this.price,
    required this.orderPaymentId,
    required this.orderPaymentUniqueId,
    required this.vehicleId,
    required this.onlyCashless,
  });
}

/// Thrown with a user-facing message when a checkout step fails, so the chat
/// can reply with it instead of a raw backend error.
class ChatCheckoutException implements Exception {
  final String message;
  const ChatCheckoutException(this.message);

  @override
  String toString() => message;
}

/// Takes a chat order straight to payment by doing, without UI, what the
/// regular Cart → Delivery → Checkout screens do:
///
///   resolve store + default specs → add_item_in_cart_new → motorbike
///   (get_vehicle_list) → distance (Google, else Haversine) → 1 s settle
///   → get_order_cart_invoice
///
/// and returns what CheckoutScreen's "Place order" passes to [KifiyaScreen].
class ChatCheckoutService {
  static const _headers = <String, String>{
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  /// Single product "Order now" — merged into the local cart when it is
  /// from the same store.
  static Future<ChatCheckoutResult> addToCart({
    required BuildContext context,
    required MockProduct product,
    required int quantity,
  }) {
    return _checkoutLines(
      context: context,
      lines: [ChatBasketLine(product: product, quantity: quantity)],
      mergeWithCart: true,
    );
  }

  /// Chat basket "Instant Checkout" — the cart becomes exactly [lines], so
  /// the invoice matches the basket the user reviewed.
  static Future<ChatCheckoutResult> addBasketToCart({
    required BuildContext context,
    required List<ChatBasketLine> lines,
  }) {
    if (lines.isEmpty) {
      throw const ChatCheckoutException('Your basket is empty.');
    }
    return _checkoutLines(context: context, lines: lines, mergeWithCart: false);
  }

  static Future<ChatCheckoutResult> _checkoutLines({
    required BuildContext context,
    required List<ChatBasketLine> lines,
    required bool mergeWithCart,
  }) async {
    final metaData = Provider.of<ZMetaData>(context, listen: false);
    final baseUrl = metaData.baseUrl;
    final product = lines.first.product;

    debugPrint("🛒 [CHAT CHECKOUT] ========================================");
    debugPrint(
      "🛒 [CHAT CHECKOUT] Starting checkout process (${lines.length} line(s), merge: $mergeWithCart)",
    );
    for (final l in lines) {
      debugPrint(
        "🛒 [CHAT CHECKOUT] Line: ${l.product.name} (id: ${l.product.id}, storeId: ${l.product.storeId}) × ${l.quantity} = ${l.total} ETB",
      );
    }

    // 1. User session
    debugPrint("🛒 [CHAT CHECKOUT] Step 1: Validating user session...");
    final userData = await Service.read('user');
    if (userData == null || userData['user'] == null) {
      debugPrint("❌ [CHAT CHECKOUT] Step 1 failed: No user found in storage");
      throw const ChatCheckoutException('Please log in to place an order.');
    }
    final String userId = userData['user']['_id'] ?? '';
    final String serverToken = userData['user']['server_token'] ?? '';
    if (userId.isEmpty || serverToken.isEmpty) {
      debugPrint(
        "❌ [CHAT CHECKOUT] Step 1 failed: Empty userId or serverToken",
      );
      throw const ChatCheckoutException('Please log in to place an order.');
    }
    debugPrint(
      "✅ [CHAT CHECKOUT] Step 1 passed: userId: $userId, serverToken present",
    );

    // Chat products carry neither specifications nor a reliable store id, so
    // load each item's full record (specs, base price, store_id).
    final itemInfos = await Future.wait(
      lines.map((l) => _fetchItemInfo(baseUrl, l.product.id)),
    );

    // Chat menus sometimes carry the store name instead of its id; recover the
    // real store id from the item record, else a global item search.
    var storeId = product.storeId;
    if (_looksLikeObjectId(product.id) && !_looksLikeObjectId(storeId)) {
      final infoStoreId = itemInfos.first?['store_id']?.toString() ?? '';
      if (_looksLikeObjectId(infoStoreId)) {
        debugPrint(
          "✅ [CHAT CHECKOUT] Resolved storeId via item info: $infoStoreId",
        );
        storeId = infoStoreId;
      } else {
        debugPrint(
          "🛒 [CHAT CHECKOUT] storeId '$storeId' is not an ObjectId, resolving via search_item_global...",
        );
        storeId = await _resolveStoreId(baseUrl, product) ?? storeId;
      }
    }
    for (final l in lines) {
      if (!_looksLikeObjectId(l.product.id) || !_looksLikeObjectId(storeId)) {
        debugPrint(
          "⚠️ [CHAT CHECKOUT] Product or Store ID is not a MongoDB ObjectId: productId='${l.product.id}', storeId='$storeId'",
        );
        throw ChatCheckoutException(
          "I can't order ${l.product.name} directly from chat yet. "
          'Please open the store and add it from there.',
        );
      }
    }

    // 2. Store detail → store location + payment restrictions
    debugPrint(
      "🛒 [CHAT CHECKOUT] Step 2: Fetching store details for storeId: $storeId...",
    );
    final storeDetail = await _post(
      '$baseUrl/api/user/user_get_store_product_item_list',
      {"store_id": storeId},
      timeout: 20,
    );
    final store = storeDetail?['store'];
    if (storeDetail == null ||
        storeDetail['success'] != true ||
        store == null) {
      debugPrint(
        "❌ [CHAT CHECKOUT] Step 2 failed: storeDetail success=${storeDetail?['success']}",
      );
      throw const ChatCheckoutException(
        "Couldn't load the store details. Please try again.",
      );
    }
    final storeLocation = _parseStoreLocation(store['location']);
    if (storeLocation == null) {
      debugPrint(
        "❌ [CHAT CHECKOUT] Step 2 failed: Unable to parse store location: ${store['location']}",
      );
      throw const ChatCheckoutException(
        "Couldn't find the store location. Please try again.",
      );
    }
    final bool onlyCashless = store['accept_only_cashless_payment'] == true;
    debugPrint(
      "✅ [CHAT CHECKOUT] Step 2 passed: Store '${store['name']}', Location: [${storeLocation.lat}, ${storeLocation.long}], onlyCashless: $onlyCashless",
    );

    // 3. Build the cart (merge with the local cart when it's the same store)
    debugPrint("🛒 [CHAT CHECKOUT] Step 3: Building cart object...");
    final cart = await _buildCart(
      userData: userData,
      userId: userId,
      serverToken: serverToken,
      lines: lines,
      itemInfos: itemInfos,
      mergeWithCart: mergeWithCart,
      storeId: storeId,
      storeLocation: storeLocation,
      fallbackLat: metaData.latitude,
      fallbackLong: metaData.longitude,
    );
    debugPrint(
      "✅ [CHAT CHECKOUT] Step 3 passed: Cart built with ${cart.items?.length ?? 0} item(s)",
    );

    if (!mergeWithCart) await Service.remove('aliexpressCart');

    // 4. Sync cart to backend
    debugPrint(
      "🛒 [CHAT CHECKOUT] Step 4: Syncing cart to backend (/api/user/add_item_in_cart_new)...",
    );
    final cartResponse = await _post(
      '$baseUrl/api/user/add_item_in_cart_new',
      cart.toJson(),
    );
    if (cartResponse == null || cartResponse['success'] != true) {
      debugPrint(
        "❌ [CHAT CHECKOUT] Step 4 failed: cartResponse=${cartResponse?.toString()}",
      );
      throw const ChatCheckoutException(
        "Couldn't add the item to your cart. Please try again.",
      );
    }
    userData['user']['cart_id'] = cartResponse['cart_id'];
    await Service.save('user', userData);
    await Service.save('cart', cart.toJson());
    debugPrint(
      "✅ [CHAT CHECKOUT] Step 4 passed: Cart synced! cart_id: ${cartResponse['cart_id']}",
    );

    // 5. Delivery vehicle (prefer motorbike, else first available)
    debugPrint(
      "🛒 [CHAT CHECKOUT] Step 5: Requesting vehicle list (/api/store/get_vehicle_list)...",
    );
    final vehicleResponse = await _post('$baseUrl/api/store/get_vehicle_list', {
      "store_id": "",
      "type": 7,
      "delivery_type": 1,
      "user_id": userId,
      "server_token": serverToken,
      "city_id": metaData.cityId,
      "user_latitude": cart.storeLocation!.lat,
      "user_longitude": cart.storeLocation!.long,
      "store_latitude": cart.destinationAddress!.lat,
      "store_longitude": cart.destinationAddress!.long,
      "use_calculation": true,
      "is_laundry": cart.isLaundryService,
    });
    final vehicleId = _pickVehicleId(vehicleResponse?['vehicles']);
    if (vehicleId.isEmpty) {
      debugPrint(
        "❌ [CHAT CHECKOUT] Step 5 failed: No valid vehicle found in: ${vehicleResponse?['vehicles']}",
      );
      throw const ChatCheckoutException(
        'No delivery vehicle is available right now. Please try again later.',
      );
    }
    debugPrint(
      "✅ [CHAT CHECKOUT] Step 5 passed: Selected vehicleId: $vehicleId",
    );

    // 6. Distance & time — Google Distance Matrix like CheckoutScreen,
    // Haversine (~2 min per km) when it fails.
    debugPrint(
      "🛒 [CHAT CHECKOUT] Step 6: Calculating distance & estimated delivery time...",
    );
    final route = await _routeDistance(cart);
    final distance =
        route?.distance ??
        AddressValidationService.calculateDistanceInMeters(
          cart.storeLocation!.lat!,
          cart.storeLocation!.long!,
          cart.destinationAddress!.lat!,
          cart.destinationAddress!.long!,
        );
    final time = route?.time ?? (distance / 1000) * 120;
    debugPrint(
      "✅ [CHAT CHECKOUT] Step 6 passed (${route != null ? 'Google' : 'Haversine'}): Distance: ${distance.toStringAsFixed(1)}m, Estimated Time: ${time.toStringAsFixed(0)}s",
    );
    // CheckoutScreen waits a second before invoicing; give the synced cart
    // the same time to settle.
    await Future.delayed(const Duration(seconds: 1));

    // 7. Order invoice — same request as CheckoutScreen.getCartInvoice
    debugPrint(
      "🛒 [CHAT CHECKOUT] Step 7: Requesting cart invoice (/api/user/get_order_cart_invoice)...",
    );
    final invoice = await _post('$baseUrl/api/user/get_order_cart_invoice', {
      "user_id": cart.userId,
      "store_id": cart.storeId,
      "total_time": time,
      "total_distance": distance,
      "order_type": 7,
      "is_user_pick_up_order": false,
      "total_item_count": cart.items?.length,
      "is_user_drop_order": !cart.isLaundryService,
      "express_option": 0,
      "server_token": cart.serverToken,
      "vehicle_id": vehicleId,
      "tip": 0,
    }, timeout: 30);
    if (invoice == null ||
        invoice['success'] != true ||
        invoice['order_payment'] == null) {
      debugPrint(
        "❌ [CHAT CHECKOUT] Step 7 failed: invoice success=${invoice?['success']}, error_code=${invoice?['error_code']}",
      );
      throw const ChatCheckoutException(
        "Couldn't generate the order invoice. Please try again.",
      );
    }
    if (invoice['is_distance_alarm'] == true) {
      debugPrint(
        "⚠️ [CHAT CHECKOUT] Step 7 failed: Distance alarm triggered (too far)",
      );
      throw const ChatCheckoutException(
        'This store is too far from your delivery address. '
        'Please choose a closer store.',
      );
    }

    final orderPayment = invoice['order_payment'];
    for (final e in (orderPayment as Map).entries) {
      if (e.value is num) {
        debugPrint("🧾 [CHAT CHECKOUT] invoice.${e.key} = ${e.value}");
      }
    }
    // Same amount CheckoutScreen charges. Never fall back to another total:
    // when the cart is priced at 0 that one is delivery only.
    final price =
        double.tryParse(orderPayment['user_pay_payment']?.toString() ?? '') ??
        0.0;
    if (price <= 0) {
      debugPrint(
        "❌ [CHAT CHECKOUT] Step 7 failed: user_pay_payment=$price, total_cart_price=${orderPayment['total_cart_price']}",
      );
      throw const ChatCheckoutException(
        "Couldn't price your order right now. Please try again in a moment.",
      );
    }
    // CheckoutScreen passes the invoice's own vehicle to KifiyaScreen.
    final invoiceVehicles = invoice['vehicles'];
    final paymentVehicleId =
        invoiceVehicles is List && invoiceVehicles.isNotEmpty
        ? invoiceVehicles.first['_id']?.toString() ?? vehicleId
        : vehicleId;
    final orderPaymentId = orderPayment['_id']?.toString() ?? '';
    final orderPaymentUniqueId = orderPayment['unique_id']?.toString() ?? '';

    debugPrint("✅ [CHAT CHECKOUT] Step 7 passed: Invoice generated!");
    debugPrint(
      "🎉 [CHAT CHECKOUT] Final Price: $price ETB, Payment ID: $orderPaymentId, Unique ID: $orderPaymentUniqueId, vehicleId: $paymentVehicleId",
    );
    debugPrint("🛒 [CHAT CHECKOUT] ========================================");

    return ChatCheckoutResult(
      price: price,
      orderPaymentId: orderPaymentId,
      orderPaymentUniqueId: orderPaymentUniqueId,
      vehicleId: paymentVehicleId,
      onlyCashless: onlyCashless,
    );
  }

  /// Road distance (m) and time (s) from the Google Distance Matrix, as
  /// CheckoutScreen computes it; null when unavailable.
  static Future<({double distance, double time})?> _routeDistance(
    Cart cart,
  ) async {
    if (kIsWeb) return null;
    final apiKey = Platform.isAndroid
        ? PlaceApiProvider.androidKey
        : PlaceApiProvider.iosKey;
    final url =
        "https://maps.googleapis.com/maps/api/distancematrix/json?origins=${cart.storeLocation?.lat?.toStringAsFixed(6)},${cart.storeLocation?.long?.toStringAsFixed(6)}&destinations=${cart.destinationAddress?.lat},${cart.destinationAddress?.long}&key=$apiKey";
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      final element = json.decode(response.body)['rows'][0]['elements'][0];
      if (element['status'] != 'OK') return null;
      return (
        distance: (element['distance']['value'] as num).toDouble(),
        time: (element['duration']['value'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint("⚠️ [CHAT CHECKOUT] Distance Matrix failed: $e");
      return null;
    }
  }

  static Future<Cart> _buildCart({
    required dynamic userData,
    required String userId,
    required String serverToken,
    required List<ChatBasketLine> lines,
    required List<Map?> itemInfos,
    required bool mergeWithCart,
    required String storeId,
    required StoreLocation storeLocation,
    required double? fallbackLat,
    required double? fallbackLong,
  }) async {
    Cart? existing;
    try {
      final cartData = await Service.read('cart');
      if (cartData != null) existing = Cart.fromJson(cartData);
    } catch (_) {}

    final items = [
      for (var i = 0; i < lines.length; i++) _cartItem(lines[i], itemInfos[i]),
    ];

    // Same store and items already in cart → keep them and merge these.
    if (mergeWithCart &&
        existing != null &&
        existing.storeId == storeId &&
        (existing.items?.isNotEmpty ?? false) &&
        existing.destinationAddress != null) {
      existing
        ..userId = userId
        ..serverToken = serverToken
        ..storeLocation = storeLocation;
      for (final item in items) {
        Service.addOrMergeCartItem(existing, item);
      }
      return existing;
    }

    // Otherwise start a fresh cart for this store. Deliver to the address
    // picked in chat, else the saved cart's, else the current location.
    final savedAddress =
        await loadChatDeliveryAddress() ?? existing?.destinationAddress;
    if (savedAddress?.lat != null && savedAddress?.long != null) {
      return Cart(
        userId: userId,
        serverToken: serverToken,
        storeId: storeId,
        storeLocation: storeLocation,
        destinationAddress: savedAddress,
        userName: userData['user']['name'] ?? '',
        phone: userData['user']['phone'] ?? '',
        items: items,
      );
    }
    final lat = await Service.read('latitude');
    final long = await Service.read('longitude');
    return Cart(
      userId: userId,
      serverToken: serverToken,
      storeId: storeId,
      storeLocation: storeLocation,
      destinationAddress: DestinationAddress(
        name: "Current Location",
        note: "User current location",
        lat: double.tryParse(lat?.toString() ?? '') ?? fallbackLat ?? 9.010498,
        long:
            double.tryParse(long?.toString() ?? '') ??
            fallbackLong ??
            38.761886,
      ),
      userName: userData['user']['name'] ?? '',
      phone: userData['user']['phone'] ?? '',
      items: items,
    );
  }

  /// Public access to [_fetchItemInfo] for chat pricing.
  static Future<Map?> fetchItemInfo(String baseUrl, String itemId) =>
      _fetchItemInfo(baseUrl, itemId);

  /// Loads the full item record (`get_item_information`), or null if it
  /// can't be fetched.
  static Future<Map?> _fetchItemInfo(String baseUrl, String itemId) async {
    if (!_looksLikeObjectId(itemId)) return null;
    try {
      final info = await _post('$baseUrl/api/admin/get_item_information', {
        "item_id": itemId,
      }, timeout: 15);
      final item = info?['item'];
      if (info?['success'] == true && item is Map) return item;
    } on ChatCheckoutException {
      // Caller falls back to the chat product data.
    }
    debugPrint("⚠️ [CHAT CHECKOUT] Could not load item info for '$itemId'");
    return null;
  }

  /// Builds the cart item for [line] the way the item screen does: the
  /// default-selected options of each specification, priced as
  /// `(base price + option prices) × quantity`. Without [info] the chat
  /// product's own price is used with no specifications.
  static Item _cartItem(ChatBasketLine line, Map? info) {
    final product = line.product;
    if (product.priceFromSpecs && info != null) {
      return _specPricedCartItem(line, info);
    }
    if (info == null) {
      return Item(
        id: product.id,
        quantity: line.quantity,
        specification: [],
        price: product.price * line.quantity,
        itemName: product.name,
        imageURL: product.imageUrl,
      );
    }

    final specs = <Specification>[];
    var optionsPrice = 0.0;
    for (final spec in (info['specifications'] as List? ?? const [])) {
      if (spec is! Map) continue;
      final defaults = [
        for (final opt in (spec['list'] as List? ?? const []))
          if (opt is Map && opt['is_default_selected'] == true)
            ListElement(
              uniqueId: opt['unique_id'],
              price: double.tryParse(opt['price']?.toString() ?? '') ?? 0.0,
            ),
      ];
      if (defaults.isEmpty) {
        if (spec['is_required'] == true) {
          debugPrint(
            "⚠️ [CHAT CHECKOUT] ${product.name}: required spec '${spec['name']}' has no default option",
          );
          throw ChatCheckoutException(
            '${product.name} needs a ${spec['name']} choice. '
            'Please open the store and pick it from there.',
          );
        }
        continue;
      }
      specs.add(Specification(uniqueId: spec['unique_id'], list: defaults));
      optionsPrice += defaults.fold(0.0, (sum, o) => sum + (o.price ?? 0));
    }

    final basePrice = double.tryParse(info['price']?.toString() ?? '') ?? 0.0;
    final unitPrice = basePrice + optionsPrice;
    debugPrint(
      "🛒 [CHAT CHECKOUT] ${product.name}: base $basePrice + options $optionsPrice = $unitPrice ETB × ${line.quantity} (chat showed ${product.price})",
    );
    return Item(
      id: product.id,
      quantity: line.quantity,
      specification: specs,
      price: unitPrice * line.quantity,
      itemName: product.name,
      imageURL: product.imageUrl,
    );
  }

  /// Cart item for a product priced from its specifications: the same
  /// options [ChatSpecPricing] used for the price shown in chat.
  static Item _specPricedCartItem(ChatBasketLine line, Map info) {
    final product = line.product;
    final selection = ChatSpecSelection.fromItemInfo(info);
    if (selection == null) {
      throw ChatCheckoutException(
        "I couldn't find a price for ${product.name}. "
        'Please open the store and order it from there.',
      );
    }
    debugPrint(
      "🛒 [CHAT CHECKOUT] ${product.name}: priced from specs ${selection.unitPrice} ETB (${selection.note}) × ${line.quantity} (chat showed ${product.price})",
    );
    return Item(
      id: product.id,
      quantity: line.quantity,
      specification: selection.specs,
      price: selection.unitPrice * line.quantity,
      itemName: product.name,
      imageURL: product.imageUrl,
    );
  }

  /// Finds [product] in `search_item_global` and returns its `store_id`.
  /// Matches on item id first, then on item name + store name. The search is
  /// capped, so it can miss the item for common names.
  static Future<String?> _resolveStoreId(
    String baseUrl,
    MockProduct product,
  ) async {
    dynamic response;
    try {
      response = await _post('$baseUrl/api/user/search_item_global', {
        "name": product.name,
      }, timeout: 30);
    } on ChatCheckoutException {
      return null;
    }
    final items = response?['items'];
    if (items is! List) return null;

    String? candidate(bool Function(Map) test) {
      for (final item in items) {
        if (item is! Map || !test(item)) continue;
        final id = item['store_id']?.toString() ?? '';
        if (_looksLikeObjectId(id)) return id;
      }
      return null;
    }

    final storeName = product.storeId.trim().toLowerCase();
    final itemName = product.name.trim().toLowerCase();
    final resolved =
        candidate((i) => i['_id']?.toString() == product.id) ??
        candidate(
          (i) =>
              i['name']?.toString().trim().toLowerCase() == itemName &&
              i['store_name']?.toString().trim().toLowerCase() == storeName,
        );
    debugPrint(
      resolved != null
          ? "✅ [CHAT CHECKOUT] Resolved storeId: $resolved"
          : "⚠️ [CHAT CHECKOUT] Could not resolve storeId for '${product.name}'",
    );
    return resolved;
  }

  /// Store `location` comes back as `[lat, long]`.
  static StoreLocation? _parseStoreLocation(dynamic location) {
    if (location is List && location.length >= 2) {
      final lat = double.tryParse(location[0].toString());
      final long = double.tryParse(location[1].toString());
      if (lat != null && long != null) {
        return StoreLocation(lat: lat, long: long);
      }
    }
    return null;
  }

  static String _pickVehicleId(dynamic vehicles) {
    if (vehicles is! List || vehicles.isEmpty) return '';
    for (final v in vehicles) {
      final name = (v['name'] ?? v['vehicle_name'] ?? '')
          .toString()
          .toLowerCase();
      if (name.contains('motor') || name.contains('bike')) {
        return v['_id'].toString();
      }
    }
    return vehicles.first['_id']?.toString() ?? '';
  }

  /// Backend ids are 24-char Mongo ObjectIds. Chat results without a real
  /// id get a `backend_...` placeholder (or a store name) and can't be ordered.
  static bool _looksLikeObjectId(String id) =>
      RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);

  static Future<dynamic> _post(String url, Map body, {int timeout = 15}) async {
    final encoded = json.encode(body);
    debugPrint("🌐 [CHAT CHECKOUT HTTP] POST $url");
    debugPrint("🌐 [CHAT CHECKOUT HTTP] Payload: $encoded");
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .post(Uri.parse(url), headers: _headers, body: encoded)
          .timeout(Duration(seconds: timeout));
      stopwatch.stop();
      debugPrint(
        "🌐 [CHAT CHECKOUT HTTP] Status: ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms",
      );
      debugPrint("🌐 [CHAT CHECKOUT HTTP] Response: ${response.body}");
      return json.decode(response.body);
    } on TimeoutException catch (e) {
      stopwatch.stop();
      debugPrint(
        "⏰ [CHAT CHECKOUT HTTP] Timeout on $url after ${stopwatch.elapsedMilliseconds}ms: $e",
      );
      throw const ChatCheckoutException(
        'The server is taking too long to respond. Please try again. ⏳',
      );
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint(
        "❌ [CHAT CHECKOUT HTTP] Error on $url after ${stopwatch.elapsedMilliseconds}ms: $e",
      );
      debugPrint("❌ [CHAT CHECKOUT HTTP] Stack: $stack");
      throw const ChatCheckoutException(
        'Something went wrong! Check your internet and try again.',
      );
    }
  }
}
