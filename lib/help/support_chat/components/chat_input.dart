import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/components/glowing_ai_orb.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

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
        getProportionateScreenWidth(16),
        getProportionateScreenHeight(8),
        getProportionateScreenWidth(16),
        getProportionateScreenHeight(14),
      ),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                getProportionateScreenWidth(6),
                getProportionateScreenHeight(6),
                getProportionateScreenWidth(8),
                getProportionateScreenHeight(6),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(
                  color: kSecondaryColor.withValues(alpha: 0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kSecondaryColor.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: getProportionateScreenWidth(34),
                    height: getProportionateScreenWidth(34),
                    child: GlowingAiOrb(
                      size: getProportionateScreenWidth(30),
                      showFloatingElements: false,
                      compact: true,
                    ),
                  ),
                  SizedBox(width: getProportionateScreenWidth(4)),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) {
                        return TextField(
                          controller: controller,
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSend(),
                          decoration: InputDecoration(
                            hintText: "Ask me anything about food...",
                            hintStyle: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontSize: getProportionateScreenWidth(13),
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: getProportionateScreenHeight(10),
                            ),
                          ),
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(14),
                            color: const Color(0xFF1E1B2E),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final hasText = controller.text.trim().isNotEmpty;
                      return GestureDetector(
                        onTap: isLoading ? null : _handleSend,
                        child: Container(
                          width: getProportionateScreenWidth(38),
                          height: getProportionateScreenWidth(38),
                          decoration: BoxDecoration(
                            gradient: hasText
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      kSecondaryColor,
                                      kSecondaryColor.withValues(alpha: 0.85),
                                    ],
                                  )
                                : null,
                            color: hasText
                                ? null
                                : kSecondaryColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            boxShadow: hasText
                                ? [
                                    BoxShadow(
                                      color: kSecondaryColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isLoading
                                ? SizedBox(
                                    width: getProportionateScreenWidth(16),
                                    height: getProportionateScreenWidth(16),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    hasText
                                        ? HeroiconsSolid.paperAirplane
                                        : HeroiconsOutline.camera,
                                    color: hasText
                                        ? kPrimaryColor
                                        : kSecondaryColor.withValues(alpha: 0.6),
                                    size: getProportionateScreenWidth(18),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
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
