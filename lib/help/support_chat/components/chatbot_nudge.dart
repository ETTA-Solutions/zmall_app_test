import 'dart:async';
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// A friendly speech-bubble nudge displayed next to the chatbot icon.
///
/// Features:
/// - Smooth entrance (fade + slide + scale) after a customizable delay.
/// - Speech bubble pointer/tail pointing towards the bot.
/// - Pulsing sparkle / indicator.
/// - Close button to dismiss.
/// - Auto-dismiss timer.
/// - Tap to trigger chat navigation.
class ChatbotNudge extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Duration delay;
  final Duration autoDismissDuration;
  final bool autoDismiss;

  const ChatbotNudge({
    super.key,
    this.text = "Need help? Ask me! 👋",
    this.onTap,
    this.onDismiss,
    this.delay = const Duration(seconds: 2),
    this.autoDismissDuration = const Duration(seconds: 8),
    this.autoDismiss = true,
  });

  @override
  State<ChatbotNudge> createState() => _ChatbotNudgeState();
}

class _ChatbotNudgeState extends State<ChatbotNudge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  Timer? _delayTimer;
  Timer? _autoDismissTimer;
  bool _visible = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _scheduleShow();
  }

  void _scheduleShow() {
    _delayTimer = Timer(widget.delay, () {
      if (mounted && !_dismissed) {
        setState(() => _visible = true);
        _animController.forward();

        if (widget.autoDismiss) {
          _autoDismissTimer = Timer(widget.autoDismissDuration, () {
            _dismiss();
          });
        }
      }
    });
  }

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _autoDismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() => _visible = false);
        widget.onDismiss?.call();
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible && !_animController.isAnimating) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  _dismiss();
                  widget.onTap?.call();
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: getProportionateScreenWidth(200),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: getProportionateScreenWidth(12),
                    vertical: getProportionateScreenHeight(8),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      getProportionateScreenWidth(16),
                    ),
                    border: Border.all(
                      color: kSecondaryColor.withValues(alpha: 0.2),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: kSecondaryColor.withValues(alpha: 0.08),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.text,
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(12),
                            fontWeight: FontWeight.w600,
                            color: kBlackColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: getProportionateScreenWidth(6)),
                      GestureDetector(
                        onTap: _dismiss,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kGreyColor.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            HeroiconsOutline.xMark,
                            size: getProportionateScreenWidth(12),
                            color: kGreyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Pointer / Triangle pointing to the bot icon on the right
              CustomPaint(
                size: Size(
                  getProportionateScreenWidth(6),
                  getProportionateScreenHeight(10),
                ),
                painter: _BubbleTailPainter(
                  color: Colors.white,
                  borderColor: kSecondaryColor.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a small speech bubble tail pointing to the right.
class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _BubbleTailPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, fillPaint);

    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      color != oldDelegate.color || borderColor != oldDelegate.borderColor;
}
