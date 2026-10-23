import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/components/store_menu_sheet.dart';
import 'package:zmall/help/support_chat/components/zmall_ui.dart';
import 'package:zmall/help/support_chat/service/chat_basket.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Inline store menu in the chat — the web widget's store header, category
/// chips and first few items, with a button into the full menu sheet.
class StoreMenuCard extends StatelessWidget {
  static const int _previewCount = 3;

  final MockStore store;
  final List<MockProduct> products;
  final ChatBasket basket;
  final ValueChanged<String?> onOpenMenu;
  final VoidCallback? onAllRestaurants;
  final ValueChanged<MockProduct>? onProductTap;

  const StoreMenuCard({
    super.key,
    required this.store,
    required this.products,
    required this.basket,
    required this.onOpenMenu,
    this.onAllRestaurants,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final groups = groupMenuByCategory(products);
    final first = groups.entries.first;
    final preview = first.value.take(_previewCount).toList();

    return ZCard(
      padding: EdgeInsets.all(getProportionateScreenWidth(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Store header ─────────────────────────────────────────
          ZCard(
            padding: EdgeInsets.all(getProportionateScreenWidth(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onAllRestaurants != null)
                      _SmallOutlinePill(
                        label: '← All Restaurants',
                        onTap: onAllRestaurants!,
                      ),
                    const Spacer(),
                    ZPill(label: 'ZMall Partner', color: kSecondaryColor),
                  ],
                ),
                SizedBox(height: getProportionateScreenHeight(12)),
                Row(
                  children: [
                    ZStoreLogo(store: store, size: 62),
                    SizedBox(width: getProportionateScreenWidth(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(17),
                              fontWeight: FontWeight.w800,
                              color: kZInk,
                            ),
                          ),
                          SizedBox(height: getProportionateScreenHeight(6)),
                          ZPill(label: '${products.length} items'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Category chips (open the sheet filtered) ────────────
          if (groups.length > 1) ...[
            SizedBox(height: getProportionateScreenHeight(12)),
            MenuCategoryChips(
              categories: groups.keys.toList(),
              selected: null,
              onSelected: onOpenMenu,
              horizontalPadding: 0,
            ),
          ],

          // ── Preview items ───────────────────────────────────────
          MenuSectionHeader(
            title: first.key,
            count: first.value.length,
            horizontalPadding: 2,
          ),
          for (var i = 0; i < preview.length; i++) ...[
            if (i > 0) SizedBox(height: getProportionateScreenHeight(10)),
            ZStaggered(
              index: i,
              child: MenuItemRow(
                product: preview[i],
                store: store,
                basket: basket,
                onTap: onProductTap == null
                    ? null
                    : () => onProductTap!(preview[i]),
              ),
            ),
          ],
          SizedBox(height: getProportionateScreenHeight(12)),
          ZOutlineButton(
            label: products.length > preview.length
                ? 'See full menu · ${products.length} items →'
                : 'Open menu →',
            onPressed: () => onOpenMenu(null),
          ),
        ],
      ),
    );
  }
}

class _SmallOutlinePill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SmallOutlinePill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kZSurface,
      shape: const StadiumBorder(side: BorderSide(color: kZBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(12),
            vertical: getProportionateScreenHeight(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: getProportionateScreenWidth(12),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Complete Your Order" card posted after Instant Checkout — summary, total,
/// delivery address and the button into payment.
class OrderReadyCard extends StatelessWidget {
  final ChatOrderReady order;
  final VoidCallback onProceed;
  final VoidCallback onBrowseMore;

  const OrderReadyCard({
    super.key,
    required this.order,
    required this.onProceed,
    required this.onBrowseMore,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = getProportionateScreenWidth(16);
    final deliveryFee = order.price - order.itemsTotal;

    return ZCard(
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Hero ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: getProportionateScreenHeight(22),
            ),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: getProportionateScreenWidth(58),
                    height: getProportionateScreenWidth(58),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kSecondaryColor.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      HeroiconsOutline.shoppingCart,
                      color: kSecondaryColor,
                      size: getProportionateScreenWidth(26),
                    ),
                  ),
                ),
                SizedBox(height: getProportionateScreenHeight(14)),
                Text(
                  'Complete Your Order',
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(19),
                    fontWeight: FontWeight.w800,
                    color: kZInk,
                  ),
                ),
                SizedBox(height: getProportionateScreenHeight(6)),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Your basket from '),
                      TextSpan(
                        text: order.storeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const TextSpan(
                        text: ' is prepared. Proceed to payment in ZMall.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(13),
                    color: kZMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kZBorder),

          Padding(
            padding: EdgeInsets.all(hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ZPrimaryButton(
                  label: 'Proceed to Payment on ZMall →',
                  onPressed: onProceed,
                ),
                SizedBox(height: getProportionateScreenHeight(14)),

                // ── Order summary ─────────────────────────────────
                Container(
                  padding: EdgeInsets.all(getProportionateScreenWidth(14)),
                  decoration: BoxDecoration(
                    color: kZSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kZBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ORDER SUMMARY',
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(11.5),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: kZMuted,
                        ),
                      ),
                      SizedBox(height: getProportionateScreenHeight(10)),
                      for (final line in order.lines)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: getProportionateScreenHeight(6),
                          ),
                          child: _summaryRow(
                            '${line.quantity}× ${line.product.name}',
                            formatEtb(line.total),
                          ),
                        ),
                      if (deliveryFee > 0.5)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: getProportionateScreenHeight(6),
                          ),
                          child: _summaryRow(
                            'Delivery & fees',
                            formatEtb(deliveryFee),
                          ),
                        ),
                      const Divider(height: 14, color: kZBorder),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(
                                fontSize: getProportionateScreenWidth(16),
                                fontWeight: FontWeight.w700,
                                color: kZInk,
                              ),
                            ),
                          ),
                          Text(
                            formatEtb(order.price),
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(16),
                              fontWeight: FontWeight.w800,
                              color: kSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: getProportionateScreenHeight(10)),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Deliver to: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                            TextSpan(text: order.deliveryAddress),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(12),
                          color: kZMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: getProportionateScreenHeight(14)),
                ZOutlineButton(
                  label: 'Browse More Restaurants',
                  onPressed: onBrowseMore,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: getProportionateScreenWidth(13),
              color: const Color(0xFF4B5563),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: getProportionateScreenWidth(12.5),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}
