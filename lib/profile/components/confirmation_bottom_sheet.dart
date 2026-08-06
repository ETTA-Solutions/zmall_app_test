import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';

class ConfirmationBottomSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool
  isDestructive; // true = red button (Delete), false = normal (Logout)
  final IconData? icon;

  const ConfirmationBottomSheet({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.onConfirm,
    this.cancelText = "Cancel",
    this.onCancel,
    this.isDestructive = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kPrimaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWhiteColor,
                // color: isDestructive
                //     ? Colors.redAccent.withValues(alpha: 0.15)
                //     : kSecondaryColor.withValues(alpha: 0.15),
                // shape: BoxShape.circle,
                borderRadius: BorderRadius.circular(kDefaultPadding),
              ),
              child: Icon(
                icon,
                size: 32,
                // color: isDestructive ? Colors.redAccent : kSecondaryColor,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              // color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Message
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              // color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 32),

          // Buttons
          Row(
            children: [
              // Cancel
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onCancel?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlackColor,
                    backgroundColor: kWhiteColor,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    cancelText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Confirm
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondaryColor,
                    // isDestructive
                    //     ? Colors.redAccent
                    //     : kSecondaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
