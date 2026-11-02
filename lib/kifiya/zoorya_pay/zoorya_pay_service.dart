import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';

/// Service for calling the ZOORYA-PAY  POST /api/zooryapay/pay  endpoint.
/// Supports methods: telebirr, mpesa, nib, telebirr_qr, ethswitch_qr
class ZooryaPayService {
  /// Calls POST [baseUrl]/api/zooryapay/pay and returns the decoded JSON body.
  ///
  /// [phoneNumber] is required for telebirr / mpesa / nib.
  /// Leave it null for telebirr_qr / ethswitch_qr.
  ///
  /// Returns:
  ///   success  → {"success":true,"data":{...}}
  ///   error    → {"success":false,"message":"<reason>"}
  ///   null     → network / timeout exception
  static Future<dynamic> pay({
    required BuildContext context,
    required String userId,
    required String serverToken,
    required String method,
    required String uniqueId,
    required double amount,
    String? phoneNumber,
  }) async {
    final baseUrl =
        Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final url = '$baseUrl/api/zooryapay/pay';

    final Map<String, dynamic> body = {
      'user_id': userId,
      'server_token': serverToken,
      'method': method,
      'unique_id': uniqueId,
      'amount': amount,
    };
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      body['phone_number'] = phoneNumber;
    }

    final encoded = json.encode(body);

    debugPrint('════════════════════════════════════════════════════════════════');
    debugPrint('[ZooryaPayService] 🚀 INITIATING ZOORYA-PAY REQUEST');
    debugPrint('[ZooryaPayService] Method:    $method');
    debugPrint('[ZooryaPayService] POST URL:  $url');
    debugPrint('[ZooryaPayService] Payload:   $encoded');
    debugPrint('════════════════════════════════════════════════════════════════');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: encoded,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('[ZooryaPayService] ⚠️ Request timed out after 30s');
              throw TimeoutException('ZOORYA-PAY request timed out');
            },
          );

      debugPrint('════════════════════════════════════════════════════════════════');
      debugPrint('[ZooryaPayService] 📥 ZOORYA-PAY RESPONSE ($method)');
      debugPrint('[ZooryaPayService] Status Code: ${response.statusCode}');
      debugPrint('[ZooryaPayService] Raw Body:    ${response.body}');
      debugPrint('════════════════════════════════════════════════════════════════');

      return json.decode(response.body);
    } catch (e, st) {
      debugPrint('[ZooryaPayService] ❌ Error in pay(): $e\n$st');
      return null;
    }
  }

  /// Polls POST [baseUrl]/admin/check_paid_order to see if payment is done.
  static Future<dynamic> checkPaidOrder({
    required BuildContext context,
    required String userId,
    required String serverToken,
    required String orderPaymentId,
  }) async {
    final baseUrl =
        Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final url = '$baseUrl/admin/check_paid_order';

    final body = json.encode({
      'user_id': userId,
      'server_token': serverToken,
      'order_payment_id': orderPaymentId,
    });

    debugPrint('[ZooryaPayService] 🔎 Polling check_paid_order URL: $url');
    debugPrint('[ZooryaPayService] 🔎 Polling payload: $body');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[ZooryaPayService] ⚠️ checkPaidOrder timed out');
              throw TimeoutException('check_paid_order timed out');
            },
          );

      debugPrint('[ZooryaPayService] 🔎 check_paid_order Status: ${response.statusCode}');
      debugPrint('[ZooryaPayService] 🔎 check_paid_order Body:   ${response.body}');
      return json.decode(response.body);
    } catch (e) {
      debugPrint('[ZooryaPayService] ❌ checkPaidOrder error: $e');
      return null;
    }
  }
}
