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

/// "Order ready" receipt posted after Instant Checkout — store, every line,
/// subtotal / delivery / total, delivery address and the button into payment.
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
    final itemCount = order.lines.fold<int>(0, (sum, l) => sum + l.quantity);
    final fees = order.price - order.itemsTotal;

    return ZStaggered(
      index: 0,
      child: ZCard(
        raised: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(order: order, itemCount: itemCount),

            // ── Items ───────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                getProportionateScreenHeight(14),
                hPad,
                getProportionateScreenHeight(4),
              ),
              child: Row(
                children: [
                  Text(
                    'ORDER SUMMARY',
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(11),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: kZMuted,
                    ),
                  ),
                  const Spacer(),
                  ZPill(label: '$itemCount item${itemCount == 1 ? '' : 's'}'),
                ],
              ),
            ),
            for (var i = 0; i < order.lines.length; i++)
              ZStaggered(
                index: i + 1,
                child: _LineRow(line: order.lines[i], hPad: hPad),
              ),

            // ── Totals ──────────────────────────────────────────────
            Container(
              margin: EdgeInsets.fromLTRB(
                hPad,
                getProportionateScreenHeight(8),
                hPad,
                0,
              ),
              padding: EdgeInsets.all(getProportionateScreenWidth(14)),
              decoration: BoxDecoration(
                color: kZSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kZBorder),
              ),
              child: Column(
                children: [
                  _amountRow('Items subtotal', formatEtb(order.itemsTotal)),
                  if (fees.abs() >= 0.01) ...[
                    SizedBox(height: getProportionateScreenHeight(6)),
                    _amountRow(
                      fees > 0 ? 'Delivery & service fee' : 'Discount',
                      formatEtb(fees),
                      valueColor: fees > 0 ? null : kGreenColor,
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: getProportionateScreenHeight(10),
                    ),
                    child: const _DashedDivider(),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total to pay',
                              style: TextStyle(
                                fontSize: getProportionateScreenWidth(14),
                                fontWeight: FontWeight.w700,
                                color: kZInk,
                              ),
                            ),
                            Text(
                              'Incl. delivery',
                              style: TextStyle(
                                fontSize: getProportionateScreenWidth(11),
                                color: kZMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatEtb(order.price),
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(20),
                          fontWeight: FontWeight.w800,
                          color: kSecondaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Delivery address ───────────────────────────────────
            if (order.deliveryAddress.trim().isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  getProportionateScreenHeight(12),
                  hPad,
                  0,
                ),
                child: Row(
                  children: [
                    Container(
                      width: getProportionateScreenWidth(32),
                      height: getProportionateScreenWidth(32),
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        HeroiconsOutline.mapPin,
                        size: getProportionateScreenWidth(16),
                        color: kSecondaryColor,
                      ),
                    ),
                    SizedBox(width: getProportionateScreenWidth(10)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deliver to',
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(11),
                              color: kZMuted,
                            ),
                          ),
                          Text(
                            order.deliveryAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(13),
                              fontWeight: FontWeight.w600,
                              color: kZInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Actions ─────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ZPrimaryButton(
                    label: 'Pay ${formatEtb(order.price)}  →',
                    onPressed: onProceed,
                  ),
                  SizedBox(height: getProportionateScreenHeight(8)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        HeroiconsOutline.lockClosed,
                        size: getProportionateScreenWidth(12),
                        color: kZMuted,
                      ),
                      SizedBox(width: getProportionateScreenWidth(4)),
                      Text(
                        'Secure checkout on ZMall',
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(11),
                          color: kZMuted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: getProportionateScreenHeight(12)),
                  ZOutlineButton(
                    label: 'Browse more stores',
                    onPressed: onBrowseMore,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String label, String value, {Color? valueColor}) {
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
            fontSize: getProportionateScreenWidth(13),
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

/// Brand gradient banner — animated check, "Order ready", store name.
class _Header extends StatelessWidget {
  final ChatOrderReady order;
  final int itemCount;

  const _Header({required this.order, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(getProportionateScreenWidth(16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kSecondaryColor,
            Color.lerp(kSecondaryColor, Colors.black, 0.25)!,
          ],
        ),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: getProportionateScreenWidth(46),
              height: getProportionateScreenWidth(46),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: kBlackColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                HeroiconsSolid.checkCircle,
                color: kSecondaryColor,
                size: getProportionateScreenWidth(28),
              ),
            ),
          ),
          SizedBox(width: getProportionateScreenWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your order is ready 🎉',
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(17),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: getProportionateScreenHeight(3)),
                Row(
                  children: [
                    Icon(
                      HeroiconsOutline.buildingStorefront,
                      size: getProportionateScreenWidth(13),
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    SizedBox(width: getProportionateScreenWidth(4)),
                    Flexible(
                      child: Text(
                        order.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(12.5),
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
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
    );
  }
}

/// One basket line — thumbnail, name, "2 × 120 ETB", line total.
class _LineRow extends StatelessWidget {
  final ChatBasketLine line;
  final double hPad;

  const _LineRow({required this.line, required this.hPad});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: getProportionateScreenHeight(6),
      ),
      child: Row(
        children: [
          ZProductThumb(product: line.product, size: 42),
          SizedBox(width: getProportionateScreenWidth(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(13.5),
                    fontWeight: FontWeight.w600,
                    color: kZInk,
                  ),
                ),
                SizedBox(height: getProportionateScreenHeight(2)),
                Text(
                  '${line.quantity} × ${formatEtb(line.product.price)}',
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(11.5),
                    color: kZMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: getProportionateScreenWidth(8)),
          Text(
            formatEtb(line.total),
            style: TextStyle(
              fontSize: getProportionateScreenWidth(13.5),
              fontWeight: FontWeight.w700,
              color: kZInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// Receipt-style dashed rule above the total.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 5.0, gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: 1,
              margin: const EdgeInsets.only(right: gap),
              color: const Color(0xFFD1D5DB),
            ),
          ),
        );
      },
    );
  }
}
