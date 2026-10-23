import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/components/chat_address_picker.dart';
import 'package:zmall/help/support_chat/components/zmall_ui.dart';
import 'package:zmall/help/support_chat/service/chat_basket.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/utils/size_config.dart';

/// Inline restaurant list shown in the chat — same layout as the web
/// ordering widget: delivery address bar, "Restaurants in …" header with the
/// count, then one bordered row per store (logo, name, rating, chevron).
///
/// The list has a fixed height and scrolls inside the chat.
class StoreCarousel extends StatefulWidget {
  final List<MockStore>? stores;
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
  State<StoreCarousel> createState() => _StoreCarouselState();
}

class _StoreCarouselState extends State<StoreCarousel> {
  @override
  Widget build(BuildContext context) {
    final storeList = widget.stores ?? const [];
    if (storeList.isEmpty) return const SizedBox.shrink();

    return ZCard(
      padding: EdgeInsets.all(getProportionateScreenWidth(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Delivering to (tap to change) ─────────────────────────
          const ChatAddressField(pill: true),
          SizedBox(height: getProportionateScreenHeight(12)),

          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ValueListenableBuilder<DestinationAddress?>(
                    valueListenable: chatDeliveryAddress,
                    builder: (context, address, _) {
                      final name = address?.name?.trim() ?? '';
                      return Text(
                        name.isEmpty
                            ? 'Restaurants near you'
                            : 'Restaurants in $name',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(14.5),
                          fontWeight: FontWeight.w700,
                          color: kZInk,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: getProportionateScreenWidth(8)),
                Text(
                  '${storeList.length} available',
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(11.5),
                    color: kZMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(10)),

          // ── Scrollable rows ───────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: getProportionateScreenHeight(380),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: storeList.length,
              separatorBuilder: (_, __) =>
                  SizedBox(height: getProportionateScreenHeight(8)),
              itemBuilder: (context, index) => ZStaggered(
                index: index,
                child: _StoreRow(
                  store: storeList[index],
                  onTap: () {
                    final store = storeList[index];
                    debugPrint(
                      "🏪 [STORE CAROUSEL] Tapped store item: ${store.name} (id: ${store.id})",
                    );
                    widget.onMenuRequested?.call(store);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  final MockStore store;
  final VoidCallback onTap;

  const _StoreRow({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ZPressable(
      onTap: onTap,
      child: ZCard(
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(14),
          vertical: getProportionateScreenHeight(12),
        ),
        child: Row(
          children: [
            ZStoreLogo(store: store, size: 60),
            SizedBox(width: getProportionateScreenWidth(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    store.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(14.5),
                      fontWeight: FontWeight.w700,
                      color: kZInk,
                      height: 1.25,
                    ),
                  ),
                  if (store.hasRating && store.rating > 0) ...[
                    SizedBox(height: getProportionateScreenHeight(6)),
                    ZPill(
                      label: _rating(store.rating),
                      icon: HeroiconsSolid.star,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              HeroiconsOutline.chevronRight,
              size: getProportionateScreenWidth(16),
              color: kZMuted,
            ),
          ],
        ),
      ),
    );
  }

  String _rating(double rating) => rating == rating.roundToDouble()
      ? rating.toStringAsFixed(0)
      : rating.toStringAsFixed(1);
}
