import 'package:flutter/material.dart';
import 'package:zmall/utils/size_config.dart';

/// ChatBotIcon composed of:
/// - Upper side: The Zmall "Z" cart body (`images/chat_bot_upper.png`)
/// - Under side: The two dots / wheels (`images/chat_bot_dots.png`)
/// - Animated: The two dots smoothly oscillate horizontally (left to right).
class ChatBotIcon extends StatefulWidget {
  final double? width;
  final double? height;
  final double? iconSize;
  final bool animated;
  final bool showContainer;
  final Color? backgroundColor;
  final Color? borderColor;

  const ChatBotIcon({
    super.key,
    this.width,
    this.height,
    this.iconSize,
    this.animated = true,
    this.showContainer = true,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<ChatBotIcon> createState() => _ChatBotIconState();
}

class _ChatBotIconState extends State<ChatBotIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _dotsOffset;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _initAnimation();
    }
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _dotsOffset = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ChatBotIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        if (_controller == null) {
          _initAnimation();
        } else {
          _controller?.repeat(reverse: true);
        }
      } else {
        _controller?.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildGraphic(double innerIconSize) {
    final totalHeight = innerIconSize;
    final upperHeight = totalHeight * 0.74;
    final upperWidth = upperHeight * (600 / 676);
    final gapHeight = totalHeight * 0.02;
    final dotsHeight = totalHeight * 0.23;
    final dotsWidth = dotsHeight * (634 / 208);
    final maxShift = totalHeight * 0.07;

    return SizedBox(
      width: innerIconSize,
      height: innerIconSize,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: upperWidth,
            height: upperHeight,
            child: Image.asset(
              'images/chat_bot_upper.png',
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: gapHeight),
          if (widget.animated && _controller != null && _dotsOffset != null)
            AnimatedBuilder(
              animation: _dotsOffset!,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_dotsOffset!.value * maxShift, 0),
                  child: child,
                );
              },
              child: SizedBox(
                width: dotsWidth,
                height: dotsHeight,
                child: Image.asset(
                  'images/chat_bot_dots.png',
                  fit: BoxFit.contain,
                ),
              ),
            )
          else
            SizedBox(
              width: dotsWidth,
              height: dotsHeight,
              child: Image.asset(
                'images/chat_bot_dots.png',
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final containerWidth = getProportionateScreenWidth(widget.width ?? 32);
    final containerHeight = getProportionateScreenWidth(widget.height ?? 32);
    final innerIconSize = getProportionateScreenWidth(
      widget.iconSize ?? (widget.width != null ? widget.width! * 0.65 : 20),
    );

    if (!widget.showContainer) {
      return _buildGraphic(innerIconSize);
    }

    return Container(
      width: containerWidth,
      height: containerHeight,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.borderColor ?? const Color(0xFFf11d3a),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: _buildGraphic(innerIconSize),
    );
  }
}
