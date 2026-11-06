import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_service.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Account number and OTP payment screen (Zemen, Nib, EthSwitch, ...).
/// Clean light theme: branded gradient hero card, 2-step progress,
/// animated step transitions and a 6-box OTP input.
class ZooryaPayOtpScreen extends StatefulWidget {
  const ZooryaPayOtpScreen({
    Key? key,
    required this.method,
    required this.displayName,
    this.imageUrl,
    required this.amount,
    required this.userId,
    required this.serverToken,
    required this.uniqueId,
    required this.orderPaymentId,
    this.initialAccountNumber,
  }) : super(key: key);

  final String method;
  final String displayName;
  final String? imageUrl;
  final double amount;
  final String userId;
  final String serverToken;
  final String uniqueId;
  final String orderPaymentId;
  final String? initialAccountNumber;

  @override
  State<ZooryaPayOtpScreen> createState() => _ZooryaPayOtpScreenState();
}

class _ZooryaPayOtpScreenState extends State<ZooryaPayOtpScreen> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _accountFocus = FocusNode();
  final FocusNode _otpFocus = FocusNode();

  static const Color _pageBg = Color(0xFFF5F6FA);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _line = Color(0xFFE5E7EB);
  static const int _otpLength = 6;

  bool _otpSent = false;
  bool _loading = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  Color get _methodColor {
    switch (widget.method) {
      case 'zemen':
      case 'zemen_qr':
        return const Color(0xFFD3214B); // Zemen Red
      case 'ethswitch':
      case 'ethswitch_qr':
        return const Color(0xFFF37423); // EthSwitch Orange
      case 'nib':
      case 'nib_qr':
        return const Color(0xFF8A4D21); // Nib Brown
      default:
        return kPrimaryColor;
    }
  }

  String get _methodLogo {
    switch (widget.method) {
      case 'zemen':
      case 'zemen_qr':
        return 'images/payment/new_payment/zemen.png';
      case 'nib':
      case 'nib_qr':
        return 'images/payment/new_payment/nib_bank.png';
      case 'ethswitch':
      case 'ethswitch_qr':
        return 'images/payment/new_payment/ethswitch.png';
      case 'mpesa':
        return 'images/payment/new_payment/mpesa.png';
      case 'telebirr':
      case 'telebirr_qr':
        return 'images/payment/new_payment/telebirr.png';
      default:
        return 'images/payment/zemen.png';
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAccountNumber != null &&
        widget.initialAccountNumber!.isNotEmpty) {
      _accountController.text = widget.initialAccountNumber!;
    }
    // Rebuild on focus / text changes so borders and OTP boxes stay in sync.
    void refresh() {
      if (mounted) setState(() {});
    }

    _accountFocus.addListener(refresh);
    _otpFocus.addListener(refresh);
    _accountController.addListener(refresh);
    _otpController.addListener(refresh);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _accountFocus.dispose();
    _otpFocus.dispose();
    _accountController.dispose();
    _otpController.dispose();
    super.dispose();
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

  /// Step 1: Request OTP for the entered account number
  Future<void> _handleSendOtp() async {
    final accountNumber = _accountController.text.trim();
    if (accountNumber.isEmpty) {
      Service.showMessage(
        context: context,
        title: "Please enter your account number",
        error: true,
      );
      return;
    }

    if (accountNumber.length < 6) {
      Service.showMessage(
        context: context,
        title: "Please enter a valid account number",
        error: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
    });

    final res = await ZooryaPayService.sendOtp(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      method: widget.method,
      accountNumber: accountNumber,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
    });

    if (res != null && res['success'] == true) {
      setState(() {
        _otpSent = true;
      });
      _startCountdown();
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _otpFocus.requestFocus();
      });
      Service.showMessage(
        context: context,
        title:
            res['message']?.toString() ??
            "OTP verification code sent to your registered phone number.",
        error: false,
        duration: 4,
      );
    } else {
      final msg =
          res?['message']?.toString() ??
          "Failed to send OTP. Please verify your account number and try again.";
      Service.showMessage(
        context: context,
        title: msg,
        error: true,
        duration: 4,
      );
    }
  }

  /// Step 2: Confirm payment using the received OTP
  Future<void> _handleConfirmPayment() async {
    final accountNumber = _accountController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      Service.showMessage(
        context: context,
        title: "Please enter the OTP verification code",
        error: true,
      );
      return;
    }

    if (otp.length < 4) {
      Service.showMessage(
        context: context,
        title: "Please enter a valid OTP code",
        error: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
    });

    final res = await ZooryaPayService.pay(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      method: widget.method,
      uniqueId: widget.uniqueId,
      amount: widget.amount,
      accountNumber: accountNumber,
      otp: otp,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
    });

    if (res != null && res['success'] == true) {
      Service.showMessage(
        context: context,
        title: "Payment confirmed successfully!",
        error: false,
        duration: 3,
      );
      Navigator.pop(context, true);
    } else {
      final msg =
          res?['message']?.toString() ??
          "Payment failed. Please verify your OTP code and try again.";
      Service.showMessage(
        context: context,
        title: msg,
        error: true,
        duration: 4,
      );
    }
  }

  // ───────────────────────────── Helpers ─────────────────────────────

  Color get _methodColorDark {
    final hsl = HSLColor.fromColor(_methodColor);
    return hsl.withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0)).toColor();
  }

  String _formatAmount(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '$whole.${parts[1]}';
  }

  String get _maskedAccount {
    final acc = _accountController.text.trim();
    return acc.length > 4 ? '•••• ${acc.substring(acc.length - 4)}' : acc;
  }

  // ───────────────────────────── Build ─────────────────────────────

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

  /// Checkout summary: who you pay with, then the price to pay.
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _line),
                  ),
                  child: _buildMethodLogo(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pay with',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.verified_user_rounded,
                  color: _methodColor,
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
                        style: TextStyle(
                          color: _methodColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
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

  /// Two-step progress: Account → Verify.
  Widget _buildStepper() {
    return Row(
      children: [
        _stepDot(index: 1, label: 'Account', active: true, done: _otpSent),
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
              widthFactor: _otpSent ? 1 : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: _methodColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        _stepDot(index: 2, label: 'Verify', active: _otpSent, done: false),
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
            color: active ? _methodColor : Colors.white,
            border: Border.all(
              color: active ? _methodColor : _line,
              width: 1.5,
            ),
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

  /// White card hosting the current step, with an animated transition.
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
          child: _otpSent
              ? KeyedSubtree(
                  key: const ValueKey('otp'),
                  child: _buildOtpInputView(),
                )
              : KeyedSubtree(
                  key: const ValueKey('account'),
                  child: _buildAccountInputView(),
                ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.45),
        ),
      ],
    );
  }

  /// Step 1: Account number entry — minimal: title, one big field, button.
  Widget _buildAccountInputView() {
    final focused = _accountFocus.hasFocus;
    final digits = _accountController.text.trim().length;
    final isValid = digits >= 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Account number',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'We\'ll send you a code by SMS',
          style: TextStyle(color: _muted, fontSize: 13.5),
        ),
        const SizedBox(height: 20),

        // Big, simple input
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: focused ? Colors.white : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focused ? _methodColor : Colors.transparent,
              width: 1.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_rounded,
                color: focused || digits > 0
                    ? _methodColor
                    : const Color(0xFFB0B5BE),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _accountController,
                  focusNode: _accountFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) =>
                      (_loading || !isValid) ? null : _handleSendOtp(),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  decoration: const InputDecoration(
                    hintText: '0000 0000 0000',
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
              // Green tick when valid, clear button while typing
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: isValid
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('ok'),
                        color: Color(0xFF16A34A),
                        size: 22,
                      )
                    : (digits > 0 && !_loading)
                    ? GestureDetector(
                        key: const ValueKey('clear'),
                        onTap: () => _accountController.clear(),
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
        const SizedBox(height: 24),

        _primaryButton(
          label: 'Send code',
          icon: Icons.arrow_forward_rounded,
          onPressed: _handleSendOtp,
          enabled: isValid,
        ),
      ],
    );
  }

  /// Step 2: OTP verification entry
  Widget _buildOtpInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Enter verification code',
          'Type the $_otpLength-digit code we sent to the phone linked to your account.',
        ),
        const SizedBox(height: 14),

        // Account chip with "Change"
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_rounded,
                color: _methodColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _maskedAccount,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() {
                          _otpSent = false;
                          _otpController.clear();
                        });
                      },
                style: TextButton.styleFrom(foregroundColor: _methodColor),
                child: const Text(
                  'Change',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildOtpBoxes(),

        const SizedBox(height: 10),

        // Resend countdown
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Didn\'t get it?',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            TextButton(
              onPressed: (_loading || _resendCountdown > 0)
                  ? null
                  : _handleSendOtp,
              style: TextButton.styleFrom(foregroundColor: _methodColor),
              child: Text(
                _resendCountdown > 0
                    ? 'Resend in 0:${_resendCountdown.toString().padLeft(2, '0')}'
                    : 'Resend code',
                style: TextStyle(
                  color: _resendCountdown > 0 ? _muted : _methodColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _primaryButton(
          label: 'Pay ETB ${_formatAmount(widget.amount)}',
          icon: Icons.lock_rounded,
          onPressed: _handleConfirmPayment,
        ),
      ],
    );
  }

  /// Six individual digit boxes driven by one hidden TextField.
  Widget _buildOtpBoxes() {
    final code = _otpController.text;
    final focused = _otpFocus.hasFocus;

    return GestureDetector(
      onTap: () => _otpFocus.requestFocus(),
      child: Stack(
        children: [
          // Hidden input that actually receives keystrokes / autofill
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 58,
              child: TextField(
                controller: _otpController,
                focusNode: _otpFocus,
                keyboardType: TextInputType.number,
                maxLength: _otpLength,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Row(
              children: List.generate(_otpLength, (i) {
                final filled = i < code.length;
                final isCurrent =
                    focused &&
                    (i == code.length ||
                        (code.length == _otpLength && i == _otpLength - 1));
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 58,
                    margin: EdgeInsets.only(right: i == _otpLength - 1 ? 0 : 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filled
                          ? _methodColor.withValues(alpha: 0.06)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? _methodColor
                            : (filled
                                  ? _methodColor.withValues(alpha: 0.4)
                                  : _line),
                        width: isCurrent ? 1.8 : 1,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: filled
                          ? Text(
                              code[i],
                              key: ValueKey('d$i${code[i]}'),
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : (isCurrent
                                ? Container(
                                    key: const ValueKey('caret'),
                                    width: 2,
                                    height: 22,
                                    color: _methodColor,
                                  )
                                : const SizedBox.shrink()),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
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
              ? LinearGradient(colors: [_methodColor, _methodColorDark])
              : const LinearGradient(
                  colors: [Color(0xFFD9DCE1), Color(0xFFD1D5DB)],
                ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _methodColor.withValues(alpha: 0.30),
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
            item(Icons.verified_user_outlined, 'Bank-verified OTP'),
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

  Widget _buildMethodLogo(BuildContext context) {
    final img = widget.imageUrl ?? '';
    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        height: 34,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackMethodLogo(),
      );
    }
    if (img.startsWith('web_images/')) {
      try {
        final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
        return Image.network(
          '$baseUrl/$img',
          height: 34,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackMethodLogo(),
        );
      } catch (_) {
        return _fallbackMethodLogo();
      }
    }
    return _fallbackMethodLogo();
  }

  Widget _fallbackMethodLogo() {
    return Image.asset(
      _methodLogo,
      height: 34,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.account_balance_rounded, color: _methodColor, size: 28),
    );
  }
}
