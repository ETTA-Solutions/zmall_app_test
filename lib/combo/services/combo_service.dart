import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/combo/combo_route.dart';
import 'package:zmall/combo/models/combo_cart.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/utils/constants.dart';

/// HTTP calls for combo (two-store) orders.
///
/// Every method returns the decoded body, or null on timeout / network error.
class ComboService {
  static Future<Map<String, dynamic>?> _post(
    BuildContext context,
    String path,
    Map<String, dynamic> body, {
    int timeout = 30,
  }) async {
    final url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/$path";
    try {
      if (kDebugMode) debugPrint("[COMBO] $path BODY: ${json.encode(body)}");
      final response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: json.encode(body),
          )
          .timeout(
            Duration(seconds: timeout),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      if (kDebugMode) debugPrint("[COMBO] $path RESPONSE: ${response.body}");
      return Map<String, dynamic>.from(json.decode(response.body));
    } catch (e) {
      if (kDebugMode) debugPrint("[COMBO] $path ERROR: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _get(
    BuildContext context,
    String path,
    Map<String, String> params, {
    int timeout = 30,
  }) async {
    final base =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/$path";
    final uri = Uri.parse(base).replace(queryParameters: params);
    try {
      if (kDebugMode) debugPrint("[COMBO] GET $path PARAMS: $params");
      final response = await http
          .get(uri, headers: {"Accept": "application/json"})
          .timeout(
            Duration(seconds: timeout),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      if (kDebugMode) debugPrint("[COMBO] GET $path RESPONSE: ${response.body}");
      return Map<String, dynamic>.from(json.decode(response.body));
    } catch (e) {
      if (kDebugMode) debugPrint("[COMBO] GET $path ERROR: $e");
      return null;
    }
  }

  static Map<String, dynamic> _items(Cart cart) => {
    "store_id": cart.storeId,
    "items": cart.items!.map((item) => item.toJson()).toList(),
  };

  /// Step 1: sends both carts. Response holds combo_id and a cart_id per store.
  static Future<Map<String, dynamic>?> addItemInCart(
    BuildContext context, {
    required dynamic userData,
    required Cart first,
    required ComboCart combo,
    required DestinationAddress destination,
    required String username,
    required String phone,
  }) => _post(context, "combo_add_item_in_cart", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
    if (combo.comboId != null) "combo_id": combo.comboId,
    "destination_address": destination.toJson(),
    "delivery_type": 1,
    "username": username,
    "phone": phone,
    "store_a": _items(first),
    "store_b": _items(combo.second),
  });

  /// Step 2: prices both carts. `store_a` must be the route origin.
  static Future<Map<String, dynamic>?> getInvoice(
    BuildContext context, {
    required dynamic userData,
    required ComboCart combo,
    required ComboRoute route,
  }) => _post(context, "combo_get_order_cart_invoice", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
    "combo_id": combo.comboId,
    "order_type": 7,
    "total_time": route.totalTime.round(),
    "total_distance": route.totalDistance.round(),
    "store_a": {
      "store_id": route.originStoreId,
      "cart_id": combo.cartIdByStore[route.originStoreId],
    },
    "store_b": {
      "store_id": route.waypointStoreId,
      "cart_id": combo.cartIdByStore[route.waypointStoreId],
    },
  });

  /// Step 3: pays both order payments. Like single-store pay_order_payment,
  /// cash and wallet both send is_payment_mode_cash: true; the wallet is
  /// chosen beforehand with [setWalletUse].
  static Future<Map<String, dynamic>?> pay(
    BuildContext context, {
    required dynamic userData,
    required String originPaymentId,
    required String waypointPaymentId,
    String otp = "",
  }) => _post(context, "combo_pay_order_payment", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
    "store_a_order_payment_id": originPaymentId,
    "store_b_order_payment_id": waypointPaymentId,
    "is_payment_mode_cash": true,
    "order_type": 7,
    "otp": otp,
  }, timeout: 40);

  /// Step 4: creates the two orders. `store_a_cart_id` is the origin's cart.
  static Future<Map<String, dynamic>?> createOrder(
    BuildContext context, {
    required dynamic userData,
    required String comboId,
    required String originCartId,
    required String waypointCartId,
  }) => _post(context, "combo_create_order", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
    "combo_id": comboId,
    "store_a_cart_id": originCartId,
    "store_b_cart_id": waypointCartId,
    "is_user_pick_up_order": false,
    "order_from": Platform.isIOS ? "ios" : "android",
  }, timeout: 50);

  /// Same call the payment screen makes before paying.
  static Future<Map<String, dynamic>?> setWalletUse(
    BuildContext context, {
    required dynamic userData,
    required bool useWallet,
  }) => _post(context, "change_user_wallet_status", {
    "user_id": userData['user']['_id'],
    "is_use_wallet": useWallet,
    "server_token": userData['user']['server_token'],
  }, timeout: 20);

  /// Same gateway list the single-store payment screen shows.
  static Future<Map<String, dynamic>?> getPaymentGateways(
    BuildContext context, {
    required dynamic userData,
    required String orderPaymentId,
  }) => _post(context, "get_payment_gateway", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
    "city_id": Provider.of<ZMetaData>(context, listen: false).cityId,
    "store_delivery_id": orderPaymentId,
    "is_user_pickup_with_schedule": false,
    "vehicleId": null,
    "device_type": Platform.isIOS ? "iOS" : "android",
    "app_version": appVersion,
  }, timeout: 20);

  static Future<Map<String, dynamic>?> getUserDetail(
    BuildContext context, {
    required dynamic userData,
  }) => _post(context, "get_detail", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
  }, timeout: 20);

  static Future<Map<String, dynamic>?> getStoreDetail(
    BuildContext context, {
    required String storeId,
  }) => _post(context, "user_get_store_product_item_list", {
    "store_id": storeId,
  }, timeout: 20);

  /// Fetches the maximum allowed distance (in metres) between two combo stores.
  ///
  /// Backend response: `{ "success": true, "combo_max_store_distance_km": 50 }`
  /// Returns the response with an added `max_distance` key in metres so callers
  /// don't need to know the backend field name or unit.
  static Future<Map<String, dynamic>?> StoreDistancegetMax(
    BuildContext context, {
    required dynamic userData,
    required String storeIdA,
    required String storeIdB,
  }) async {
    final res = await _get(context, "get_combo_max_store_distance", {
      "user_id": userData['user']['_id'],
      "server_token": userData['user']['server_token'],
      "store_a_id": storeIdA,
      "store_b_id": storeIdB,
    }, timeout: 15);

    debugPrint('┌─────────────────────────────────────────────────────');
    debugPrint('│ [COMBO-DEBUG] get_combo_max_store_distance call:');
    debugPrint('│ store_a_id: $storeIdA, store_b_id: $storeIdB');
    debugPrint('│ raw response: $res');

    if (res != null && res['success'] == true) {
      // Backend returns km — convert to metres for distance comparisons
      final num? km = (res['combo_max_store_distance_km'] ??
          res['max_store_distance_km'] ??
          res['max_distance_km'] ??
          res['combo_max_distance_km'] ??
          res['distance_km']) as num?;
      if (km != null) {
        res['max_distance'] = km.toDouble() * 1000.0;
      } else if (res['max_distance'] != null) {
        res['max_distance'] = (res['max_distance'] as num).toDouble();
      } else if (res['max_store_distance'] != null) {
        res['max_distance'] = (res['max_store_distance'] as num).toDouble() * 1000.0;
      }
      debugPrint('│ computed max_distance: ${res['max_distance']} m (${(res['max_distance'] != null ? (res['max_distance'] as num) / 1000.0 : 0)} km)');
    } else {
      debugPrint('│ ⚠️ get_combo_max_store_distance failed or null!');
    }
    debugPrint('└─────────────────────────────────────────────────────');
    return res;
  }

  /// Best readable error from a combo response. Combo endpoints return
  /// plain-text errors in `error`/`message`; wrapped single-store calls
  /// return numeric `error_code`s.
  static String errorText(Map<String, dynamic>? data, {String? fallback}) {
    if (data == null) {
      return "Something went wrong! Check your internet and try again";
    }
    for (final side in ["store_a", "store_b"]) {
      final sideData = data[side];
      if (sideData is Map && sideData['success'] == false) {
        return errorText(Map<String, dynamic>.from(sideData));
      }
    }
    final code = data['error_code'];
    if (code != null && errorCodes['$code'] != null) {
      return "${errorCodes['$code']}";
    }
    if (code == "YOUR_WALLET_AMOUNT_NEGATIVE") {
      return "Not enough wallet balance. Pay with cash or top up your wallet.";
    }
    for (final key in ["error", "error_message", "message"]) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return fallback ?? "Something went wrong. Please try again.";
  }

  static bool isSessionExpired(Map<String, dynamic>? data) =>
      data != null && "${data['error_code']}" == "999";
}
