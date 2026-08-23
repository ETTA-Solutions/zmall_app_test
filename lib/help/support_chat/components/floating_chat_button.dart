import 'package:flutter/material.dart';
import 'package:zmall/help/support_chat/components/chat_bot_icon.dart';
import 'package:zmall/utils/size_config.dart';

/// Floating circular chatbot button shown on the dashboard (bottom-right).
/// Uses the animated [ChatBotIcon] with oscillating dots; scales up slightly
/// when hovered or tapped.
class FloatingChatButton extends StatefulWidget {
  final VoidCallback? onTap;

  const FloatingChatButton({super.key, this.onTap});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _swing;

  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _swing = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = getProportionateScreenWidth(60);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedBuilder(
        animation: _swing,
        builder: (context, child) {
          return Transform.rotate(angle: _swing.value, child: child);
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovering ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFf11d3a),
                  width: 2,
                ),
              ),
              padding: EdgeInsets.all(getProportionateScreenWidth(6)),
              child: Center(
                child: ChatBotIcon(
                  width: size * 0.75,
                  height: size * 0.75,
                  iconSize: size * 0.58,
                  showContainer: false,
                  animated: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
