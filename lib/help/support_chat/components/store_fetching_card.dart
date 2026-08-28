import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// A sleek, vertically scrollable store fetching card for the AI chatbot.
///
/// Matches the modern delivery card design featuring:
/// - Store brand header with logo avatar, name, delivery time, and expand icon
/// - Vertical product item rows with image thumbnails, titles, prices (with strikethrough original prices), and unit labels
/// - Expandable "+X more items" preview with stacked miniature thumbnails
/// - Smooth vertical scrollable view
/// - Footer with "Item subtotal" and formatted total amount
///
///
class StoreFetchingCard extends StatefulWidget {
  final MockStore store;
  final List<MockProduct> products;
  final ValueChanged<MockProduct>? onProductTap;
  final ValueChanged<MockProduct>? onAddToCart;
  final VoidCallback? onViewCart;
  final bool initiallyShowProducts;

  /// When true only the store header (name + delivery time + expand icon)
  /// is shown — no products, no fees, no checkout button.
  final bool storeOnly;

  const StoreFetchingCard({
    super.key,
    required this.store,
    required this.products,
    this.onProductTap,
    this.onAddToCart,
    this.onViewCart,
    this.initiallyShowProducts = true,
    this.storeOnly = false,
  });

  @override
  State<StoreFetchingCard> createState() => _StoreFetchingCardState();
}

class _StoreFetchingCardState extends State<StoreFetchingCard>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyShowProducts;
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double get _subtotal {
    if (widget.products.isEmpty) return 0.0;
    return widget.products.fold(0.0, (sum, p) => sum + p.price);
  }

  String get _formattedSubtotal {
    if (widget.products.isEmpty) return '\$0.00';
    final hasDollar = widget.products.any((p) => p.currencySymbol == '\$');
    if (hasDollar) {
      return '\$${_subtotal.toStringAsFixed(2)}';
    }
    return '${_subtotal.toStringAsFixed(0)} ETB';
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final products = widget.products.isNotEmpty
        ? widget.products
        : getStoreProducts(store.id);

    final visibleCount = _isExpanded
        ? products.length
        : products.length.clamp(0, 3);
    final remainingCount = products.length - 3;
    final hasMore = remainingCount > 0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: getProportionateScreenHeight(4)),
      padding: EdgeInsets.all(getProportionateScreenWidth(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Store header is always shown ─────────────────────────
          _buildStoreHeader(store),

          // ── Everything below is hidden in storeOnly mode ─────────
          if (!widget.storeOnly) ...[
            SizedBox(height: getProportionateScreenHeight(14)),

            if (_isExpanded)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: getProportionateScreenHeight(260),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  radius: const Radius.circular(8),
                  thickness: 3.5,
                  child: ListView.separated(
                    controller: _scrollController,
                    shrinkWrap: false,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _isExpanded ? products.length : visibleCount,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: getProportionateScreenHeight(10)),
                    itemBuilder: (context, index) {
                      return _buildProductRow(products[index]);
                    },
                  ),
                ),
              )
            else
              _buildViewProductsButton(),

            if (hasMore) ...[
              SizedBox(height: getProportionateScreenHeight(10)),
              _buildMoreItemsRow(products, remainingCount),
            ],

            _buildCheckoutFooter(products),
          ],
        ],
      ),
    );
  }

  Widget _buildViewProductsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          setState(() => _isExpanded = true);
        },
        icon: Icon(
          HeroiconsOutline.shoppingBag,
          size: getProportionateScreenWidth(16),
        ),
        label: const Text('View products'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1E293B),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          padding: EdgeInsets.symmetric(
            vertical: getProportionateScreenHeight(11),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: TextStyle(
            fontSize: getProportionateScreenWidth(13),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Store Header ───────────────────────────────────────────────────
  Widget _buildStoreHeader(MockStore store) {
    final logoText = store.logoText.isNotEmpty
        ? store.logoText
        : (store.name.length > 12 ? store.name.substring(0, 12) : store.name);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Store Avatar / Icon badge
        Container(
          width: getProportionateScreenWidth(42),
          height: getProportionateScreenWidth(42),
          decoration: BoxDecoration(
            color: store.themeColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: store.themeColor.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.all(getProportionateScreenWidth(3)),
          child: Text(
            logoText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: getProportionateScreenWidth(9),
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),

        SizedBox(width: getProportionateScreenWidth(12)),

        // Store Name & Description
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                store.name,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(15.5),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: getProportionateScreenHeight(3)),
              // Category badge
              Text(
                store.category,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(12),
                  fontWeight: FontWeight.w500,
                  color: kSecondaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: getProportionateScreenHeight(4)),
              // Rating + delivery time + location row
              Wrap(
                spacing: getProportionateScreenWidth(8),
                runSpacing: getProportionateScreenHeight(2),
                children: [
                  // Star rating
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        HeroiconsSolid.star,
                        size: getProportionateScreenWidth(11),
                        color: const Color(0xFFF59E0B),
                      ),
                      SizedBox(width: getProportionateScreenWidth(3)),
                      Text(
                        store.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(11.5),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  // Delivery time
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        HeroiconsOutline.clock,
                        size: getProportionateScreenWidth(11),
                        color: const Color(0xFF94A3B8),
                      ),
                      SizedBox(width: getProportionateScreenWidth(3)),
                      Text(
                        store.deliveryTime,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(11.5),
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  // Location
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        HeroiconsSolid.mapPin,
                        size: getProportionateScreenWidth(11),
                        color: const Color(0xFF94A3B8),
                      ),
                      SizedBox(width: getProportionateScreenWidth(3)),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: getProportionateScreenWidth(110),
                        ),
                        child: Text(
                          store.location,
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(11.5),
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── end of store info ──────────────────────────────────────
      ],
    );
  }

  // ── Product Row ────────────────────────────────────────────────────
  Widget _buildProductRow(MockProduct product) {
    final hasOriginal =
        product.originalPrice != null && product.originalPrice! > product.price;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onProductTap?.call(product);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: getProportionateScreenHeight(3),
          horizontal: getProportionateScreenWidth(2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product Thumbnail
            Container(
              width: getProportionateScreenWidth(44),
              height: getProportionateScreenWidth(44),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: product.localImageAsset.isNotEmpty
                    ? Image.asset(
                        product.localImageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackThumbnail(),
                      )
                    : _buildFallbackThumbnail(),
              ),
            ),

            SizedBox(width: getProportionateScreenWidth(11)),

            // Name & Pricing
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(13.5),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: getProportionateScreenHeight(3)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.formattedPrice,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(13),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      if (hasOriginal) ...[
                        SizedBox(width: getProportionateScreenWidth(6)),
                        Text(
                          product.formattedOriginalPrice ?? '',
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(12),
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFF94A3B8),
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: getProportionateScreenWidth(8)),

            // Unit Label / Quick Add
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onAddToCart?.call(product);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(9),
                  vertical: getProportionateScreenHeight(4),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.unit,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(12.5),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(width: getProportionateScreenWidth(4)),
                    Icon(
                      HeroiconsMini.plus,
                      size: getProportionateScreenWidth(12),
                      color: kSecondaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── "+X more items" Row ────────────────────────────────────────────
  Widget _buildMoreItemsRow(List<MockProduct> products, int remainingCount) {
    final nextProducts = products.skip(3).take(2).toList();

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: getProportionateScreenHeight(5),
          horizontal: getProportionateScreenWidth(2),
        ),
        child: Row(
          children: [
            // Stacked miniature thumbnails
            SizedBox(
              width: getProportionateScreenWidth(44),
              height: getProportionateScreenWidth(26),
              child: Stack(
                children: [
                  for (int i = 0; i < nextProducts.length; i++)
                    Positioned(
                      left: i * getProportionateScreenWidth(14),
                      child: Container(
                        width: getProportionateScreenWidth(24),
                        height: getProportionateScreenWidth(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: nextProducts[i].localImageAsset.isNotEmpty
                              ? Image.asset(
                                  nextProducts[i].localImageAsset,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildMiniFallback(),
                                )
                              : _buildMiniFallback(),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(width: getProportionateScreenWidth(11)),

            // "+X more items" text
            Expanded(
              child: Text(
                _isExpanded
                    ? "Show fewer items"
                    : "+$remainingCount more items",
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(13.5),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),

            // Chevron
            Icon(
              _isExpanded ? HeroiconsMini.chevronUp : HeroiconsMini.chevronDown,
              size: getProportionateScreenWidth(16),
              color: const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  // ── Checkout Footer (Instacart-style) ──────────────────────────────
  Widget _buildCheckoutFooter(List<MockProduct> products) {
    final deliveryFee = widget.store.deliveryFee;
    final double serviceFee = (_subtotal * 0.049).clamp(0.0, 9999.0);
    final double estimatedTax = (_subtotal * 0.005).clamp(0.0, 9999.0);
    final double total = _subtotal + deliveryFee + serviceFee + estimatedTax;

    String fmt(double v) {
      final hasDollar = widget.products.any((p) => p.currencySymbol == '\$');
      if (hasDollar) return '\$${v.toStringAsFixed(2)}';
      if (v == 0) return '\$0.00';
      return '${v.toStringAsFixed(0)} ETB';
    }

    String fmtTotal(double v) {
      final hasDollar = widget.products.any((p) => p.currencySymbol == '\$');
      if (hasDollar) return '\$${v.toStringAsFixed(2)}';
      return '${v.toStringAsFixed(0)} ETB';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: getProportionateScreenHeight(14)),

        // ── Fee breakdown rows ─────────────────────────────────────
        _buildFeeRow(
          label: '${products.length} item${products.length != 1 ? 's' : ''}',
          value: _formattedSubtotal,
          strikeValue: null,
          isBold: false,
        ),
        SizedBox(height: getProportionateScreenHeight(6)),
        _buildFeeRow(
          label: 'Delivery fee',
          value: deliveryFee == 0 ? '\$0.00' : fmt(deliveryFee),
          strikeValue: null,
          isBold: false,
        ),
        SizedBox(height: getProportionateScreenHeight(6)),
        _buildFeeRow(
          label: 'Service fee',
          value: fmt(serviceFee),
          strikeValue: null,
          hasInfo: true,
          isBold: false,
        ),
        SizedBox(height: getProportionateScreenHeight(6)),
        _buildFeeRow(
          label: 'Estimated taxes',
          value: fmt(estimatedTax),
          strikeValue: null,
          hasInfo: true,
          isBold: false,
        ),

        SizedBox(height: getProportionateScreenHeight(14)),

        // ── Divider ────────────────────────────────────────────────
        Container(height: 1, color: const Color(0xFFF1F5F9)),

        SizedBox(height: getProportionateScreenHeight(14)),

        // ── ZMall brand row ────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: getProportionateScreenWidth(22),
              height: getProportionateScreenWidth(22),

              decoration: BoxDecoration(
                color: kSecondaryColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                'Z',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: getProportionateScreenWidth(11),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: getProportionateScreenWidth(7)),
            Text(
              'ZMall',
              style: TextStyle(
                fontSize: getProportionateScreenWidth(14),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),

        SizedBox(height: getProportionateScreenHeight(16)),

        // ── Total row ──────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: TextStyle(
                fontSize: getProportionateScreenWidth(18),
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              fmtTotal(total),
              style: TextStyle(
                fontSize: getProportionateScreenWidth(18),
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),

        SizedBox(height: getProportionateScreenHeight(14)),

        // ── Place Order button ─────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onViewCart?.call();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: EdgeInsets.symmetric(
                vertical: getProportionateScreenHeight(15),
              ),
              decoration: BoxDecoration(
                color: kSecondaryColor,
                borderRadius: BorderRadius.circular(50),
              ),
              alignment: Alignment.center,
              child: Text(
                'Place order',
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(15),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: getProportionateScreenHeight(12)),

        // ── Fine print ─────────────────────────────────────────────
        Text(
          'By ordering, you agree to ZMall\'s Terms of Service and Privacy Policy. '
          'ZMall AI does not process your order, collect payment, or handle fulfillment.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: getProportionateScreenWidth(10),
            fontWeight: FontWeight.w400,
            color: const Color(0xFFCBD5E1),
            height: 1.45,
          ),
        ),

        SizedBox(height: getProportionateScreenHeight(4)),
      ],
    );
  }

  /// A single fee breakdown row.
  Widget _buildFeeRow({
    required String label,
    required String value,
    String? strikeValue,
    bool hasInfo = false,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: getProportionateScreenWidth(13),
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color: const Color(0xFF475569),
              ),
            ),
            if (hasInfo) ...[
              SizedBox(width: getProportionateScreenWidth(4)),
              Icon(
                HeroiconsOutline.informationCircle,
                size: getProportionateScreenWidth(13),
                color: const Color(0xFF94A3B8),
              ),
            ],
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (strikeValue != null) ...[
              Text(
                strikeValue,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(12.5),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: const Color(0xFF94A3B8),
                  color: const Color(0xFF94A3B8),
                ),
              ),
              SizedBox(width: getProportionateScreenWidth(5)),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: getProportionateScreenWidth(13),
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFallbackThumbnail() {
    return Center(
      child: Icon(
        HeroiconsOutline.shoppingBag,
        size: getProportionateScreenWidth(20),
        color: const Color(0xFFCBD5E1),
      ),
    );
  }

  Widget _buildMiniFallback() {
    return Center(
      child: Icon(
        HeroiconsOutline.shoppingBag,
        size: getProportionateScreenWidth(12),
        color: const Color(0xFFCBD5E1),
      ),
    );
  }
}
