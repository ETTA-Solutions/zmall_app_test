import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';

/// Service for calling ZOORYA-PAY endpoints:
///   - POST /api/zooryapay/send_otp (for OTP-based bank methods like Zemen)
///   - POST /api/zooryapay/pay (USSD, QR, or OTP-authenticated payment)
///   - POST /api/zooryapay/status (payment + order status; self-heals settlement)
///   - POST /admin/check_paid_order (Polling payment status)
class ZooryaPayService {
  /// Calls POST [baseUrl]/api/zooryapay/send_otp to send a verification OTP
  /// to the phone number linked with the bank account.
  ///
  /// Payload:
  /// {
  ///   "user_id": userId,
  ///   "server_token": serverToken,
  ///   "method": method,
  ///   "account_number": accountNumber
  /// }
  static Future<dynamic> sendOtp({
    required BuildContext context,
    required String userId,
    required String serverToken,
    required String method,
    required String accountNumber,
  }) async {
    final baseUrl =
        Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final url = '$baseUrl/api/zooryapay/send_otp';

    final Map<String, dynamic> body = {
      'user_id': userId,
      'server_token': serverToken,
      'method': method,
      'account_number': accountNumber,
    };

    final encoded = json.encode(body);

    debugPrint('════════════════════════════════════════════════════════════════');
    debugPrint('[ZooryaPayService] 📩 SENDING ZOORYA-PAY OTP REQUEST');
    debugPrint('[ZooryaPayService] Method:         $method');
    debugPrint('[ZooryaPayService] Account Number: $accountNumber');
    debugPrint('[ZooryaPayService] POST URL:       $url');
    debugPrint('[ZooryaPayService] Payload:        $encoded');
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
            const Duration(seconds: 25),
            onTimeout: () {
              debugPrint('[ZooryaPayService] ⚠️ sendOtp timed out after 25s');
              throw TimeoutException('send_otp request timed out');
            },
          );

      debugPrint('════════════════════════════════════════════════════════════════');
      debugPrint('[ZooryaPayService] 📥 ZOORYA-PAY OTP RESPONSE ($method)');
      debugPrint('[ZooryaPayService] Status Code: ${response.statusCode}');
      debugPrint('[ZooryaPayService] Raw Body:    ${response.body}');
      debugPrint('════════════════════════════════════════════════════════════════');

      return json.decode(response.body);
    } catch (e, st) {
      debugPrint('[ZooryaPayService] ❌ Error in sendOtp(): $e\n$st');
      return null;
    }
  }

  /// Calls POST [baseUrl]/api/zooryapay/pay and returns the decoded JSON body.
  ///
  /// [phoneNumber] is required for telebirr / mpesa / nib / dashen.
  /// [accountNumber] & [otp] are required for OTP-based bank payments (e.g. zemen).
  /// Leave them null for telebirr_qr / ethswitch_qr.
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
    String? accountNumber,
    String? otp,
  }) async {
    final baseUrl =
        Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final url = '$baseUrl/api/zooryapay/pay';

    final Map<String, dynamic> body = {
      'user_id': userId,
      'server_token': serverToken,
      'method': method,
      'unique_id': int.tryParse(uniqueId) ?? uniqueId,
      'amount': amount,
    };
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      body['phone_number'] = phoneNumber;
    }
    if (accountNumber != null && accountNumber.isNotEmpty) {
      body['account_number'] = accountNumber;
    }
    if (otp != null && otp.isNotEmpty) {
      body['otp'] = otp;
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

      final decoded = json.decode(response.body);
      final paymentId = decoded is Map && decoded['data'] is Map
          ? decoded['data']['zooryapay_payment_id']
          : null;
      if (paymentId != null && '$paymentId'.isNotEmpty) {
        await _rememberPaymentId(uniqueId, '$paymentId');
      }
      return decoded;
    } catch (e, st) {
      debugPrint('[ZooryaPayService] ❌ Error in pay(): $e\n$st');
      return null;
    }
  }

  // ── zooryapay_payment_id lookup ───────────────────────────────────────────

  /// order_payment unique_id → latest zooryapay_payment_id from /pay. Saved
  /// on the device so /status can still be called after the app is reopened.
  static const String _paymentIdsKey = 'zooryapay_payment_ids';
  static const Duration _paymentIdMaxAge = Duration(hours: 24);

  static Future<void> _rememberPaymentId(String uniqueId, String id) async {
    try {
      final stored = await Service.read(_paymentIdsKey);
      final Map<String, dynamic> ids =
          stored is Map ? Map<String, dynamic>.from(stored) : {};
      final now = DateTime.now();
      ids.removeWhere((_, v) {
        final at = v is Map ? DateTime.tryParse('${v['saved_at']}') : null;
        return at == null || now.difference(at) > _paymentIdMaxAge;
      });
      ids[uniqueId] = {'id': id, 'saved_at': now.toIso8601String()};
      await Service.save(_paymentIdsKey, ids);
    } catch (e) {
      debugPrint('[ZooryaPayService] could not save payment id: $e');
    }
  }

  /// The zooryapay_payment_id of the last /pay call for this order_payment
  /// unique_id, or null if this order was not paid through ZOORYA-PAY.
  static Future<String?> paymentIdFor(String? uniqueId) async {
    if (uniqueId == null || uniqueId.isEmpty) return null;
    try {
      final stored = await Service.read(_paymentIdsKey);
      final entry = stored is Map ? stored[uniqueId] : null;
      final id = entry is Map ? entry['id'] : null;
      return id == null || '$id'.isEmpty ? null : '$id';
    } catch (_) {
      return null;
    }
  }

  /// POST [baseUrl]/api/zooryapay/status. Returns the same payment shape as
  /// /pay. If the payment is confirmed but the order was not created yet, the
  /// backend creates it during this call. Returns null on network error.
  static Future<dynamic> status({
    required BuildContext context,
    required String userId,
    required String serverToken,
    required String zooryapayPaymentId,
  }) async {
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final url = '$baseUrl/api/zooryapay/status';
    final body = json.encode({
      'user_id': userId,
      'server_token': serverToken,
      'zooryapay_payment_id': zooryapayPaymentId,
    });
    debugPrint('[ZooryaPayService] 🔎 status → $url $body');
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
          .timeout(const Duration(seconds: 15));
      debugPrint(
        '[ZooryaPayService] 🔎 status ← ${response.statusCode} ${response.body}',
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint('[ZooryaPayService] ❌ status error: $e');
      return null;
    }
  }

  /// How long a payment screen keeps checking /admin/check_paid_order before it
  /// stops and asks the user to resend the prompt or check again. The phone
  /// prompt (USSD / PIN) expires in about this time anyway.
  static const Duration pollWindow = Duration(minutes: 2);

  /// Wait between two checks (the next check starts only after the previous
  /// answer came back).
  static const Duration pollInterval = Duration(seconds: 2);

  /// True when a check_paid_order response says the payment is done.
  static bool isPaid(dynamic result) {
    bool yes(dynamic v) => v == true || v == 'true';
    if (result is! Map) return false;
    if (yes(result['success']) || yes(result['is_paid']) || yes(result['paid'])) {
      return true;
    }
    final data = result['data'];
    if (data is Map) {
      if (yes(data['is_paid']) || yes(data['paid'])) return true;
      if (data['status'] == 'PAID' || data['status'] == 'COMPLETED') return true;
    }
    return false;
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
