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
    final cardWidth = getProportionateScreenWidth(165);
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
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9080A8).withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Image with Rating Badge ──────────────────────────────
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: imageHeight,
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
                    top: getProportionateScreenHeight(8),
                    left: getProportionateScreenWidth(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: getProportionateScreenWidth(8),
                        vertical: getProportionateScreenHeight(4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
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
                            size: getProportionateScreenWidth(11),
                          ),
                          SizedBox(width: getProportionateScreenWidth(3.5)),
                          Text(
                            "4.8",
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(10.5),
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

              // ── Product Details & Add button ────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  getProportionateScreenWidth(12),
                  getProportionateScreenHeight(10),
                  getProportionateScreenWidth(12),
                  getProportionateScreenHeight(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.product.name,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(13),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E1B2E),
                        height: 1.25,
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
                    ),
                    SizedBox(height: getProportionateScreenHeight(8)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            "${widget.product.price.toStringAsFixed(0)} ETB",
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(14.5),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1E1B2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: getProportionateScreenWidth(6)),
                        // Sleek Circular '+' Add to Cart Button
                        GestureDetector(
                          onTap: widget.onAddToCart,
                          child: Container(
                            width: getProportionateScreenWidth(32),
                            height: getProportionateScreenWidth(32),
                            decoration: BoxDecoration(
                              color: kSecondaryColor.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: kSecondaryColor.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                HeroiconsOutline.plus,
                                size: getProportionateScreenWidth(16),
                                color: const Color(0xFF1E1B2E),
                              ),
                            ),
                          ),
                        ),
                      ],
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
      color: const Color(0xFFF5EEF8),
      child: Center(
        child: Icon(
          HeroiconsOutline.shoppingBag,
          size: getProportionateScreenWidth(32),
          color: const Color(0xFFC4B5FD),
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
          height: getProportionateScreenHeight(228),
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
