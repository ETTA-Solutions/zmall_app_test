import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';

/// Seamless looping GIF animation widget.
/// Flutter's [Image.asset] natively loops GIF files with zero plugins.
/// Falls back to food.png if the GIF fails to load.
class ZmallLoopGif extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Asset path – defaults to the zmall_ai GIF animation.
  final String assetPath;

  const ZmallLoopGif({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.assetPath = zmallAiGif,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true, // prevents flicker between GIF frames
      errorBuilder: (_, __, ___) => Image.asset(
        'images/food.png',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );

    if (borderRadius != null) {
      content = ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }
}