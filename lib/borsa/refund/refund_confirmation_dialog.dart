import 'package:flutter/material.dart';
import 'package:zmall/borsa/refund/refund_service.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/custom_widgets/custom_button.dart';

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

  Future<void> _handleRefund() async {
    if (_processing) return;
    setState(() => _processing = true);

    Map<String, dynamic> result;
    try {
      result = await widget.service.processRefund(
        transactionId: '${widget.transaction['unique_id'] ?? ''}',
        transactionAmount: widget.transaction['from_amount'],
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
          content: Text(result['message'] ?? "Refund processed successfully!"),
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
    final refundAmount =
        widget.transaction['from_amount']?.toStringAsFixed(2) ?? '0.00';
    final refundDesc =
        widget.transaction['wallet_description'] ?? 'Refund to telebirr';

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
      content: Column(
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
          SizedBox(height: 4),
          Text(
            "This amount will be refunded to your telebirr account.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kGreyColor.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          SizedBox(height: 12),
        ],
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
            press: _handleRefund,
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
