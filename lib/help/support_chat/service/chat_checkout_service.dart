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

    // 1. User session
    final userData = await Service.read('user');
    if (userData == null || userData['user'] == null) {
      throw const ChatCheckoutException('Please log in to place an order.');
    }
    final String userId = userData['user']['_id'] ?? '';
    final String serverToken = userData['user']['server_token'] ?? '';
    if (userId.isEmpty || serverToken.isEmpty) {
      throw const ChatCheckoutException('Please log in to place an order.');
    }

    if (!_looksLikeObjectId(product.id) ||
        !_looksLikeObjectId(product.storeId)) {
      throw ChatCheckoutException(
        "I can't order ${product.name} directly from chat yet. "
        'Please open the store and add it from there.',
      );
    }

    // 2. Store detail → store location + payment restrictions
    final storeDetail = await _post(
      '$baseUrl/api/user/user_get_store_product_item_list',
      {"store_id": product.storeId},
      timeout: 20,
    );
    final store = storeDetail?['store'];
    if (storeDetail == null || storeDetail['success'] != true || store == null) {
      throw const ChatCheckoutException(
        "Couldn't load the store details. Please try again.",
      );
    }
    final storeLocation = _parseStoreLocation(store['location']);
    if (storeLocation == null) {
      throw const ChatCheckoutException(
        "Couldn't find the store location. Please try again.",
      );
    }
    final bool onlyCashless = store['accept_only_cashless_payment'] == true;

    // 3. Build the cart (merge with the local cart when it's the same store)
    final cart = await _buildCart(
      userData: userData,
      userId: userId,
      serverToken: serverToken,
      product: product,
      quantity: quantity,
      storeLocation: storeLocation,
      fallbackLat: metaData.latitude,
      fallbackLong: metaData.longitude,
    );

    // 4. Sync cart to backend
    final cartResponse = await _post(
      '$baseUrl/api/user/add_item_in_cart_new',
      cart.toJson(),
    );
    if (cartResponse == null || cartResponse['success'] != true) {
      throw const ChatCheckoutException(
        "Couldn't add the item to your cart. Please try again.",
      );
    }
    userData['user']['cart_id'] = cartResponse['cart_id'];
    await Service.save('user', userData);
    await Service.save('cart', cart.toJson());

    // 5. Delivery vehicle (prefer motorbike, else first available)
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
      throw const ChatCheckoutException(
        'No delivery vehicle is available right now. Please try again later.',
      );
    }

    // 6. Distance & time — Haversine, ~2 min per km (urban average)
    final distance = AddressValidationService.calculateDistanceInMeters(
      cart.storeLocation!.lat!,
      cart.storeLocation!.long!,
      cart.destinationAddress!.lat!,
      cart.destinationAddress!.long!,
    );
    final time = (distance / 1000) * 120;

    // 7. Order invoice
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
      throw const ChatCheckoutException(
        "Couldn't generate the order invoice. Please try again.",
      );
    }
    if (invoice['is_distance_alarm'] == true) {
      throw const ChatCheckoutException(
        'This store is too far from your delivery address. '
        'Please choose a closer store.',
      );
    }

    final orderPayment = invoice['order_payment'];
    return ChatCheckoutResult(
      price:
          double.tryParse(orderPayment['user_pay_payment']?.toString() ?? '') ??
              0.0,
      orderPaymentId: orderPayment['_id']?.toString() ?? '',
      orderPaymentUniqueId: orderPayment['unique_id']?.toString() ?? '',
      vehicleId: vehicleId,
      onlyCashless: onlyCashless,
    );
  }

  static Future<Cart> _buildCart({
    required dynamic userData,
    required String userId,
    required String serverToken,
    required MockProduct product,
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
        existing.storeId == product.storeId &&
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
      storeId: product.storeId,
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
    try {
      final response = await http
          .post(Uri.parse(url), headers: _headers, body: json.encode(body))
          .timeout(Duration(seconds: timeout));
      return json.decode(response.body);
    } on TimeoutException {
      throw const ChatCheckoutException(
        'The server is taking too long to respond. Please try again. ⏳',
      );
    } catch (_) {
      throw const ChatCheckoutException(
        'Something went wrong! Check your internet and try again.',
      );
    }
  }
}
