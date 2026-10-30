import 'dart:async';
import 'dart:convert';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:zmall/utils/constants.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';

/// Wegagen Bank USSD payment.
///
/// Unlike the other gateways, Wegagen confirms the charge synchronously in the
/// response, so there is no separate verify/polling step. This screen pops with:
///   * `true`  -> payment approved, caller should create the order
///   * `false` -> payment failed/declined, caller should let the user retry
class WegagenUssd extends StatefulWidget {
  const WegagenUssd({
    super.key,
    required this.url,
    required this.hisab,
    required this.phone,
    required this.traceNo,
    required this.orderPaymentId,
    required this.orderPaymentUniqueId,
    this.title = "Wegagen Bank",
  });
  final String url;
  final String title;
  final double hisab;
  final String phone;
  final String traceNo;
  final String orderPaymentId;

  /// The numeric order-payment unique id (e.g. "597169"). The backend's
  /// `order_payment.unique_id` is a Number, so this is sent as `invoiceId`
  /// (kept clean/numeric) while `referenceId` carries the unique-per-attempt
  /// value Wegagen requires.
  final String orderPaymentUniqueId;

  @override
  _WegagenUssdState createState() => _WegagenUssdState();
}

class _WegagenUssdState extends State<WegagenUssd> {
  @override
  void initState() {
    super.initState();
    _initPayment();
  }

  void _initPayment() async {
    var data = await initPayment();
    if (!mounted) return;
    final approved = _isApproved(data);
    _logPaymentResult(data, approved);
    if (data != null && approved) {
      Service.showMessage(
        context: context,
        title: "Payment approved. Creating your order...",
        error: false,
        duration: 3,
      );
      Navigator.pop(context, true);
    } else {
      Service.showMessage(
        context: context,
        title:
            "${_message(data) ?? 'Payment could not be completed'}. Please try other payment methods",
        error: true,
        duration: 4,
      );
      await Future.delayed(Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pop(context, false);
    }
  }

  /// Prints a detailed, icon-prefixed breakdown of the payment result once the
  /// Wegagen charge has completed. Use `flutter run | grep "\[Wegagen\]"` to
  /// follow only these lines.
  void _logPaymentResult(dynamic data, bool approved) {
    // final params = (data is Map && data['params'] is Map)
    // ? data['params'] as Map
    // : const {};

    // String row(String icon, String label, dynamic value) =>
    //     '[Wegagen] $icon $label: ${value ?? '-'}';

    // final headerIcon = approved ? '🟩✅' : '🟥❌';
    // debugPrint('[Wegagen] ──────── Payment Result ────────');
    // debugPrint('$headerIcon ${approved ? 'PAYMENT APPROVED' : 'PAYMENT FAILED'}', );
    // debugPrint(row('💳', 'Method', 'Wegagen Bank'));
    // debugPrint(row('🧾', 'Order Payment ID', widget.orderPaymentId));
    // debugPrint(row('🔖', 'Trace No', widget.traceNo));
    // debugPrint(row('💰', 'Amount', widget.hisab.toStringAsFixed(2)));
    // debugPrint(row('📟', 'Response Code', data is Map ? data['responseCode'] : null),);
    // debugPrint(row('⚠️', 'Error Code', data is Map ? data['errorCode'] : null));
    // debugPrint(row('📝', 'Response Msg', data is Map ? data['responseMsg'] : null),);
    // debugPrint(row('📌', 'State', params['state']));
    // debugPrint(row('🆔', 'Transaction ID', params['transactionId']));
    // debugPrint(row('🏦', 'Issuer Txn ID', params['issuerTransactionId']));
    // debugPrint(row('🔗', 'Reference ID', params['referenceId']));
    // debugPrint(row('💵', 'Charged Amount', params['txAmount']));
    // if (!approved) {  debugPrint(row('🛑', 'Failure Reason', _message(data)));}
    // debugPrint( row('🧭',  'Next Step', approved ? 'Creating order' : 'Retry / choose another method', ),);
    // debugPrint('[Wegagen] ────────────────────────────────');
    // debugPrint('[Wegagen] 📦 Raw response: $data');
  }

  /// The gateway may answer with a raw schema (responseCode "2001" /
  /// params.state "APPROVED") or a backend-wrapped {"success": true}.
  bool _isApproved(dynamic data) {
    if (data is! Map) return false;
    if (data['success'] == true) return true;
    if (data['responseCode']?.toString() == "2001") return true;
    final state = (data['params'] is Map)
        ? data['params']['state']?.toString().toUpperCase()
        : null;
    return state == "APPROVED";
  }

  String? _message(dynamic data) {
    if (data is! Map) return null;
    return (data['message'] ?? data['responseMsg'] ?? data['errorCode'])
        ?.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: kBlackColor)),
        elevation: 1.0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pay Using Wegagen Bank',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Powered by Wegagen Bank',
                    style: TextStyle(fontSize: 21, color: Colors.black45),
                  ),
                ],
              ),
              Image.asset(
                "images/payment/wegagen_real.png",
                height: getProportionateScreenHeight(kDefaultPadding * 10),
                width: getProportionateScreenWidth(kDefaultPadding * 10),
              ),
              SizedBox(
                height: getProportionateScreenHeight(kDefaultPadding / 2),
              ),
              SpinKitPouringHourGlassRefined(color: kBlackColor),
              SizedBox(
                height: getProportionateScreenHeight(kDefaultPadding / 2),
              ),
              Text(
                "Processing your Wegagen Bank payment. \nPlease wait....",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⚠️ TEMPORARY TEST OVERRIDE — remove before production.
  // Wegagen's test system only recognizes specific registered accounts, so we
  // force the known-good test account. In production use "251${widget.phone}".
  // static const bool _useTestAccount = true;
  // static const String _testAccountNo = "251947635677";
  Future<dynamic> initPayment() async {
    // final accountNo = _useTestAccount ? _testAccountNo : "251${widget.phone}";

    // Wegagen rejects a referenceId it has seen before ("Duplicate
    // reference_id"), so we append a timestamp to keep every attempt unique.
    // final unique = "${widget.traceNo}_${DateTime.now().millisecondsSinceEpoch}";

    // invoiceId must be the clean numeric order-payment unique id: the backend
    // casts it to `order_payment.unique_id` (a Number). Sending the compound
    // `unique` (with underscores) caused a 500 CastError. Strip to digits only
    // so the cast can never fail.
    final invoiceId = widget.orderPaymentUniqueId.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    Map data = {
      "requestId":
          "purchase-${widget.traceNo}", //purchase-widget.traceNo format
      "referenceId": widget.traceNo, //just use trace number
      "invoiceId": invoiceId,
      "accountNo": "251${widget.phone}", //for dynamic use
      "amount": widget.hisab.toStringAsFixed(2),
      "description": "ZMall order payment",
    };

    var body = json.encode(data);
    // debugPrint('[WegagenUssd] POST ${widget.url}');
    // debugPrint('[WegagenUssd] request body: $body');
    try {
      http.Response response = await http
          .post(
            Uri.parse(widget.url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            Duration(seconds: 60),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );

      // debugPrint('[WegagenUssd] status: ${response.statusCode}');
      // debugPrint('[WegagenUssd] response body: ${response.body}');
      return json.decode(response.body);
    } catch (e) {
      // debugPrint('[WegagenUssd] request failed: $e');
      if (mounted) {
        Service.showMessage(
          context: context,
          title: "Something went wrong. Please check your internet connection!",
          error: true,
        );
      }
      return null;
    }
  }
}
