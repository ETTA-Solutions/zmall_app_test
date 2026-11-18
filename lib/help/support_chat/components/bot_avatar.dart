import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// ZMall AI avatar — brand gradient circle with a sparkle, used everywhere
/// the assistant appears (header, messages, typing, welcome).
class BotAvatar extends StatelessWidget {
  final double size;

  const BotAvatar({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final dimension = getProportionateScreenWidth(size);
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(kSecondaryColor, Colors.white, 0.18)!,
            kSecondaryColor,
          ],
        ),
      ),
      child: Icon(
        HeroiconsSolid.sparkles,
        color: Colors.white,
        size: dimension * 0.52,
      ),
    );
  }
}

/// Soft fill used by bot bubbles, chips and the input bar.
const kChatSurfaceColor = Color(0xFFF4F5F7);

/// Bot bubbles: white with a hairline border and a soft lift.
const kChatBubbleBorderColor = Color(0xFFEAECEF);
const kChatBubbleShadow = [
  BoxShadow(color: Color(0x0D101828), blurRadius: 10, offset: Offset(0, 3)),
];
