// =============================================================================
// ZOORYAPAY TELEBIRR USSD  (new flow — NOT the original Telebirr USSD)
// =============================================================================
// Telebirr USSD push routed through the ZOORYA-PAY gateway.
//
//   * Shown when the user taps the ZOORYA-PAY method whose key is "telebirr".
//     The card title / logo come from the backend (payment_gateway ->
//     ZOORYA-PAY -> methods[].name / image_url), so the UI shows whatever
//     name the backend sends.
//   * Init  : POST {baseUrl}/api/zooryapay/pay      (ZooryaPayService.pay)
//   * Verify: POST {baseUrl}/admin/check_paid_order (ZooryaPayService.checkPaidOrder)
//     polled every ZooryaPayService.pollInterval for ZooryaPayService.pollWindow.
//   * The backend creates the order inside check_paid_order, so on success
//     this screen pops with that response (handled by
//     _onZooryaTelebirrResult in kifiya_screen.dart).
//
// The ORIGINAL Telebirr USSD (Odoo /telebirr/ussd/send_sms, gateway name
// "tele birr") lives separately in lib/kifiya/components/telebirr_ussd.dart
// (TelebirrUssd). Keep the two stand-alone — do not merge them again.
// =============================================================================
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_brand.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';

class ZooryaTelebirrUssd extends StatefulWidget {
  const ZooryaTelebirrUssd({
    Key? key,
    required this.hisab,
    required this.phone,
    required this.traceNo,
    required this.orderPaymentId,
    this.title = "telebirr",
    this.isAbroad = false,
    required this.serverToken,
    required this.userId,
    this.uniqueId,
    this.imageUrl,
    this.type = 'ussd',
  }) : super(key: key);

  final String title;
  final double hisab;
  final String phone;
  final String traceNo;
  final String orderPaymentId;
  final bool isAbroad;
  final String userId;
  final String serverToken;
  final String? uniqueId;
  final String? imageUrl;
  final String type;

  @override
  _ZooryaTelebirrUssdState createState() => _ZooryaTelebirrUssdState();
}

class _ZooryaTelebirrUssdState extends State<ZooryaTelebirrUssd> {
  bool _loading = false;
  int _verifyAttempt = 0;
  // 2-minute check window (ZooryaPayService.pollWindow).
  DateTime? _verifyStartedAt;
  int _verifyGen = 0;
  bool _timedOut = false;
  bool _manualChecking = false;

  @override
  void initState() {
    super.initState();
    debugPrint('================ [ZooryaTelebirrUssd] INIT ================');
    debugPrint('[ZooryaTelebirrUssd] Widget Params:');
    debugPrint('[ZooryaTelebirrUssd]   phone: ${widget.phone}');
    debugPrint('[ZooryaTelebirrUssd]   traceNo: ${widget.traceNo}');
    debugPrint('[ZooryaTelebirrUssd]   hisab: ${widget.hisab}');
    debugPrint('[ZooryaTelebirrUssd]   orderPaymentId: ${widget.orderPaymentId}');
    debugPrint('[ZooryaTelebirrUssd]   userId: ${widget.userId}');
    debugPrint('[ZooryaTelebirrUssd]   title: ${widget.title}');
    debugPrint('[ZooryaTelebirrUssd]   isAbroad: ${widget.isAbroad}');
    debugPrint('=============================================================');
    _initTelebirr();
  }

  /// Sends the telebirr USSD push through ZOORYA-PAY, then starts polling.
  void _initTelebirr() async {
    debugPrint('[ZooryaTelebirrUssd] 🚀 Initiating ZooryaPay Telebirr USSD...');
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
      debugPrint('[ZooryaTelebirrUssd] ✅ ZooryaPay Telebirr USSD initiated! Starting verify polling...');
      _startVerify();
    } else {
      final msg = result?['message']?.toString() ??
          "Telebirr payment initiation failed. Please try again.";
      debugPrint('[ZooryaTelebirrUssd] ❌ ZooryaPay Telebirr init failed: $msg');
      Service.showMessage(
        context: context,
        title: msg,
        error: true,
        duration: 5,
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
    final result = await ZooryaPayService.checkPaidOrder(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      orderPaymentId: widget.orderPaymentId,
    );
    return ZooryaPayService.isPaid(result) ? result : null;
  }

  void _onPaid(dynamic result) {
    debugPrint('[ZooryaTelebirrUssd] ✅ Payment verified! Response: $result');
    _verifyGen++; // stop the loop
    // The backend creates the order inside check_paid_order, so return
    // that response instead of calling /api/user/create_order.
    Navigator.pop(context, result);
  }

  /// Check → wait for the answer → wait 2s → check again, for up to
  /// 2 minutes. After that, stop and let the user resend or check again.
  void _verifyPayment(int gen) async {
    while (mounted && gen == _verifyGen) {
      final elapsed = DateTime.now().difference(_verifyStartedAt!);
      if (elapsed >= ZooryaPayService.pollWindow) {
        debugPrint(
          '[ZooryaTelebirrUssd] ⏱️ Stopped checking after 2 min ($_verifyAttempt checks).',
        );
        setState(() => _timedOut = true);
        return;
      }
      _verifyAttempt++;
      debugPrint('[ZooryaTelebirrUssd] 🔄 Check #$_verifyAttempt');
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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(kDefaultPadding * 1.5),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    _buildTelebirrLogo(context),
                    const SizedBox(height: 28),
                    Text(
                      'Pay with ${widget.type.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Secured by Zoorya Pay',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, color: Color(0xFF8E8E93)),
                    ),
                    const SizedBox(height: 40),
                    if (_timedOut)
                      _buildTimedOut()
                    else ...[
                      const SpinKitPouringHourGlassRefined(
                        color: Colors.black,
                        size: 56,
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        "Complete the payment on the USSD prompt.\nWaiting for confirmation…",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Color(0xFF2C2C2E),
                        ),
                      ),
                    ],
                    const Spacer(flex: 3),
                    const ZooryaPayBadge(height: 56),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
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
        height: 110,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackLogo(),
      );
    }
    if (img.startsWith('web_images/')) {
      try {
        final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
        return Image.network(
          '$baseUrl/$img',
          height: 110,
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
      height: 110,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        "images/payment/new_payment/telebirr.png",
        height: 110,
        fit: BoxFit.contain,
      ),
    );
  }
}
