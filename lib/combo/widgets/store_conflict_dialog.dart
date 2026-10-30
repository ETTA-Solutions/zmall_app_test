import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/utils/constants.dart';

/// Shown when an item comes from a store other than the one in the cart.
///
/// [allowCombo] adds "Order from both stores". [comboFull] means two stores
/// are already in the cart, so only clearing is possible.
/// The dialog closes itself before calling [onClear] / [onCombo].
Future<void> showStoreConflictDialog({
  required BuildContext context,
  required bool allowCombo,
  required bool comboFull,
  required VoidCallback onClear,
  required VoidCallback onCombo,
}) {
  final lang = Provider.of<ZLanguage>(context, listen: false);
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: kPrimaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kDefaultPadding),
      ),
      title: Text(
        comboFull
            ? lang.warning
            : allowCombo
            ? "Combo Order"
            : lang.warning,
        style: TextStyle(
          color: kBlackColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: Text(
        comboFull
            ? lang.comboStoreLimit
            : allowCombo
            ? lang.comboItemsFound
            : lang.itemsFound,
        style: TextStyle(
          color: kBlackColor.withValues(alpha: 0.8),
          fontSize: 14,
          height: 1.4,
        ),
      ),
      actions: [
        if (allowCombo)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onCombo();
            },
            child: Text(
              lang.orderFromBothStores,
              style: TextStyle(
                color: kSecondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                lang.cancel,
                style: TextStyle(
                  color: kBlackColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: kDefaultPadding / 4),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onClear();
              },
              child: Text(
                lang.clear,
                style: TextStyle(
                  color: kGreyColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
