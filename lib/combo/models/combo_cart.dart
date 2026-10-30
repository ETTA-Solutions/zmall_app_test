import 'package:zmall/models/cart.dart';
import 'package:zmall/services/service.dart';

/// Local state for a two-store (combo) order.
///
/// The first store stays in the normal `cart` key so every existing screen
/// keeps working. This object holds the second store and the ids returned by
/// the `combo_*` endpoints. Ids are always keyed by store_id, because the
/// server's `store_a` / `store_b` labels change after the route is computed.
class ComboCart {
  static const String storageKey = 'combo_cart';

  ComboCart({
    required this.second,
    this.comboId,
    this.originStoreId,
    Map<String, String>? cartIdByStore,
    Map<String, String>? orderPaymentIdByStore,
  }) : cartIdByStore = cartIdByStore ?? {},
       orderPaymentIdByStore = orderPaymentIdByStore ?? {};

  /// Second store's cart (items, store id, store location).
  Cart second;

  /// From combo_add_item_in_cart.
  String? comboId;

  /// Farther store from the customer; sent as `store_a` from the invoice on.
  String? originStoreId;

  /// store_id -> cart_id, from combo_add_item_in_cart.
  Map<String, String> cartIdByStore;

  /// store_id -> order_payment _id, from combo_get_order_cart_invoice.
  Map<String, String> orderPaymentIdByStore;

  String? get secondStoreId => second.storeId;

  factory ComboCart.fromJson(Map<String, dynamic> json) => ComboCart(
    second: Cart.fromJson(json['second']),
    comboId: json['combo_id'],
    originStoreId: json['origin_store_id'],
    cartIdByStore: Map<String, String>.from(json['cart_id_by_store'] ?? {}),
    orderPaymentIdByStore: Map<String, String>.from(
      json['order_payment_id_by_store'] ?? {},
    ),
  );

  Map<String, dynamic> toJson() => {
    'second': second.toJson(),
    'combo_id': comboId,
    'origin_store_id': originStoreId,
    'cart_id_by_store': cartIdByStore,
    'order_payment_id_by_store': orderPaymentIdByStore,
  };

  static Future<ComboCart?> load() async {
    final data = await Service.read(storageKey);
    if (data == null) return null;
    try {
      final combo = ComboCart.fromJson(Map<String, dynamic>.from(data));
      if (combo.second.items == null || combo.second.items!.isEmpty) {
        await clear();
        return null;
      }
      return combo;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save() => Service.save(storageKey, toJson());

  static Future<void> clear() => Service.remove(storageKey);

  /// Starts a combo with [item] as the first item of the second store.
  static Future<ComboCart> start({
    required dynamic userData,
    required String storeId,
    required Item item,
    required StoreLocation storeLocation,
    required DestinationAddress destination,
  }) async {
    final combo = ComboCart(
      second: Cart(
        userId: userData['user']['_id'],
        serverToken: userData['user']['server_token'],
        items: [item],
        storeId: storeId,
        storeLocation: storeLocation,
        destinationAddress: destination,
      ),
    );
    await combo.save();
    return combo;
  }

  /// Merges [item] into the second store when [storeId] is that store.
  /// Returns false when there is no combo or it belongs to another store.
  static Future<bool> addToSecondStoreIfMatches(
    String? storeId,
    Item item,
  ) async {
    final combo = await load();
    if (combo == null || combo.secondStoreId != storeId) return false;
    Service.addOrMergeCartItem(combo.second, item);
    // Items changed, so server-side ids are stale.
    combo.resetServerState();
    await combo.save();
    return true;
  }

  /// Whether a new store may become the second store of a combo.
  static Future<bool> canStartWith(Cart? firstCart) async {
    if (firstCart == null || firstCart.storeId == null) return false;
    if (firstCart.items == null || firstCart.items!.isEmpty) return false;
    if (firstCart.isLaundryService) return false;
    if (await load() != null) return false;
    final aliCart = await Service.read('aliexpressCart');
    if (aliCart != null) {
      try {
        if (AliExpressCart.fromJson(aliCart).cart.storeId ==
            firstCart.storeId) {
          return false;
        }
      } catch (_) {}
    }
    return true;
  }

  /// Keeps combo_id (the server reuses it on re-sync) but drops ids that
  /// belong to an older version of the carts.
  void resetServerState() {
    cartIdByStore.clear();
    orderPaymentIdByStore.clear();
    originStoreId = null;
  }
}
