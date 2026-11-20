import 'package:flutter/material.dart';
import 'zoorya_brand.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_service.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// ZOORYA-PAY USSD waiting screen.
/// Used for: telebirr, mpesa, nib, zemen, ethswitch, dashen
///
/// Features authentic ZOORYA-PAY theme with #06182A background and #45B5E4 accents.
class ZooryaPayUssdScreen extends StatefulWidget {
  const ZooryaPayUssdScreen({
    Key? key,
    required this.method,
    required this.displayName,
    this.type = 'ussd',
    this.imageUrl,
    required this.amount,
    required this.userId,
    required this.serverToken,
    required this.uniqueId,
    required this.orderPaymentId,
    required this.phoneNumber,
  }) : super(key: key);

  /// ZOORYA-PAY method key: 'telebirr', 'mpesa', 'nib', 'zemen', 'ethswitch', 'dashen'
  final String method;

  /// Human-readable name shown in the AppBar title
  final String displayName;

  /// Dynamic payment type from backend: e.g. 'ussd', 'qr', 'otp'
  final String type;

  /// Dynamic image URL from backend: e.g. 'web_images/dashen.png'
  final String? imageUrl;

  final double amount;
  final String userId;
  final String serverToken;

  /// order_payment unique_id  (used in /api/zooryapay/pay payload)
  final String uniqueId;

  /// order_payment_id  (used in /admin/check_paid_order payload)
  final String orderPaymentId;

  /// Phone number (e.g. "912345678")
  final String phoneNumber;

  @override
  State<ZooryaPayUssdScreen> createState() => _ZooryaPayUssdScreenState();
}

class _ZooryaPayUssdScreenState extends State<ZooryaPayUssdScreen> {
  bool _payInitiated = false;
  bool _payError = false;
  String _errorMessage = '';
  int _pollAttempt = 0;
  // Checks stop after ZooryaPayService.pollWindow (2 min).
  int _pollGen = 0;
  DateTime? _pollStartedAt;
  bool _pollTimedOut = false;
  bool _manualChecking = false;

  // Zoorya Pay Brand Colors
  static const Color _zooryaDarkBg = Color(0xFF06182A);
  static const Color _zooryaCyan = Color(0xFF45B5E4);
  static const Color _cardSurface = Color(0xFF0B2238);
  static const Color _cardSurfaceLight = Color(0xFF0D2A45);

  // Primary brand colour per method:
  Color get _methodColor {
    switch (widget.method) {
      case 'ethswitch':
      case 'ethswitch_qr':
        return const Color(0xFFF37423); // EthSwitch Orange
      case 'zemen':
      case 'zemen_qr':
        return const Color(0xFFD3214B); // Zemen Red
      case 'nib':
      case 'nib_qr':
        return const Color(0xFF8A4D21); // Nib Brown
      case 'dashen':
        return kZooryaBlue; // Dashen Navy
      case 'mpesa':
      case 'telebirr':
      case 'telebirr_qr':
      default:
        return _zooryaCyan; // #45B5E4
    }
  }

  // Secondary / Accent colour per method
  Color get _methodSecondaryColor {
    switch (widget.method) {
      case 'zemen':
      case 'zemen_qr':
        return const Color(0xFF1A1A1A); // Zemen Black
      case 'nib':
      case 'nib_qr':
        return const Color(0xFFFEB914); // Nib Yellow / Gold
      case 'dashen':
        return kZooryaBlue; // Dashen Gold
      case 'ethswitch':
      case 'ethswitch_qr':
        return const Color(0xFF142548); // EthSwitch Navy
      case 'mpesa':
      case 'telebirr':
      case 'telebirr_qr':
      default:
        return _zooryaDarkBg; // #06182A
    }
  }

  // Method logo image asset
  String get _methodLogo {
    switch (widget.method) {
      case 'ethswitch':
      case 'ethswitch_qr':
        return 'images/payment/new_payment/ethswitch.png';
      case 'zemen':
      case 'zemen_qr':
        return 'images/payment/new_payment/zemen.png';
      case 'nib':
      case 'nib_qr':
        return 'images/payment/new_payment/nib_bank.png';
      case 'dashen':
        return 'images/payment/dashen.png';
      case 'mpesa':
        return 'images/payment/new_payment/mpesa.png';
      case 'telebirr':
      case 'telebirr_qr':
      default:
        return 'images/payment/new_payment/telebirr.png';
    }
  }

  // Method brand subtitle
  String get _methodSubtitle {
    switch (widget.method) {
      case 'ethswitch':
      case 'ethswitch_qr':
        return 'Powered by EthSwitch';
      case 'zemen':
      case 'zemen_qr':
        return 'Zemen Bank';
      case 'nib':
      case 'nib_qr':
        return 'Nib International Bank';
      case 'dashen':
        return 'Dashen Bank';
      case 'telebirr':
      case 'telebirr_qr':
        return 'Powered by Ethio telecom';
      case 'mpesa':
        return 'M-PESA';
      default:
        return 'Digital Payment';
    }
  }

  @override
  void initState() {
    super.initState();
    _initiatePay();
  }

  String get _normalizedPhone {
    String p = widget.phoneNumber.trim();
    if (p.startsWith('+251')) {
      p = '0${p.substring(4)}';
    } else if (p.startsWith('251')) {
      p = '0${p.substring(3)}';
    } else if (!p.startsWith('0') && p.isNotEmpty) {
      p = '0$p';
    }
    return p;
  }

  Future<void> _initiatePay() async {
    final phone = _normalizedPhone;
    debugPrint(
      '[ZooryaPayUssd] Initiating pay — method=${widget.method}, phone=$phone',
    );
    final result = await ZooryaPayService.pay(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      method: widget.method,
      uniqueId: widget.uniqueId,
      amount: widget.amount,
      phoneNumber: phone,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _payError = true;
        _errorMessage =
            'Could not connect to ZOORYA-PAY. Please check your internet connection.';
      });
      return;
    }

    if (result['success'] == true) {
      debugPrint('[ZooryaPayUssd] Pay initiated successfully. Starting poll.');
      setState(() {
        _payInitiated = true;
      });
      if (mounted) {
        Service.showMessage(
          context: context,
          title:
              'Payment request sent to ${widget.displayName}. '
              'Please complete the payment on your phone.',
          error: false,
          duration: 6,
        );
      }
      _startPolling();
    } else {
      final msg =
          result['message']?.toString() ??
          'Payment initiation failed. Please try again.';
      debugPrint('[ZooryaPayUssd] Pay failed: $msg');
      setState(() {
        _payError = true;
        _errorMessage = msg;
      });
      if (mounted) {
        Service.showMessage(
          context: context,
          title: msg,
          error: true,
          duration: 6,
        );
      }
    }
  }

  /// Starts (or restarts) checking with a fresh 2-minute window.
  void _startPolling() {
    _pollGen++;
    _pollAttempt = 0;
    _pollStartedAt = DateTime.now();
    if (mounted) setState(() => _pollTimedOut = false);
    _pollPaymentStatus(_pollGen);
  }

  /// Check → wait for the answer → wait 2s → check again, for up to 2 min.
  void _pollPaymentStatus(int gen) async {
    while (mounted && gen == _pollGen) {
      if (DateTime.now().difference(_pollStartedAt!) >=
          ZooryaPayService.pollWindow) {
        debugPrint(
          '[ZooryaPayUssd] ⏱️ Stopped checking after 2 min ($_pollAttempt checks).',
        );
        setState(() => _pollTimedOut = true);
        return;
      }
      _pollAttempt++;
      debugPrint(
        '[ZooryaPayUssd] Poll attempt #$_pollAttempt for orderPaymentId=${widget.orderPaymentId}',
      );
      final result = await ZooryaPayService.checkPaidOrder(
        context: context,
        userId: widget.userId,
        serverToken: widget.serverToken,
        orderPaymentId: widget.orderPaymentId,
      );
      if (!mounted || gen != _pollGen) return;
      if (ZooryaPayService.isPaid(result)) {
        debugPrint('[ZooryaPayUssd] Payment confirmed! Closing screen.');
        _pollGen++;
        // Return the check_paid_order response (backend creates the order).
        Navigator.pop(context, result is Map ? result : true);
        return;
      }
      await Future.delayed(ZooryaPayService.pollInterval);
    }
  }

  /// "I've paid, check again" — a single check after the 2 minutes.
  Future<void> _manualCheck() async {
    setState(() => _manualChecking = true);
    final result = await ZooryaPayService.checkPaidOrder(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      orderPaymentId: widget.orderPaymentId,
    );
    if (!mounted) return;
    setState(() => _manualChecking = false);
    if (ZooryaPayService.isPaid(result)) {
      Navigator.pop(context, result is Map ? result : true);
    } else {
      Service.showMessage(
        context: context,
        title: 'Payment not received yet. Resend the prompt to try again.',
        error: true,
        duration: 4,
      );
    }
  }

  /// "Resend prompt" — sends a new prompt and starts a new 2 minutes.
  void _resendPrompt() {
    setState(() {
      _pollTimedOut = false;
      _payInitiated = false;
      _pollAttempt = 0;
    });
    _initiatePay();
  }

  /// Shown after 2 minutes without a confirmed payment.
  Widget _buildTimedOutBody({required bool light}) {
    final ink = light ? _dInk : Colors.white;
    final muted = light ? _dMuted : Colors.white70;
    final accent = light ? _dNavy : _zooryaCyan;
    final onAccent = light ? Colors.white : _zooryaDarkBg;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
      margin: light
          ? EdgeInsets.zero
          : EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
      decoration: BoxDecoration(
        color: light ? Colors.white : _cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_off_outlined, size: 40, color: muted),
          const SizedBox(height: 14),
          Text(
            "We couldn't confirm your payment",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The prompt may have expired. Resend it, or check again if you already paid.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _manualChecking ? null : _resendPrompt,
              icon: Icon(Icons.refresh_rounded, color: onAccent),
              label: Text(
                'Resend prompt',
                style: TextStyle(
                  color: onAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _manualChecking ? null : _manualCheck,
            child: _manualChecking
                ? SpinKitThreeBounce(color: accent, size: 16)
                : Text(
                    "I've paid, check again",
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.method == 'dashen') {
      return _buildDashenCleanWhiteScaffold();
    }

    final isTelebirr = widget.method == 'telebirr';

    return Scaffold(
      backgroundColor: _zooryaDarkBg,
      appBar: AppBar(
        title: isTelebirr
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Image.asset(
                      'images/payment/new_payment/telebirr.png',
                      height: 20,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'telebirr USSD',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              )
            : Text(
                widget.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
        backgroundColor: _zooryaDarkBg,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: _payError
            ? _buildErrorBody()
            : _pollTimedOut
            ? Center(
                child: SingleChildScrollView(
                  child: _buildTimedOutBody(light: false),
                ),
              )
            : isTelebirr
            ? _buildTelebirrWaitingBody()
            : _buildGenericWaitingBody(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHEN — CLEAN LIGHT UI
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color _dNavy = kZooryaBlue;
  static const Color _dNavyDark = kZooryaBlueDark;
  static const Color _dGold = kZooryaBlue;
  static const Color _dBg = Color(0xFFF5F6FA);
  static const Color _dInk = Color(0xFF111827);
  static const Color _dMuted = Color(0xFF6B7280);

  String _dFormatAmount(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '$whole.${parts[1]}';
  }

  /// 0912345678 → 0912 345 678
  String get _dDisplayPhone {
    final p = _normalizedPhone;
    if (p.length != 10) return p;
    return '${p.substring(0, 4)} ${p.substring(4, 7)} ${p.substring(7)}';
  }

  Widget _buildDashenCleanWhiteScaffold() {
    return Scaffold(
      backgroundColor: _dBg,
      appBar: AppBar(
        backgroundColor: _dBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context, false),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_rounded, color: _dInk, size: 20),
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Secure Checkout',
          style: TextStyle(
            color: _dInk,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            getProportionateScreenWidth(kDefaultPadding),
            8,
            getProportionateScreenWidth(kDefaultPadding),
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDashenHeroCard(),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _payError
                    ? KeyedSubtree(
                        key: const ValueKey('err'),
                        child: _buildDashenErrorBody(),
                      )
                    : _pollTimedOut
                    ? KeyedSubtree(
                        key: const ValueKey('timeout'),
                        child: _buildTimedOutBody(light: true),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('wait'),
                        child: _buildDashenCleanWhiteBody(),
                      ),
              ),
              const SizedBox(height: 22),
              const ZooryaPayBadge(),
            ],
          ),
        ),
      ),
    );
  }

  /// Navy gradient card: logo, bank name and animated amount.
  Widget _buildDashenHeroCard() {
    final name = widget.displayName.isNotEmpty
        ? Service.capitalizeFirstLetters(widget.displayName)
        : 'Dashen Bank';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_dNavy, _dNavyDark],
        ),
        boxShadow: [
          BoxShadow(
            color: _dNavy.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -40, top: -50, child: _dRing(170, 0.08)),
          Positioned(right: 50, bottom: -70, child: _dRing(140, 0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildDashenLogo(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paying with',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.type.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _dGold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.type.toUpperCase(),
                          style: const TextStyle(
                            color: _dGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  'Total amount',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: widget.amount),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'ETB ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _dFormatAmount(value),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dRing(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: alpha),
          width: 22,
        ),
      ),
    );
  }

  /// White card: pulsing phone, short title, phone chip, 3 icon steps, status.
  Widget _buildDashenCleanWhiteBody() {
    final sent = _payInitiated;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const _PulsingIcon(icon: Icons.phone_iphone_rounded, color: _dNavy),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              sent ? 'Check your phone' : 'Sending request…',
              key: ValueKey(sent),
              style: const TextStyle(
                color: _dInk,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your PIN to approve',
            style: TextStyle(color: _dMuted, fontSize: 14),
          ),
          if (_normalizedPhone.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _dBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_rounded, size: 16, color: _dNavy),
                  const SizedBox(width: 8),
                  Text(
                    _dDisplayPhone,
                    style: const TextStyle(
                      color: _dInk,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // 3 tiny steps — icons first, one word each
          Row(
            children: [
              _dStep(Icons.notifications_active_outlined, 'Open prompt', true),
              _dStepLine(sent),
              _dStep(Icons.pin_outlined, 'Enter PIN', sent),
              _dStepLine(false),
              _dStep(Icons.check_circle_outline_rounded, 'Done', false),
            ],
          ),
          const SizedBox(height: 24),

          // Live status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _dNavy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _dNavy,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Waiting for payment',
                  style: TextStyle(
                    color: _dNavy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dStep(IconData icon, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? _dNavy : _dBg,
          ),
          child: Icon(
            icon,
            size: 20,
            color: active ? Colors.white : const Color(0xFFB0B5BE),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? _dInk : _dMuted,
          ),
        ),
      ],
    );
  }

  Widget _dStepLine(bool active) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: active ? _dNavy : const Color(0xFFE5E7EB),
        ),
      ),
    );
  }

  Widget _buildDashenLogo() {
    final img = widget.imageUrl ?? '';
    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        height: 34,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildDashenFallbackLogo(),
      );
    }
    if (img.startsWith('web_images/')) {
      try {
        final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
        return Image.network(
          '$baseUrl/$img',
          height: 34,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildDashenFallbackLogo(),
        );
      } catch (_) {
        return _buildDashenFallbackLogo();
      }
    }
    return _buildDashenFallbackLogo();
  }

  Widget _buildDashenFallbackLogo() {
    return Image.asset(
      'images/payment/dashen.png',
      height: 34,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.account_balance, color: _dNavy, size: 28),
    );
  }

  Widget _buildBrandLogo(BuildContext context) {
    final img = widget.imageUrl ?? '';
    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        height: getProportionateScreenHeight(50),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackBrandLogo(),
      );
    }
    if (img.startsWith('web_images/')) {
      try {
        final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
        return Image.network(
          '$baseUrl/$img',
          height: getProportionateScreenHeight(50),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackBrandLogo(),
        );
      } catch (_) {
        return _fallbackBrandLogo();
      }
    }
    return _fallbackBrandLogo();
  }

  Widget _fallbackBrandLogo() {
    return Image.asset(
      _methodLogo,
      height: getProportionateScreenHeight(50),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.account_balance_wallet_rounded,
        size: 40,
        color: _methodColor,
      ),
    );
  }

  Widget _buildDashenErrorBody() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFEF2F2),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Payment not started',
            style: TextStyle(
              color: _dInk,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _dMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _payError = false;
                  _payInitiated = false;
                  _errorMessage = '';
                  _pollAttempt = 0;
                });
                _initiatePay();
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text(
                'Try again',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _dNavy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TELEBIRR UI WAITING BODY (#06182A with #45B5E4)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTelebirrWaitingBody() {
    final formattedPhone = widget.phoneNumber.isNotEmpty
        ? (widget.phoneNumber.startsWith('0') ||
                  widget.phoneNumber.startsWith('+')
              ? widget.phoneNumber
              : '0${widget.phoneNumber}')
        : '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Payment Summary Card ──
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(16),
              vertical: getProportionateScreenHeight(16),
            ),
            padding: EdgeInsets.all(getProportionateScreenWidth(20)),
            decoration: BoxDecoration(
              color: _cardSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _zooryaCyan.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _zooryaCyan.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Merchant Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _zooryaCyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.store_mall_directory_rounded,
                        color: _zooryaCyan,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ZMall Online Delivery',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getProportionateScreenHeight(14)),

                // Total Amount
                const Text(
                  'Amount to Pay',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: getProportionateScreenHeight(4)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      'ETB ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _zooryaCyan,
                      ),
                    ),
                    Text(
                      widget.amount.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: _zooryaCyan,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getProportionateScreenHeight(16)),

                Divider(color: _zooryaCyan.withValues(alpha: 0.20), height: 1),
                SizedBox(height: getProportionateScreenHeight(12)),

                // Account & Method Rows
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'telebirr Phone',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_android_rounded,
                          size: 15,
                          color: _zooryaCyan,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedPhone,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: getProportionateScreenHeight(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'USSD Direct Debit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _zooryaCyan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── USSD Push Prompt Guide Card ──
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(16),
            ),
            padding: EdgeInsets.all(getProportionateScreenWidth(16)),
            decoration: BoxDecoration(
              color: _cardSurfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _zooryaCyan.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: _zooryaCyan,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pin_outlined,
                        color: _zooryaDarkBg,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'USSD Prompt Sent to Phone',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _zooryaCyan,
                            ),
                          ),
                          Text(
                            'Complete authorization on your phone',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _zooryaCyan,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '*127#',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _zooryaDarkBg,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getProportionateScreenHeight(14)),

                // 3 Steps
                _buildTelebirrStep(
                  '1',
                  'Check your phone screen for the telebirr USSD pop-up',
                ),
                SizedBox(height: getProportionateScreenHeight(8)),
                _buildTelebirrStep('2', 'Enter your 4-digit telebirr PIN'),
                SizedBox(height: getProportionateScreenHeight(8)),
                _buildTelebirrStep(
                  '3',
                  'Press "Send" or "OK" to approve the payment',
                ),
              ],
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(24)),

          // ── Spinner & Waiting Indicator ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitWave(color: _zooryaCyan, size: 28),
              const SizedBox(width: 14),
              Text(
                _payInitiated
                    ? 'Waiting for telebirr PIN...'
                    : 'Initiating telebirr request...',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: _zooryaCyan,
                ),
              ),
            ],
          ),
          SizedBox(height: getProportionateScreenHeight(20)),

          // ── Warning Badge ──
          if (_payInitiated)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _zooryaCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _zooryaCyan.withValues(alpha: 0.40)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: _zooryaCyan,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please keep this screen open until the transaction completes.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: getProportionateScreenHeight(16)),

          // ── Security Reassurance Footer ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.security_rounded, color: _zooryaCyan, size: 14),
              SizedBox(width: 6),
              Text(
                'Secured by Ethio telecom telebirr payment gateway',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: getProportionateScreenHeight(24)),
        ],
      ),
    );
  }

  Widget _buildTelebirrStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: _zooryaCyan,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: _zooryaDarkBg,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERIC BRAND WAITING BODY (M-PESA, NIB, ZEMEN, ETHSWITCH)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGenericWaitingBody() {
    final formattedPhone = widget.phoneNumber.isNotEmpty
        ? (widget.phoneNumber.startsWith('0') ||
                  widget.phoneNumber.startsWith('+')
              ? widget.phoneNumber
              : '0${widget.phoneNumber}')
        : '';

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding),
        vertical: getProportionateScreenHeight(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: getProportionateScreenHeight(10)),

          // ── Brand Card with Logo ──
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(16),
            ),
            padding: EdgeInsets.symmetric(
              vertical: getProportionateScreenHeight(20),
              horizontal: getProportionateScreenWidth(20),
            ),
            decoration: BoxDecoration(
              color: _cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.method == 'zemen'
                    ? const Color(0xFFD3214B).withValues(alpha: 0.5)
                    : widget.method == 'nib'
                    ? const Color(0xFFFEB914).withValues(alpha: 0.6)
                    : _methodColor.withValues(alpha: 0.40),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: _methodColor.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _buildBrandLogo(context),
                ),
                SizedBox(height: getProportionateScreenHeight(12)),
                _buildSubtitleBadge(),
              ],
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(28)),

          // Animated spinner
          SpinKitWave(
            color: _payInitiated ? _zooryaCyan : _methodColor,
            size: 38,
          ),
          SizedBox(height: getProportionateScreenHeight(24)),

          // Status Title
          Text(
            _payInitiated
                ? _getSuccessTitle()
                : 'Connecting to ${widget.displayName}...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _zooryaCyan,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: getProportionateScreenHeight(12)),

          // Instructions text
          Text(
            _payInitiated
                ? _getInstructionText(formattedPhone)
                : 'Please wait while we initiate your payment...',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: getProportionateScreenHeight(28)),

          // Amount chip
          _buildAmountChip(),
          SizedBox(height: getProportionateScreenHeight(22)),

          if (_payInitiated)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _zooryaCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _zooryaCyan.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.info_outline, size: 16, color: _zooryaCyan),
                  SizedBox(width: 8),
                  Text(
                    'Do NOT close this screen until payment is confirmed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a customized subtitle badge per brand
  Widget _buildSubtitleBadge() {
    if (widget.method == 'zemen' || widget.method == 'zemen_qr') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFD3214B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Zemen Bank',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    if (widget.method == 'nib' || widget.method == 'nib_qr') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEB914),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8A4D21), width: 1.2),
        ),
        child: const Text(
          'Nib International Bank',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF8A4D21),
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    if (widget.method == 'dashen') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: kZooryaBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kZooryaBlue, width: 1.2),
        ),
        child: const Text(
          'Dashen Bank',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: kZooryaBlue,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    if (widget.method == 'ethswitch' || widget.method == 'ethswitch_qr') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF37423).withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF37423), width: 1.2),
        ),
        child: const Text(
          'Powered by EthSwitch',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF37423),
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    // Default (mpesa)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _zooryaCyan.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _methodSubtitle,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _zooryaCyan,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Builds customized amount chip per brand
  Widget _buildAmountChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _zooryaCyan, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Amount: ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          Text(
            'ETB ${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _zooryaCyan,
            ),
          ),
        ],
      ),
    );
  }

  String _getSuccessTitle() {
    switch (widget.method) {
      case 'zemen':
        return 'Zemen Bank USSD Request Sent!';
      case 'nib':
        return 'Nib Bank USSD Request Sent!';
      case 'ethswitch':
        return 'EthSwitch USSD Request Sent!';
      default:
        return 'USSD Request Sent!';
    }
  }

  String _getInstructionText(String phone) {
    switch (widget.method) {
      case 'zemen':
        return 'A USSD push notification has been sent to $phone.\n\n'
            'Please check your phone and enter your Zemen mobile banking PIN to approve the payment.\n\n'
            'Waiting for payment confirmation...';
      case 'nib':
        return 'A USSD push notification has been sent to $phone.\n\n'
            'Please check your phone and enter your Nib Bank PIN to approve the payment.\n\n'
            'Waiting for payment confirmation...';
      case 'ethswitch':
        return 'A USSD prompt has been sent to $phone.\n\n'
            'Please complete your payment through the prompt.\n\n'
            'Waiting for payment confirmation...';
      default:
        return 'A USSD prompt has been sent to $phone.\n\n'
            'Please complete your payment through the prompt.\n\n'
            'Waiting for payment confirmation...';
    }
  }

  Widget _buildErrorBody() {
    return Padding(
      padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 72, color: Colors.red[400]),
          const SizedBox(height: 20),
          const Text(
            'Payment Failed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _zooryaCyan,
                foregroundColor: _zooryaDarkBg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Go Back',
                style: TextStyle(
                  color: _zooryaDarkBg,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft pulsing rings behind an icon — used on the Dashen waiting card.
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          Widget ring(double t) {
            final v = (_c.value + t) % 1.0;
            return Opacity(
              opacity: (1 - v) * 0.35,
              child: Container(
                width: 56 + 54 * v,
                height: 56 + 54 * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.25),
                ),
              ),
            );
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              ring(0),
              ring(0.5),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
            ],
          );
        },
      ),
    );
  }
}
