import 'dart:async';
import 'dart:convert';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';

class TelebirrUssd extends StatefulWidget {
  const TelebirrUssd({
    Key? key,
    this.url = "",
    required this.hisab,
    required this.phone,
    required this.traceNo,
    required this.orderPaymentId,
    this.title = "telebirr",
    this.isAbroad = false,
    required this.serverToken,
    required this.userId,
    this.isZooryaPay = false,
    this.uniqueId,
    this.imageUrl,
    this.type = 'ussd',
  }) : super(key: key);

  final String url;
  final String title;
  final double hisab;
  final String phone;
  final String traceNo;
  final String orderPaymentId;
  final bool isAbroad;
  final String userId;
  final String serverToken;
  final bool isZooryaPay;
  final String? uniqueId;
  final String? imageUrl;
  final String type;

  @override
  _TelebirrUssdState createState() => _TelebirrUssdState();
}

class _TelebirrUssdState extends State<TelebirrUssd> {
  bool _loading = false;
  String telebirrUrl = "";
  String uuid = "";
  int _verifyAttempt = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('==================== [TelebirrUssd] INIT ====================');
    debugPrint('[TelebirrUssd] Widget Params:');
    debugPrint('[TelebirrUssd]   isZooryaPay: ${widget.isZooryaPay}');
    debugPrint('[TelebirrUssd]   url: ${widget.url}');
    debugPrint('[TelebirrUssd]   phone: ${widget.phone}');
    debugPrint('[TelebirrUssd]   traceNo: ${widget.traceNo}');
    debugPrint('[TelebirrUssd]   hisab: ${widget.hisab}');
    debugPrint('[TelebirrUssd]   orderPaymentId: ${widget.orderPaymentId}');
    debugPrint('[TelebirrUssd]   userId: ${widget.userId}');
    debugPrint('[TelebirrUssd]   title: ${widget.title}');
    debugPrint('[TelebirrUssd]   isAbroad: ${widget.isAbroad}');
    debugPrint('=============================================================');
    _initTelebirr();
  }

  void _initTelebirr() async {
    if (widget.isZooryaPay) {
      debugPrint('[TelebirrUssd] 🚀 Initiating ZooryaPay Telebirr USSD...');
      final result = await ZooryaPayService.pay(
        context: context,
        userId: widget.userId,
        serverToken: widget.serverToken,
        method: 'telebirr',
        uniqueId: widget.uniqueId ?? widget.traceNo,
        amount: widget.hisab,
        phoneNumber: widget.phone,
      );
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        debugPrint('[TelebirrUssd] ✅ ZooryaPay Telebirr USSD initiated! Starting verify polling...');
        _verifyPayment();
      } else {
        final msg = result?['message']?.toString() ??
            "Telebirr payment initiation failed. Please try again.";
        debugPrint('[TelebirrUssd] ❌ ZooryaPay Telebirr init failed: $msg');
        Service.showMessage(
          context: context,
          title: msg,
          error: true,
          duration: 5,
        );
      }
      return;
    }

    debugPrint('[TelebirrUssd] Calling initTelebirr()...');
    var data = await initTelebirr();
    debugPrint('[TelebirrUssd] initTelebirr returned: $data');
    if (!mounted) return;

    if (data != null &&
        data['result'] != null &&
        data['result']['success'] == true) {
      debugPrint(
        '[TelebirrUssd] ✅ Init successful: ${data['result']['message']}',
      );
      _verifyPayment();
    } else {
      debugPrint('[TelebirrUssd] ❌ Init failed or unapproved: $data');
      final errorMsg =
          (data != null &&
                  data['result'] != null &&
                  data['result']['message'] != null)
              ? data['result']['message'].toString()
              : "Telebirr USSD initialization failed";
      Service.showMessage(
        context: context,
        title: errorMsg,
        error: true,
        duration: 6,
      );
    }
  }

  void _verifyPayment() async {
    if (!mounted) return;
    _verifyAttempt++;
    debugPrint(
      '[TelebirrUssd] 🔄 Verify payment polling attempt #$_verifyAttempt...',
    );

    if (widget.isZooryaPay) {
      final result = await ZooryaPayService.checkPaidOrder(
        context: context,
        userId: widget.userId,
        serverToken: widget.serverToken,
        orderPaymentId: widget.orderPaymentId,
      );
      if (!mounted) return;

      bool isPaid = false;
      if (result != null) {
        if (result['success'] == true || result['success'] == 'true') isPaid = true;
        if (result['is_paid'] == true || result['is_paid'] == 'true') isPaid = true;
        if (result['paid'] == true || result['paid'] == 'true') isPaid = true;
        if (result['data'] is Map) {
          final data = result['data'] as Map;
          if (data['is_paid'] == true || data['is_paid'] == 'true') isPaid = true;
          if (data['paid'] == true || data['paid'] == 'true') isPaid = true;
          if (data['status'] == 'PAID' || data['status'] == 'COMPLETED') isPaid = true;
        }
      }

      if (isPaid) {
        debugPrint('[TelebirrUssd] ✅ ZooryaPay Telebirr payment verified! check_paid_order response: $result');
        // Return the check_paid_order response itself — the backend creates
        // the order inside check_paid_order, so the caller uses this response
        // instead of calling /api/user/create_order.
        Navigator.pop(context, result);
      } else {
        if (_verifyAttempt < 60) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) _verifyPayment();
        }
      }
      return;
    }

    var data = await verifyPayment();
    debugPrint(
      '[TelebirrUssd] Verify attempt #$_verifyAttempt response: $data',
    );
    if (!mounted) return;

    if (data != null && data['success'] == true) {
      debugPrint(
        '[TelebirrUssd] ✅ Payment verified successfully! Closing screen.',
      );
      Navigator.pop(context, true);
    } else {
      debugPrint(
        '[TelebirrUssd] ⏳ Payment not yet completed. Re-checking in 2 seconds...',
      );
      await Future.delayed(
        Duration(seconds: 2),
      );
      if (mounted) {
        _verifyPayment();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.isZooryaPay
                      ? 'Pay Using ${widget.type.toUpperCase()}'
                      : 'Pay Using telebirr',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isZooryaPay
                      ? 'Pay With ZooryaPay'
                      : 'Powered by Ethiotelecom',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                SizedBox(
                  height: getProportionateScreenHeight(kDefaultPadding * 2),
                ),
                _buildTelebirrLogo(context),
                SizedBox(
                  height: getProportionateScreenHeight(kDefaultPadding * 2),
                ),
                const SpinKitPouringHourGlassRefined(
                  color: Colors.black,
                  size: 40,
                ),
                SizedBox(
                  height: getProportionateScreenHeight(kDefaultPadding),
                ),
                const Text(
                  "Please complete payment through the USSD prompt.\nWaiting for payment to be completed....",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Color(0xFF2C2C2E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTelebirrLogo(BuildContext context) {
    final img = widget.imageUrl ?? '';
    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        height: 65,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackLogo(),
      );
    }
    if (img.startsWith('web_images/')) {
      try {
        final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
        return Image.network(
          '$baseUrl/$img',
          height: 65,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackLogo(),
        );
      } catch (_) {
        return _fallbackLogo();
      }
    }
    return _fallbackLogo();
  }

  Widget _fallbackLogo() {
    return Image.asset(
      "images/payment/telebirr.png",
      height: 65,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        "images/payment/new_payment/telebirr.png",
        height: 65,
        fit: BoxFit.contain,
      ),
    );
  }

  Future<dynamic> initTelebirr() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    var url = widget.url;

    //New configuration
    Map data = {
      "traceNo": widget.traceNo,
      "amount": widget.hisab,
      "phone": "251${widget.phone}",
      "payerId": "22",
      "appId": "1234",
      "apiKey": "90e503b019a811ef9bc8005056a4ed36",
      "zmall": true,
      "channel": "zmalltest",
    };

    /*  
    //Old configuration.
    //  Map data = {
    //   "trace_no": widget.traceNo,
    //   "amount": widget.hisab,
    //   "phone": widget.phone,
    //   "appId": "1234"
    }; */

    var body = json.encode(data);
    debugPrint('[TelebirrUssd] ─── initTelebirr Request ───');
    debugPrint('[TelebirrUssd] POST URL: $url');
    debugPrint(
      '[TelebirrUssd] Headers: {"Content-Type": "application/json", "Accept": "application/json"}',
    );
    debugPrint('[TelebirrUssd] Request Body: $body');
    debugPrint('[TelebirrUssd] ────────────────────────────');

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
            Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[TelebirrUssd] ⚠️ Request timed out after 10s!');
              throw TimeoutException("The connection has timed out!");
            },
          );

      debugPrint('[TelebirrUssd] ─── initTelebirr Response ───');
      debugPrint('[TelebirrUssd] Status Code: ${response.statusCode}');
      debugPrint('[TelebirrUssd] Raw Body: ${response.body}');
      debugPrint('[TelebirrUssd] ─────────────────────────────');

      return json.decode(response.body);
    } catch (e, stackTrace) {
      debugPrint('[TelebirrUssd] ❌ Error in initTelebirr: $e');
      debugPrint('[TelebirrUssd] StackTrace: $stackTrace');

      if (mounted) {
        Service.showMessage(
          context: context,
          title: "Something went wrong. Please check your internet connection!",
          error: true,
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          this._loading = false;
        });
      }
    }
  }

  Future<dynamic> verifyPayment() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/admin/check_paid_order";

    Map data = {
      "user_id": widget.userId,
      "server_token": widget.serverToken,
      "order_payment_id": widget.orderPaymentId,
    };

    var body = json.encode(data);
    debugPrint('[TelebirrUssd] ─── verifyPayment Request ───');
    debugPrint('[TelebirrUssd] POST URL: $url');
    debugPrint('[TelebirrUssd] Request Body: $body');
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
            Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[TelebirrUssd] ⚠️ verifyPayment timed out after 10s');
              throw TimeoutException("The connection has timed out!");
            },
          );

      debugPrint(
        '[TelebirrUssd] verifyPayment Status: ${response.statusCode}',
      );
      debugPrint('[TelebirrUssd] verifyPayment Raw Body: ${response.body}');
      return json.decode(response.body);
    } catch (e, stackTrace) {
      debugPrint('[TelebirrUssd] ❌ Error in verifyPayment: $e');
      debugPrint('[TelebirrUssd] StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          this._loading = false;
        });

        Service.showMessage(
          context: context,
          title: "Checking if payment is made. Please wait a moment...",
          error: true,
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          this._loading = false;
        });
      }
    }
  }
}
