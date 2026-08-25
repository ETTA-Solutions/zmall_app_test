import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/cart/cart_screen.dart';
import 'package:zmall/help/support_chat/components/support_chat_canvas.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Slide-up route for the chatbot product viewer.
class SlideProductPageRoute<T> extends PageRouteBuilder<T> {
  SlideProductPageRoute({required Widget page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 340),
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            );
            final fade = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.15, 1, curve: Curves.easeOut),
            );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
          },
        );
}

class MockProductScreen extends StatefulWidget {
  final List<MockProduct> products;
  final int initialIndex;

  const MockProductScreen({
    super.key,
    required this.products,
    this.initialIndex = 0,
  });

  /// Convenience when opening a single product.
  MockProductScreen.single({super.key, required MockProduct product})
      : products = [product],
        initialIndex = 0;

  @override
  State<MockProductScreen> createState() => _MockProductScreenState();
}

class _MockProductScreenState extends State<MockProductScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late int _currentIndex;
  late final AnimationController _hintController;
  bool _showSwipeHint = true;
  bool _isAdding = false;
  final Map<String, int> _quantities = {};

  MockProduct get _currentProduct => widget.products[_currentIndex];

  int _quantityFor(MockProduct product) => _quantities[product.id] ?? 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.products.length - 1);
    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: 0.92,
    );
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    if (widget.products.length > 1) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showSwipeHint = false);
      });
    } else {
      _showSwipeHint = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
      _showSwipeHint = false;
    });
  }

  void _setQuantity(MockProduct product, int qty) {
    setState(() {
      _quantities[product.id] = qty.clamp(1, 9);
    });
  }

  Future<void> _addToCart() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);
    final product = _currentProduct;
    final qty = _quantityFor(product);
    final items = List<MockProduct>.filled(qty, product);
    await addMockProductsToCart(items);
    if (!mounted) return;
    setState(() => _isAdding = false);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(HeroiconsSolid.checkCircle, color: kPrimaryColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$qty × ${product.name} added',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: kBlackColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: SnackBarAction(
          label: 'View Cart',
          textColor: kSecondaryColor,
          onPressed: () => Navigator.pushNamed(context, CartScreen.routeName),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSwipe = widget.products.length > 1;

    return Scaffold(
      backgroundColor: kPrimaryColor,
      body: SupportChatCanvas(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(canSwipe),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.products.length,
                  onPageChanged: _onPageChanged,
                  physics: canSwipe
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double scale = 1;
                        double opacity = 1;
                        if (_pageController.position.haveDimensions) {
                          final page = _pageController.page ?? _currentIndex.toDouble();
                          final delta = (page - index).abs();
                          scale = (1 - delta * 0.06).clamp(0.9, 1.0);
                          opacity = (1 - delta * 0.35).clamp(0.65, 1.0);
                        }
                        return Transform.scale(
                          scale: scale,
                          child: Opacity(opacity: opacity, child: child),
                        );
                      },
                      child: _ProductSlidePage(
                        product: widget.products[index],
                        pageIndex: index,
                        isActive: index == _currentIndex,
                      ),
                    );
                  },
                ),
              ),
              if (canSwipe) _buildPageIndicator(),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool canSwipe) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        getProportionateScreenWidth(12),
        getProportionateScreenHeight(4),
        getProportionateScreenWidth(16),
        getProportionateScreenHeight(8),
      ),
      child: Row(
        children: [
          _CircleIconButton(
            icon: HeroiconsOutline.chevronLeft,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          if (canSwipe)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(12),
                vertical: getProportionateScreenHeight(6),
              ),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: kSecondaryColor.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: kSecondaryColor.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                '${_currentIndex + 1} / ${widget.products.length}',
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(12),
                  fontWeight: FontWeight.w800,
                  color: kBlackColor,
                ),
              ),
            ),
          if (canSwipe) SizedBox(width: getProportionateScreenWidth(8)),
          if (_showSwipeHint && canSwipe) _buildSwipeHint(),
        ],
      ),
    );
  }

  Widget _buildSwipeHint() {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.6, end: 1).animate(_hintController),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(10),
          vertical: getProportionateScreenHeight(5),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kSecondaryColor.withValues(alpha: 0.12),
              kSecondaryColor.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              HeroiconsOutline.arrowsRightLeft,
              size: getProportionateScreenWidth(13),
              color: kSecondaryColor,
            ),
            SizedBox(width: getProportionateScreenWidth(4)),
            Text(
              'Swipe',
              style: TextStyle(
                fontSize: getProportionateScreenWidth(11),
                fontWeight: FontWeight.w700,
                color: kSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: EdgeInsets.only(
        top: getProportionateScreenHeight(6),
        bottom: getProportionateScreenHeight(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.products.length, (i) {
          final active = i == _currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(3),
            ),
            width: active
                ? getProportionateScreenWidth(22)
                : getProportionateScreenWidth(7),
            height: getProportionateScreenHeight(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: active
                  ? LinearGradient(
                      colors: [kSecondaryColor, kSecondaryColor.withValues(alpha: 0.75)],
                    )
                  : null,
              color: active ? null : kSecondaryColor.withValues(alpha: 0.2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar() {
    final product = _currentProduct;
    final qty = _quantityFor(product);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            getProportionateScreenWidth(20),
            getProportionateScreenHeight(16),
            getProportionateScreenWidth(20),
            getProportionateScreenHeight(16) +
                MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: kSecondaryColor.withValues(alpha: 0.1)),
            ),
            boxShadow: [
              BoxShadow(
                color: kSecondaryColor.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Row(
                  key: ValueKey(product.id),
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(14),
                              fontWeight: FontWeight.w800,
                              color: kBlackColor,
                            ),
                          ),
                          Text(
                            '${product.price.toStringAsFixed(0)} ETB',
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(18),
                              fontWeight: FontWeight.w900,
                              color: kSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _QuantityStepper(
                      quantity: qty,
                      onChanged: (v) => _setQuantity(product, v),
                    ),
                  ],
                ),
              ),
              SizedBox(height: getProportionateScreenHeight(14)),
              SizedBox(
                width: double.infinity,
                height: getProportionateScreenHeight(52),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        kSecondaryColor,
                        kSecondaryColor.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: kSecondaryColor.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isAdding ? null : _addToCart,
                      borderRadius: BorderRadius.circular(18),
                      child: Center(
                        child: _isAdding
                            ? SizedBox(
                                width: getProportionateScreenWidth(22),
                                height: getProportionateScreenWidth(22),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    HeroiconsSolid.shoppingCart,
                                    color: kPrimaryColor,
                                    size: getProportionateScreenWidth(18),
                                  ),
                                  SizedBox(
                                    width: getProportionateScreenWidth(8),
                                  ),
                                  Text(
                                    'Add to Cart',
                                    style: TextStyle(
                                      color: kPrimaryColor,
                                      fontSize: getProportionateScreenWidth(15),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductSlidePage extends StatelessWidget {
  final MockProduct product;
  final int pageIndex;
  final bool isActive;

  const _ProductSlidePage({
    required this.product,
    required this.pageIndex,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final deliveryTime = getMockStoreDeliveryTime(product.storeId);
    final hasImage = product.localImageAsset.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        getProportionateScreenWidth(8),
        0,
        getProportionateScreenWidth(8),
        getProportionateScreenHeight(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'mock_product_image_${product.id}',
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: getProportionateScreenHeight(300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: kSecondaryColor.withValues(alpha: 0.12),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          hasImage
                              ? Image.asset(
                                  product.localImageAsset,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildImageFallback(),
                                )
                              : _buildImageFallback(),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.45),
                                  ],
                                  stops: const [0.55, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: getProportionateScreenHeight(14),
                    left: getProportionateScreenWidth(14),
                    child: _RatingBadge(),
                  ),
                  Positioned(
                    bottom: getProportionateScreenHeight(14),
                    left: getProportionateScreenWidth(14),
                    right: getProportionateScreenWidth(14),
                    child: Row(
                      children: [
                        _InfoChip(
                          icon: HeroiconsOutline.tag,
                          label: product.category,
                        ),
                        SizedBox(width: getProportionateScreenWidth(8)),
                        _InfoChip(
                          icon: HeroiconsOutline.clock,
                          label: deliveryTime,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(18)),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isActive ? 1 : 0.7,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(getProportionateScreenWidth(18)),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: kSecondaryColor.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kSecondaryColor.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(22),
                          fontWeight: FontWeight.w900,
                          color: kBlackColor,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: getProportionateScreenHeight(8)),
                      Row(
                        children: [
                          Text(
                            '${product.price.toStringAsFixed(0)} ETB',
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(20),
                              fontWeight: FontWeight.w900,
                              color: kSecondaryColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: getProportionateScreenWidth(10),
                              vertical: getProportionateScreenHeight(4),
                            ),
                            decoration: BoxDecoration(
                              color: kGreenColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  HeroiconsSolid.bolt,
                                  size: getProportionateScreenWidth(12),
                                  color: kGreenColor,
                                ),
                                SizedBox(width: getProportionateScreenWidth(4)),
                                Text(
                                  'Popular',
                                  style: TextStyle(
                                    fontSize: getProportionateScreenWidth(10.5),
                                    fontWeight: FontWeight.w700,
                                    color: kGreenColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: getProportionateScreenHeight(14)),
                      Text(
                        product.description.isNotEmpty
                            ? product.description
                            : 'Freshly prepared and ready to deliver to your door.',
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(14),
                          color: kGreyColor,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: kSecondaryColor.withValues(alpha: 0.06),
      child: Center(
        child: Icon(
          HeroiconsOutline.photo,
          size: 48,
          color: kSecondaryColor.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSecondaryColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: HeroiconsOutline.minus,
            enabled: quantity > 1,
            onTap: () => onChanged(quantity - 1),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(10),
            ),
            child: Text(
              '$quantity',
              style: TextStyle(
                fontSize: getProportionateScreenWidth(15),
                fontWeight: FontWeight.w800,
                color: kBlackColor,
              ),
            ),
          ),
          _StepButton(
            icon: HeroiconsOutline.plus,
            enabled: quantity < 9,
            onTap: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: getProportionateScreenWidth(16),
            color: enabled ? kSecondaryColor : kGreyColor.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(10),
          vertical: getProportionateScreenHeight(6),
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: getProportionateScreenWidth(12), color: kPrimaryColor),
            SizedBox(width: getProportionateScreenWidth(4)),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(11),
                  fontWeight: FontWeight.w600,
                  color: kPrimaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(10),
        vertical: getProportionateScreenHeight(5),
      ),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
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
            size: getProportionateScreenWidth(13),
          ),
          SizedBox(width: getProportionateScreenWidth(4)),
          Text(
            '4.8',
            style: TextStyle(
              fontSize: getProportionateScreenWidth(12),
              fontWeight: FontWeight.w800,
              color: kBlackColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: getProportionateScreenWidth(38),
        height: getProportionateScreenWidth(38),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: kSecondaryColor.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: kSecondaryColor.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: kBlackColor,
          size: getProportionateScreenWidth(18),
        ),
      ),
    );
  }
}
