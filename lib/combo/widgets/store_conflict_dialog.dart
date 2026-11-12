import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/utils/constants.dart';

/// Shown when an item comes from a store other than the one in the cart.
///
/// [allowCombo] adds "Order from both stores". [comboFull] means two stores
/// are already in the cart, so only clearing is possible.
/// [onReplace] (only when [comboFull]) swaps the combo's second store for the
/// new one and keeps the first store.
/// The dialog closes itself before calling [onClear] / [onCombo] / [onReplace].
Future<void> showStoreConflictDialog({
  required BuildContext context,
  required bool allowCombo,
  required bool comboFull,
  required VoidCallback onClear,
  required VoidCallback onCombo,
  VoidCallback? onReplace,
}) {
  final lang = Provider.of<ZLanguage>(context, listen: false);
  debugPrint(
    '[COMBO DIALOG] allowCombo=$allowCombo comboFull=$comboFull '
    'hasReplace=${onReplace != null}',
  );
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: kPrimaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kDefaultPadding),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (allowCombo ? kSecondaryColor : Colors.orange).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              allowCombo ? Icons.layers_outlined : Icons.warning_amber_rounded,
              color: allowCombo ? kSecondaryColor : Colors.orange[800],
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              comboFull
                  ? lang.warning
                  : allowCombo
                  ? "Combo Order"
                  : lang.warning,
              style: const TextStyle(
                color: kBlackColor,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ],
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
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (allowCombo) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onCombo();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: const Icon(
                    Icons.storefront_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    lang.orderFromBothStores,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    lang.cancel,
                    style: TextStyle(
                      color: kBlackColor.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (comboFull && onReplace != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      onReplace();
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: kSecondaryColor.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: kSecondaryColor.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    icon: Icon(
                      Icons.swap_horiz_rounded,
                      size: 16,
                      color: kSecondaryColor,
                    ),
                    label: Text(
                      "Replace second store",
                      style: TextStyle(
                        color: kSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      onClear();
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: allowCombo
                            ? kSecondaryColor.withValues(alpha: 0.6)
                            : Colors.redAccent.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor:
                          (allowCombo ? kSecondaryColor : Colors.redAccent)
                              .withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    icon: Icon(
                      allowCombo
                          ? Icons.swap_horiz_rounded
                          : Icons.delete_outline_rounded,
                      size: 16,
                      color: allowCombo ? kSecondaryColor : Colors.redAccent,
                    ),
                    label: Text(
                      allowCombo ? "Replace" : lang.clear,
                      style: TextStyle(
                        color: allowCombo ? kSecondaryColor : Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
