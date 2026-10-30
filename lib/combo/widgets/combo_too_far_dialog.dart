import 'package:flutter/material.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Shows a centered dialog when two combo stores are too far apart.
Future<void> showComboTooFarDialog({
  required BuildContext context,
  required double actualKm,
  required double maxKm,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ComboTooFarDialog(actualKm: actualKm, maxKm: maxKm),
  );
}

class _ComboTooFarDialog extends StatelessWidget {
  final double actualKm;
  final double maxKm;

  const _ComboTooFarDialog({
    required this.actualKm,
    required this.maxKm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding * 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(kDefaultPadding * 1.2),
        ),
        padding: EdgeInsets.all(
          getProportionateScreenWidth(kDefaultPadding * 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon (no background, no shadow)
            Icon(
              Icons.store_mall_directory_outlined,
              color: kSecondaryColor,
              size: getProportionateScreenWidth(kDefaultPadding * 3.2),
            ),

            SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),

            // Title
            Text(
              'Stores Are Too Far Apart',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kBlackColor,
              ),
            ),

            SizedBox(
              height: getProportionateScreenHeight(kDefaultPadding * 0.8),
            ),

            // Body
            Text(
              'These two stores are ${actualKm.toStringAsFixed(1)} km apart.\n'
              'Combo orders are only available when stores are within '
              '${maxKm.toStringAsFixed(1)} km of each other.\n\n'
              'Please pick a closer store or order from each store separately.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: kBlackColor.withValues(alpha: 0.65),
                height: 1.5,
              ),
            ),

            SizedBox(
              height: getProportionateScreenHeight(kDefaultPadding * 1.5),
            ),

            // Dismiss button (brand button)
            CustomButton(
              title: 'Got it',
              color: kSecondaryColor,
              press: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
