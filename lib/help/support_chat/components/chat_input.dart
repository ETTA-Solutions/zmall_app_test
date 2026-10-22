import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/components/bot_avatar.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Clean input bar — ZMall brand theme.
/// Soft grey pill, + left, plain field, send circle right.
class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;
  final VoidCallback? onQuickRepliesToggle;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
    this.onQuickRepliesToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        getProportionateScreenWidth(12),
        getProportionateScreenHeight(8),
        getProportionateScreenWidth(12),
        getProportionateScreenHeight(10),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: kBlackColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: kChatSurfaceColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── + button ──────────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  debugPrint("⌨️ [CHAT INPUT] (+) Quick replies toggle pressed");
                  onQuickRepliesToggle?.call();
                },
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    getProportionateScreenWidth(14),
                    0,
                    getProportionateScreenWidth(4),
                    getProportionateScreenHeight(11),
                  ),
                  child: Icon(
                    HeroiconsOutline.plusCircle,
                    size: getProportionateScreenWidth(22),
                    color: kSecondaryColor,
                  ),
                ),
              ),

              // ── text field ────────────────────────────────────────────
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: InputDecoration(
                    hintText: 'Ask ZMall AI anything…',
                    hintStyle: TextStyle(
                      color: kGreyColor.withValues(alpha: 0.7),
                      fontSize: getProportionateScreenWidth(14),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: getProportionateScreenHeight(11),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(14),
                    color: kBlackColor,
                  ),
                ),
              ),

              // ── send button ─────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  getProportionateScreenWidth(4),
                  0,
                  getProportionateScreenWidth(8),
                  getProportionateScreenHeight(8),
                ),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final hasText = controller.text.trim().isNotEmpty;
                    return GestureDetector(
                      onTap: isLoading ? null : _handleSend,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: getProportionateScreenWidth(36),
                        height: getProportionateScreenWidth(36),
                        decoration: BoxDecoration(
                          color: hasText ? kSecondaryColor : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isLoading
                              ? SizedBox(
                                  width: getProportionateScreenWidth(16),
                                  height: getProportionateScreenWidth(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      hasText ? Colors.white : kGreyColor,
                                    ),
                                  ),
                                )
                              : Icon(
                                  HeroiconsSolid.arrowUp,
                                  color: hasText
                                      ? Colors.white
                                      : kGreyColor.withValues(alpha: 0.5),
                                  size: getProportionateScreenWidth(16),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSend() {
    final text = controller.text.trim();
    if (text.isNotEmpty && !isLoading) {
      debugPrint("⌨️ [CHAT INPUT] _handleSend triggered with text: \"$text\"");
      onSend();
    } else {
      debugPrint("⌨️ [CHAT INPUT] _handleSend ignored (hasText=${text.isNotEmpty}, isLoading=$isLoading)");
    }
  }
}
