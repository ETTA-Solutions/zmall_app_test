import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zmall/borsa/refund/refund_otp_sheet.dart';
import 'package:zmall/borsa/refund/refund_service.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/widgets/custom_text_field.dart';

class RefundConfirmationDialog extends StatefulWidget {
  const RefundConfirmationDialog({
    super.key,
    required this.verifyResult,
    required this.transaction,
    required this.service,
    required this.currency,
    required this.onSuccess,
    required this.onForceLogout,
  });

  final Map<String, dynamic> verifyResult;
  final dynamic transaction;
  final RefundService service;
  final String currency;
  final VoidCallback onSuccess;
  final Future<void> Function() onForceLogout;

  /// Shows the refund confirmation dialog.
  static void show({
    required BuildContext context,
    required Map<String, dynamic> verifyResult,
    required dynamic transaction,
    required RefundService service,
    required String currency,
    required VoidCallback onSuccess,
    required Future<void> Function() onForceLogout,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RefundConfirmationDialog(
        verifyResult: verifyResult,
        transaction: transaction,
        service: service,
        currency: currency,
        onSuccess: onSuccess,
        onForceLogout: onForceLogout,
      ),
    );
  }

  @override
  State<RefundConfirmationDialog> createState() =>
      _RefundConfirmationDialogState();
}

class _RefundConfirmationDialogState extends State<RefundConfirmationDialog> {
  bool _processing = false;
  bool _useOtherNumber = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _numberController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Returns 09XXXXXXXX for 09…, 9… or 251 9… input, or null if it is not a
  /// valid Ethio telecom (Telebirr) number.
  static String? _normalizeTelebirr(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('251')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length == 9 && digits.startsWith('9')) return '0$digits';
    return null;
  }

  /// 09XXXXXXXX -> 09XX XXX XXX
  static String _format(String number) =>
      '${number.substring(0, 4)} ${number.substring(4, 7)} ${number.substring(7)}';

  /// The ZMall phone as shown to the user.
  String get _zmallNumberText {
    final normalized = _normalizeTelebirr(widget.service.phone);
    return normalized != null ? _format(normalized) : widget.service.phone;
  }

  Future<void> _onGetRefund() async {
    if (_processing) return;

    String? receiver; // null means the ZMall phone
    var shownNumber = _zmallNumberText;
    if (_useOtherNumber) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      receiver = _normalizeTelebirr(_numberController.text);
      if (receiver == null) return;
      shownNumber = _format(receiver);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Send refund?",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: "We will send "),
              TextSpan(
                text: "${_amountText()} ${widget.currency}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: " to Telebirr "),
              TextSpan(
                text: shownNumber,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ". This can't be undone. Continue?"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("Cancel", style: TextStyle(color: kGreyColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              "Continue",
              style: TextStyle(
                color: kSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (receiver == null) {
      await _handleRefund(shownNumber: shownNumber);
      return;
    }

    // A different destination needs a fresh OTP, sent to the ZMall phone, so
    // only the account owner can approve a new number.
    final newReceiver = receiver;
    RefundOtpSheet.show(
      context: context,
      transaction: widget.transaction,
      service: widget.service,
      currency: widget.currency,
      onForceLogout: widget.onForceLogout,
      onVerified: (_) {
        if (!mounted) return;
        _handleRefund(receiverPhone: newReceiver, shownNumber: shownNumber);
      },
    );
  }

  String _amountText() =>
      widget.transaction['from_amount']?.toStringAsFixed(2) ?? '0.00';

  Future<void> _handleRefund({
    String? receiverPhone,
    required String shownNumber,
  }) async {
    if (_processing) return;
    setState(() => _processing = true);

    Map<String, dynamic> result;
    try {
      result = await widget.service.processRefund(
        transactionId: '${widget.transaction['unique_id'] ?? ''}',
        transactionAmount: widget.transaction['from_amount'],
        receiverPhone: receiverPhone,
      );
    } catch (e) {
      result = {
        'success': false,
        'error_type': 'unknown',
        'message': 'Something went wrong. Please try again.',
      };
    } finally {
      if (mounted) setState(() => _processing = false);
    }

    if (!mounted) return;

    if (result['success'] == true) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      widget.onSuccess();
      messenger.showSnackBar(
        SnackBar(
          content: Text("Refund sent to $shownNumber"),
          backgroundColor: kGreenColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kDefaultPadding),
          ),
        ),
      );
    } else {
      if (result['error_code'] == 999) {
        Navigator.of(context).pop();
        await widget.onForceLogout();
        return;
      }
      if (!mounted) return;
      Service.showMessage(
        context: context,
        title: RefundService.getErrorMessage(
          result,
          "Refund failed. Please try again.",
        ),
        error: true,
        duration: 3,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final refundAmount = _amountText();
    final refundDesc =
        widget.transaction['wallet_description'] ?? 'Refund to telebirr';
    final hintStyle = TextStyle(
      color: kGreyColor.withValues(alpha: 0.7),
      fontSize: 12,
    );

    return AlertDialog(
      backgroundColor: kPrimaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      title: Text(
        "Confirm Refund",
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${widget.currency} $refundAmount",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kSecondaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            SizedBox(height: 8),
            Text(
              refundDesc,
              textAlign: TextAlign.center,
              style: TextStyle(color: kGreyColor, fontSize: 14),
            ),
            SizedBox(height: 8),
            if (!_useOtherNumber) ...[
              Text.rich(
                TextSpan(
                  style: hintStyle,
                  children: [
                    const TextSpan(text: "Refund will be sent to "),
                    TextSpan(
                      text: _zmallNumberText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text:
                          " (your ZMall number). Make sure this number has Telebirr.",
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ] else
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomTextField(
                      controller: _numberController,
                      enabled: !_processing,
                      keyboardType: TextInputType.phone,
                      maxLength: 13,
                      counterText: "",
                      hintText: "Telebirr number (09XXXXXXXX)",
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      ],
                      validator: (value) {
                        if (_normalizeTelebirr(value ?? '') == null) {
                          return "Enter a valid Telebirr number (09XXXXXXXX)";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    CustomTextField(
                      controller: _confirmController,
                      enabled: !_processing,
                      keyboardType: TextInputType.phone,
                      maxLength: 13,
                      counterText: "",
                      hintText: "Re-enter number",
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      ],
                      validator: (value) {
                        final first = _normalizeTelebirr(
                          _numberController.text,
                        );
                        final second = _normalizeTelebirr(value ?? '');
                        if (second == null || first != second) {
                          return "Numbers do not match";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            TextButton(
              onPressed: _processing
                  ? null
                  : () => setState(() => _useOtherNumber = !_useOtherNumber),
              child: Text(
                _useOtherNumber
                    ? "Use my ZMall number"
                    : "Send to a different Telebirr number",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kSecondaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _processing ? null : () => Navigator.of(context).pop(),
          child: Text("Cancel", style: TextStyle(color: kGreyColor)),
        ),
        SizedBox(
          width: 140,
          child: CustomButton(
            title: "Get Refund",
            isLoading: _processing,
            color: kSecondaryColor,
            press: _onGetRefund,
          ),
        ),
      ],
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:zmall/borsa/refund/refund_service.dart';
// import 'package:zmall/services/service.dart';
// import 'package:zmall/utils/constants.dart';
// import 'package:zmall/custom_widgets/custom_button.dart';
// import 'package:zmall/utils/size_config.dart';

// class RefundConfirmationDialog extends StatefulWidget {
//   const RefundConfirmationDialog({
//     super.key,
//     required this.verifyResult,
//     required this.transaction,
//     required this.service,
//     required this.currency,
//     required this.onSuccess,
//     required this.onForceLogout,
//   });

//   final Map<String, dynamic> verifyResult;
//   final dynamic transaction;
//   final RefundService service;
//   final String currency;
//   final VoidCallback onSuccess;
//   final Future<void> Function() onForceLogout;

//   /// Shows the refund confirmation as a bottom sheet.
//   static void show({
//     required BuildContext context,
//     required Map<String, dynamic> verifyResult,
//     required dynamic transaction,
//     required RefundService service,
//     required String currency,
//     required VoidCallback onSuccess,
//     required Future<void> Function() onForceLogout,
//   }) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: kPrimaryColor,
//       isScrollControlled: true,
//       isDismissible: false,
//       enableDrag: false,
//       showDragHandle: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       constraints: BoxConstraints(
//         minHeight: MediaQuery.sizeOf(context).height * 0.30,
//         maxHeight: MediaQuery.sizeOf(context).height * 1.0,
//       ),
//       builder: (_) => RefundConfirmationDialog(
//         verifyResult: verifyResult,
//         transaction: transaction,
//         service: service,
//         currency: currency,
//         onSuccess: onSuccess,
//         onForceLogout: onForceLogout,
//       ),
//     );
//   }

//   @override
//   State<RefundConfirmationDialog> createState() =>
//       _RefundConfirmationDialogState();
// }

// class _RefundConfirmationDialogState extends State<RefundConfirmationDialog> {
//   bool _processing = false;
//   String errorMessage = "";
//   Future<void> _handleRefund() async {
//     if (_processing) return;
//     setState(() => _processing = true);

//     Map<String, dynamic> result;
//     try {
//       result = await widget.service.processRefund(
//         transactionId: '${widget.transaction['unique_id'] ?? ''}',
//         transactionAmount: widget.transaction['from_amount'],
//       );
//       // debugPrint("result: $result");
//     } catch (e) {
//       result = {
//         'success': false,
//         'error_type': 'unknown',
//         'message': 'Something went wrong. Please try again.',
//       };
//     } finally {
//       if (mounted) setState(() => _processing = false);
//     }

//     if (!mounted) return;

//     if (result['success'] == true) {
//       Navigator.of(context).pop();
//       widget.onSuccess();
//       Service.showMessage(
//         context: context,
//         title: result['message'] ?? "Refund processed successfully!",
//         error: false,
//       );
//     } else {
//       if (result['error_code'] == 999) {
//         Navigator.of(context).pop();
//         await widget.onForceLogout();
//         return;
//       }
//       if (!mounted) return;
//       errorMessage = "Refund failed. Please try again.";
//       Service.showMessage(
//         context: context,
//         error: true,
//         duration: 3,
//         title: RefundService.getErrorMessage(
//           result,
//           "Refund failed. Please try again.",
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final refundAmount =
//         widget.transaction['from_amount']?.toStringAsFixed(2) ?? '0.00';
//     final refundDesc =
//         widget.transaction['wallet_description'] ?? 'Refund to telebirr';

//     return SafeArea(
//       child: Container(
//         width: double.infinity,
//         padding:
//             EdgeInsets.symmetric(
//               horizontal: getProportionateScreenWidth(kDefaultPadding),
//               vertical: getProportionateScreenHeight(kDefaultPadding),
//             ).copyWith(
//               bottom:
//                   MediaQuery.of(context).viewInsets.bottom + kDefaultPadding,
//             ),
//         decoration: BoxDecoration(
//           color: kPrimaryColor,
//           borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           spacing: getProportionateScreenHeight(kDefaultPadding),
//           children: [
//             // Title
//             const Text(
//               "Confirm Refund",
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18,
//                 color: kBlackColor,
//               ),
//             ),

//             Center(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   // Amount
//                   Text(
//                     "${widget.currency} $refundAmount",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: kSecondaryColor,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 28,
//                     ),
//                   ),

//                   // Description
//                   Text(
//                     refundDesc,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(color: kGreyColor, fontSize: 14),
//                   ),

//                   const SizedBox(height: 4),

//                   Text(
//                     "This amount will be refunded to your telebirr account.",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: kGreyColor.withValues(alpha: 0.7),
//                       fontSize: 11,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   // error message
//                   if (errorMessage.isNotEmpty && !_processing)
//                     Text(
//                       errorMessage,
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         color: kSecondaryColor,
//                         fontSize: kDefaultPadding,
//                       ),
//                     ),
//                 ],
//               ),
//             ),

//             // Buttons
//             Row(
//               children: [
//                 Expanded(
//                   child: OutlinedButton(
//                     onPressed: _processing
//                         ? null
//                         : () => Navigator.of(context).pop(),
//                     style: OutlinedButton.styleFrom(
//                       foregroundColor: kBlackColor,
//                       backgroundColor: kWhiteColor,
//                       side: const BorderSide(color: Colors.white24),
//                       padding: const EdgeInsets.symmetric(vertical: 14),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     child: const Text(
//                       "Cancel",
//                       style: TextStyle(
//                         fontWeight: FontWeight.w600,
//                         fontSize: 15,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: CustomButton(
//                     title: "Get Refund",
//                     isLoading: _processing,
//                     color: kSecondaryColor,
//                     press: _handleRefund,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
