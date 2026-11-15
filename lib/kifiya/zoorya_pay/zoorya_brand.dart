import 'package:flutter/material.dart';

/// Zoorya Pay brand blue, sampled from the logo pill.
const Color kZooryaBlue = Color(0xFF01AFF3);
const Color kZooryaBlueDark = Color(0xFF0090CC);

/// The Zoorya Pay logo pill, used as the "powered by" mark on every
/// Zoorya Pay payment page.
class ZooryaPayBadge extends StatelessWidget {
  const ZooryaPayBadge({super.key, this.height = 26});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'images/payment/zoorya_pay_logo.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Zoorya Pay',
    );
  }
}
