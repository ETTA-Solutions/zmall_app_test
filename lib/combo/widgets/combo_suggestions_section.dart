// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/combo/services/combo_service.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/product/product_screen.dart';
import 'package:zmall/services/core_services.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// "Complete your order" section shown at the bottom of the cart.
///
/// Fetches [POST /api/user/combo_suggestions] once when mounted, then
/// re-fetches whenever [storeId] or [itemNames] change (debounced 400 ms)
/// or the cached result is older than 2 minutes.
///
/// Shows skeleton placeholders while loading; hides itself when both lists
/// are empty or the user is not logged in.
class ComboSuggestionsSection extends StatefulWidget {
  /// Current cart's store id. Null = cart is empty → section stays hidden.
  final String? storeId;

  /// Names of all items currently in the cart (for the request body).
  final List<String> itemNames;

  /// Pass null when the user is not logged in → section stays hidden.
  final dynamic userData;

  /// Called when the user taps "Add" on a suggestion item.
  /// [storeData] is the store map from the response,
  /// [item]      is the item map (`item_id`, `name`, `price`, `has_options`, `image`).
  final Future<void> Function(
    Map<String, dynamic> storeData,
    Map<String, dynamic> item,
  )
  onAdd;

  const ComboSuggestionsSection({
    super.key,
    required this.storeId,
    required this.itemNames,
    required this.userData,
    required this.onAdd,
  });

  @override
  State<ComboSuggestionsSection> createState() =>
      _ComboSuggestionsSectionState();
}

class _ComboSuggestionsSectionState extends State<ComboSuggestionsSection> {
  // ── State ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _goesWithCart = [];
  bool _loading = false;
  DateTime? _fetchedAt;

  // ── Debounce / cache ───────────────────────────────────────────────────────
  Timer? _debounce;
  String? _lastStoreId;
  List<String> _lastItemNames = [];
  String? _busyItemId; // item_id being added right now

  static const _debounceMs = 400;
  static const _cacheMinutes = 2;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final sid = widget.storeId;
    if (sid != null && widget.itemNames.isNotEmpty) {
      final c = ComboService.cachedSuggestions(sid, widget.itemNames);
      if (c != null) {
        _lastStoreId = sid;
        _lastItemNames = List<String>.from(widget.itemNames);
        _fetchedAt = DateTime.now();
        _favorites = _parseStores(c['favorites']);
        _goesWithCart = _parseStores(c['goes_with_cart']);
      }
    }
    _scheduleFetch();
  }

  @override
  void didUpdateWidget(covariant ComboSuggestionsSection old) {
    super.didUpdateWidget(old);
    final storeChanged = widget.storeId != old.storeId;
    final namesChanged = !_listsEqual(widget.itemNames, old.itemNames);
    final userChanged = (widget.userData == null) != (old.userData == null);
    if (storeChanged || namesChanged || userChanged) {
      _scheduleFetch();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ── Fetching ───────────────────────────────────────────────────────────────

  void _scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), _maybeFetch);
  }

  Future<void> _maybeFetch() async {
    final storeId = widget.storeId;
    debugPrint(
      '[COMBO] suggestions check store=$storeId user=${widget.userData != null} items=${widget.itemNames.length}',
    );
    if (storeId == null ||
        storeId.isEmpty ||
        widget.userData == null ||
        widget.itemNames.isEmpty) {
      return;
    }

    // Cache still valid?
    final sameQuery =
        storeId == _lastStoreId &&
        _listsEqual(widget.itemNames, _lastItemNames);
    final fresh =
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!).inMinutes < _cacheMinutes;
    if (sameQuery && fresh) return;

    if (!mounted) return;
    setState(() => _loading = true);

    final data = await ComboService.getSuggestions(
      context,
      userData: widget.userData,
      storeId: storeId,
      itemNames: widget.itemNames,
    );

    if (!mounted) return;

    // Session expired?
    if (ComboService.isSessionExpired(data)) {
      Service.showMessage(
        context: context,
        title: "${errorCodes['999']}!",
        error: true,
      );
      await CoreServices.clearCache();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      return;
    }

    setState(() {
      _loading = false;
      if (data != null && data['success'] == true) {
        _lastStoreId = storeId;
        _lastItemNames = List<String>.from(widget.itemNames);
        _fetchedAt = DateTime.now();
        _favorites = _parseStores(data['favorites']);
        _goesWithCart = _parseStores(data['goes_with_cart']);
      }
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<Map<String, dynamic>> _parseStores(dynamic raw) {
    if (raw == null) return [];
    return (raw as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static List<Map<String, dynamic>> _parseItems(dynamic raw) {
    if (raw == null) return [];
    return (raw as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.userData == null) return const SizedBox.shrink();

    final meta = Provider.of<ZMetaData>(context, listen: false);
    final baseUrl = meta.baseUrl;
    final currency = meta.currency;

    if (_loading && _favorites.isEmpty && _goesWithCart.isEmpty) {
      return _Skeleton();
    }
    final tabs = <String, List<Map<String, dynamic>>>{
      if (_favorites.isNotEmpty) 'Your favourites': _favorites,
      if (_goesWithCart.isNotEmpty) 'Goes well with': _goesWithCart,
    };
    if (tabs.isEmpty) return const SizedBox.shrink();

    final keys = tabs.keys.toList();
    if (_tab >= keys.length) _tab = 0;
    final entries = tabs[keys[_tab]]!;

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              getProportionateScreenWidth(kDefaultPadding),
              getProportionateScreenHeight(kDefaultPadding / 2),
              getProportionateScreenWidth(kDefaultPadding),
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Z MORE',
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(19),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: kSecondaryColor,
                  ),
                ),
                SizedBox(width: getProportionateScreenWidth(8)),
                Flexible(
                  child: Text(
                    'Two cravings · Two places · One checkout',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(13),
                      color: kGreyColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(kDefaultPadding),
            ),
            child: Row(
              children: [
                for (var i = 0; i < keys.length; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: getProportionateScreenWidth(kDefaultPadding),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 2,
                            color: i == _tab
                                ? kSecondaryColor
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Text(
                        keys[i],
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(14),
                          fontWeight: i == _tab
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: i == _tab ? kBlackColor : kGreyColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: getProportionateScreenHeight(240),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(kDefaultPadding),
                vertical: getProportionateScreenHeight(8),
              ),
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
                  SizedBox(width: getProportionateScreenWidth(10)),
              itemBuilder: (_, i) => _StoreCard(
                entry: entries[i],
                baseUrl: baseUrl,
                currency: currency,
                busyItemId: _busyItemId,
                onAdd: _onAdd,
                latitude: meta.latitude,
                longitude: meta.longitude,
              ),
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
        ],
      ),
    );
  }

  Future<void> _onAdd(
    Map<String, dynamic> storeData,
    Map<String, dynamic> item,
  ) async {
    if (_busyItemId != null) return;
    setState(() => _busyItemId = '${item['item_id']}');
    try {
      await widget.onAdd(storeData, item);
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }
}

// ── Store card ───────────────────────────────────────────────────────────────

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String baseUrl;
  final String currency;
  final String? busyItemId;
  final double? latitude;
  final double? longitude;
  final Future<void> Function(
    Map<String, dynamic> storeData,
    Map<String, dynamic> item,
  )
  onAdd;

  const _StoreCard({
    required this.entry,
    required this.baseUrl,
    required this.currency,
    required this.busyItemId,
    required this.onAdd,
    required this.latitude,
    required this.longitude,
  });

  String? _distance(Map store) {
    final d = store['distance_km'];
    if (d is! num) return null;
    return d < 1 ? '${(d * 1000).round()} m' : '${d.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final store = Map<String, dynamic>.from(entry['store'] as Map? ?? {});
    final items = [
      ..._ComboSuggestionsSectionState._parseItems(entry['order_again_items']),
      ..._ComboSuggestionsSectionState._parseItems(entry['goes_with_items']),
      ..._ComboSuggestionsSectionState._parseItems(entry['matched_items']),
    ].take(2).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final storeImage = '${store['image_url'] ?? ''}';
    final rating = (store['user_rate'] as num?)?.toDouble();
    final dist = _distance(store);

    Widget logoFallback() => Container(
      width: 40,
      height: 40,
      color: kPrimaryColor,
      child: Icon(Icons.storefront_outlined, color: kGreyColor, size: 20),
    );

    return Container(
      width: getProportionateScreenWidth(270),
      padding: EdgeInsets.all(getProportionateScreenWidth(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kDefaultPadding),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: storeImage.isEmpty
                    ? logoFallback()
                    : CachedNetworkImage(
                        imageUrl: '$baseUrl/$storeImage',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => logoFallback(),
                        placeholder: (_, __) => logoFallback(),
                      ),
              ),
              SizedBox(width: getProportionateScreenWidth(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${store['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: getProportionateScreenWidth(14),
                        color: kBlackColor,
                      ),
                    ),
                    if (rating != null || dist != null)
                      Row(
                        children: [
                          if (rating != null) ...[
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.amber[600],
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$rating',
                              style: TextStyle(fontSize: 12, color: kGreyColor),
                            ),
                          ],
                          if (rating != null && dist != null)
                            Text(' · ', style: TextStyle(color: kGreyColor)),
                          if (dist != null)
                            Text(
                              dist,
                              style: TextStyle(fontSize: 12, color: kGreyColor),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items)
            _ItemRow(
              item: item,
              store: store,
              baseUrl: baseUrl,
              currency: currency,
              busyItemId: busyItemId,
              onAdd: onAdd,
            ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductScreen(
                    latitude: latitude ?? 0.0,
                    longitude: longitude ?? 0.0,
                    store: store,
                    location: store['location'] ?? [],
                    isOpen: true,
                  ),
                ),
              );
            },
            child: Text(
              'View store',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kGreyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item row ──────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic> store;
  final String baseUrl;
  final String currency;
  final String? busyItemId;
  final Future<void> Function(
    Map<String, dynamic> storeData,
    Map<String, dynamic> item,
  )
  onAdd;

  const _ItemRow({
    required this.item,
    required this.store,
    required this.baseUrl,
    required this.currency,
    required this.busyItemId,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final busy = busyItemId == '${item['item_id']}';
    final image = '${item['image'] ?? ''}';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final hasOptions = item['has_options'] == true;

    Widget fallback() => Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.shopping_cart_outlined,
        color: Colors.white,
        size: 22,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image.isEmpty
                ? fallback()
                : CachedNetworkImage(
                    imageUrl: '$baseUrl/$image',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => fallback(),
                    placeholder: (_, __) => fallback(),
                  ),
          ),
          SizedBox(width: getProportionateScreenWidth(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(13),
                    fontWeight: FontWeight.w600,
                    color: kBlackColor,
                  ),
                ),
                Text(
                  '${hasOptions ? 'from ' : ''}$currency ${price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(12),
                    color: kGreyColor,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: busyItemId != null ? null : () => onAdd(store, item),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kSecondaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: kSecondaryColor,
                      ),
                    )
                  : Icon(Icons.add, size: 18, color: kSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton placeholder ──────────────────────────────────────────────────────

class _Skeleton extends StatefulWidget {
  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Opacity(
        opacity: 0.4 + 0.3 * _ctrl.value,
        child: SizedBox(
          height: getProportionateScreenHeight(240 + 40),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              getProportionateScreenWidth(kDefaultPadding),
              getProportionateScreenHeight(40),
              getProportionateScreenWidth(kDefaultPadding),
              getProportionateScreenHeight(8),
            ),
            itemCount: 3,
            separatorBuilder: (_, __) =>
                SizedBox(width: getProportionateScreenWidth(10)),
            itemBuilder: (_, __) => Container(
              width: getProportionateScreenWidth(270),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(kDefaultPadding),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
