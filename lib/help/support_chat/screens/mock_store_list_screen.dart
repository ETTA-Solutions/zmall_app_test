import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/screens/mock_product_screen.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Slide-up route (reuse same pattern as MockProductScreen)
// ─────────────────────────────────────────────────────────────────────────────
class SlideStoreListPageRoute<T> extends PageRouteBuilder<T> {
  SlideStoreListPageRoute({required Widget page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (_, animation, __, child) {
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
              curve: const Interval(0.1, 1, curve: Curves.easeOut),
            );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
          },
        );
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-store background gradient palettes
// ─────────────────────────────────────────────────────────────────────────────
const List<List<Color>> _storeGradients = [
  [Color(0xFFFF6B6B), Color(0xFFFF8E53)], // warm red-orange  → burgers
  [Color(0xFF667EEA), Color(0xFF764BA2)], // purple-indigo    → pizza
  [Color(0xFF11998E), Color(0xFF38EF7D)], // teal-green       → coffee
  [Color(0xFFF7971E), Color(0xFFFFD200)], // golden-yellow    → healthy
];

// ─────────────────────────────────────────────────────────────────────────────
// Background image asset for each store (matches mock_data order)
// ─────────────────────────────────────────────────────────────────────────────
const List<String> _storeImages = [
  'images/meal/burger_with_fires.jpg',
  'images/meal/pizza_hot.jpg',
  'images/meal/two.jpg',
  'images/meal/one.jpg',
];

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class MockStoreListScreen extends StatefulWidget {
  const MockStoreListScreen({super.key});

  @override
  State<MockStoreListScreen> createState() => _MockStoreListScreenState();
}

class _MockStoreListScreenState extends State<MockStoreListScreen>
    with TickerProviderStateMixin {
  late final AnimationController _headerController;
  late final AnimationController _listController;
  late final List<AnimationController> _cardControllers;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<Offset>> _cardSlides;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Staggered card animations
    _cardControllers = List.generate(
      mockStores.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );

    _cardFades = _cardControllers.map((c) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      );
    }).toList();

    _cardSlides = _cardControllers.map((c) {
      return Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));
    }).toList();

    // Stagger the cards
    for (int i = 0; i < _cardControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 180 + i * 110), () {
        if (mounted) _cardControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _openMenu(MockStore store) {
    HapticFeedback.selectionClick();
    final products = mockProducts
        .where((p) => p.storeId == store.id)
        .toList();

    if (products.isEmpty) {
      // Fallback: show all products
      Navigator.push(
        context,
        SlideProductPageRoute(
          page: MockProductScreen(products: mockProducts, initialIndex: 0),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      SlideProductPageRoute(
        page: MockProductScreen(products: products, initialIndex: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: kPrimaryColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              _buildSectionHeader(),
              Expanded(child: _buildStoreList()),
            ],
          ),
        ),
      ),
    );
  }

  // ── top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        getProportionateScreenWidth(16),
        getProportionateScreenHeight(8),
        getProportionateScreenWidth(16),
        0,
      ),
      child: Row(
        children: [
          _CircleIconButton(
            icon: HeroiconsOutline.chevronLeft,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          FadeTransition(
            opacity: _headerController,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(14),
                vertical: getProportionateScreenHeight(7),
              ),
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: kSecondaryColor.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    HeroiconsSolid.mapPin,
                    color: kSecondaryColor,
                    size: getProportionateScreenWidth(13),
                  ),
                  SizedBox(width: getProportionateScreenWidth(5)),
                  Text(
                    'Addis Ababa',
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(12),
                      fontWeight: FontWeight.w700,
                      color: kSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── section header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
      ),
      child: FadeTransition(
        opacity: _headerController,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            getProportionateScreenWidth(20),
            getProportionateScreenHeight(18),
            getProportionateScreenWidth(20),
            getProportionateScreenHeight(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(26),
                    fontWeight: FontWeight.w900,
                    color: kBlackColor,
                    height: 1.15,
                    letterSpacing: -0.5,
                    fontFamily: 'Nunito',
                  ),
                  children: [
                    const TextSpan(text: 'Top '),
                    TextSpan(
                      text: 'Stores',
                      style: TextStyle(color: kSecondaryColor),
                    ),
                    const TextSpan(text: '\nNear You 📍'),
                  ],
                ),
              ),
              SizedBox(height: getProportionateScreenHeight(6)),
              Text(
                'Tap "Menu" to browse items & add to cart',
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(13),
                  color: kGreyColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: getProportionateScreenHeight(14)),
              // Horizontal category chips
              _buildCategoryChips(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final chips = ['All', '🍔 Burgers', '🍕 Pizza', '☕ Cafe', '🥗 Healthy'];
    return SizedBox(
      height: getProportionateScreenHeight(34),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) =>
            SizedBox(width: getProportionateScreenWidth(8)),
        itemBuilder: (context, i) {
          final active = i == 0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(14),
              vertical: getProportionateScreenHeight(6),
            ),
            decoration: BoxDecoration(
              color: active ? kSecondaryColor : kWhiteColor,
              borderRadius: BorderRadius.circular(20),
              border: active
                  ? null
                  : Border.all(color: kGreyColor.withValues(alpha: 0.15)),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: kSecondaryColor.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              chips[i],
              style: TextStyle(
                fontSize: getProportionateScreenWidth(12),
                fontWeight: FontWeight.w700,
                color: active ? kPrimaryColor : kGreyColor,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── store list ─────────────────────────────────────────────────────────────
  Widget _buildStoreList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        getProportionateScreenWidth(16),
        getProportionateScreenHeight(14),
        getProportionateScreenWidth(16),
        getProportionateScreenHeight(32) +
            MediaQuery.paddingOf(context).bottom,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: mockStores.length,
      itemBuilder: (context, index) {
        final store = mockStores[index];
        return FadeTransition(
          opacity: _cardFades[index],
          child: SlideTransition(
            position: _cardSlides[index],
            child: Padding(
              padding: EdgeInsets.only(
                bottom: getProportionateScreenHeight(18),
              ),
              child: _StoreCard(
                store: store,
                gradientColors: _storeGradients[index % _storeGradients.length],
                imagePath: _storeImages[index % _storeImages.length],
                onMenuTap: () => _openMenu(store),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Store card
// ─────────────────────────────────────────────────────────────────────────────
class _StoreCard extends StatefulWidget {
  final MockStore store;
  final List<Color> gradientColors;
  final String imagePath;
  final VoidCallback onMenuTap;

  const _StoreCard({
    required this.store,
    required this.gradientColors,
    required this.imagePath,
    required this.onMenuTap,
  });

  @override
  State<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<_StoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0,
      upperBound: 1,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        child: Container(
          height: getProportionateScreenHeight(220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors[0].withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── background image ────────────────────────────────────────
                Image.asset(
                  widget.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildGradientFallback(),
                ),

                // ── gradient overlay ────────────────────────────────────────
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.gradientColors[0].withValues(alpha: 0.72),
                        widget.gradientColors[1].withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),

                // ── dark bottom fade ────────────────────────────────────────
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.58),
                        ],
                        stops: const [0.35, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── content ─────────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.all(getProportionateScreenWidth(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: open badge + delivery fee
                      Row(
                        children: [
                          _GlassBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: getProportionateScreenWidth(7),
                                  height: getProportionateScreenWidth(7),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: getProportionateScreenWidth(5)),
                                Text(
                                  'Open Now',
                                  style: TextStyle(
                                    fontSize: getProportionateScreenWidth(11),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          _GlassBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  HeroiconsOutline.truck,
                                  size: getProportionateScreenWidth(12),
                                  color: Colors.white,
                                ),
                                SizedBox(width: getProportionateScreenWidth(4)),
                                Text(
                                  '${widget.store.deliveryFee.toStringAsFixed(0)} ETB',
                                  style: TextStyle(
                                    fontSize: getProportionateScreenWidth(11),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // ── bottom section ─────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Store name
                                Text(
                                  widget.store.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: getProportionateScreenWidth(17),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                    shadows: [
                                      Shadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: getProportionateScreenHeight(4)),
                                // Category + location
                                Text(
                                  widget.store.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: getProportionateScreenWidth(12),
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                ),
                                SizedBox(height: getProportionateScreenHeight(6)),
                                // Info row: rating · time · location
                                Wrap(
                                  spacing: getProportionateScreenWidth(8),
                                  runSpacing: 4,
                                  children: [
                                    _InlineChip(
                                      icon: HeroiconsSolid.star,
                                      iconColor: const Color(0xFFF59E0B),
                                      label:
                                          widget.store.rating.toStringAsFixed(1),
                                    ),
                                    _InlineChip(
                                      icon: HeroiconsOutline.clock,
                                      iconColor:
                                          Colors.white.withValues(alpha: 0.9),
                                      label: widget.store.deliveryTime,
                                    ),
                                    _InlineChip(
                                      icon: HeroiconsSolid.mapPin,
                                      iconColor:
                                          Colors.white.withValues(alpha: 0.9),
                                      label: widget.store.location
                                          .split(',')
                                          .first,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: getProportionateScreenWidth(12)),
                          // ── MENU button ─────────────────────────────────────
                          _MenuButton(onTap: widget.onMenuTap),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.gradientColors,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu button with shimmer pulse
// ─────────────────────────────────────────────────────────────────────────────
class _MenuButton extends StatefulWidget {
  final VoidCallback onTap;
  const _MenuButton({required this.onTap});

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: _pulseAnim.value,
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(16),
                vertical: getProportionateScreenHeight(11),
              ),
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
                    color: kSecondaryColor.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    HeroiconsSolid.bookOpen,
                    color: Colors.white,
                    size: getProportionateScreenWidth(14),
                  ),
                  SizedBox(width: getProportionateScreenWidth(6)),
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(13),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Glass-morphism badge used on the store card
class _GlassBadge extends StatelessWidget {
  final Widget child;
  const _GlassBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(10),
            vertical: getProportionateScreenHeight(5),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Small text+icon chip shown inside the card bottom section
class _InlineChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _InlineChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: getProportionateScreenWidth(11), color: iconColor),
        SizedBox(width: getProportionateScreenWidth(3)),
        Text(
          label,
          style: TextStyle(
            fontSize: getProportionateScreenWidth(11),
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ],
    );
  }
}

/// Round back / action button
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: getProportionateScreenWidth(40),
        height: getProportionateScreenWidth(40),
        decoration: BoxDecoration(
          color: kWhiteColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kBlackColor.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: getProportionateScreenWidth(18),
          color: kBlackColor,
        ),
      ),
    );
  }
}
