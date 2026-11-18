import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_service.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';

/// Payment → order settlement (backend-created orders).
///
/// The backend now creates the order itself once a payment is confirmed,
/// from the order details (the "intent") sent on the invoice call. The app:
///   1. calls [checkBeforePay] right before launching any payment, so a cart
///      that is already paid or in flight is never charged twice;
///   2. after paying, polls for the created order and reads its `order_id`
///      instead of calling `/api/user/create_order`;
///   3. if confirmation is slow, shows "processing" and never asks the user to
///      pay again. A pending payment is remembered locally so it can be
///      re-checked when the app is reopened or the "order placed" push opens it.
class OrderSettlementService {
  OrderSettlementService._();

  /// How often to ask the backend while the user is watching.
  static const Duration pollInterval = Duration(seconds: 3);

  /// How long to keep asking before switching to "processing".
  static const Duration pollWindow = Duration(minutes: 3);

  /// A pending payment older than this is no longer re-checked on reopen.
  static const Duration pendingMaxAge = Duration(hours: 24);

  static const String _pendingKey = 'pending_order_payment';

  /// `status` values that mean the payment itself failed. Only these allow the
  /// user to start a new payment.
  static const Set<String> failedStatuses = {
    'FAILED',
    'CREATE_FAILED',
    'REJECTED',
    'CANCELLED',
    'EXPIRED',
  };

  // ── check_before_pay ──────────────────────────────────────────────────────

  /// POST /api/user/check_before_pay. Returns the decoded body, or null when
  /// the call fails (network error, endpoint not deployed yet, bad JSON).
  static Future<Map<String, dynamic>?> checkBeforePay({
    required BuildContext context,
    required String userId,
    required String serverToken,
    required String cartId,
  }) async {
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final url = '$baseUrl/api/user/check_before_pay';
    final body = json.encode({
      'user_id': userId,
      'server_token': serverToken,
      'cart_id': cartId,
    });
    debugPrint('[SETTLEMENT] check_before_pay → $body');
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
          .timeout(const Duration(seconds: 10));
      debugPrint(
        '[SETTLEMENT] check_before_pay ← ${response.statusCode} ${response.body}',
      );
      final decoded = json.decode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('[SETTLEMENT] check_before_pay error: $e');
      return null;
    }
  }

  // ── Reading responses ─────────────────────────────────────────────────────

  static Map? _data(Map? res) => res?['data'] is Map ? res!['data'] as Map : null;

  static Map? _order(Map? res) {
    final d = _data(res);
    for (final src in [res, d]) {
      for (final key in const ['order', 'courier_order']) {
        if (src?[key] is Map) return src![key] as Map;
      }
    }
    return null;
  }

  /// The order_payment object, where some responses put the order's id.
  static Map? _orderPayment(Map? res) {
    if (res?['order_payment'] is Map) return res!['order_payment'] as Map;
    final d = _data(res);
    return d?['order_payment'] is Map ? d!['order_payment'] as Map : null;
  }

  static String? _nonEmpty(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty || s == 'null' ? null : s;
  }

  /// `state` from check_before_pay: NONE, PENDING, PAID or ORDER_CREATED.
  static String stateOf(Map? res) =>
      (_nonEmpty(res?['state']) ?? _nonEmpty(_data(res)?['state']) ?? '')
          .toUpperCase();

  /// The created order's id, if the backend has created it.
  static String? orderIdOf(Map? res) =>
      _nonEmpty(res?['order_id']) ??
      _nonEmpty(_data(res)?['order_id']) ??
      _nonEmpty(_order(res)?['_id']) ??
      _nonEmpty(_orderPayment(res)?['order_id']);

  /// The created order's unique id (the number shown to the customer).
  static String? orderUniqueIdOf(Map? res) =>
      _nonEmpty(res?['order_unique_id']) ??
      _nonEmpty(_data(res)?['order_unique_id']) ??
      _nonEmpty(_order(res)?['unique_id']) ??
      _nonEmpty(_orderPayment(res)?['order_unique_id']);

  /// True once the backend reports a created order.
  static bool hasOrder(Map? res) =>
      orderIdOf(res) != null || orderUniqueIdOf(res) != null;

  static String _status(Map? res) =>
      (_nonEmpty(res?['status']) ?? _nonEmpty(_data(res)?['status']) ?? '')
          .toUpperCase();

  /// True when the payment itself failed (the user may start a new payment).
  static bool isFailed(Map? res) => failedStatuses.contains(_status(res));

  /// True when the payment is confirmed (the order may still be in progress).
  static bool isPaid(Map? res) {
    bool yes(dynamic v) => v == true || v == 'true';
    final d = _data(res);
    final status = _status(res);
    return yes(res?['is_paid']) ||
        yes(d?['is_paid']) ||
        status == 'SUCCESSFUL' ||
        status == 'SUCCESS' ||
        status == 'COMPLETED' ||
        status == 'PAID' ||
        _nonEmpty(res?['settlement_status']) != null ||
        _nonEmpty(d?['settlement_status']) != null;
  }

  // ── Checking for the created order ────────────────────────────────────────

  /// Asks the backend for this payment's order. Uses /api/zooryapay/status
  /// when the payment went through ZOORYA-PAY (it creates the order on the
  /// spot if the payment is confirmed but settlement hasn't run), otherwise
  /// /admin/check_paid_order. Returns the decoded body, or null.
  static Future<Map?> checkOrder({
    required BuildContext context,
    required String userId,
    required String serverToken,
    required String orderPaymentId,
    String? orderPaymentUniqueId,
  }) async {
    final zooryaId = await ZooryaPayService.paymentIdFor(orderPaymentUniqueId);
    if (!context.mounted) return null;
    final res = zooryaId != null
        ? await ZooryaPayService.status(
            context: context,
            userId: userId,
            serverToken: serverToken,
            zooryapayPaymentId: zooryaId,
          )
        : await ZooryaPayService.checkPaidOrder(
            context: context,
            userId: userId,
            serverToken: serverToken,
            orderPaymentId: orderPaymentId,
          );
    return res is Map ? res : null;
  }

  // ── Pending payment (re-checked on app reopen) ────────────────────────────

  static Future<void> savePending({
    required String orderPaymentId,
    required String orderPaymentUniqueId,
    bool isCourier = false,
  }) async {
    await Service.save(_pendingKey, {
      'order_payment_id': orderPaymentId,
      'order_payment_unique_id': orderPaymentUniqueId,
      'is_courier': isCourier,
      'saved_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> clearPending() => Service.remove(_pendingKey);

  /// Re-checks a payment that was still pending when the app closed. Call on
  /// app start (home screen) and when an "order placed" push is opened.
  /// Shows a message when the order now exists; stays silent otherwise.
  static Future<void> resumePending(BuildContext context) async {
    try {
      final pending = await Service.read(_pendingKey);
      if (pending is! Map) return;
      final savedAt = DateTime.tryParse('${pending['saved_at']}');
      if (savedAt == null ||
          DateTime.now().difference(savedAt) > pendingMaxAge) {
        await clearPending();
        return;
      }
      final user = await Service.read('user');
      if (user == null || user['user'] == null) return;
      if (!context.mounted) return;

      final map = await checkOrder(
        context: context,
        userId: user['user']['_id'],
        serverToken: user['user']['server_token'],
        orderPaymentId: '${pending['order_payment_id']}',
        orderPaymentUniqueId: '${pending['order_payment_unique_id']}',
      );
      if (hasOrder(map)) {
        await clearPending();
        if (!context.mounted) return;
        final ref = orderUniqueIdOf(map) ?? '${pending['order_payment_unique_id']}';
        Service.showMessage(
          context: context,
          title: 'Your order #$ref has been placed.',
          error: false,
          duration: 5,
        );
      } else if (isFailed(map)) {
        await clearPending();
      }
    } catch (e) {
      debugPrint('[SETTLEMENT] resumePending error: $e');
    }
  }
}
