import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_service.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Account number and OTP payment screen.
/// Designed with a clean, simple white theme matching the Telebirr payment UI.
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
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
          widget.displayName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(kDefaultPadding * 1.2),
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // Title matching Telebirr style
              Text(
                'Pay Using ${widget.displayName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                'Powered by ${widget.displayName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: 24),

              // Clean Image / Logo
              _buildMethodLogo(context),
              const SizedBox(height: 20),

              // Amount Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Amount: ETB ${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Step 1 (Account Number) or Step 2 (OTP)
              _otpSent ? _buildOtpInputView() : _buildAccountInputView(),

              const SizedBox(height: 32),

              // Subtle Security Note
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF9CA3AF),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '256-bit encrypted secure bank transaction',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 1: Account number entry
  Widget _buildAccountInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter your ${widget.displayName} account number. A one-time verification code (OTP) will be sent to the phone number registered with your account.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),

        // Clean white textfield
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: _accountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter Account Number',
              hintStyle: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 15,
                letterSpacing: 0,
              ),
              prefixIcon: Icon(
                Icons.account_balance_outlined,
                color: Color(0xFF6B7280),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Action Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _methodColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _loading ? null : _handleSendOtp,
            child: _loading
                ? const SpinKitThreeBounce(color: Colors.white, size: 22)
                : const Text(
                    'Send OTP Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Step 2: OTP verification entry
  Widget _buildOtpInputView() {
    final maskedAccount = _accountController.text.length > 4
        ? '•••• ${_accountController.text.substring(_accountController.text.length - 4)}'
        : _accountController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Masked Account & Change option
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Account: $maskedAccount',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loading
                  ? null
                  : () {
                      setState(() {
                        _otpSent = false;
                        _otpController.clear();
                      });
                    },
              child: Text(
                'Change',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _methodColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const Text(
          'Please enter the 6-digit OTP verification code sent to your registered phone number.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),

        // Clean OTP field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
              letterSpacing: 10,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: TextStyle(
                color: Color(0xFFD1D5DB),
                letterSpacing: 10,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Resend countdown
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: (_loading || _resendCountdown > 0)
                ? null
                : _handleSendOtp,
            child: Text(
              _resendCountdown > 0
                  ? 'Resend OTP in ${_resendCountdown}s'
                  : 'Resend OTP',
              style: TextStyle(
                color: _resendCountdown > 0 ? Colors.black38 : _methodColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Confirm & Pay Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _methodColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _loading ? null : _handleConfirmPayment,
            child: _loading
                ? const SpinKitThreeBounce(color: Colors.white, size: 22)
                : Text(
                    'Confirm & Pay ETB ${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
        height: 65,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackMethodLogo(),
      );
    }
    if (img.startsWith('web_images/')) {
      try {
        final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
        return Image.network(
          '$baseUrl/$img',
          height: 65,
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
      height: 65,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.account_balance_rounded,
        color: _methodColor,
        size: 50,
      ),
    );
  }
}
