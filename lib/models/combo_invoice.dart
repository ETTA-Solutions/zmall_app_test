import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// StoreFlags
// ---------------------------------------------------------------------------
// Only the fields the client needs from the invoice `store` object.
// The raw server store document contains private data (password hash,
// bank details, device tokens). NEVER keep the raw map. (§11.3)
// ---------------------------------------------------------------------------

class StoreFlags {
  const StoreFlags({
    required this.storeId,
    required this.storeName,
    required this.imageUrl,
    required this.location,
    required this.onlyCashless,
    required this.onlyScheduled,
    required this.onlyPickup,
    required this.isLaundry,
    required this.isBusy,
    required this.minOrderPrice,
    required this.deliveryTime,
    required this.deliveryTimeMax,
  });

  /// store._id
  final String storeId;

  /// store.name
  final String storeName;

  /// store.image_url (relative; prefix the same way single-store images are prefixed)
  final String imageUrl;

  /// store.location -> [lat, lng]
  final List<double> location;

  /// store.accept_only_cashless_payment
  final bool onlyCashless;

  /// store.accept_scheduled_order_only — combos cannot be scheduled in Phase 1.
  final bool onlyScheduled;

  /// store.accept_user_pickup_delivery_only — not compatible with combos.
  final bool onlyPickup;

  /// store.is_provide_laundry_service — must be false for combo eligibility.
  final bool isLaundry;

  /// store.is_store_busy
  final bool isBusy;

  /// store.min_order_price
  final double minOrderPrice;

  /// store.delivery_time (minutes, lower bound)
  final int deliveryTime;

  /// store.delivery_time_max (minutes, upper bound)
  final int deliveryTimeMax;

  factory StoreFlags.fromJson(Map<String, dynamic> j) {
    final rawLoc = j['location'];
    final loc = rawLoc is List
        ? rawLoc.map<double>((v) => (v as num).toDouble()).toList()
        : <double>[0.0, 0.0];

    return StoreFlags(
      storeId: '${j['_id'] ?? ''}',
      storeName: '${j['name'] ?? ''}',
      imageUrl: '${j['image_url'] ?? ''}',
      location: loc,
      onlyCashless: j['accept_only_cashless_payment'] == true,
      onlyScheduled: j['accept_scheduled_order_only'] == true,
      onlyPickup: j['accept_user_pickup_delivery_only'] == true,
      isLaundry: j['is_provide_laundry_service'] == true,
      isBusy: j['is_store_busy'] == true,
      minOrderPrice: (j['min_order_price'] as num? ?? 0).toDouble(),
      deliveryTime: (j['delivery_time'] as num? ?? 0).toInt(),
      deliveryTimeMax: (j['delivery_time_max'] as num? ?? 0).toInt(),
    );
  }
}

// ---------------------------------------------------------------------------
// StoreInvoice
// ---------------------------------------------------------------------------
// One store's side of a combo_get_order_cart_invoice response.
// Maps to store_a or store_b in the response body.
// ---------------------------------------------------------------------------

class StoreInvoice {
  const StoreInvoice({
    required this.success,
    required this.storeId,
    required this.cartId,
    required this.orderPaymentId,
    required this.orderPaymentUniqueId,
    required this.orderPrice,
    required this.deliveryPrice,
    required this.promo,
    required this.userPay,
    required this.distanceKm,
    required this.timeMin,
    required this.store,
    this.vehicleId,
    this.vehicleName,
  });

  /// store_x.success
  final bool success;

  /// order_payment.store_id
  final String storeId;

  /// order_payment.cart_id
  final String cartId;

  /// order_payment._id  (used in combo_pay_order_payment and combo_create_order)
  final String orderPaymentId;

  /// order_payment.unique_id as String  (int in JSON)
  /// Used as the idempotency / trace reference for the ORIGIN store.
  final String orderPaymentUniqueId;

  /// order_payment.total_order_price  (items subtotal)
  final double orderPrice;

  /// order_payment.total_delivery_price  (exactly half of combined_delivery_price)
  final double deliveryPrice;

  /// order_payment.promo_payment
  final double promo;

  /// order_payment.user_pay_payment  (orderPrice + deliveryPrice - promo)
  final double userPay;

  /// order_payment.total_distance in km  (server returns km, not meters)
  final double distanceKm;

  /// order_payment.total_time in minutes
  final double timeMin;

  /// vehicles[0]._id  — use origin's vehicleId for get_payment_gateway
  final String? vehicleId;

  /// vehicles[0].vehicle_name  — displayed in the checkout summary
  final String? vehicleName;

  /// Safe subset of the store object. Never expose the raw store map. (§11.3)
  final StoreFlags store;

  factory StoreInvoice.fromJson(Map<String, dynamic> j) {
    final payment = (j['order_payment'] as Map?)?.cast<String, dynamic>() ?? {};
    final storeMap = (j['store'] as Map?)?.cast<String, dynamic>() ?? {};
    final vehicles = j['vehicles'] as List? ?? [];
    final firstVehicle = vehicles.isNotEmpty
        ? (vehicles[0] as Map?)?.cast<String, dynamic>()
        : null;

    return StoreInvoice(
      success: j['success'] == true,
      storeId: '${payment['store_id'] ?? ''}',
      cartId: '${payment['cart_id'] ?? ''}',
      orderPaymentId: '${payment['_id'] ?? ''}',
      // unique_id is an int in JSON; convert to String.
      orderPaymentUniqueId: '${payment['unique_id'] ?? ''}',
      orderPrice: (payment['total_order_price'] as num? ?? 0).toDouble(),
      deliveryPrice: (payment['total_delivery_price'] as num? ?? 0).toDouble(),
      promo: (payment['promo_payment'] as num? ?? 0).toDouble(),
      userPay: (payment['user_pay_payment'] as num? ?? 0).toDouble(),
      distanceKm: (payment['total_distance'] as num? ?? 0).toDouble(),
      timeMin: (payment['total_time'] as num? ?? 0).toDouble(),
      vehicleId: firstVehicle != null ? '${firstVehicle['_id'] ?? ''}' : null,
      vehicleName: firstVehicle != null
          ? '${firstVehicle['vehicle_name'] ?? ''}'
          : null,
      // Strip the raw store object — copy only what the client needs. (§11.3)
      store: StoreFlags.fromJson(storeMap),
    );
  }
}

// ---------------------------------------------------------------------------
// ComboInvoice
// ---------------------------------------------------------------------------
// Parsed result of POST /api/user/combo_get_order_cart_invoice.
//
// The caller decides which store is the origin (farther from the customer,
// §11.2) and sends it as store_a. This class always exposes [origin]
// (= store_a) and [secondary] (= store_b), matching that convention.
// ---------------------------------------------------------------------------

class ComboInvoice {
  const ComboInvoice({
    required this.comboId,
    required this.combinedDelivery,
    required this.combinedUserPay,
    required this.origin,
    required this.secondary,
  });

  /// combo_id from the response
  final String comboId;

  /// combined_delivery_price  (origin.deliveryPrice + secondary.deliveryPrice)
  final double combinedDelivery;

  /// combined_user_pay_payment — the canonical total for display and payment.
  /// Use this everywhere: bottom bar, Kifiya price, wallet balance check. (§3.2)
  final double combinedUserPay;

  /// store_a in the invoice response — the route origin (farther store).
  final StoreInvoice origin;

  /// store_b in the invoice response — the waypoint store.
  final StoreInvoice secondary;

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  /// Vehicle id from the origin leg; use this for get_payment_gateway. (§11.7)
  String? get vehicleId => origin.vehicleId;

  /// Vehicle name from the origin leg; shown in the checkout summary.
  String? get vehicleName => origin.vehicleName;

  // ---------------------------------------------------------------------------
  // Store-flag helpers (§11.3)
  // ---------------------------------------------------------------------------

  /// Either store requires cashless-only payment.
  bool get onlyCashless =>
      origin.store.onlyCashless || secondary.store.onlyCashless;

  /// Either store is scheduled-only — blocks combo checkout in Phase 1.
  bool get onlyScheduled =>
      origin.store.onlyScheduled || secondary.store.onlyScheduled;

  /// Either store is pickup-only — not compatible with a combo.
  bool get onlyPickup =>
      origin.store.onlyPickup || secondary.store.onlyPickup;

  /// Either store is currently marked busy.
  bool get anyStoreBusy =>
      origin.store.isBusy || secondary.store.isBusy;

  /// Name of the first busy store (for error messages).
  String? get busyStoreName {
    if (origin.store.isBusy) return origin.store.storeName;
    if (secondary.store.isBusy) return secondary.store.storeName;
    return null;
  }

  /// ETA range string using the larger window across both stores, e.g. "30-45 min".
  String get etaLabel {
    final lo = origin.store.deliveryTime > secondary.store.deliveryTime
        ? origin.store.deliveryTime
        : secondary.store.deliveryTime;
    final hi = origin.store.deliveryTimeMax > secondary.store.deliveryTimeMax
        ? origin.store.deliveryTimeMax
        : secondary.store.deliveryTimeMax;
    if (lo == 0 && hi == 0) return '';
    return '$lo-$hi min';
  }

  // ---------------------------------------------------------------------------
  // Factory
  // ---------------------------------------------------------------------------

  factory ComboInvoice.fromJson(Map<String, dynamic> j) {
    final a = StoreInvoice.fromJson(
        (j['store_a'] as Map?)?.cast<String, dynamic>() ?? {});
    final b = StoreInvoice.fromJson(
        (j['store_b'] as Map?)?.cast<String, dynamic>() ?? {});

    // Validate: combined_user_pay_payment should equal the sum of the two legs.
    // If they differ by more than cent 1, log it and trust the server value. (§11.5)
    final clientSum =
        double.parse((a.userPay + b.userPay).toStringAsFixed(2));
    final serverTotal =
        (j['combined_user_pay_payment'] as num?)?.toDouble() ?? clientSum;
    if ((serverTotal - clientSum).abs() > 0.01) {
      debugPrint(
        '[COMBO] WARNING: combined_user_pay_payment mismatch '
        '— server=$serverTotal  client_sum=$clientSum. '
        'Trusting server value.',
      );
    }

    return ComboInvoice(
      comboId: '${j['combo_id'] ?? ''}',
      combinedDelivery: (j['combined_delivery_price'] as num? ??
              a.deliveryPrice + b.deliveryPrice)
          .toDouble(),
      combinedUserPay: serverTotal,
      origin: a,
      secondary: b,
    );
  }

  // ---------------------------------------------------------------------------
  // Validation (§11.5)
  // ---------------------------------------------------------------------------

  /// Returns null if the invoice is structurally valid, or a human-readable
  /// error string that can be shown directly to the user.
  String? validate() {
    if (comboId.isEmpty) return 'Invalid combo id in invoice.';
    if (!origin.success) return 'Store A invoice failed.';
    if (!secondary.success) return 'Store B invoice failed.';
    if (origin.orderPaymentId.isEmpty || secondary.orderPaymentId.isEmpty) {
      return 'Missing order payment id in invoice.';
    }
    return null;
  }
}
