import 'package:flutter/material.dart';
import 'package:zmall/help/support_chat/components/chat_bot_icon.dart';
import 'package:zmall/help/support_chat/components/chatbot_nudge.dart';

/// Floating chatbot button shown on the dashboard (bottom-right).
/// Includes:
/// - An animated [ChatBotIcon] with oscillating dots and swinging motion.
/// - An optional [ChatbotNudge] speech bubble that slides in to invite users.
class FloatingChatButton extends StatefulWidget {
  final VoidCallback? onTap;
  final String? nudgeText;
  final bool showNudge;
  final Duration nudgeDelay;
  final Duration autoDismissDuration;
  final bool autoDismiss;

  const FloatingChatButton({
    super.key,
    this.onTap,
    this.nudgeText,
    this.showNudge = true,
    this.nudgeDelay = const Duration(seconds: 2),
    this.autoDismissDuration = const Duration(seconds: 8),
    this.autoDismiss = true,
  });

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.showNudge)
          ChatbotNudge(
            text: widget.nudgeText ?? "Need help? Ask me! 👋",
            onTap: widget.onTap,
            delay: widget.nudgeDelay,
            autoDismissDuration: widget.autoDismissDuration,
            autoDismiss: widget.autoDismiss,
          ),
        if (widget.showNudge) const SizedBox(width: 4),
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedBuilder(
            animation: _swing,
            builder: (context, child) {
              return Transform.rotate(angle: _swing.value, child: child);
            },
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedScale(
                scale: _hovering ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: const ChatBotIcon(
                  width: 65,
                  height: 65,
                  iconSize: 65,
                  showContainer: false,
                  animated: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
