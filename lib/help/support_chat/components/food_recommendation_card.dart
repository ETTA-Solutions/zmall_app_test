import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// A compact food card for mock chatbot product results.
///
/// Shows:
/// - Floating rating badge (`⭐ 4.8`) at top-left
/// - High-resolution meal image
/// - Product name & subtitle/delivery time
/// - Price in ETB
/// - Minimalist `+` Add to Cart button
class FoodRecommendationCard extends StatefulWidget {
  final MockProduct product;
  final VoidCallback? onAddToCart;
  final VoidCallback? onProductTap;

  const FoodRecommendationCard({
    super.key,
    required this.product,
    this.onAddToCart,
    this.onProductTap,
  });

  @override
  State<FoodRecommendationCard> createState() => _FoodRecommendationCardState();
}

class _FoodRecommendationCardState extends State<FoodRecommendationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.04,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = getProportionateScreenWidth(155);
    final imageHeight = getProportionateScreenHeight(115);
    final hasImage = widget.product.localImageAsset.isNotEmpty;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: widget.onProductTap,
        child: Container(
          width: cardWidth,
          padding: EdgeInsets.all(getProportionateScreenWidth(8)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9080A8).withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Image Container (Rounded Rectangle with Border) ──────
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: imageHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Hero(
                        tag: 'mock_product_image_${widget.product.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: hasImage
                              ? Image.asset(
                                  widget.product.localImageAsset,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                  alignment: Alignment.center,
                                  errorBuilder: (_, __, ___) =>
                                      _buildImagePlaceholder(imageHeight),
                                )
                              : _buildImagePlaceholder(imageHeight),
                        ),
                      ),
                    ),
                  ),
                  // Rating Badge (⭐ 4.8)
                  Positioned(
                    top: getProportionateScreenHeight(6),
                    left: getProportionateScreenWidth(6),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: getProportionateScreenWidth(7),
                        vertical: getProportionateScreenHeight(3),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            HeroiconsSolid.star,
                            color: const Color(0xFFF59E0B),
                            size: getProportionateScreenWidth(10),
                          ),
                          SizedBox(width: getProportionateScreenWidth(3)),
                          Text(
                            "4.8",
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(10),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Product Details & Full-Width Add Button ─────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  getProportionateScreenWidth(2),
                  getProportionateScreenHeight(8),
                  getProportionateScreenWidth(2),
                  getProportionateScreenHeight(2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${widget.product.price.toStringAsFixed(0)} ETB",
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(14.5),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E1B2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: getProportionateScreenHeight(2)),
                    Text(
                      widget.product.name,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(12),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E1B2E),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: getProportionateScreenHeight(2)),
                    Text(
                      widget.product.category,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(10),
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: getProportionateScreenHeight(8)),
                    // Full-width pill 'Add' button
                    GestureDetector(
                      onTap: widget.onAddToCart,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: getProportionateScreenHeight(7),
                        ),
                        decoration: BoxDecoration(
                          color: kSecondaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            "Add",
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(12),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(double height) {
    return Container(
      height: height,
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Icon(
          HeroiconsOutline.shoppingBag,
          size: getProportionateScreenWidth(30),
          color: const Color(0xFFCBD5E1),
        ),
      ),
    );
  }
}

/// A horizontal scrollable row of [FoodRecommendationCard]s shown
/// inside bot responses as a simple horizontal product strip.
class FoodRecommendationRow extends StatelessWidget {
  final List<MockProduct> products;
  final VoidCallback? onViewCart;
  final ValueChanged<MockProduct>? onProductTap;
  final ValueChanged<MockProduct>? onAddToCart;

  const FoodRecommendationRow({
    super.key,
    required this.products,
    this.onViewCart,
    this.onProductTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: getProportionateScreenHeight(2)),
        SizedBox(
          height: getProportionateScreenHeight(255),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            padding: EdgeInsets.only(
              right: getProportionateScreenWidth(4),
              bottom: getProportionateScreenHeight(4),
            ),
            itemCount: products.length,
            separatorBuilder: (_, __) =>
                SizedBox(width: getProportionateScreenWidth(12)),
            itemBuilder: (context, index) {
              return FoodRecommendationCard(
                product: products[index],
                onAddToCart: () => onAddToCart?.call(products[index]),
                onProductTap: () => onProductTap?.call(products[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
