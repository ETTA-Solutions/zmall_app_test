import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Shows a product detail bottom sheet without leaving the chat.
///
/// Usage:
///   ProductDetailSheet.show(context, product: product, onAddToCart: ...);
class ProductDetailSheet {
  static void show(
    BuildContext context, {
    required MockProduct product,
    required Future<void> Function(MockProduct, int) onAddToCart,
    Future<void> Function(MockProduct, int)? onOrderNow,
  }) {
    debugPrint("🔍 [PRODUCT SHEET] Showing sheet for: ${product.name} (id: ${product.id}, storeId: ${product.storeId}, price: ${product.price})");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _ProductDetailSheet(
        product: product,
        onAddToCart: onAddToCart,
        onOrderNow: onOrderNow,
      ),
    );
  }
}

class _ProductDetailSheet extends StatefulWidget {
  final MockProduct product;
  final Future<void> Function(MockProduct, int) onAddToCart;

  /// Skips the cart and goes straight to payment (see ChatCheckoutService).
  final Future<void> Function(MockProduct, int)? onOrderNow;

  const _ProductDetailSheet({
    required this.product,
    required this.onAddToCart,
    this.onOrderNow,
  });

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  int _qty = 1;
  bool _adding = false;

  void _increment() {
    HapticFeedback.selectionClick();
    if (_qty < 9) {
      setState(() => _qty++);
      debugPrint("🔢 [PRODUCT SHEET] Incremented quantity: $_qty for ${widget.product.name}");
    }
  }

  void _decrement() {
    HapticFeedback.selectionClick();
    if (_qty > 1) {
      setState(() => _qty--);
      debugPrint("🔢 [PRODUCT SHEET] Decremented quantity: $_qty for ${widget.product.name}");
    }
  }

  Future<void> _handleAdd() async {
    if (_adding) return;
    setState(() => _adding = true);
    HapticFeedback.mediumImpact();
    debugPrint("🛒 [PRODUCT SHEET] Adding to cart: ${widget.product.name} x $_qty");
    await widget.onAddToCart(widget.product, _qty);
    if (!mounted) return;
    setState(() => _adding = false);
    Navigator.pop(context);
  }

  void _handleOrderNow() {
    if (_adding) return;
    HapticFeedback.mediumImpact();
    final qty = _qty;
    debugPrint("⚡ [PRODUCT SHEET] Direct Order Now: ${widget.product.name} x $qty");
    // Close the sheet first; the chat shows progress and opens payment.
    Navigator.pop(context);
    widget.onOrderNow!(widget.product, qty);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final hasImage = product.localImageAsset.isNotEmpty;
    final hasOriginal =
        product.originalPrice != null &&
        product.originalPrice! > product.price;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(top: getProportionateScreenHeight(12)),
                child: Container(
                  width: getProportionateScreenWidth(40),
                  height: getProportionateScreenHeight(4),
                  decoration: BoxDecoration(
                    color: kGreyColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // ── Product image ──────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  getProportionateScreenWidth(20),
                  getProportionateScreenHeight(16),
                  getProportionateScreenWidth(20),
                  0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    height: getProportionateScreenHeight(210),
                    color: const Color(0xFFF8F8F8),
                    padding: EdgeInsets.all(getProportionateScreenWidth(20)),
                    child: hasImage
                        ? Image.asset(
                            product.localImageAsset,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => _fallback(),
                          )
                        : _fallback(),
                  ),
                ),
              ),

              // ── Info + controls ────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  getProportionateScreenWidth(20),
                  getProportionateScreenHeight(18),
                  getProportionateScreenWidth(20),
                  getProportionateScreenHeight(16) + bottomPad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(18),
                        fontWeight: FontWeight.w800,
                        color: kBlackColor,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),

                    SizedBox(height: getProportionateScreenHeight(6)),

                    // Price row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(20),
                            fontWeight: FontWeight.w900,
                            color: kSecondaryColor,
                          ),
                        ),
                        if (hasOriginal) ...[
                          SizedBox(width: getProportionateScreenWidth(8)),
                          Text(
                            product.formattedOriginalPrice ?? '',
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(14),
                              decoration: TextDecoration.lineThrough,
                              decorationColor: kGreyColor,
                              color: kGreyColor,
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Unit label
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: getProportionateScreenWidth(10),
                            vertical: getProportionateScreenHeight(4),
                          ),
                          decoration: BoxDecoration(
                            color: kGreyColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            product.unit,
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(12),
                              color: kGreyColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Description
                    if (product.description.isNotEmpty) ...[
                      SizedBox(height: getProportionateScreenHeight(12)),
                      Text(
                        product.description,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(13.5),
                          color: kGreyColor,
                          height: 1.55,
                        ),
                      ),
                    ],

                    SizedBox(height: getProportionateScreenHeight(22)),

                    // ── Qty stepper + Add to Cart ──────────────────
                    Row(
                      children: [
                        // Stepper
                        Container(
                          decoration: BoxDecoration(
                            color: kGreyColor.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: kGreyColor.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StepBtn(
                                label: '−',
                                enabled: _qty > 1,
                                onTap: _decrement,
                              ),
                              SizedBox(
                                width: getProportionateScreenWidth(32),
                                child: Center(
                                  child: Text(
                                    '$_qty',
                                    style: TextStyle(
                                      fontSize:
                                          getProportionateScreenWidth(16),
                                      fontWeight: FontWeight.w800,
                                      color: kBlackColor,
                                    ),
                                  ),
                                ),
                              ),
                              _StepBtn(
                                label: '+',
                                enabled: _qty < 9,
                                onTap: _increment,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: getProportionateScreenWidth(14)),

                        // Add to Cart button
                        Expanded(
                          child: GestureDetector(
                            onTap: _adding ? null : _handleAdd,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              height: getProportionateScreenHeight(52),
                              decoration: BoxDecoration(
                                color: _adding
                                    ? kSecondaryColor.withValues(alpha: 0.7)
                                    : kSecondaryColor,
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        kSecondaryColor.withValues(alpha: 0.3),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: _adding
                                  ? SizedBox(
                                      width: getProportionateScreenWidth(20),
                                      height: getProportionateScreenWidth(20),
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          HeroiconsSolid.shoppingCart,
                                          color: Colors.white,
                                          size: getProportionateScreenWidth(
                                            16,
                                          ),
                                        ),
                                        SizedBox(
                                          width:
                                              getProportionateScreenWidth(8),
                                        ),
                                        Text(
                                          'Add to Cart',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize:
                                                getProportionateScreenWidth(
                                              15,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Order Now → payment ────────────────────────
                    if (widget.onOrderNow != null) ...[
                      SizedBox(height: getProportionateScreenHeight(12)),
                      GestureDetector(
                        onTap: _adding ? null : _handleOrderNow,
                        child: Container(
                          height: getProportionateScreenHeight(52),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: kSecondaryColor,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                HeroiconsOutline.creditCard,
                                color: kSecondaryColor,
                                size: getProportionateScreenWidth(16),
                              ),
                              SizedBox(width: getProportionateScreenWidth(8)),
                              Text(
                                'Order Now · ${(product.price * _qty).toStringAsFixed(0)} ${product.currencySymbol}',
                                style: TextStyle(
                                  color: kSecondaryColor,
                                  fontSize: getProportionateScreenWidth(15),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Center(
        child: Icon(
          HeroiconsOutline.shoppingBag,
          size: getProportionateScreenWidth(48),
          color: kGreyColor.withValues(alpha: 0.2),
        ),
      );
}

class _StepBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(14),
          vertical: getProportionateScreenHeight(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: getProportionateScreenWidth(20),
            fontWeight: FontWeight.w400,
            color: enabled ? kSecondaryColor : kGreyColor.withValues(alpha: 0.3),
            height: 1,
          ),
        ),
      ),
    );
  }
}
