import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
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

/// Takes a product picked in the support chat through the same backend steps
/// as the regular checkout (see CHATBOT_TO_PAYMENT_FLOW.md):
///
///   store detail → add_item_in_cart_new → get_vehicle_list
///   → distance (Haversine) → get_order_cart_invoice
///
/// and returns the invoice data for [KifiyaScreen].
class ChatCheckoutService {
  static const _headers = <String, String>{
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  static Future<ChatCheckoutResult> checkout({
    required BuildContext context,
    required MockProduct product,
    required int quantity,
  }) async {
    final metaData = Provider.of<ZMetaData>(context, listen: false);
    final baseUrl = metaData.baseUrl;

    debugPrint("🛒 [CHAT CHECKOUT] ========================================");
    debugPrint("🛒 [CHAT CHECKOUT] Starting checkout process");
    debugPrint("🛒 [CHAT CHECKOUT] Product: ${product.name} (id: ${product.id}, storeId: ${product.storeId})");
    debugPrint("🛒 [CHAT CHECKOUT] Unit price: ${product.price} ETB, Quantity: $quantity, Total: ${product.price * quantity} ETB");

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
      debugPrint("❌ [CHAT CHECKOUT] Step 1 failed: Empty userId or serverToken");
      throw const ChatCheckoutException('Please log in to place an order.');
    }
    debugPrint("✅ [CHAT CHECKOUT] Step 1 passed: userId: $userId, serverToken present");

    // Chat menus sometimes carry the store name instead of its id; look the
    // item up globally to recover the real store id.
    var storeId = product.storeId;
    if (_looksLikeObjectId(product.id) && !_looksLikeObjectId(storeId)) {
      debugPrint("🛒 [CHAT CHECKOUT] storeId '$storeId' is not an ObjectId, resolving via search_item_global...");
      storeId = await _resolveStoreId(baseUrl, product) ?? storeId;
    }
    if (!_looksLikeObjectId(product.id) || !_looksLikeObjectId(storeId)) {
      debugPrint("⚠️ [CHAT CHECKOUT] Product or Store ID is not a MongoDB ObjectId: productId='${product.id}', storeId='$storeId'");
      throw ChatCheckoutException(
        "I can't order ${product.name} directly from chat yet. "
        'Please open the store and add it from there.',
      );
    }

    // 2. Store detail → store location + payment restrictions
    debugPrint("🛒 [CHAT CHECKOUT] Step 2: Fetching store details for storeId: $storeId...");
    final storeDetail = await _post(
      '$baseUrl/api/user/user_get_store_product_item_list',
      {"store_id": storeId},
      timeout: 20,
    );
    final store = storeDetail?['store'];
    if (storeDetail == null || storeDetail['success'] != true || store == null) {
      debugPrint("❌ [CHAT CHECKOUT] Step 2 failed: storeDetail success=${storeDetail?['success']}");
      throw const ChatCheckoutException(
        "Couldn't load the store details. Please try again.",
      );
    }
    final storeLocation = _parseStoreLocation(store['location']);
    if (storeLocation == null) {
      debugPrint("❌ [CHAT CHECKOUT] Step 2 failed: Unable to parse store location: ${store['location']}");
      throw const ChatCheckoutException(
        "Couldn't find the store location. Please try again.",
      );
    }
    final bool onlyCashless = store['accept_only_cashless_payment'] == true;
    debugPrint("✅ [CHAT CHECKOUT] Step 2 passed: Store '${store['name']}', Location: [${storeLocation.lat}, ${storeLocation.long}], onlyCashless: $onlyCashless");

    // 3. Build the cart (merge with the local cart when it's the same store)
    debugPrint("🛒 [CHAT CHECKOUT] Step 3: Building cart object...");
    final cart = await _buildCart(
      userData: userData,
      userId: userId,
      serverToken: serverToken,
      product: product,
      storeId: storeId,
      quantity: quantity,
      storeLocation: storeLocation,
      fallbackLat: metaData.latitude,
      fallbackLong: metaData.longitude,
    );
    debugPrint("✅ [CHAT CHECKOUT] Step 3 passed: Cart built with ${cart.items?.length ?? 0} item(s)");

    // 4. Sync cart to backend
    debugPrint("🛒 [CHAT CHECKOUT] Step 4: Syncing cart to backend (/api/user/add_item_in_cart_new)...");
    final cartResponse = await _post(
      '$baseUrl/api/user/add_item_in_cart_new',
      cart.toJson(),
    );
    if (cartResponse == null || cartResponse['success'] != true) {
      debugPrint("❌ [CHAT CHECKOUT] Step 4 failed: cartResponse=${cartResponse?.toString()}");
      throw const ChatCheckoutException(
        "Couldn't add the item to your cart. Please try again.",
      );
    }
    userData['user']['cart_id'] = cartResponse['cart_id'];
    await Service.save('user', userData);
    await Service.save('cart', cart.toJson());
    debugPrint("✅ [CHAT CHECKOUT] Step 4 passed: Cart synced! cart_id: ${cartResponse['cart_id']}");

    // 5. Delivery vehicle (prefer motorbike, else first available)
    debugPrint("🛒 [CHAT CHECKOUT] Step 5: Requesting vehicle list (/api/store/get_vehicle_list)...");
    final vehicleResponse = await _post(
      '$baseUrl/api/store/get_vehicle_list',
      {
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
      },
    );
    final vehicleId = _pickVehicleId(vehicleResponse?['vehicles']);
    if (vehicleId.isEmpty) {
      debugPrint("❌ [CHAT CHECKOUT] Step 5 failed: No valid vehicle found in: ${vehicleResponse?['vehicles']}");
      throw const ChatCheckoutException(
        'No delivery vehicle is available right now. Please try again later.',
      );
    }
    debugPrint("✅ [CHAT CHECKOUT] Step 5 passed: Selected vehicleId: $vehicleId");

    // 6. Distance & time — Haversine, ~2 min per km (urban average)
    debugPrint("🛒 [CHAT CHECKOUT] Step 6: Calculating distance & estimated delivery time...");
    final distance = AddressValidationService.calculateDistanceInMeters(
      cart.storeLocation!.lat!,
      cart.storeLocation!.long!,
      cart.destinationAddress!.lat!,
      cart.destinationAddress!.long!,
    );
    final time = (distance / 1000) * 120;
    debugPrint("✅ [CHAT CHECKOUT] Step 6 passed: Distance: ${distance.toStringAsFixed(1)}m, Estimated Time: ${time.toStringAsFixed(0)}s");

    // 7. Order invoice
    debugPrint("🛒 [CHAT CHECKOUT] Step 7: Requesting cart invoice (/api/user/get_order_cart_invoice)...");
    final invoice = await _post(
      '$baseUrl/api/user/get_order_cart_invoice',
      {
        "user_id": userId,
        "store_id": cart.storeId,
        "total_time": time,
        "total_distance": distance,
        "order_type": 7,
        "is_user_pick_up_order": false,
        "total_item_count": cart.items?.length,
        "is_user_drop_order": !cart.isLaundryService,
        "express_option": 0,
        "server_token": serverToken,
        "vehicle_id": vehicleId,
        "tip": 0,
      },
      timeout: 30,
    );
    if (invoice == null ||
        invoice['success'] != true ||
        invoice['order_payment'] == null) {
      debugPrint("❌ [CHAT CHECKOUT] Step 7 failed: invoice success=${invoice?['success']}, error_code=${invoice?['error_code']}");
      throw const ChatCheckoutException(
        "Couldn't generate the order invoice. Please try again.",
      );
    }
    if (invoice['is_distance_alarm'] == true) {
      debugPrint("⚠️ [CHAT CHECKOUT] Step 7 failed: Distance alarm triggered (too far)");
      throw const ChatCheckoutException(
        'This store is too far from your delivery address. '
        'Please choose a closer store.',
      );
    }

    final orderPayment = invoice['order_payment'];
    final finalPrice =
        double.tryParse(orderPayment['user_pay_payment']?.toString() ?? '') ??
            0.0;
    final orderPaymentId = orderPayment['_id']?.toString() ?? '';
    final orderPaymentUniqueId = orderPayment['unique_id']?.toString() ?? '';

    debugPrint("✅ [CHAT CHECKOUT] Step 7 passed: Invoice generated!");
    debugPrint("🎉 [CHAT CHECKOUT] Final Price: $finalPrice ETB, Payment ID: $orderPaymentId, Unique ID: $orderPaymentUniqueId");
    debugPrint("🛒 [CHAT CHECKOUT] ========================================");

    return ChatCheckoutResult(
      price: finalPrice,
      orderPaymentId: orderPaymentId,
      orderPaymentUniqueId: orderPaymentUniqueId,
      vehicleId: vehicleId,
      onlyCashless: onlyCashless,
    );
  }

  static Future<Cart> _buildCart({
    required dynamic userData,
    required String userId,
    required String serverToken,
    required MockProduct product,
    required String storeId,
    required int quantity,
    required StoreLocation storeLocation,
    required double? fallbackLat,
    required double? fallbackLong,
  }) async {
    Cart? existing;
    try {
      final cartData = await Service.read('cart');
      if (cartData != null) existing = Cart.fromJson(cartData);
    } catch (_) {}

    final item = Item(
      id: product.id,
      quantity: quantity,
      specification: [],
      price: product.price * quantity,
      itemName: product.name,
      imageURL: product.imageUrl,
    );

    // Same store and items already in cart → keep them and merge this one.
    if (existing != null &&
        existing.storeId == storeId &&
        (existing.items?.isNotEmpty ?? false) &&
        existing.destinationAddress != null) {
      existing
        ..userId = userId
        ..serverToken = serverToken
        ..storeLocation = storeLocation;
      Service.addOrMergeCartItem(existing, item);
      return existing;
    }

    // Otherwise start a fresh cart for this store, delivering to the
    // user's current location.
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
        long: double.tryParse(long?.toString() ?? '') ??
            fallbackLong ??
            38.761886,
      ),
      userName: userData['user']['name'] ?? '',
      phone: userData['user']['phone'] ?? '',
      items: [item],
    );
  }

  /// Finds [product] in `search_item_global` and returns its `store_id`.
  /// Matches on item id first, then on item name + store name.
  static Future<String?> _resolveStoreId(
    String baseUrl,
    MockProduct product,
  ) async {
    dynamic response;
    try {
      response = await _post(
        '$baseUrl/api/user/search_item_global',
        {"name": product.name},
        timeout: 30,
      );
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
    final resolved = candidate((i) => i['_id']?.toString() == product.id) ??
        candidate((i) =>
            i['name']?.toString().trim().toLowerCase() == itemName &&
            i['store_name']?.toString().trim().toLowerCase() == storeName);
    debugPrint(resolved != null
        ? "✅ [CHAT CHECKOUT] Resolved storeId: $resolved"
        : "⚠️ [CHAT CHECKOUT] Could not resolve storeId for '${product.name}'");
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

  static Future<dynamic> _post(
    String url,
    Map body, {
    int timeout = 15,
  }) async {
    final encoded = json.encode(body);
    debugPrint("🌐 [CHAT CHECKOUT HTTP] POST $url");
    debugPrint("🌐 [CHAT CHECKOUT HTTP] Payload: $encoded");
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .post(Uri.parse(url), headers: _headers, body: encoded)
          .timeout(Duration(seconds: timeout));
      stopwatch.stop();
      debugPrint("🌐 [CHAT CHECKOUT HTTP] Status: ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms");
      debugPrint("🌐 [CHAT CHECKOUT HTTP] Response: ${response.body}");
      return json.decode(response.body);
    } on TimeoutException catch (e) {
      stopwatch.stop();
      debugPrint("⏰ [CHAT CHECKOUT HTTP] Timeout on $url after ${stopwatch.elapsedMilliseconds}ms: $e");
      throw const ChatCheckoutException(
        'The server is taking too long to respond. Please try again. ⏳',
      );
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint("❌ [CHAT CHECKOUT HTTP] Error on $url after ${stopwatch.elapsedMilliseconds}ms: $e");
      debugPrint("❌ [CHAT CHECKOUT HTTP] Stack: $stack");
      throw const ChatCheckoutException(
        'Something went wrong! Check your internet and try again.',
      );
    }
  }
}
