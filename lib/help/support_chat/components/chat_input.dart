import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Clean input bar — ZMall brand theme.
/// kWhiteColor border pill, + left, plain field, send circle right.
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
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        getProportionateScreenWidth(12),
        getProportionateScreenHeight(6),
        getProportionateScreenWidth(12),
        getProportionateScreenHeight(10),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: kGreyColor.withValues(alpha: 0.2),
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── + button ──────────────────────────────────────────────
              GestureDetector(
                onTap: onQuickRepliesToggle,
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
                    hintText: 'Ask anything',
                    hintStyle: TextStyle(
                      color: kGreyColor.withValues(alpha: 0.6),
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

              // ── send / mic button ─────────────────────────────────────
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
                      child: Container(
                        width: getProportionateScreenWidth(36),
                        height: getProportionateScreenWidth(36),
                        decoration: BoxDecoration(
                          color: hasText ? kSecondaryColor : kWhiteColor,
                          shape: BoxShape.circle,
                          border: hasText
                              ? null
                              : Border.all(
                                  color: kGreyColor.withValues(alpha: 0.25),
                                  width: 1,
                                ),
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
                                  hasText
                                      ? HeroiconsSolid.paperAirplane
                                      : HeroiconsOutline.microphone,
                                  color: hasText ? Colors.white : kGreyColor,
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
    if (controller.text.trim().isNotEmpty && !isLoading) {
      onSend();
    }
  }
}
