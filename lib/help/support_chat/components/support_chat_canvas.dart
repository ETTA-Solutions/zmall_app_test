import 'package:flutter/material.dart';

/// Plain white canvas — clean, minimal, no glow effects.
class SupportChatCanvas extends StatelessWidget {
  final Widget child;

  const SupportChatCanvas({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Colors.white, child: child);
  }
}
