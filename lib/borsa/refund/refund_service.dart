import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/utils/constants.dart';

class RefundService {
  final String userId;
  final String phone;
  final BuildContext context;

  const RefundService({
    required this.userId,
    required this.phone,
    required this.context,
  });

  /// Returns the best user-facing error message from a service response.
  ///
  /// Priority: error_type message → errorCodes map → server message → fallback.
  static String getErrorMessage(Map<String, dynamic> result, String fallback) {
    // Client-side errors (timeout, network, etc.) carry their own message
    if (result.containsKey('error_type')) {
      return result['message'] ?? fallback;
    }
    // Server error codes mapped to user-friendly messages
    final errorCode = result['error_code'];
    if (errorCode != null) {
      final mapped = errorCodes['$errorCode'];
      if (mapped != null) return mapped;
      // The server can put readable text in error_code, for example
      // "Enter a valid Telebirr number (09XXXXXXXX)".
      if (errorCode is String &&
          errorCode.trim().isNotEmpty &&
          int.tryParse(errorCode.trim()) == null) {
        return errorCode;
      }
    }
    // Server-provided message, then fallback
    return result['message'] ?? fallback;
  }

  /// Shared POST helper that returns a structured result for every outcome.
  /// Never returns null — callers always get a map with at least 'success'.
  Future<Map<String, dynamic>> _post({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    final url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}$endpoint";
    // debugPrint('### REFUND _post URL: $url');
    // debugPrint('### REFUND _post body: $body');
    try {
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
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      // debugPrint('### REFUND _post response [$endpoint]: $decoded');
      return decoded;
    } on TimeoutException {
      return {
        'success': false,
        'error_type': 'timeout',
        'message':
            'Connection timed out. Please check your internet and try again.',
      };
    } on SocketException {
      return {
        'success': false,
        'error_type': 'network',
        'message':
            'No internet connection. Please check your network and try again.',
      };
    } on FormatException {
      return {
        'success': false,
        'error_type': 'server',
        'message': 'Something went wrong. Please try again later.',
      };
    } catch (e) {
      return {
        'success': false,
        'error_type': 'unknown',
        'message': 'Something went wrong. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> generateOtp() async {
    return _post(
      endpoint: kRefundGenerateOtpEndpoint,
      body: {"user_id": userId, "phone": phone},
    );
  }

  Future<Map<String, dynamic>> verifyOtp({required String otpCode}) async {
    return _post(
      endpoint: kRefundVerifyOtpEndpoint,
      body: {"user_id": userId, "phone": phone, "code": otpCode},
    );
  }

  /// [receiverPhone] is the Telebirr number that receives the money. Leave it
  /// null to refund to the ZMall phone. `phone` always stays the ZMall phone
  /// (the OTP went there).
  Future<Map<String, dynamic>> processRefund({
    required String transactionId,
    required dynamic transactionAmount,
    String? receiverPhone,
  }) async {
    return _post(
      endpoint: kRefundProcessEndpoint,
      body: {
        "user_id": userId,
        "phone": phone,
        "amount": transactionAmount,
        "unique_id": transactionId,
        if (receiverPhone != null && receiverPhone.isNotEmpty)
          "receiver_phone": receiverPhone,
      },
    );
  }
}
