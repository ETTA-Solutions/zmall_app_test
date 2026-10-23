import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/components/chat_basket_view.dart';
import 'package:zmall/help/support_chat/components/product_detail_sheet.dart';
import 'package:zmall/help/support_chat/components/zmall_ui.dart';
import 'package:zmall/help/support_chat/service/chat_basket.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Groups [products] by category, keeping the backend order.
Map<String, List<MockProduct>> groupMenuByCategory(List<MockProduct> products) {
  final groups = <String, List<MockProduct>>{};
  for (final p in products) {
    final key = p.category.trim().isEmpty ? 'Menu' : p.category.trim();
    groups.putIfAbsent(key, () => []).add(p);
  }
  return groups;
}

/// Adds [product] to [basket], asking first when that would replace a basket
/// from another store.
Future<void> addToChatBasket(
  BuildContext context,
  ChatBasket basket,
  MockStore store,
  MockProduct product, {
  int quantity = 1,
}) async {
  if (basket.conflictsWith(store)) {
    final replace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Start a new basket?'),
        content: Text(
          'Your basket has items from ${basket.store!.name}. '
          'Adding from ${store.name} will clear it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep', style: TextStyle(color: kZMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'New basket',
              style: TextStyle(
                color: kSecondaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (replace != true) return;
  }
  for (var i = 0; i < quantity; i++) {
    basket.add(store, product);
  }
}

/// Opens [ProductDetailSheet] for a menu item, wired to the chat basket.
void openChatMenuProduct(
  BuildContext context, {
  required ChatBasket basket,
  required MockStore store,
  required MockProduct product,
  Future<void> Function(MockProduct, int)? onOrderNow,
}) {
  ProductDetailSheet.show(
    context,
    product: product,
    onAddToCart: (p, qty) =>
        addToChatBasket(context, basket, store, p, quantity: qty),
    onOrderNow: onOrderNow,
  );
}

/// Full-height, immersive store menu — no page navigation.
///
///   StoreMenuSheet.show(context, store: store, products: items, basket: basket, ...)
class StoreMenuSheet {
  static Future<void> show(
    BuildContext context, {
    required MockStore store,
    required List<MockProduct> products,
    required ChatBasket basket,
    required Future<void> Function() onCheckout,
    VoidCallback? onAllRestaurants,
    Future<void> Function(MockProduct, int)? onOrderNow,
    String? initialCategory,
  }) {
    debugPrint(
      "🏪 [STORE MENU SHEET] Opening sheet for store: ${store.name} (id: ${store.id}), products count: ${products.length}",
    );
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _StoreMenuSheet(
        store: store,
        products: products,
        basket: basket,
        onCheckout: onCheckout,
        onAllRestaurants: onAllRestaurants,
        onOrderNow: onOrderNow,
        initialCategory: initialCategory,
      ),
    );
  }
}

class _StoreMenuSheet extends StatefulWidget {
  final MockStore store;
  final List<MockProduct> products;
  final ChatBasket basket;
  final Future<void> Function() onCheckout;
  final VoidCallback? onAllRestaurants;
  final Future<void> Function(MockProduct, int)? onOrderNow;
  final String? initialCategory;

  const _StoreMenuSheet({
    required this.store,
    required this.products,
    required this.basket,
    required this.onCheckout,
    this.onAllRestaurants,
    this.onOrderNow,
    this.initialCategory,
  });

  @override
  State<_StoreMenuSheet> createState() => _StoreMenuSheetState();
}

class _StoreMenuSheetState extends State<_StoreMenuSheet> {
  late String? _category = widget.initialCategory;
  bool _showBasket = false;

  void _toggleBasket() {
    setState(() => _showBasket = !_showBasket);
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupMenuByCategory(widget.products);
    final visible = _category == null
        ? groups
        : {_category!: groups[_category!] ?? const <MockProduct>[]};
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ColoredBox(
          color: Colors.white,
          child: Stack(
            children: [
              CustomScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _MenuHero(
                      store: widget.store,
                      itemCount: widget.products.length,
                      onClose: () => Navigator.pop(context),
                      onAllRestaurants: widget.onAllRestaurants == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              widget.onAllRestaurants!();
                            },
                    ),
                  ),
                  if (groups.length > 1)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ChipsHeader(
                        child: MenuCategoryChips(
                          categories: groups.keys.toList(),
                          selected: _category,
                          onSelected: (c) => setState(() => _category = c),
                        ),
                      ),
                    ),
                  for (final entry in visible.entries) ...[
                    SliverToBoxAdapter(
                      child: MenuSectionHeader(
                        title: entry.key,
                        count: entry.value.length,
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: getProportionateScreenWidth(14),
                      ),
                      sliver: SliverList.separated(
                        itemCount: entry.value.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: getProportionateScreenHeight(10)),
                        itemBuilder: (context, i) => ZStaggered(
                          index: i,
                          child: MenuItemRow(
                            product: entry.value[i],
                            store: widget.store,
                            basket: widget.basket,
                            onTap: () => openChatMenuProduct(
                              context,
                              basket: widget.basket,
                              store: widget.store,
                              product: entry.value[i],
                              onOrderNow: widget.onOrderNow,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Room for the floating basket bar
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: getProportionateScreenHeight(110) + bottomPad,
                    ),
                  ),
                ],
              ),

              // ── Floating basket bar + review panel ────────────────
              Positioned(
                left: getProportionateScreenWidth(12),
                right: getProportionateScreenWidth(12),
                bottom: getProportionateScreenHeight(10) + bottomPad,
                child: ListenableBuilder(
                  listenable: widget.basket,
                  builder: (context, _) {
                    final isThisStore =
                        widget.basket.store?.id == widget.store.id;
                    if (!isThisStore) return const SizedBox.shrink();
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                      ),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ChatBasketBar(
                              basket: widget.basket,
                              actionLabel: _showBasket
                                  ? 'Hide'
                                  : 'Review & Checkout →',
                              onAction: _toggleBasket,
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              child: _showBasket
                                  ? Padding(
                                      padding: EdgeInsets.only(
                                        top: getProportionateScreenHeight(10),
                                      ),
                                      child: ChatBasketPanel(
                                        basket: widget.basket,
                                        onClose: () =>
                                            setState(() => _showBasket = false),
                                        onCheckout: widget.onCheckout,
                                      ),
                                    )
                                  : const SizedBox(width: double.infinity),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sheet header: brand-tinted backdrop, back/close controls, logo, name and
/// item count.
class _MenuHero extends StatelessWidget {
  final MockStore store;
  final int itemCount;
  final VoidCallback onClose;
  final VoidCallback? onAllRestaurants;

  const _MenuHero({
    required this.store,
    required this.itemCount,
    required this.onClose,
    this.onAllRestaurants,
  });

  @override
  Widget build(BuildContext context) {
    final bannerHeight = getProportionateScreenHeight(96);
    final logoSize = 72.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand banner
            Container(
              height: bannerHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kSecondaryColor,
                    Color.lerp(kSecondaryColor, Colors.black, 0.35)!,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Soft decorative circles
                  Positioned(right: -30, top: -40, child: _circle(140, 0.10)),
                  Positioned(left: 80, bottom: -50, child: _circle(110, 0.07)),
                  // Drag handle
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: EdgeInsets.only(
                        top: getProportionateScreenHeight(8),
                      ),
                      width: getProportionateScreenWidth(38),
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      getProportionateScreenWidth(12),
                      getProportionateScreenHeight(20),
                      getProportionateScreenWidth(12),
                      0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (onAllRestaurants != null)
                          _GlassButton(
                            label: '← All Restaurants',
                            onTap: onAllRestaurants!,
                          ),
                        const Spacer(),
                        _GlassButton(
                          icon: HeroiconsOutline.xMark,
                          onTap: onClose,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Name row (leaves room for the overlapping logo)
            Padding(
              padding: EdgeInsets.fromLTRB(
                getProportionateScreenWidth(logoSize + 30),
                getProportionateScreenHeight(10),
                getProportionateScreenWidth(14),
                getProportionateScreenHeight(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(19),
                      fontWeight: FontWeight.w800,
                      color: kZInk,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: getProportionateScreenHeight(6)),
                  Wrap(
                    spacing: getProportionateScreenWidth(6),
                    runSpacing: getProportionateScreenHeight(4),
                    children: [
                      ZPill(label: '$itemCount items'),
                      if (store.hasRating && store.rating > 0)
                        ZPill(
                          label: store.rating.toStringAsFixed(1),
                          icon: HeroiconsSolid.star,
                        ),
                      ZPill(label: 'ZMall Partner', color: kSecondaryColor),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kZBorder),
          ],
        ),
        // Overlapping logo
        Positioned(
          left: getProportionateScreenWidth(16),
          top: bannerHeight - getProportionateScreenWidth(logoSize) / 2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: kBlackColor.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ZStoreLogo(store: store, size: logoSize),
          ),
        ),
      ],
    );
  }

  Widget _circle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

class _GlassButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  const _GlassButton({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(label == null ? 7 : 12),
            vertical: getProportionateScreenHeight(6),
          ),
          child: label != null
              ? Text(
                  label!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: getProportionateScreenWidth(12.5),
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Icon(
                  icon,
                  color: Colors.white,
                  size: getProportionateScreenWidth(18),
                ),
        ),
      ),
    );
  }
}

class _ChipsHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  _ChipsHeader({required this.child});

  double get _height => getProportionateScreenHeight(56);

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: overlaps
            ? [
                BoxShadow(
                  color: kBlackColor.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _ChipsHeader oldDelegate) =>
      oldDelegate.child != child;
}

/// "All · BURGER · SANDWICH · DRINK" filter chips.
class MenuCategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final double horizontalPadding;

  const MenuCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.horizontalPadding = 14,
  });

  @override
  Widget build(BuildContext context) {
    final all = <String?>[null, ...categories];
    return SizedBox(
      height: getProportionateScreenHeight(36),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(horizontalPadding),
        ),
        itemCount: all.length,
        separatorBuilder: (_, __) =>
            SizedBox(width: getProportionateScreenWidth(8)),
        itemBuilder: (context, i) {
          final category = all[i];
          final isSelected = category == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(category);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(16),
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? kSecondaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? kSecondaryColor : kZBorder,
                ),
              ),
              child: Text(
                category == null ? 'All' : category.toUpperCase(),
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(12.5),
                  fontWeight: FontWeight.w600,
                  letterSpacing: category == null ? 0 : 0.3,
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "BURGER (5)" section label with a hairline underneath.
class MenuSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final double horizontalPadding;

  const MenuSectionHeader({
    super.key,
    required this.title,
    required this.count,
    this.horizontalPadding = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        getProportionateScreenWidth(horizontalPadding),
        getProportionateScreenHeight(16),
        getProportionateScreenWidth(horizontalPadding),
        getProportionateScreenHeight(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: title.toUpperCase()),
                TextSpan(
                  text: ' ($count)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: getProportionateScreenWidth(12),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: kZMuted,
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(6)),
          const Divider(height: 1, color: kZBorder),
        ],
      ),
    );
  }
}

/// One menu item: thumbnail, name, description, price and + Add / stepper.
class MenuItemRow extends StatelessWidget {
  final MockProduct product;
  final MockStore store;
  final ChatBasket basket;
  final VoidCallback? onTap;

  const MenuItemRow({
    super.key,
    required this.product,
    required this.store,
    required this.basket,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ZPressable(
      onTap: onTap,
      child: ZCard(
        padding: EdgeInsets.all(getProportionateScreenWidth(14)),
        child: Row(
          children: [
            ZProductThumb(product: product),
            SizedBox(width: getProportionateScreenWidth(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(14.5),
                      fontWeight: FontWeight.w700,
                      color: kZInk,
                      height: 1.25,
                    ),
                  ),
                  if (product.description.trim().isNotEmpty) ...[
                    SizedBox(height: getProportionateScreenHeight(3)),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(11.5),
                        color: kZMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                  SizedBox(height: getProportionateScreenHeight(6)),
                  Text(
                    formatEtb(product.price),
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(14.5),
                      fontWeight: FontWeight.w800,
                      color: kZInk,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: getProportionateScreenWidth(10)),
            ListenableBuilder(
              listenable: basket,
              builder: (context, _) {
                final qty = basket.store?.id == store.id
                    ? basket.quantityOf(product)
                    : 0;
                return ZAddStepper(
                  quantity: qty,
                  onAdd: () => addToChatBasket(context, basket, store, product),
                  onRemove: () => basket.decrement(product),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
