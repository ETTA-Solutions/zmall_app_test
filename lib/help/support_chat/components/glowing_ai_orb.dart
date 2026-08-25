import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// A glowing, iridescent AI sphere with animated sheen and ambient glow,
/// matching the iridescent AI aesthetic from the reference design.
class GlowingAiOrb extends StatefulWidget {
  final double size;
  final bool showFloatingElements;

  /// When true, fits exactly inside [size] with no glow overflow.
  final bool compact;

  const GlowingAiOrb({
    super.key,
    this.size = 140,
    this.showFloatingElements = true,
    this.compact = false,
  });

  @override
  State<GlowingAiOrb> createState() => _GlowingAiOrbState();
}

class _GlowingAiOrbState extends State<GlowingAiOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbSize = widget.size;
    final compact = widget.compact;
    final outerSize = compact ? orbSize : orbSize * 1.3;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        final floatOffset =
            compact ? 0.0 : math.sin(val * 2 * math.pi) * 5;

        return SizedBox(
          width: outerSize,
          height: outerSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            children: [
              if (!compact)
                Container(
                  width: orbSize * 1.15,
                  height: orbSize * 1.15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        kSecondaryColor.withValues(alpha: 0.15),
                        const Color(0xFFE9D5FF).withValues(alpha: 0.5),
                        const Color(0xFFBAE6FD).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.1, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),

              Transform.translate(
                offset: Offset(0, floatOffset),
                child: Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.35, -0.35),
                      radius: 0.95,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFFF1F3),
                        Color(0xFFFBCFE8),
                        Color(0xFFE0F2FE),
                        Color(0xFFF472B6),
                        Color(0xFFC084FC),
                      ],
                      stops: [0.0, 0.2, 0.4, 0.55, 0.82, 1.0],
                    ),
                    boxShadow: compact
                        ? null
                        : [
                            BoxShadow(
                              color: kSecondaryColor.withValues(alpha: 0.25),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.3),
                              blurRadius: 25,
                              offset: const Offset(-6, -6),
                            ),
                          ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        // Glass Highlight Sheen
                        Positioned(
                          top: orbSize * 0.1,
                          left: orbSize * 0.18,
                          child: Container(
                            width: orbSize * 0.38,
                            height: orbSize * 0.25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.85),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Inner Dynamic Swirl
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                transform: GradientRotation(val * 2 * math.pi),
                                colors: [
                                  Colors.transparent,
                                  const Color(
                                    0xFF60A5FA,
                                  ).withValues(alpha: 0.18),
                                  const Color(
                                    0xFFF43F5E,
                                  ).withValues(alpha: 0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Sparkles & Food Elements (if enabled)
              if (widget.showFloatingElements) ...[
                // Top-right Sparkle
                Positioned(
                  top: orbSize * 0.15,
                  right: orbSize * 0.1,
                  child: Text(
                    "✨",
                    style: TextStyle(fontSize: getProportionateScreenWidth(16)),
                  ),
                ),
                // Top-left Pizza slice accent
                Positioned(
                  top: orbSize * 0.18 + floatOffset * 0.5,
                  left: orbSize * 0.05,
                  child: Text(
                    "🍕",
                    style: TextStyle(fontSize: getProportionateScreenWidth(26)),
                  ),
                ),
                // Bottom-right Pepper / Burger accent
                Positioned(
                  bottom: orbSize * 0.2 - floatOffset * 0.5,
                  right: orbSize * 0.06,
                  child: Text(
                    "🍔",
                    style: TextStyle(fontSize: getProportionateScreenWidth(22)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
