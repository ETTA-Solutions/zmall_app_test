import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:zmall/borsa/refund/refund_service.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/custom_widgets/custom_button.dart';

class RefundOtpSheet extends StatefulWidget {
  const RefundOtpSheet({
    super.key,
    required this.transaction,
    required this.service,
    required this.currency,
    required this.onVerified,
    required this.onForceLogout,
  });

  final dynamic transaction;
  final RefundService service;
  final String currency;
  final void Function(Map<String, dynamic> verifyResult) onVerified;
  final Future<void> Function() onForceLogout;

  /// Shows the refund OTP verification bottom sheet.
  static void show({
    required BuildContext context,
    required dynamic transaction,
    required RefundService service,
    required String currency,
    required void Function(Map<String, dynamic> verifyResult) onVerified,
    required Future<void> Function() onForceLogout,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: kPrimaryColor,
      constraints: BoxConstraints(
        minHeight: MediaQuery.sizeOf(context).height * 0.40,
        maxHeight: MediaQuery.sizeOf(context).height * 1.0,
      ),
      builder: (_) => RefundOtpSheet(
        transaction: transaction,
        service: service,
        currency: currency,
        onVerified: onVerified,
        onForceLogout: onForceLogout,
      ),
    );
  }

  @override
  State<RefundOtpSheet> createState() => _RefundOtpSheetState();
}

class _RefundOtpSheetState extends State<RefundOtpSheet> {
  String _otpCode = '';
  bool _otpLoading = false;
  bool _otpSending = false;
  bool _hasVerified = false;
  bool _isError = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  // ---- Timer ---- //

  void _startCountdown() {
    _remainingSeconds = kRefundOtpCountdownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  // ---- OTP Generation ---- //

  Future<void> _sendOtp() async {
    setState(() => _otpSending = true);

    final result = await widget.service.generateOtp();

    if (!mounted) return;
    setState(() => _otpSending = false);

    if (result['success'] == true) {
      _startCountdown();
    } else {
      if (result['error_code'] == 999) {
        await widget.onForceLogout();
        return;
      }
      if (mounted) {
        Service.showMessage(
          context: context,
          title: RefundService.getErrorMessage(
            result,
            "Failed to send OTP. Please try again.",
          ),
          error: true,
          duration: 3,
        );
      }
    }
  }

  // ---- OTP Verification ---- //

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6 || _otpLoading || _hasVerified) return;

    setState(() {
      _hasVerified = true;
      _otpLoading = true;
      _isError = false;
    });

    final result = await widget.service.verifyOtp(
      otpCode: _otpCode,
    );

    if (!mounted) return;
    setState(() => _otpLoading = false);

    if (result['success'] == true) {
      final callback = widget.onVerified;
      Navigator.of(context).pop();
      callback(result);
    } else {
      setState(() {
        _isError = true;
        _hasVerified = false;
      });
      if (result['error_code'] == 999) {
        await widget.onForceLogout();
        return;
      }
      if (!mounted) return;
      Service.showMessage(
        context: context,
        title: RefundService.getErrorMessage(
          result,
          "OTP verification failed. Please try again.",
        ),
        error: true,
      );
    }
  }

  // ---- Resend ---- //

  void _handleResend() {
    _otpController.clear();
    setState(() {
      _otpCode = '';
      _isError = false;
      _hasVerified = false;
    });
    _sendOtp();
  }

  // ---- UI ---- //

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding),
        vertical: getProportionateScreenHeight(kDefaultPadding / 2),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Refund Verification",
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: kBlackColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),

            SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),

            // Transaction info card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                getProportionateScreenWidth(kDefaultPadding / 1.5),
              ),
              decoration: BoxDecoration(
                color: kWhiteColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.transaction['wallet_description'] ?? 'Transaction',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: kBlackColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "${widget.currency} ${widget.transaction['from_amount']?.toStringAsFixed(2) ?? '0.00'}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: kSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),

            // OTP label
            Text(
              "Enter the 6-digit OTP sent to your phone",
              style: TextStyle(color: kGreyColor, fontSize: 13),
            ),

            SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),

            // PinFieldAutoFill OTP input
            PinFieldAutoFill(
              codeLength: 6,
              autoFocus: true,
              currentCode: _otpCode,
              controller: _otpController,
              decoration: BoxLooseDecoration(
                strokeColorBuilder: FixedColorBuilder(
                  _isError
                      ? kSecondaryColor
                      : kGreyColor.withValues(alpha: 0.3),
                ),
                bgColorBuilder: FixedColorBuilder(
                  _isError
                      ? kSecondaryColor.withValues(alpha: 0.18)
                      : Colors.transparent,
                ),
                strokeWidth: _isError ? 2.0 : 1.0,
              ),
              onCodeChanged: (code) {
                if (_hasVerified) return;
                setState(() {
                  _otpCode = code ?? '';
                  _isError = false;
                });
                if (code != null &&
                    code.length == 6 &&
                    !_otpLoading &&
                    !_hasVerified) {
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (!_otpLoading && !_hasVerified) {
                      _verifyOtp();
                    }
                  });
                }
              },
              onCodeSubmitted: (code) {
                if (_hasVerified) return;
                if (code.length == 6 && !_otpLoading && !_hasVerified) {
                  setState(() => _otpCode = code);
                  _verifyOtp();
                }
              },
            ),

            SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),

            // Loading indicator or countdown/resend
            if (_otpLoading || _otpSending)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: kDefaultPadding / 2),
                  child: Column(
                    children: [
                      SpinKitWave(
                        color: kSecondaryColor,
                        size: getProportionateScreenWidth(kDefaultPadding),
                      ),
                      if (_otpSending) ...[
                        SizedBox(height: 8),
                        Text(
                          "Sending OTP to your phone...",
                          style: TextStyle(color: kGreyColor, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else ...[
              // Countdown / Resend
              Center(
                child: _remainingSeconds > 0
                    ? Text(
                        "Resend OTP in ${_remainingSeconds}s",
                        style: TextStyle(color: kGreyColor, fontSize: 13),
                      )
                    : TextButton(
                        onPressed: _handleResend,
                        child: Text(
                          "Re-Send OTP Code",
                          style: TextStyle(
                            color: kSecondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),

              SizedBox(
                height: getProportionateScreenHeight(kDefaultPadding / 2),
              ),

              // Manual verify button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  title: "Verify & Continue",
                  isLoading: _otpLoading,
                  color: kSecondaryColor,
                  press: () {
                    if (_otpCode.length == 6 &&
                        !_otpLoading &&
                        !_hasVerified) {
                      _verifyOtp();
                    }
                  },
                ),
              ),
            ],

            SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
          ],
        ),
      ),
    );
  }
}
