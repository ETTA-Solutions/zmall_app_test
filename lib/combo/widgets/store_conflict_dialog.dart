import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/utils/constants.dart';

/// Shown when an item comes from a store other than the one in the cart.
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

  // Short, friendly label shown above the buttons
  final String hint = comboFull
      ? lang.comboStoreLimit
      : allowCombo
      ? lang.comboItemsFound
      : lang.itemsFound;

  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (dialogContext) {
      return _StoreConflictDialog(
        hint: hint,
        allowCombo: allowCombo,
        comboFull: comboFull,
        lang: lang,
        onCombo: () {
          Navigator.of(dialogContext).pop();
          onCombo();
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
        onReplace: onReplace != null
            ? () {
                Navigator.of(dialogContext).pop();
                onReplace();
              }
            : null,
        onClear: () {
          Navigator.of(dialogContext).pop();
          onClear();
        },
      );
    },
  );
}

class _StoreConflictDialog extends StatefulWidget {
  final String hint;
  final bool allowCombo;
  final bool comboFull;
  final ZLanguage lang;
  final VoidCallback onCombo;
  final VoidCallback onCancel;
  final VoidCallback? onReplace;
  final VoidCallback onClear;

  const _StoreConflictDialog({
    required this.hint,
    required this.allowCombo,
    required this.comboFull,
    required this.lang,
    required this.onCombo,
    required this.onCancel,
    required this.onReplace,
    required this.onClear,
  });

  @override
  State<_StoreConflictDialog> createState() => _StoreConflictDialogState();
}

class _StoreConflictDialogState extends State<_StoreConflictDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: kPrimaryColor,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Short hint line ───────────────────────────────────────
                Text(
                  widget.hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kBlackColor.withValues(alpha: 0.75),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // ── Primary action: order from both stores ────────────────
                if (widget.allowCombo && !widget.comboFull) ...[
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: widget.onCombo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSecondaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                      child: Text(
                        widget.lang.orderFromBothStores,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Secondary row: Cancel | Replace / Clear ───────────────
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: widget.onCancel,
                          style: TextButton.styleFrom(
                            backgroundColor:
                                kBlackColor.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Text(
                            widget.lang.cancel,
                            style: TextStyle(
                              color: kBlackColor.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: widget.comboFull && widget.onReplace != null
                          ? _outlinedBtn(
                              label: "Replace store",
                              color: kSecondaryColor,
                              onTap: widget.onReplace!,
                            )
                          : _outlinedBtn(
                              label: widget.allowCombo
                                  ? "Replace"
                                  : widget.lang.clear,
                              color: widget.allowCombo
                                  ? kSecondaryColor
                                  : Colors.redAccent,
                              onTap: widget.onClear,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlinedBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.55), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
