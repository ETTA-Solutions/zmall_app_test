import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Shared building blocks for the chat ordering UI. Colours, radii and
/// controls follow the ZMall web ordering widget so both feel the same.
const kZInk = Color(0xFF111827);
const kZMuted = Color(0xFF6B7280);
const kZBorder = Color(0xFFE5E7EB);
const kZSurface = Color(0xFFF9FAFB);

String _resolveImageUrl(BuildContext context, String url) {
  if (url.isEmpty || url.startsWith('http')) return url;
  final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
  return '$baseUrl/$url';
}

/// Bordered white card used by every ordering surface.
class ZCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? accent; // optional left accent stripe (basket bar)
  final bool raised;

  const ZCard({
    super.key,
    required this.child,
    this.padding,
    this.accent,
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kZBorder),
        boxShadow: raised
            ? [
                BoxShadow(
                  color: kBlackColor.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: accent == null
            ? null
            : BoxDecoration(
                border: Border(left: BorderSide(color: accent!, width: 3)),
              ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Small rounded label — "10 items", "★ 4.5", "ZMall Partner".
class ZPill extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const ZPill({super.key, required this.label, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final tint = color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(9),
        vertical: getProportionateScreenHeight(3),
      ),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.08) ?? const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: tint == null
            ? null
            : Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: getProportionateScreenWidth(11),
              color: tint ?? const Color(0xFFF59E0B),
            ),
            SizedBox(width: getProportionateScreenWidth(3)),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: getProportionateScreenWidth(11.5),
              fontWeight: FontWeight.w600,
              color: tint ?? const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

/// Store logo — network image on a light tile, monogram fallback.
class ZStoreLogo extends StatelessWidget {
  final MockStore store;
  final double size;

  const ZStoreLogo({super.key, required this.store, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final dimension = getProportionateScreenWidth(size);
    final url = _resolveImageUrl(context, store.imageUrl);

    Widget fallback() => Container(
      color: kSecondaryColor.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        store.name.isNotEmpty ? store.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: kSecondaryColor,
          fontSize: dimension * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kZBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? fallback()
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback(),
              errorWidget: (_, __, ___) => fallback(),
            ),
    );
  }
}

/// Product thumbnail — network image, or the web widget's red gradient tile
/// with a cart glyph when the item has no photo.
class ZProductThumb extends StatelessWidget {
  final MockProduct product;
  final double size;

  const ZProductThumb({super.key, required this.product, this.size = 78});

  @override
  Widget build(BuildContext context) {
    final dimension = getProportionateScreenWidth(size);
    final url = _resolveImageUrl(context, product.imageUrl);

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(kSecondaryColor, Colors.white, 0.35)!,
            kSecondaryColor,
            Color.lerp(kSecondaryColor, Colors.black, 0.28)!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          HeroiconsOutline.shoppingCart,
          color: Colors.white,
          size: dimension * 0.34,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(size > 50 ? 6 : 4),
      child: SizedBox(
        width: dimension,
        height: dimension,
        child: url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

/// "+ Add" outlined button that morphs into a − n + stepper once the item is
/// in the basket.
class ZAddStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const ZAddStepper({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: quantity == 0
          ? _AddButton(key: const ValueKey('add'), onTap: onAdd)
          : ZQtyStepper(
              key: const ValueKey('stepper'),
              quantity: quantity,
              onAdd: onAdd,
              onRemove: onRemove,
              filled: true,
            ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(14),
            vertical: getProportionateScreenHeight(7),
          ),
          child: Text(
            '+ Add',
            style: TextStyle(
              fontSize: getProportionateScreenWidth(13),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }
}

/// − n + stepper. [filled] uses the brand colour (menu rows); otherwise the
/// neutral bordered style of the web basket.
class ZQtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool filled;

  const ZQtyStepper({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : kZInk;

    Widget button(String glyph, VoidCallback onTap) => InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: getProportionateScreenWidth(32),
        height: getProportionateScreenWidth(32),
        child: Center(
          child: Text(
            glyph,
            style: TextStyle(
              fontSize: getProportionateScreenWidth(16),
              fontWeight: FontWeight.w600,
              color: fg,
              height: 1,
            ),
          ),
        ),
      ),
    );

    return Material(
      color: filled ? kSecondaryColor : kZSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: filled ? BorderSide.none : const BorderSide(color: kZBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('−', onRemove),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.6),
                end: Offset.zero,
              ).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Container(
              key: ValueKey(quantity),
              constraints: BoxConstraints(
                minWidth: getProportionateScreenWidth(22),
              ),
              color: filled ? null : Colors.white,
              alignment: Alignment.center,
              height: getProportionateScreenWidth(32),
              child: Text(
                '$quantity',
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(14),
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ),
          button('+', onAdd),
        ],
      ),
    );
  }
}

/// Full-width brand button — "Instant Checkout · 800 ETB".
class ZPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const ZPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: getProportionateScreenHeight(50),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kSecondaryColor,
          disabledBackgroundColor: kSecondaryColor.withValues(alpha: 0.7),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: loading
            ? SizedBox(
                width: getProportionateScreenWidth(20),
                height: getProportionateScreenWidth(20),
                child: const CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Full-width outlined button — "Browse More Restaurants".
class ZOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const ZOutlineButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: getProportionateScreenHeight(42),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF374151),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: getProportionateScreenWidth(14),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Tap feedback: slight scale-down while pressed.
class ZPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const ZPressable({super.key, required this.child, this.onTap});

  @override
  State<ZPressable> createState() => _ZPressableState();
}

class _ZPressableState extends State<ZPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        child: widget.child,
      ),
    );
  }
}

/// Fades + slides a child in after [index] × 45 ms — staggered list entrance.
class ZStaggered extends StatelessWidget {
  final int index;
  final Widget child;

  const ZStaggered({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 10)) * 45;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Interval(delay / (320 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
