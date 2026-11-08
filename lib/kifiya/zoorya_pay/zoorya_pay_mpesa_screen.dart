import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_service.dart';
import 'package:zmall/kifiya/zoorya_pay/mpesa_phone_sheet.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Dedicated M-PESA checkout screen.
/// Designed with the exact same visual language, clean light theme,
/// branded hero card, and 2-step progress stepper as ZooryaPayOtpScreen (Zemen).
class ZooryaPayMpesaScreen extends StatefulWidget {
  const ZooryaPayMpesaScreen({
    Key? key,
    this.displayName = 'M-PESA',
    this.imageUrl,
    required this.amount,
    required this.userId,
    required this.serverToken,
    required this.uniqueId,
    required this.orderPaymentId,
    this.initialPhoneNumber,
  }) : super(key: key);

  final String displayName;
  final String? imageUrl;
  final double amount;
  final String userId;
  final String serverToken;
  final String uniqueId;
  final String orderPaymentId;
  final String? initialPhoneNumber;

  @override
  State<ZooryaPayMpesaScreen> createState() => _ZooryaPayMpesaScreenState();
}

class _ZooryaPayMpesaScreenState extends State<ZooryaPayMpesaScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  static const Color _pageBg = Color(0xFFF5F6FA);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _line = Color(0xFFE5E7EB);
  static const Color _mpesaGreen = Color(0xFF00A650);
  static const Color _mpesaGreenDark = Color(0xFF007A3D);

  bool _promptSent = false;
  bool _loading = false;
  bool _checkingStatus = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;
  int _pollAttempts = 0;
  // Bumped whenever polling restarts/stops so an older wait loop exits.
  int _pollGeneration = 0;
  // Checking stops after ZooryaPayService.pollWindow (2 min).
  bool _pollTimedOut = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null &&
        widget.initialPhoneNumber!.isNotEmpty) {
      final raw = widget.initialPhoneNumber!;
      if (isMpesaPhone(raw)) {
        // Field shows the 9 digits after the fixed '+251' (7XXXXXXXX).
        _phoneController.text = normalizeEthPhone(raw).substring(1);
      }
    }

    void refresh() {
      if (mounted) setState(() {});
    }

    _phoneFocus.addListener(refresh);
    _phoneController.addListener(refresh);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollGeneration++;
    _phoneFocus.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// What the user typed — the full number, e.g. '0718081364'.
  /// The 9 digits typed after the fixed '+251', e.g. '718081364'.
  String get _enteredDigits => _phoneController.text.trim();

  /// Number sent to the backend: always '07XXXXXXXX'.
  String get _fullMpesaPhone => '0$_enteredDigits';

  bool get _isValidPhone => RegExp(r'^7\d{8}$').hasMatch(_enteredDigits);

  String? get _phoneValidationError {
    if (_enteredDigits.isEmpty) return null;
    if (!_enteredDigits.startsWith('7')) {
      return 'M-PESA numbers start with 7 after +251';
    }
    return null;
  }

  String _formatAmount(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '$whole.${parts[1]}';
  }

  /// e.g. '+251 718 081 364'
  String get _formattedPhone {
    final d = _enteredDigits;
    if (d.length == 9) {
      return '+251 ${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
    }
    return '+251 $d';
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        setState(() {
          _resendCountdown = 0;
        });
        timer.cancel();
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  /// Same logic as the telebirr USSD check: call /admin/check_paid_order,
  /// wait for the answer, wait 2s, check again — until the payment is
  /// confirmed (then continue automatically) or the user leaves / changes
  /// the number. Only one request is in flight at a time.
  Future<void> _startPolling() async {
    final gen = ++_pollGeneration;
    _pollAttempts = 0;
    final startedAt = DateTime.now();
    if (mounted) setState(() => _pollTimedOut = false);

    while (mounted && gen == _pollGeneration) {
      await Future.delayed(ZooryaPayService.pollInterval);
      if (!mounted || gen != _pollGeneration) return;
      if (DateTime.now().difference(startedAt) >= ZooryaPayService.pollWindow) {
        debugPrint(
          '[ZooryaPayMpesa] ⏱️ Stopped checking after 2 min ($_pollAttempts checks).',
        );
        setState(() => _pollTimedOut = true);
        return;
      }
      _pollAttempts++;
      debugPrint('[ZooryaPayMpesa] 🔄 Check attempt #$_pollAttempts');
      final paid = await _checkPaidStatus();
      if (paid) return;
    }
  }

  /// "I've paid, check again" — one single check after the 2 minutes.
  Future<void> _manualCheck() async {
    final paid = await _checkPaidStatus();
    if (!mounted || paid) return;
    Service.showMessage(
      context: context,
      title: "Payment not received yet. Resend the prompt to try again.",
      error: true,
      duration: 4,
    );
  }

  void _stopPolling() {
    _pollGeneration++;
  }

  /// Step 1: Send the USSD / STK Push to the Safaricom phone
  Future<void> _handleSendPrompt() async {
    if (!_isValidPhone) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final phone = _fullMpesaPhone;

    final res = await ZooryaPayService.pay(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      method: 'mpesa',
      uniqueId: widget.uniqueId,
      amount: widget.amount,
      phoneNumber: phone,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
    });

    if (res != null && res['success'] == true) {
      setState(() {
        _promptSent = true;
      });
      _startCountdown();
      _startPolling();
      Service.showMessage(
        context: context,
        title: "Prompt sent! Please approve on your phone.",
        error: false,
        duration: 4,
      );
    } else {
      final msg =
          res?['message']?.toString() ??
          "Unable to send M-PESA prompt. Please verify your phone number and try again.";
      setState(() {
        _errorMessage = msg;
      });
      Service.showMessage(
        context: context,
        title: msg,
        error: true,
        duration: 4,
      );
    }
  }

  /// Check payment status via /admin/check_paid_order.
  /// Returns true (and leaves the screen) once the payment is confirmed.
  Future<bool> _checkPaidStatus() async {
    if (_checkingStatus) return false;
    setState(() {
      _checkingStatus = true;
    });

    final res = await ZooryaPayService.checkPaidOrder(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      orderPaymentId: widget.orderPaymentId,
    );

    if (!mounted) return false;
    setState(() {
      _checkingStatus = false;
    });

    if (ZooryaPayService.isPaid(res)) {
      _stopPolling();
      _countdownTimer?.cancel();
      Service.showMessage(
        context: context,
        title: "M-PESA payment confirmed successfully!",
        error: false,
        duration: 3,
      );
      Navigator.pop(context, true);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
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
                  child: Icon(Icons.arrow_back_rounded, color: _ink, size: 20),
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Secure Checkout',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
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
                _buildHeroCard(),
                const SizedBox(height: 22),
                _buildStepper(),
                const SizedBox(height: 18),
                _buildFormCard(),
                const SizedBox(height: 22),
                _buildTrustFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Checkout summary hero card: M-PESA badge + Price to pay
  Widget _buildHeroCard() {
    return Container(
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
          // Payment method row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _line),
                  ),
                  child: Image.asset(
                    'images/payment/new_payment/mpesa.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.phone_android_rounded,
                      color: _mpesaGreen,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay with',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'M-PESA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.verified_user_rounded,
                  color: _mpesaGreen,
                  size: 20,
                ),
              ],
            ),
          ),

          // Receipt-style dashed divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (_, c) {
                final count = (c.maxWidth / 9).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    count,
                    (_) => Container(width: 5, height: 1.2, color: _line),
                  ),
                );
              },
            ),
          ),

          // Price to pay
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Total to pay',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'ETB ',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: _formatAmount(widget.amount),
                        style: const TextStyle(
                          color: _mpesaGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
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

  /// Two-step progress: Number → Approve.
  Widget _buildStepper() {
    return Row(
      children: [
        _stepDot(index: 1, label: 'Number', active: true, done: _promptSent),
        Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _line,
              borderRadius: BorderRadius.circular(2),
            ),
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              widthFactor: _promptSent ? 1 : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: _mpesaGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        _stepDot(index: 2, label: 'Approve', active: _promptSent, done: false),
      ],
    );
  }

  Widget _stepDot({
    required int index,
    required String label,
    required bool active,
    required bool done,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? _mpesaGreen : Colors.white,
            border: Border.all(color: active ? _mpesaGreen : _line, width: 1.5),
          ),
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : Text(
                  '$index',
                  style: TextStyle(
                    color: active ? Colors.white : _muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: active ? _ink : _muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// Main white card with smooth transition between Step 1 and Step 2
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
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
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: _promptSent
              ? KeyedSubtree(
                  key: const ValueKey('waiting_approval'),
                  child: _buildWaitingApprovalView(),
                )
              : KeyedSubtree(
                  key: const ValueKey('phone_input'),
                  child: _buildPhoneInputView(),
                ),
        ),
      ),
    );
  }

  /// Step 1: Safaricom phone entry
  Widget _buildPhoneInputView() {
    final focused = _phoneFocus.hasFocus;
    final error = _phoneValidationError;
    final borderColor = error != null
        ? Colors.redAccent
        : (focused ? _mpesaGreen : Colors.transparent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'M-PESA Phone Number',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter your Safaricom number to receive the prompt',
          style: TextStyle(color: _muted, fontSize: 13.5),
        ),
        const SizedBox(height: 20),

        // Phone Input Container
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: focused ? Colors.white : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phone_iphone_rounded,
                color: (focused || _enteredDigits.isNotEmpty)
                    ? _mpesaGreen
                    : const Color(0xFFB0B5BE),
                size: 22,
              ),
              const SizedBox(width: 10),
              // Fixed country code — always visible, not editable.
              const Text(
                '+251',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1.5, height: 22, color: const Color(0xFFD1D5DB)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  maxLength: 9, // 7XXXXXXXX
                  inputFormatters: [_MpesaPhoneFormatter()],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) =>
                      (_loading || !_isValidPhone) ? null : _handleSendPrompt(),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '7XX XXX XXX',
                    hintStyle: TextStyle(
                      color: Color(0xFFCDD1D8),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: _isValidPhone
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('ok'),
                        color: _mpesaGreen,
                        size: 22,
                      )
                    : (_enteredDigits.isNotEmpty && !_loading)
                    ? GestureDetector(
                        key: const ValueKey('clear'),
                        onTap: () => _phoneController.clear(),
                        child: const Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFFB0B5BE),
                          size: 20,
                        ),
                      )
                    : const SizedBox(key: ValueKey('none'), width: 22),
              ),
            ],
          ),
        ),

        // Error message if invalid prefix
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: error == null && _errorMessage == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          error ?? _errorMessage ?? '',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 24),

        _primaryButton(
          label: 'Send M-PESA Prompt',
          icon: Icons.arrow_forward_rounded,
          onPressed: _handleSendPrompt,
          enabled: _isValidPhone,
        ),
      ],
    );
  }

  /// Step 2: Live USSD Prompt Waiting & Verification View
  Widget _buildWaitingApprovalView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Approve on your phone',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'A prompt has been sent to your Safaricom phone',
          style: TextStyle(color: _muted, fontSize: 13.5),
        ),
        const SizedBox(height: 16),

        // Phone chip with "Change"
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.phone_iphone_rounded,
                color: _mpesaGreen,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formattedPhone,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              TextButton(
                onPressed: _checkingStatus
                    ? null
                    : () {
                        _stopPolling();
                        setState(() {
                          _promptSent = false;
                          _pollTimedOut = false;
                        });
                      },
                style: TextButton.styleFrom(
                  foregroundColor: _mpesaGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Live Prompt Guidance Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _mpesaGreen.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _mpesaGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      color: _mpesaGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check your phone screen',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enter your M-PESA PIN to authorize',
                          style: TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFFDCFCE7), height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_pollTimedOut)
                    const Icon(
                      Icons.timer_off_outlined,
                      color: Color(0xFFB45309),
                      size: 16,
                    )
                  else
                    const SpinKitThreeBounce(color: _mpesaGreen, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    _pollTimedOut
                        ? "We couldn't confirm your payment"
                        : _checkingStatus
                        ? 'Verifying payment...'
                        : 'Waiting for PIN approval...',
                    style: TextStyle(
                      color: _pollTimedOut
                          ? const Color(0xFFB45309)
                          : const Color(0xFF15803D),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (_pollTimedOut) ...[
          const Text(
            'The prompt may have expired. Resend it, or check again if you already paid.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          _primaryButton(
            label: 'Resend prompt',
            icon: Icons.refresh_rounded,
            onPressed: _handleSendPrompt,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: (_loading || _checkingStatus) ? null : _manualCheck,
            style: TextButton.styleFrom(foregroundColor: _mpesaGreen),
            child: _checkingStatus
                ? const SpinKitThreeBounce(color: _mpesaGreen, size: 16)
                : const Text(
                    "I've paid, check again",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ] else
        // Resend countdown
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Didn\'t receive the prompt?',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            TextButton(
              onPressed: (_loading || _resendCountdown > 0)
                  ? null
                  : _handleSendPrompt,
              style: TextButton.styleFrom(foregroundColor: _mpesaGreen),
              child: Text(
                _resendCountdown > 0
                    ? 'Resend in 0:${_resendCountdown.toString().padLeft(2, '0')}'
                    : 'Resend prompt',
                style: TextStyle(
                  color: _resendCountdown > 0 ? _muted : _mpesaGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    final active = enabled && !_loading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _loading ? 0.85 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: enabled
              ? const LinearGradient(colors: [_mpesaGreen, _mpesaGreenDark])
              : const LinearGradient(
                  colors: [Color(0xFFD9DCE1), Color(0xFFD1D5DB)],
                ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _mpesaGreen.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: active ? onPressed : null,
            child: Center(
              child: _loading
                  ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustFooter() {
    Widget item(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
        ),
      ],
    );

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            item(Icons.lock_outline_rounded, 'Encrypted'),
            item(Icons.verified_user_outlined, 'Safaricom M-PESA Secure'),
          ],
        ),
        const SizedBox(height: 8),
        const Text.rich(
          TextSpan(
            text: 'Powered by ',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            children: [
              TextSpan(
                text: 'ZOORYA-PAY',
                style: TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Keeps the 9 digits that go after the fixed '+251'.
/// A typed or pasted '0' / '251' / '+251' in front is removed, so
/// '0718081364', '251718081364' and '+251718081364' all become '718081364'.
class _MpesaPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('251') && d.length >= 12) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length > 9) d = d.substring(0, 9);
    return TextEditingValue(
      text: d,
      selection: TextSelection.collapsed(offset: d.length),
    );
  }
}
