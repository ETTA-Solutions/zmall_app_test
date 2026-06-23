import 'package:flutter/foundation.dart';

class BackendLogger {
  // Disable logging in production (release builds)
  static bool get _isEnabled => kDebugMode;

  static void request({
    required String method,
    required String url,
    Object? headers,
    Object? body,
  }) {
    if (!_isEnabled) return;
    // debugPrintSynchronously('[BACKEND] [$method] $url');
    // if (headers != null) {
    //   debugPrintSynchronously('[BACKEND] headers: ${_safeText(headers)}');
    // }
    // if (body != null) {
    //   debugPrintSynchronously('[BACKEND] body: ${_safeText(body)}');
    // }
  }

  static void response({
    required String method,
    required String url,
    required int statusCode,
    Object? body,
  }) {
    if (!_isEnabled) return;
    // debugPrintSynchronously('[BACKEND] [$method] $url -> $statusCode');
    // if (body != null) {
    //   debugPrintSynchronously('[BACKEND] response: ${_safeText(body)}');
    // }
  }

  static void error({
    required String method,
    required String url,
    required Object error,
  }) {
    if (!_isEnabled) return;
    // debugPrintSynchronously('[BACKEND] [$method] $url -> ERROR: $error');
  }

  static String _safeText(Object value) {
    final text = value.toString();
    if (text.length <= 1200) return text;
    return '${text.substring(0, 1200)}... [truncated ${text.length - 1200} chars]';
  }
}
