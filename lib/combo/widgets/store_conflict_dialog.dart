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
  final String title = comboFull
      ? lang.warning
      : allowCombo
      ? "Items from another store"
      : lang.warning;
  final String message = comboFull
      ? lang.comboStoreLimit
      : allowCombo
      ? lang.comboItemsFound
      : lang.itemsFound;

  return showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: kPrimaryColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kDefaultPadding * 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kBlackColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kBlackColor.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (allowCombo) ...[
              SizedBox(
                height: 46,
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
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: Text(
                    lang.orderFromBothStores,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      lang.cancel,
                      style: TextStyle(
                        color: kBlackColor.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: comboFull && onReplace != null
                      ? _actionButton(
                          icon: Icons.swap_horiz_rounded,
                          label: "Replace second store",
                          color: kSecondaryColor,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            onReplace();
                          },
                        )
                      : _actionButton(
                          icon: allowCombo
                              ? Icons.swap_horiz_rounded
                              : Icons.delete_outline_rounded,
                          label: allowCombo ? "Replace" : lang.clear,
                          color: allowCombo ? kSecondaryColor : Colors.redAccent,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            onClear();
                          },
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

/// Outlined action with no background fill.
Widget _actionButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    ),
    icon: Icon(icon, size: 16, color: color),
    label: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}
