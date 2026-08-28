import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/support_chat/components/store_fetching_card.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Full-screen sheet that shows ALL stores using the same [StoreFetchingCard]
/// UI — triggered when the user taps the expand (↗) icon on an inline card.
class AllStoresSheet extends StatefulWidget {
  /// The store that was already shown inline; highlighted at the top.
  final MockStore? highlightedStore;
  final ValueChanged<MockProduct>? onAddToCart;
  final ValueChanged<MockProduct>? onProductTap;

  const AllStoresSheet({
    super.key,
    this.highlightedStore,
    this.onAddToCart,
    this.onProductTap,
  });

  @override
  State<AllStoresSheet> createState() => _AllStoresSheetState();
}

class _AllStoresSheetState extends State<AllStoresSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _headerAnim;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  /// Put highlighted store first, then the rest.
  List<MockStore> get _orderedStores {
    if (widget.highlightedStore == null) return mockStores;
    final others = mockStores
        .where((s) => s.id != widget.highlightedStore!.id)
        .toList();
    return [widget.highlightedStore!, ...others];
  }

  @override
  Widget build(BuildContext context) {
    final stores = _orderedStores;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────
              _buildHeader(context),

              // ── Store cards list ────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    getProportionateScreenWidth(16),
                    getProportionateScreenHeight(8),
                    getProportionateScreenWidth(16),
                    getProportionateScreenHeight(32) +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: getProportionateScreenHeight(14),
                      ),
                      child: StoreFetchingCard(
                        store: store,
                        products: const [],
                        onProductTap: widget.onProductTap,
                        onAddToCart: widget.onAddToCart,
                        storeOnly: true,
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

  Widget _buildHeader(BuildContext context) {
    return SlideTransition(
      position: _headerSlide,
      child: FadeTransition(
        opacity: _headerFade,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            getProportionateScreenWidth(16),
            getProportionateScreenHeight(10),
            getProportionateScreenWidth(16),
            getProportionateScreenHeight(14),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: const Color(0xFFF1F5F9), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Back button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: EdgeInsets.all(getProportionateScreenWidth(8)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(
                      HeroiconsOutline.chevronLeft,
                      size: getProportionateScreenWidth(18),
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),

              SizedBox(width: getProportionateScreenWidth(12)),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Stores Near You',
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(17),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${mockStores.length} stores available',
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(12),
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),

              // Location chip
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(10),
                  vertical: getProportionateScreenHeight(6),
                ),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
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
                      size: getProportionateScreenWidth(12),
                    ),
                    SizedBox(width: getProportionateScreenWidth(4)),
                    Text(
                      'Addis Ababa',
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(11.5),
                        fontWeight: FontWeight.w700,
                        color: kSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Route that slides up from the bottom (same feel as product screen).
class SlideAllStoresPageRoute<T> extends PageRouteBuilder<T> {
  SlideAllStoresPageRoute({required Widget page})
    : super(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (_, animation, __, child) {
          final slide =
              Tween<Offset>(
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
