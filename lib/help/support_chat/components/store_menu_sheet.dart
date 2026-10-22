import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/help/support_chat/components/product_detail_sheet.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Bottom sheet that shows a store's full menu — no page navigation.
///
/// Usage:
///   StoreMenuSheet.show(context, store: store);
///   StoreMenuSheet.show(context, store: store, products: backendProducts);
class StoreMenuSheet {
  static void show(BuildContext context, {required MockStore store, List<MockProduct>? products}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _StoreMenuSheet(store: store, products: products),
    );
  }
}

class _StoreMenuSheet extends StatefulWidget {
  final MockStore store;
  final List<MockProduct>? products; // Optional backend products
  const _StoreMenuSheet({required this.store, this.products});

  @override
  State<_StoreMenuSheet> createState() => _StoreMenuSheetState();
}

class _StoreMenuSheetState extends State<_StoreMenuSheet> {
  // Tracks per-product cart quantities for the inline +/- stepper
  final Map<String, int> _quantities = {};

  int _qtyFor(String id) => _quantities[id] ?? 0;

  Future<void> _handleAddToCart(MockProduct product, int qty) async {
    final items = List<MockProduct>.filled(qty, product);
    await addMockProductsToCart(items);
    if (!mounted) return;
    setState(() => _quantities[product.id] = qty);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$qty × ${product.name} added to cart'),
        backgroundColor: kBlackColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _openProduct(MockProduct product) {
    ProductDetailSheet.show(
      context,
      product: product,
      onAddToCart: _handleAddToCart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final products = widget.products ?? const [];
    final logoText = store.logoText.isNotEmpty
        ? store.logoText
        : store.name.substring(0, store.name.length.clamp(0, 10));
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          // Max 85% of screen height so it feels like a proper sheet
          constraints: BoxConstraints(maxHeight: screenH * 0.85),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                  top: getProportionateScreenHeight(12),
                  bottom: getProportionateScreenHeight(4),
                ),
                child: Container(
                  width: getProportionateScreenWidth(40),
                  height: getProportionateScreenHeight(4),
                  decoration: BoxDecoration(
                    color: kGreyColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // ── Store header ─────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  getProportionateScreenWidth(20),
                  getProportionateScreenHeight(12),
                  getProportionateScreenWidth(20),
                  getProportionateScreenHeight(4),
                ),
                child: Row(
                  children: [
                    // Logo / Image
                    _buildHeaderAvatar(context, logoText),

                    SizedBox(width: getProportionateScreenWidth(14)),

                    // Name + meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.name,
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(17),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: getProportionateScreenHeight(3)),
                          Text(
                            store.category,
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(12),
                              fontWeight: FontWeight.w500,
                              color: kSecondaryColor,
                            ),
                          ),
                          SizedBox(height: getProportionateScreenHeight(5)),
                          Row(
                            children: [
                              // Only show rating if available from backend
                              if (store.hasRating) ...[
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
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                SizedBox(width: getProportionateScreenWidth(10)),
                              ],
                              Icon(
                                HeroiconsOutline.clock,
                                size: getProportionateScreenWidth(11),
                                color: const Color(0xFF94A3B8),
                              ),
                              SizedBox(width: getProportionateScreenWidth(3)),
                              Flexible(
                                child: Text(
                                  store.deliveryTime,
                                  style: TextStyle(
                                    fontSize: getProportionateScreenWidth(11.5),
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(getProportionateScreenWidth(8)),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Icon(
                          HeroiconsOutline.xMark,
                          size: getProportionateScreenWidth(16),
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(20),
                  vertical: getProportionateScreenHeight(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(height: 1, color: const Color(0xFFF1F5F9)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: getProportionateScreenWidth(10),
                      ),
                      child: Text(
                        '${products.length} items',
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(11),
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(height: 1, color: const Color(0xFFF1F5F9)),
                    ),
                  ],
                ),
              ),

              // ── Product list ─────────────────────────────────────
              Flexible(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    getProportionateScreenWidth(16),
                    0,
                    getProportionateScreenWidth(16),
                    getProportionateScreenHeight(24) + bottomPad,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => Container(
                    height: 1,
                    color: const Color(0xFFF8FAFC),
                    margin: EdgeInsets.symmetric(
                      vertical: getProportionateScreenHeight(2),
                    ),
                  ),
                  itemBuilder: (context, index) => _MenuProductRow(
                    product: products[index],
                    qty: _qtyFor(products[index].id),
                    onTap: () => _openProduct(products[index]),
                    onAdd: () async {
                      HapticFeedback.selectionClick();
                      await _handleAddToCart(products[index], 1);
                    },
                    onIncrement: () async {
                      final current = _qtyFor(products[index].id);
                      await _handleAddToCart(products[index], current + 1);
                    },
                    onDecrement: () {
                      HapticFeedback.selectionClick();
                      final current = _qtyFor(products[index].id);
                      if (current > 0) {
                        setState(() => _quantities[products[index].id] = current - 1);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAvatar(BuildContext context, String logoText) {
    final hasImage = widget.store.imageUrl.isNotEmpty;
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final fullImageUrl = hasImage
        ? (widget.store.imageUrl.startsWith('http')
            ? widget.store.imageUrl
            : '$baseUrl/${widget.store.imageUrl}')
        : '';

    Widget fallback() => Container(
          width: getProportionateScreenWidth(48),
          height: getProportionateScreenWidth(48),
          decoration: BoxDecoration(
            color: widget.store.themeColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.store.themeColor.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.all(getProportionateScreenWidth(4)),
          child: Text(
            logoText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: getProportionateScreenWidth(8.5),
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        );

    if (!hasImage) return fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: getProportionateScreenWidth(48),
        height: getProportionateScreenWidth(48),
        color: const Color(0xFFF1F5F9),
        child: CachedNetworkImage(
          imageUrl: fullImageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback(),
          errorWidget: (_, __, ___) => fallback(),
        ),
      ),
    );
  }
}

/// A single product row inside the store menu sheet.
class _MenuProductRow extends StatelessWidget {
  final MockProduct product;
  final int qty;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _MenuProductRow({
    required this.product,
    required this.qty,
    required this.onTap,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = product.localImageAsset.isNotEmpty;
    final hasOriginal =
        product.originalPrice != null &&
        product.originalPrice! > product.price;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: getProportionateScreenHeight(10),
          horizontal: getProportionateScreenWidth(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: getProportionateScreenWidth(58),
                height: getProportionateScreenWidth(58),
                color: const Color(0xFFF8F8F8),
                padding: EdgeInsets.all(getProportionateScreenWidth(6)),
                child: hasImage
                    ? Image.asset(
                        product.localImageAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _fallback(),
                      )
                    : _fallback(),
              ),
            ),

            SizedBox(width: getProportionateScreenWidth(12)),

            // Name + price
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: getProportionateScreenHeight(4)),
                  Row(
                    children: [
                      Text(
                        product.formattedPrice,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(13),
                          fontWeight: FontWeight.w700,
                          color: kSecondaryColor,
                        ),
                      ),
                      if (hasOriginal) ...[
                        SizedBox(width: getProportionateScreenWidth(6)),
                        Text(
                          product.formattedOriginalPrice ?? '',
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(11.5),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: kGreyColor,
                            color: kGreyColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: getProportionateScreenWidth(10)),

            // Add button or stepper
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: qty == 0
                  ? _AddBtn(key: const ValueKey('add'), onTap: onAdd)
                  : _InlineStepper(
                      key: const ValueKey('stepper'),
                      qty: qty,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Center(
        child: Icon(
          HeroiconsOutline.shoppingBag,
          size: getProportionateScreenWidth(22),
          color: kGreyColor.withValues(alpha: 0.25),
        ),
      );
}

class _AddBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(16),
          vertical: getProportionateScreenHeight(8),
        ),
        decoration: BoxDecoration(
          color: kSecondaryColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          'Add',
          style: TextStyle(
            color: Colors.white,
            fontSize: getProportionateScreenWidth(12.5),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InlineStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _InlineStepper({
    super.key,
    required this.qty,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(10),
                vertical: getProportionateScreenHeight(7),
              ),
              child: Text(
                '−',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: getProportionateScreenWidth(16),
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
          Text(
            '$qty',
            style: TextStyle(
              color: Colors.white,
              fontSize: getProportionateScreenWidth(13),
              fontWeight: FontWeight.w800,
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(10),
                vertical: getProportionateScreenHeight(7),
              ),
              child: Text(
                '+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: getProportionateScreenWidth(16),
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
