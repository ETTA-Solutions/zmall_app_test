import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Vertically scrollable inline store list shown directly in the chat.
///
/// Has a fixed height so it fits inside the message column without
/// pushing everything else off-screen. The user simply scrolls up/down
/// inside the card to browse all stores — no navigation needed.
class StoreCarousel extends StatelessWidget {
  final List<MockStore>? stores; // Optional: if null, uses mock data
  final ValueChanged<MockProduct>? onProductTap;
  final ValueChanged<MockProduct>? onAddToCart;
  final ValueChanged<MockStore>? onMenuRequested;
  final Function(MockStore, List<MockProduct>)? onMenuRequestedWithProducts;

  const StoreCarousel({
    super.key,
    this.stores,
    this.onProductTap,
    this.onAddToCart,
    this.onMenuRequested,
    this.onMenuRequestedWithProducts,
  });

  @override
  Widget build(BuildContext context) {
    final storeList = stores ?? const [];
    if (storeList.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(
            left: getProportionateScreenWidth(2),
            bottom: getProportionateScreenHeight(8),
          ),
          child: Row(
            children: [
              Icon(
                HeroiconsSolid.mapPin,
                size: getProportionateScreenWidth(13),
                color: kSecondaryColor,
              ),
              SizedBox(width: getProportionateScreenWidth(5)),
              Text(
                'Stores near you',
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(13),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(9),
                  vertical: getProportionateScreenHeight(3),
                ),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: kSecondaryColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  '${storeList.length} stores',
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(11),
                    fontWeight: FontWeight.w600,
                    color: kSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Scrollable list ───────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            // Show exactly 4 store rows at once
            height: getProportionateScreenHeight(340),
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: storeList.length,
              separatorBuilder: (_, __) => Container(
                height: 1,
                color: const Color(0xFFF1F5F9),
                margin: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(14),
                ),
              ),
              itemBuilder: (context, index) => _StoreRow(
                store: storeList[index],
                isFirst: index == 0,
                isLast: index == storeList.length - 1,
                onProductTap: onProductTap,
                onAddToCart: onAddToCart,
                onMenuRequested: onMenuRequested,
                onMenuRequestedWithProducts: onMenuRequestedWithProducts,
              ),
            ),
          ),
        ),

        // ── Scroll hint ────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(
            top: getProportionateScreenHeight(6),
            left: getProportionateScreenWidth(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                HeroiconsMini.chevronUpDown,
                size: getProportionateScreenWidth(11),
                color: kGreyColor.withValues(alpha: 0.5),
              ),
              SizedBox(width: getProportionateScreenWidth(4)),
              Text(
                'Scroll to see all stores',
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(11),
                  color: kGreyColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single row inside the scrollable store list.
class _StoreRow extends StatelessWidget {
  final MockStore store;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<MockProduct>? onProductTap;
  final ValueChanged<MockProduct>? onAddToCart;
  final ValueChanged<MockStore>? onMenuRequested;
  final Function(MockStore, List<MockProduct>)? onMenuRequestedWithProducts;

  const _StoreRow({
    required this.store,
    required this.isFirst,
    required this.isLast,
    this.onProductTap,
    this.onAddToCart,
    this.onMenuRequested,
    this.onMenuRequestedWithProducts,
  });

  @override
  Widget build(BuildContext context) {
    final logoText = store.logoText.isNotEmpty
        ? store.logoText
        : store.name.substring(0, store.name.length.clamp(0, 10));

    return InkWell(
      onTap: () {
        // If we have the callback with products, use it (for backend stores)
        if (onMenuRequestedWithProducts != null) {
          // For backend stores, we'll need to fetch products dynamically
          // For now, fall back to the simple callback
          onMenuRequested?.call(store);
        } else {
          onMenuRequested?.call(store);
        }
      },
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(14),
          vertical: getProportionateScreenHeight(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo avatar
            Container(
              width: getProportionateScreenWidth(44),
              height: getProportionateScreenWidth(44),
              decoration: BoxDecoration(
                color: store.themeColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: store.themeColor.withValues(alpha: 0.25),
                    blurRadius: 5,
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
                  fontSize: getProportionateScreenWidth(8),
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),

            SizedBox(width: getProportionateScreenWidth(12)),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    store.name,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(13.5),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: getProportionateScreenHeight(2)),
                  Text(
                    store.category,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(11),
                      fontWeight: FontWeight.w500,
                      color: kSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: getProportionateScreenHeight(4)),
                  // Rating · delivery · location (only show rating if available)
                  Wrap(
                    spacing: getProportionateScreenWidth(10),
                    children: [
                      if (store.hasRating)
                        _meta(
                          HeroiconsSolid.star,
                          const Color(0xFFF59E0B),
                          store.rating.toStringAsFixed(1),
                        ),
                      _meta(
                        HeroiconsOutline.clock,
                        const Color(0xFF94A3B8),
                        store.deliveryTime,
                      ),
                      _meta(
                        HeroiconsSolid.mapPin,
                        const Color(0xFF94A3B8),
                        store.location,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: getProportionateScreenWidth(6)),
            Tooltip(
              message: 'View menu',
              child: Icon(
                HeroiconsOutline.rectangleStack,
                size: getProportionateScreenWidth(18),
                color: kSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: getProportionateScreenWidth(10), color: color),
        SizedBox(width: getProportionateScreenWidth(3)),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: getProportionateScreenWidth(100),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: getProportionateScreenWidth(10.5),
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}
