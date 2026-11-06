import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';

/// CyberSource Unified Checkout (Visa / Mastercard with 3-D Secure).
///
/// Flow:
///   1. [pay]    → POST /api/user/cybersource/pay    → checkout_id + checkout_url
///   2. open checkout_url in a WebView until it lands on /pay/<id>/result
///   3. [status] → POST /api/user/cybersource/status → poll until PAID / terminal
///
/// The backend creates the order itself once the payment is PAID, so the app
/// must NEVER call create_order for a CyberSource payment.
class CyberSourceService {
  static const String paid = 'PAID';
  static const String verifying = 'VERIFYING';
  static const String review = 'REVIEW';
  static const String created = 'CREATED';
  static const String expired = 'EXPIRED';

  /// Starts (or resumes — the endpoint is idempotent) the checkout for an
  /// order_payment. Returns the decoded body, or null on network failure.
  static Future<Map<String, dynamic>?> pay({
    required BuildContext context,
    required String userId,
    required String serverToken,
    required String uniqueId,
    String? returnUrl,
  }) {
    return _post(context, '/api/user/cybersource/pay', {
      'user_id': userId,
      'server_token': serverToken,
      // order_payment.unique_id is numeric on the backend.
      'unique_id': int.tryParse(uniqueId) ?? uniqueId,
      if (returnUrl != null && returnUrl.isNotEmpty) 'return_url': returnUrl,
    });
  }

  /// Reads the real payment status for a checkout.
  static Future<Map<String, dynamic>?> status({
    required BuildContext context,
    required String userId,
    required String serverToken,
    required String checkoutId,
  }) {
    return _post(context, '/api/user/cybersource/status', {
      'user_id': userId,
      'server_token': serverToken,
      'checkout_id': checkoutId,
    });
  }

  static Future<Map<String, dynamic>?> _post(
    BuildContext context,
    String path,
    Map<String, dynamic> body,
  ) async {
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final url = '$baseUrl$path';
    debugPrint(
      '[CyberSource] POST $url  body=${json.encode({...body, 'server_token': '***'})}',
    );
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 20));
      debugPrint('[CyberSource] ← ${response.statusCode} ${response.body}');
      final decoded = json.decode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('[CyberSource] ❌ $path failed: $e');
      return null;
    }
  }

  /// Polls [status] every 2.5s until PAID or a terminal status.
  /// CREATED right after the result page usually means declined/cancelled,
  /// so it stops after 3 CREATED in a row. Gives up after ~60s and returns
  /// `status: VERIFYING`. Returns a 999 response as soon as one arrives.
  static Future<Map<String, dynamic>> waitForResult({
    required BuildContext context,
    required String userId,
    required String serverToken,
    required String checkoutId,
  }) async {
    Map<String, dynamic>? last;
    int createdPolls = 0;
    for (var attempt = 0; attempt < 24; attempt++) {
      if (!context.mounted) break;
      final data = await status(
        context: context,
        userId: userId,
        serverToken: serverToken,
        checkoutId: checkoutId,
      );
      if (isInvalidToken(data)) return data!;
      if (data != null && data['success'] == true) {
        last = data;
        final s = data['status']?.toString();
        if (data['is_paid'] == true || s == paid) break;
        if (s == review || s == expired) break;
        if (s == created && ++createdPolls >= 3) break;
      }
      await Future.delayed(const Duration(milliseconds: 2500));
    }
    return last ??
        <String, dynamic>{
          'success': false,
          'status': verifying,
          'checkout_id': checkoutId,
        };
  }

  static bool isInvalidToken(Map? data) =>
      data != null && data['success'] == false && data['error_code'] == 999;
}
