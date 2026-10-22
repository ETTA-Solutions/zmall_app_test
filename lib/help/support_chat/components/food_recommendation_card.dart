import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Chatbot product card — matches the reference image exactly:
///   • White card, rounded corners
///   • Square white image area (product centered, BoxFit.contain)
///   • Price bold + strikethrough original below image
///   • Product name (2 lines, regular weight)
///   • Unit / qty label (small gray)
///   • Full-width rounded Add button in kSecondaryColor
///   • Tapping the card or Add opens the product sheet (qty, Add to cart,
///     Order now) — one place to pick a quantity
class FoodRecommendationCard extends StatefulWidget {
  final MockProduct product;
  final VoidCallback? onProductTap;

  const FoodRecommendationCard({
    super.key,
    required this.product,
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
      duration: const Duration(milliseconds: 100),
      lowerBound: 0,
      upperBound: 0.03,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Card is fixed 160 wide — two cards visible at a time
    final cardWidth = getProportionateScreenWidth(160);
    final imageAreaSize = cardWidth; // square image area
    final hasImage = widget.product.localImageAsset.isNotEmpty;
    final hasOriginal =
        widget.product.originalPrice != null &&
        widget.product.originalPrice! > widget.product.price;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: () {
          HapticFeedback.selectionClick();
          debugPrint("🍔 [FOOD CARD] Card tapped: '${widget.product.name}' (id: ${widget.product.id}, price: ${widget.product.price})");
          widget.onProductTap?.call();
        },
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kGreyColor.withValues(alpha: 0.14),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: kBlackColor.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Image area: full-bleed product image ───────────────
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: imageAreaSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: kGreyColor.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      child: hasImage
                          ? Image.asset(
                              widget.product.localImageAsset,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) =>
                                  _buildImageFallback(),
                            )
                          : _buildImageFallback(),
                    ),
                  ),

                ],
              ),

              // ── Text + button ──────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  getProportionateScreenWidth(10),
                  getProportionateScreenHeight(10),
                  getProportionateScreenWidth(10),
                  getProportionateScreenHeight(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Price row: bold current + strikethrough original
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          widget.product.formattedPrice,
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(14.5),
                            fontWeight: FontWeight.w800,
                            color: kBlackColor,
                          ),
                        ),
                        if (hasOriginal) ...[
                          SizedBox(width: getProportionateScreenWidth(5)),
                          Text(
                            widget.product.formattedOriginalPrice ?? '',
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(11.5),
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: kGreyColor,
                              color: kGreyColor,
                            ),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: getProportionateScreenHeight(5)),

                    // Product name — regular weight, 2 lines max
                    Text(
                      widget.product.name,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(13),
                        fontWeight: FontWeight.w500,
                        color: kBlackColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: getProportionateScreenHeight(3)),

                    // Unit / qty label — small gray
                    Text(
                      widget.product.unit,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(11.5),
                        color: kGreyColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    SizedBox(height: getProportionateScreenHeight(12)),

                    _buildAddButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Full-width kSecondaryColor "Add" pill — the card's tap opens the sheet
  Widget _buildAddButton() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: getProportionateScreenHeight(10),
      ),
      decoration: BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            HeroiconsSolid.plus,
            size: getProportionateScreenWidth(15),
            color: Colors.white,
          ),
          SizedBox(width: getProportionateScreenWidth(4)),
          Text(
            'Add',
            style: TextStyle(
              fontSize: getProportionateScreenWidth(13.5),
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFallback() {
    return Center(
      child: Icon(
        HeroiconsOutline.shoppingBag,
        size: getProportionateScreenWidth(36),
        color: kGreyColor.withValues(alpha: 0.25),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal scrollable strip of FoodRecommendationCards
// ─────────────────────────────────────────────────────────────────────────────
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

    return SizedBox(
      // card image (160) + text area + button — fixed height
      height: getProportionateScreenHeight(340),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.only(
          right: getProportionateScreenWidth(4),
          bottom: getProportionateScreenHeight(4),
          top: getProportionateScreenHeight(2),
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, __) =>
            SizedBox(width: getProportionateScreenWidth(12)),
        itemBuilder: (context, i) => FoodRecommendationCard(
          product: products[i],
          onProductTap: () => onProductTap?.call(products[i]),
        ),
      ),
    );
  }
}
