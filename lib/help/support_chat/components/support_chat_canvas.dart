import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';

/// Branded chat canvas: soft white base with ZMall red accent washes.
class SupportChatCanvas extends StatelessWidget {
  final Widget child;

  const SupportChatCanvas({super.key, required this.child});

  static BoxDecoration get decoration => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFFBFB),
            kPrimaryColor,
            const Color(0xFFFFF5F6),
            kWhiteColor,
          ],
          stops: const [0.0, 0.35, 0.72, 1.0],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(child: DecoratedBox(decoration: decoration)),
        // Top-right brand glow
        Positioned(
          top: -100,
          right: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  kSecondaryColor.withValues(alpha: 0.12),
                  kSecondaryColor.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        // Bottom-left soft accent
        Positioned(
          bottom: 80,
          left: -80,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  kSecondaryColor.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Subtle center sheen
        Positioned(
          top: MediaQuery.sizeOf(context).height * 0.18,
          left: MediaQuery.sizeOf(context).width * 0.15,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kSecondaryColor.withValues(alpha: 0.025),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
