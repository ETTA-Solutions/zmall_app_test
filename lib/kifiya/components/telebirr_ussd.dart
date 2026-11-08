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
  // 2-minute check window (ZooryaPayService.pollWindow).
  DateTime? _verifyStartedAt;
  int _verifyGen = 0;
  bool _timedOut = false;
  bool _manualChecking = false;

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
        _startVerify();
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
      _startVerify();
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

  /// Starts (or restarts) the check loop with a fresh 2-minute window.
  void _startVerify() {
    _verifyGen++;
    _verifyAttempt = 0;
    _verifyStartedAt = DateTime.now();
    if (mounted) setState(() => _timedOut = false);
    _verifyPayment(_verifyGen);
  }

  /// One call to /admin/check_paid_order. Returns the response when paid,
  /// otherwise null.
  Future<dynamic> _checkOnce() async {
    if (widget.isZooryaPay) {
      final result = await ZooryaPayService.checkPaidOrder(
        context: context,
        userId: widget.userId,
        serverToken: widget.serverToken,
        orderPaymentId: widget.orderPaymentId,
      );
      return ZooryaPayService.isPaid(result) ? result : null;
    }
    final data = await verifyPayment();
    return (data != null && data['success'] == true) ? data : null;
  }

  void _onPaid(dynamic result) {
    debugPrint('[TelebirrUssd] ✅ Payment verified! Response: $result');
    _verifyGen++; // stop the loop
    if (widget.isZooryaPay) {
      // The backend creates the order inside check_paid_order, so return
      // that response instead of calling /api/user/create_order.
      Navigator.pop(context, result);
    } else {
      Navigator.pop(context, true);
    }
  }

  /// Check → wait for the answer → wait 2s → check again, for up to
  /// 2 minutes. After that, stop and let the user resend or check again.
  void _verifyPayment(int gen) async {
    while (mounted && gen == _verifyGen) {
      final elapsed = DateTime.now().difference(_verifyStartedAt!);
      if (elapsed >= ZooryaPayService.pollWindow) {
        debugPrint(
          '[TelebirrUssd] ⏱️ Stopped checking after 2 min ($_verifyAttempt checks).',
        );
        setState(() => _timedOut = true);
        return;
      }
      _verifyAttempt++;
      debugPrint('[TelebirrUssd] 🔄 Check #$_verifyAttempt');
      final paid = await _checkOnce();
      if (!mounted || gen != _verifyGen) return;
      if (paid != null) {
        _onPaid(paid);
        return;
      }
      await Future.delayed(ZooryaPayService.pollInterval);
    }
  }

  /// "I've paid, check again" — a single check.
  Future<void> _manualCheck() async {
    setState(() => _manualChecking = true);
    final paid = await _checkOnce();
    if (!mounted) return;
    setState(() => _manualChecking = false);
    if (paid != null) {
      _onPaid(paid);
    } else {
      Service.showMessage(
        context: context,
        title: "Payment not received yet. Resend the prompt to try again.",
        error: true,
        duration: 4,
      );
    }
  }

  /// "Resend prompt" — sends a new USSD prompt and starts a new 2 minutes.
  void _resend() {
    setState(() => _timedOut = false);
    _initTelebirr();
  }

  Widget _buildTimedOut() {
    return Column(
      children: [
        const Icon(Icons.timer_off_outlined, size: 40, color: Color(0xFF8E8E93)),
        SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
        const Text(
          "We couldn't confirm your payment",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          "The prompt may have expired. Resend it, or check again if you already paid.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF6B7280)),
        ),
        SizedBox(height: getProportionateScreenHeight(kDefaultPadding * 1.5)),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_loading || _manualChecking) ? null : _resend,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Resend prompt',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: (_loading || _manualChecking) ? null : _manualCheck,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _manualChecking
                ? const SpinKitThreeBounce(color: Colors.black, size: 18)
                : const Text(
                    "I've paid, check again",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
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
          child: SingleChildScrollView(
            padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                if (_timedOut)
                  _buildTimedOut()
                else ...[
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
