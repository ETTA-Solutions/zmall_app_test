import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';

class ChatService {
  ////get usser data
  static Future<dynamic> userDetails({
    required BuildContext context,
    required String userId,
    required String serverToken,
  }) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_detail";
    Map data = {"user_id": userId, "server_token": serverToken};
    var body = json.encode(data);
    try {
      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      return json.decode(response.body);
    } catch (e) {
      // debugPrint(e);
      return null;
    }
  }

  /// Send a message to the chat API and get bot response
  static Future<Map<String, dynamic>?> sendMessage({
    required String message,
    required BuildContext context,
    required String userId,
    String? sessionId,
    String? orderId,
    required String serverToken,
    required List userLocation,
  }) async {
    // Get base URL from metadata provider
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    var url = "$baseUrl/chat_test";
    // var url = "https://test.zmallapp.com/chat_test";

    try {
      Map<String, dynamic> data = {
        "message": message,
        "user_id": userId,
        "user_location": userLocation,
        "server_token": serverToken,
      };

      // Add optional parameters if provided
      if (sessionId != null && sessionId.isNotEmpty) {
        data["session_id"] = sessionId;
      }
      if (orderId != null && orderId.isNotEmpty) {
        data["order_id"] = orderId;
      }

      // debugPrint("====Chat API Request: $data");
      var body = json.encode(data);

      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );

      debugPrint("=====Chat API Response Status: ${response.statusCode}");
      debugPrint("====Chat API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        debugPrint("====Chat API Error: Status ${response.statusCode}");
        return {
          'error': true,

          'message':
              'Connection timed out. Please try again.', // 'message': 'Failed to get response. Status: ${response.statusCode}',
        };
      }
    } on TimeoutException {
      // debugPrint("====Chat API Timeout: $e");
      return {
        'error': true,
        'message': 'Connection timed out. Please try again.',
      };
    } catch (e) {
      // debugPrint("=====Chat API Error: $e");
      return {'error': true, 'message': 'You finished your daily token.'};
    }
  }

  /// Fetch nearby stores using the real store-listing endpoint.
  ///
  /// Calls `/api/user/get_company_list` with the user's city + location.
  static Future<dynamic> getNearbyStores({
    required BuildContext context,
  }) async {
    final meta = Provider.of<ZMetaData>(context, listen: false);
    var url = "${meta.baseUrl}/api/user/get_company_list";
    Map data = {
      "city_id": meta.cityId,
      "latitude": meta.latitude,
      "longitude": meta.longitude,
    };
    var body = json.encode(data);
    try {
      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      return json.decode(response.body);
    } catch (e) {
      return null;
    }
  }

  /// Fetch the menu (items) for a specific store.
  ///
  /// Calls `/api/user/user_get_store_product_item_list` with the store id.
  static Future<dynamic> getStoreItems({
    required BuildContext context,
    required String storeId,
  }) async {
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    var url = "$baseUrl/api/user/user_get_store_product_item_list";
    Map data = {"store_id": storeId};
    var body = json.encode(data);
    try {
      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      return json.decode(response.body);
    } catch (e) {
      return null;
    }
  }

  ////////////////////get user order///////////////////

  static Future<dynamic> getOrders({
    required String userId,
    required String serverToken,
    required BuildContext context,
  }) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_orders";
    Map data = {"user_id": userId, "server_token": serverToken};
    var body = json.encode(data);
    try {
      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );

      var decoded = json.decode(response.body);

      // DEBUG ONLY: compare order_status with get_order_status
      debugCheckOrderStatusMatch(
        userId: userId,
        serverToken: serverToken,
        ordersResponseData: decoded,
        context: context,
      );

      return decoded;
    } catch (e) {
      return null;
    }
  }

  ////////////////////get order status///////////////////

  static Future<dynamic> getOrderStatus({
    required String userId,
    required String serverToken,
    required String orderId,
    required BuildContext context,
  }) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_order_status";
    Map data = {
      "user_id": userId,
      "server_token": serverToken,
      "order_id": orderId,
    };
    var body = json.encode(data);
    try {
      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );

      return json.decode(response.body);
    } catch (e) {
      debugPrint("⚠️ [DEBUG_ORDER] getOrderStatus error: $e");
      return null;
    }
  }

  /// DEBUG ONLY: Compare status between get_orders and get_order_status
  static Future<void> debugCheckOrderStatusMatch({
    required String userId,
    required String serverToken,
    required dynamic ordersResponseData,
    required BuildContext context,
  }) async {
    try {
      if (ordersResponseData != null &&
          ordersResponseData['success'] == true &&
          ordersResponseData['order_list'] != null &&
          (ordersResponseData['order_list'] as List).isNotEmpty) {
        var firstOrder = ordersResponseData['order_list'][0];
        var orderId = firstOrder['_id']?.toString() ?? '';
        var uniqueId = firstOrder['unique_id']?.toString() ?? '';
        var statusFromGetOrders = firstOrder['order_status'];
        var deliveryStatusFromGetOrders = firstOrder['delivery_status'];

        var statusData = await getOrderStatus(
          userId: userId,
          serverToken: serverToken,
          orderId: orderId,
          context: context,
        );

        var statusFromGetOrderStatus = statusData != null
            ? (statusData['order_status'] ??
                statusData['order']?['order_status'] ??
                statusData['delivery_status'])
            : null;

        debugPrint("================== [DEBUG_ORDER COMPARISON] ==================");
        debugPrint("📌 Order _id: $orderId | unique_id: $uniqueId");
        debugPrint("📦 get_orders       -> order_status: $statusFromGetOrders | delivery_status: $deliveryStatusFromGetOrders");
        debugPrint("📊 get_order_status -> order_status: $statusFromGetOrderStatus | full_response: $statusData");

        if (statusFromGetOrders?.toString() == statusFromGetOrderStatus?.toString()) {
          debugPrint("✅ STATUS MATCH: Both endpoints return order_status '$statusFromGetOrders'");
        } else {
          debugPrint("❌ STATUS MISMATCH: get_orders ($statusFromGetOrders) vs get_order_status ($statusFromGetOrderStatus)");
        }
        debugPrint("==============================================================");
      } else {
        debugPrint("🔍 [DEBUG_ORDER] No orders found in get_orders to compare");
      }
    } catch (e) {
      debugPrint("⚠️ [DEBUG_ORDER] Error comparing order statuses: $e");
    }
  }

  /////////////////////////////////////////////////////////////////////
  /// Send message with full metadata context
  static Future<Map<String, dynamic>?> sendMessageWithContext({
    required String message,
    required BuildContext context,
    Map<String, dynamic>? additionalData,
  }) async {
    // Get base URL from metadata provider
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    var url = "$baseUrl/chat_test";

    try {
      Map<String, dynamic> data = {"message": message};

      // Add any additional data
      if (additionalData != null) {
        data.addAll(additionalData);
      }

      var body = json.encode(data);

      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'error': true,
          'message': 'Failed to get response. Status: ${response.statusCode}',
        };
      }
    } on TimeoutException {
      // debugPrint("Chat API Timeout: $e");
      return {
        'error': true,
        'message': 'Connection timed out. Please try again.',
      };
    } catch (e) {
      // debugPrint("Chat API Error: $e");
      return {
        'error': true,
        'message':
            'Sorry, I’m temporarily unavailable right now. Please try again later. 🙏 ',
      };
    }
  }
}
