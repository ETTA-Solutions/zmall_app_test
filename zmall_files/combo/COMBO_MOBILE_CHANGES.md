# Combo Order: Mobile Changes

| | |
| --- | --- |
| **Branch** | `new_combo` |
| **Date** | 2026-10-04 |
| **Status** | Built, `flutter analyze lib` shows 0 errors. **Not yet tested on a device or against the test backend.** Not committed. |
| **Related** | `zmall_files/combo/COMBO_ORDER_IMPLEMENTATION.md` (the spec this follows) |

## Contents

1. [Summary](#1-summary)
2. [User flow](#2-user-flow)
3. [Design decisions](#3-design-decisions)
4. [File list](#4-file-list)
5. [New files (full code)](#5-new-files-full-code)
6. [Changed files (diffs)](#6-changed-files-diffs)
7. [Not done yet / open questions](#7-not-done-yet--open-questions)
8. [How to test](#8-how-to-test)

## 1. Summary

Customers can now order from **2 stores in one checkout**, and one driver delivers both. The app uses the 4 backend endpoints:

| Step | Endpoint | Called from |
| --- | --- | --- |
| 1 | `combo_add_item_in_cart` | `DeliveryScreen._addToComboCart` |
| 2 | `combo_get_order_cart_invoice` | `ComboCheckoutScreen._getInvoice` |
| 3 | `combo_pay_order_payment` | `ComboCheckoutScreen._pay` |
| 4 | `combo_create_order` | `ComboCheckoutScreen._createOrder` |

Single-store ordering is unchanged. If there is no `combo_cart`, every screen takes the old path.

## 2. User flow

```
Item / Product / Store screen
  ├─ same store as cart            → merge (unchanged)
  ├─ same store as combo store 2   → merge into store 2
  ├─ new store, no combo yet       → dialog: [Cancel] [Clear] [Order from both stores]
  └─ new store, combo already full → dialog: [Cancel] [Clear]   ("at most 2 stores")
        │
        ▼
Cart: store 1 items + "Second store · same delivery" section, total = both stores
        │  (store 1 emptied → store 2 becomes the normal cart)
        │  (store 2 emptied → combo removed)
        ▼
DeliveryScreen ── combo_add_item_in_cart ──► combo_id + cart_id per store_id
        │  (self-pickup blocked)
        ▼
ComboCheckoutScreen
   ├─ computeComboRoute: farther store = origin (store_a), Directions API (falls back to haversine)
   ├─ combo_get_order_cart_invoice ──► order_payment per store, combined totals
   ├─ choose Cash or Wallet
   ├─ change_user_wallet_status(is_use_wallet)
   ├─ combo_pay_order_payment
   └─ combo_create_order ──► clear cart + combo_cart → ReportScreen
```

## 3. Design decisions

| Decision | Why |
| --- | --- |
| Store 1 stays in the normal `cart` key. Only store 2 and the server ids go in `combo_cart`. | Every existing screen (cart badge, item screens, delivery, single checkout) keeps reading `cart` without changes. The spec suggested putting both carts in `combo_cart`, but that would have broken those screens. |
| Ids are saved **by `store_id`**, never as "a"/"b". | The server's `store_a`/`store_b` labels swap after the route is computed. |
| The farther store from the customer is the origin (`store_a`). | The store-to-store leg is the same both ways, so ending at the nearer store gives the shorter trip. Driver search starts around `store_a`. |
| `total_distance` is sent in meters and `total_time` in seconds, rounded. | Matches what web sends (863 m / 282 s). |
| Wallet uses `change_user_wallet_status` first, then pays with `is_payment_mode_cash: true`. | This is how the existing `KifiyaScreen` pays with wallet. The spec says "false = wallet", but that doesn't match the app's current flow. |
| `order_from` is `"android"` / `"ios"`. | Web sends `"web"`. **Confirm with the backend.** |
| Only cash and wallet are offered. | The backend doesn't support external gateways for combo yet. |
| A separate `ComboCheckoutScreen` instead of changing `CheckoutScreen` / `KifiyaScreen`. | Those screens are 2,200 and 4,200 lines and already busy. Keeping combo separate avoids breaking single-store checkout. |
| After a successful pay, the screen remembers `_paid` and won't let the user go back. A retry only calls create. | Prevents paying twice if create fails. |
| Every new item resets the server ids, but `combo_id` is kept. | The delivery screen re-syncs and sends the same `combo_id`, as the spec asks. |

## 4. File list

**New**

- `lib/combo/models/combo_cart.dart`: Local combo state. Holds the **second** store's cart and the ids the server returns, keyed by `store_id`. Saved under the `combo_cart` key.
- `lib/combo/services/combo_service.dart`: The 4 combo HTTP calls, plus `change_user_wallet_status`, `get_detail` and the store detail call. Also turns error responses into readable text.
- `lib/combo/combo_route.dart`: Picks the pickup order (the farther store goes first) and gets the whole-trip distance and time from Google Directions. Falls back to straight-line distance.
- `lib/combo/combo_checkout_screen.dart`: New checkout screen for 2 stores: route → invoice → wallet/cash → pay → create → success.
- `lib/combo/widgets/store_conflict_dialog.dart`: Shared "different store" dialog with **Cancel / Clear / Order from both stores**.
- `lib/combo/widgets/combo_store_section.dart`: Cart section for the second store: items, +/− quantity, remove, subtotal, "Add more?".

**Changed**

- `lib/item/components/body.dart`: Item screen. A different-store item now goes through `_handleOtherStore`: it merges into the combo's second store, or shows the new dialog. Clear also removes `combo_cart`.
- `lib/product/product_screen.dart`: Store product list. Same change as the item screen. Shows a message instead of closing the screen.
- `lib/notifications/notification_store.dart`: Store screen opened from a notification or "Add more?". Same change, plus a `language.dart` import.
- `lib/cart/components/body.dart`: Cart screen. Loads `combo_cart`, shows `ComboStoreSection` as the last list row and includes store 2 in the total. If store 1 is emptied, store 2 becomes the normal cart. Clear also removes the combo.
- `lib/delivery/delivery_screen.dart`: Delivery screen. If a combo exists, `_addToCart` calls `_addToComboCart`: it blocks self-pickup, calls `combo_add_item_in_cart`, saves `combo_id` and the cart ids by `store_id`, then opens `ComboCheckoutScreen`.
- `lib/models/language.dart`: New strings (English and Chinese): `orderFromBothStores`, `comboItemsFound`, `comboStoreLimit`, `comboAdded`.
- `lib/services/service.dart`: Logout (`clearUserData`) also removes `combo_cart`.
- `lib/services/core_services.dart`: Cache clear also removes `combo_cart`.
- `lib/profile/components/body.dart`: Logout and delete-account paths (3 places) also remove `combo_cart`.

> Some files were already modified on this branch before this work: `checkout_screen.dart`, `kifiya_screen.dart`, `telebirr_inapp.dart`, `wegagen_ussd.dart`, `constants.dart` and others. Those changes are **not** part of this document.

## 5. New files (full code)

### 5.1 `lib/combo/models/combo_cart.dart`

Local combo state. Holds the **second** store's cart and the ids the server returns, keyed by `store_id`. Saved under the `combo_cart` key.

```dart
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
```

### 5.2 `lib/combo/services/combo_service.dart`

The 4 combo HTTP calls, plus `change_user_wallet_status`, `get_detail` and the store detail call. Also turns error responses into readable text.

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/combo/combo_route.dart';
import 'package:zmall/combo/models/combo_cart.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/utils/constants.dart';

/// HTTP calls for combo (two-store) orders.
///
/// Every method returns the decoded body, or null on timeout / network error.
class ComboService {
  static Future<Map<String, dynamic>?> _post(
    BuildContext context,
    String path,
    Map<String, dynamic> body, {
    int timeout = 30,
  }) async {
    final url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/$path";
    try {
      if (kDebugMode) debugPrint("[COMBO] $path BODY: ${json.encode(body)}");
      final response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: json.encode(body),
          )
          .timeout(
            Duration(seconds: timeout),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      if (kDebugMode) debugPrint("[COMBO] $path RESPONSE: ${response.body}");
      return Map<String, dynamic>.from(json.decode(response.body));
    } catch (e) {
      if (kDebugMode) debugPrint("[COMBO] $path ERROR: $e");
      return null;
    }
  }

  static Map<String, dynamic> _items(Cart cart) => {
    "store_id": cart.storeId,
    "items": cart.items!.map((item) => item.toJson()).toList(),
  };

  /// Step 1: sends both carts. Response holds combo_id and a cart_id per store.
  static Future<Map<String, dynamic>?> addItemInCart(
    BuildContext context, {
    required dynamic userData,
    required Cart first,
    required ComboCart combo,
    required DestinationAddress destination,
    required String username,
    required String phone,
  }) => _post(context, "combo_add_item_in_cart", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
    if (combo.comboId != null) "combo_id": combo.comboId,
    "destination_address": destination.toJson(),
    "delivery_type": 1,
    "username": username,
    "phone": phone,
    "store_a": _items(first),
    "store_b": _items(combo.second),
  });

  /// Step 2: prices both carts. `store_a` must be the route origin.
  static Future<Map<String, dynamic>?> getInvoice(
    BuildContext context, {
    required dynamic userData,
    required ComboCart combo,
    required ComboRoute route,
  }) => _post(context, "combo_get_order_cart_invoice", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
    "combo_id": combo.comboId,
    "order_type": 7,
    "total_time": route.totalTime.round(),
    "total_distance": route.totalDistance.round(),
    "store_a": {
      "store_id": route.originStoreId,
      "cart_id": combo.cartIdByStore[route.originStoreId],
    },
    "store_b": {
      "store_id": route.waypointStoreId,
      "cart_id": combo.cartIdByStore[route.waypointStoreId],
    },
  });

  /// Step 3: pays both order payments. Like single-store pay_order_payment,
  /// cash and wallet both send is_payment_mode_cash: true; the wallet is
  /// chosen beforehand with [setWalletUse].
  static Future<Map<String, dynamic>?> pay(
    BuildContext context, {
    required dynamic userData,
    required String originPaymentId,
    required String waypointPaymentId,
    String otp = "",
  }) => _post(context, "combo_pay_order_payment", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
    "store_a_order_payment_id": originPaymentId,
    "store_b_order_payment_id": waypointPaymentId,
    "is_payment_mode_cash": true,
    "order_type": 7,
    "otp": otp,
  }, timeout: 40);

  /// Step 4: creates the two orders. `store_a_cart_id` is the origin's cart.
  static Future<Map<String, dynamic>?> createOrder(
    BuildContext context, {
    required dynamic userData,
    required String comboId,
    required String originCartId,
    required String waypointCartId,
  }) => _post(context, "combo_create_order", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
    "combo_id": comboId,
    "store_a_cart_id": originCartId,
    "store_b_cart_id": waypointCartId,
    "is_user_pick_up_order": false,
    "order_from": Platform.isIOS ? "ios" : "android",
  }, timeout: 50);

  /// Same call the payment screen makes before paying.
  static Future<Map<String, dynamic>?> setWalletUse(
    BuildContext context, {
    required dynamic userData,
    required bool useWallet,
  }) => _post(context, "change_user_wallet_status", {
    "user_id": userData['user']['_id'],
    "is_use_wallet": useWallet,
    "server_token": userData['user']['server_token'],
  }, timeout: 20);

  static Future<Map<String, dynamic>?> getUserDetail(
    BuildContext context, {
    required dynamic userData,
  }) => _post(context, "get_detail", {
    "user_id": userData['user']['_id'],
    "server_token": userData['user']['server_token'],
  }, timeout: 20);

  static Future<Map<String, dynamic>?> getStoreDetail(
    BuildContext context, {
    required String storeId,
  }) => _post(context, "user_get_store_product_item_list", {
    "store_id": storeId,
  }, timeout: 20);

  /// Best readable error from a combo response. Combo endpoints return
  /// plain-text errors in `error`/`message`; wrapped single-store calls
  /// return numeric `error_code`s.
  static String errorText(Map<String, dynamic>? data, {String? fallback}) {
    if (data == null) {
      return "Something went wrong! Check your internet and try again";
    }
    for (final side in ["store_a", "store_b"]) {
      final sideData = data[side];
      if (sideData is Map && sideData['success'] == false) {
        return errorText(Map<String, dynamic>.from(sideData));
      }
    }
    final code = data['error_code'];
    if (code != null && errorCodes['$code'] != null) {
      return "${errorCodes['$code']}";
    }
    if (code == "YOUR_WALLET_AMOUNT_NEGATIVE") {
      return "Not enough wallet balance. Pay with cash or top up your wallet.";
    }
    for (final key in ["error", "error_message", "message"]) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return fallback ?? "Something went wrong. Please try again.";
  }

  static bool isSessionExpired(Map<String, dynamic>? data) =>
      data != null && "${data['error_code']}" == "999";
}
```

### 5.3 `lib/combo/combo_route.dart`

Picks the pickup order (the farther store goes first) and gets the whole-trip distance and time from Google Directions. Falls back to straight-line distance.

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zmall/services/address_validation_service.dart';

/// Pickup order and trip totals for a combo delivery.
class ComboRoute {
  ComboRoute({
    required this.originStoreId,
    required this.waypointStoreId,
    required this.totalDistance,
    required this.totalTime,
    required this.fromFallback,
  });

  /// Picked up first; sent as `store_a`.
  final String originStoreId;

  /// Picked up second; sent as `store_b`.
  final String waypointStoreId;

  /// Meters, whole trip (origin -> waypoint -> customer).
  final double totalDistance;

  /// Seconds, whole trip.
  final double totalTime;

  final bool fromFallback;
}

/// The farther store from the customer is the origin. The store-to-store leg
/// is the same both ways, so ending at the nearer store gives the shorter trip.
Future<ComboRoute> computeComboRoute({
  required String storeIdX,
  required double xLat,
  required double xLng,
  required String storeIdY,
  required double yLat,
  required double yLng,
  required double custLat,
  required double custLng,
  required String apiKey,
}) async {
  final dx = AddressValidationService.calculateDistanceInMeters(
    xLat,
    xLng,
    custLat,
    custLng,
  );
  final dy = AddressValidationService.calculateDistanceInMeters(
    yLat,
    yLng,
    custLat,
    custLng,
  );
  final xIsOrigin = dx >= dy;

  final originId = xIsOrigin ? storeIdX : storeIdY;
  final waypointId = xIsOrigin ? storeIdY : storeIdX;
  final oLat = xIsOrigin ? xLat : yLat, oLng = xIsOrigin ? xLng : yLng;
  final wLat = xIsOrigin ? yLat : xLat, wLng = xIsOrigin ? yLng : xLng;

  try {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${oLat.toStringAsFixed(6)},${oLng.toStringAsFixed(6)}'
        '&destination=$custLat,$custLng'
        '&waypoints=${wLat.toStringAsFixed(6)},${wLng.toStringAsFixed(6)}'
        '&mode=driving&key=$apiKey';
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    final data = json.decode(response.body);
    if (data['status'] == 'OK') {
      final legs = data['routes'][0]['legs'] as List;
      double distance = 0, time = 0;
      for (final leg in legs) {
        distance += (leg['distance']['value'] as num).toDouble();
        time += (leg['duration']['value'] as num).toDouble();
      }
      return ComboRoute(
        originStoreId: originId,
        waypointStoreId: waypointId,
        totalDistance: distance,
        totalTime: time,
        fromFallback: false,
      );
    }
  } catch (_) {}

  // Fallback: two straight-line legs, ~2 min per km (same as checkout).
  final distance =
      AddressValidationService.calculateDistanceInMeters(
        oLat,
        oLng,
        wLat,
        wLng,
      ) +
      AddressValidationService.calculateDistanceInMeters(
        wLat,
        wLng,
        custLat,
        custLng,
      );
  return ComboRoute(
    originStoreId: originId,
    waypointStoreId: waypointId,
    totalDistance: distance,
    totalTime: distance / 1000 * 120,
    fromFallback: true,
  );
}
```

### 5.4 `lib/combo/combo_checkout_screen.dart`

New checkout screen for 2 stores: route → invoice → wallet/cash → pay → create → success.

```dart
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/combo/combo_route.dart';
import 'package:zmall/combo/models/combo_cart.dart';
import 'package:zmall/combo/services/combo_service.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/report/report_screen.dart';
import 'package:zmall/services/core_services.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/linear_loading_indicator.dart';
import 'package:zmall/widgets/order_status_row.dart';

/// Checkout for a two-store order: route -> invoice -> pay -> create.
///
/// Only cash and wallet are offered; the combo endpoints don't support
/// external gateways yet.
class ComboCheckoutScreen extends StatefulWidget {
  const ComboCheckoutScreen({super.key});

  @override
  State<ComboCheckoutScreen> createState() => _ComboCheckoutScreenState();
}

class _ComboCheckoutScreenState extends State<ComboCheckoutScreen> {
  var userData;
  Cart? cart;
  ComboCart? combo;
  ComboRoute? route;
  Map<String, dynamic>? invoice;

  /// Invoice side (order_payment, store, vehicles) by store_id.
  final Map<String, Map<String, dynamic>> _sideByStore = {};

  bool _loading = true;
  bool _placing = false;
  bool _paid = false;
  bool _useWallet = false;
  double walletBalance = 0;
  String? _invoiceError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    userData = await Service.read('user');
    final cartData = await Service.read('cart');
    combo = await ComboCart.load();
    if (!mounted) return;
    if (userData == null || cartData == null || combo == null) {
      Service.showMessage(
        context: context,
        title: "Your cart has changed. Please try again.",
        error: true,
      );
      Navigator.of(context).pop();
      return;
    }
    cart = Cart.fromJson(cartData);
    walletBalance = double.tryParse('${userData['user']['wallet']}') ?? 0;
    _refreshWallet();
    await _getInvoice();
  }

  Future<void> _refreshWallet() async {
    final data = await ComboService.getUserDetail(context, userData: userData);
    if (!mounted || data == null || data['success'] != true) return;
    setState(() {
      userData = data;
      walletBalance = double.tryParse('${data['user']['wallet']}') ?? 0;
    });
    Service.save('user', data);
  }

  Future<void> _getInvoice() async {
    setState(() {
      _loading = true;
      _invoiceError = null;
    });

    final destination = cart!.destinationAddress!;
    final first = cart!.storeLocation!;
    final second = combo!.second.storeLocation!;
    route = await computeComboRoute(
      storeIdX: cart!.storeId!,
      xLat: first.lat!,
      xLng: first.long!,
      storeIdY: combo!.second.storeId!,
      yLat: second.lat!,
      yLng: second.long!,
      custLat: destination.lat!,
      custLng: destination.long!,
      apiKey: apiKey,
    );
    if (!mounted) return;

    final data = await ComboService.getInvoice(
      context,
      userData: userData,
      combo: combo!,
      route: route!,
    );
    if (!mounted) return;

    if (data != null && data['success'] == true) {
      _sideByStore.clear();
      combo!.orderPaymentIdByStore.clear();
      for (final side in ['store_a', 'store_b']) {
        final sideData = Map<String, dynamic>.from(data[side]);
        final payment = sideData['order_payment'];
        final storeId = '${payment['store_id']}';
        _sideByStore[storeId] = sideData;
        combo!.orderPaymentIdByStore[storeId] = '${payment['_id']}';
      }
      combo!.originStoreId = route!.originStoreId;
      await combo!.save();
      if (!mounted) return;
      setState(() {
        invoice = data;
        _paid = false;
        if (_cashNotAccepted) _useWallet = true;
        _loading = false;
      });
    } else if (ComboService.isSessionExpired(data)) {
      await _logout();
    } else {
      setState(() {
        invoice = null;
        _invoiceError = ComboService.errorText(data);
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    Service.showMessage(
      context: context,
      title: "${errorCodes['999']}!",
      error: true,
    );
    await CoreServices.clearCache();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  }

  List<String> get _pickupOrder => [
    route!.originStoreId,
    route!.waypointStoreId,
  ];

  double get _total =>
      (invoice?['combined_user_pay_payment'] as num?)?.toDouble() ?? 0;

  bool get _cashNotAccepted => _sideByStore.values.any(
    (side) => side['store']?['accept_only_cashless_payment'] == true,
  );

  Future<void> _placeOrder() async {
    if (_placing || invoice == null) return;
    if (_useWallet && walletBalance < _total) {
      Service.showMessage(
        context: context,
        title:
            "Not enough wallet balance. Pay with cash or top up your wallet.",
        error: true,
        duration: 4,
      );
      return;
    }
    if (!_useWallet && _cashNotAccepted) {
      Service.showMessage(
        context: context,
        title: "One of the stores accepts only digital payment.",
        error: true,
        duration: 4,
      );
      return;
    }

    setState(() {
      _placing = true;
    });
    try {
      if (!_paid && !await _pay()) return;
      await _createOrder();
    } finally {
      if (mounted) {
        setState(() {
          _placing = false;
        });
      }
    }
  }

  Future<bool> _pay() async {
    final walletData = await ComboService.setWalletUse(
      context,
      userData: userData,
      useWallet: _useWallet,
    );
    if (!mounted) return false;
    if (walletData == null || walletData['success'] != true) {
      if (ComboService.isSessionExpired(walletData)) {
        await _logout();
      } else {
        Service.showMessage(
          context: context,
          title: ComboService.errorText(walletData),
          error: true,
        );
      }
      return false;
    }

    final origin = route!.originStoreId, waypoint = route!.waypointStoreId;
    final data = await ComboService.pay(
      context,
      userData: userData,
      originPaymentId: combo!.orderPaymentIdByStore[origin]!,
      waypointPaymentId: combo!.orderPaymentIdByStore[waypoint]!,
    );
    if (!mounted) return false;
    if (data != null && data['success'] == true) {
      _paid = true;
      return true;
    }
    if (ComboService.isSessionExpired(data)) {
      await _logout();
      return false;
    }
    final error = ComboService.errorText(data);
    Service.showMessage(
      context: context,
      title: error,
      error: true,
      duration: 4,
    );
    if (error.toLowerCase().contains("order_payment not found")) {
      _getInvoice();
    }
    return false;
  }

  Future<void> _createOrder() async {
    final origin = route!.originStoreId, waypoint = route!.waypointStoreId;
    final data = await ComboService.createOrder(
      context,
      userData: userData,
      comboId: combo!.comboId!,
      originCartId: combo!.cartIdByStore[origin]!,
      waypointCartId: combo!.cartIdByStore[waypoint]!,
    );
    if (!mounted) return;

    if (data != null && data['success'] == true) {
      final orderIds = List.from(data['order_unique_ids'] ?? []);
      await Service.remove('cart');
      await Service.remove('aliexpressCart');
      await ComboCart.clear();
      if (!mounted) return;
      Service.showMessage(
        context: context,
        title: orderIds.isNotEmpty
            ? "Orders #${orderIds.join(' and #')} created"
            : "Order successfully created",
        error: false,
        duration: 3,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReportScreen(
            price: _total,
            orderPaymentUniqueId: orderIds.join(','),
          ),
        ),
      );
      return;
    }

    // Payment went through; keep the combo so the user can retry create.
    if (ComboService.isSessionExpired(data)) {
      await _logout();
      return;
    }
    Service.showMessage(
      context: context,
      title:
          "${ComboService.errorText(data, fallback: 'Failed to create the order.')} "
          "Your payment was received. Tap Place Order to retry, or call 8707 for help.",
      error: true,
      duration: 6,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<ZLanguage>(context);
    final currency = Provider.of<ZMetaData>(context, listen: false).currency;

    return PopScope(
      canPop: !_placing && !_paid,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _paid) {
          Service.showMessage(
            context: context,
            title: "Payment received. Tap Place Order to finish your order.",
            error: true,
            duration: 4,
          );
        }
      },
      child: Scaffold(
        backgroundColor: kPrimaryColor,
        appBar: AppBar(
          title: Text(lang.checkout, style: TextStyle(color: kBlackColor)),
        ),
        bottomNavigationBar: invoice == null
            ? null
            : SafeArea(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: getProportionateScreenHeight(kDefaultPadding / 4),
                    horizontal: getProportionateScreenHeight(kDefaultPadding),
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    border: Border(top: BorderSide(color: kWhiteColor)),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(kDefaultPadding),
                      topRight: Radius.circular(kDefaultPadding),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: getProportionateScreenHeight(kDefaultPadding / 2),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("${lang.total} :"),
                          SizedBox(width: kDefaultPadding / 2),
                          Text(
                            "$currency ${_total.toStringAsFixed(2)}",
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      CustomButton(
                        isLoading: _placing,
                        title: lang.placeOrder,
                        press: _placeOrder,
                        color: kSecondaryColor,
                      ),
                    ],
                  ),
                ),
              ),
        body: ModalProgressHUD(
          inAsyncCall: _loading,
          color: kPrimaryColor,
          progressIndicator: LinearLoadingIndicator(
            title: "Calculating your order...",
          ),
          child: _invoiceError != null
              ? _errorView()
              : invoice == null
              ? SizedBox.shrink()
              : ListView(
                  padding: EdgeInsets.all(
                    getProportionateScreenWidth(kDefaultPadding),
                  ),
                  children: [
                    _card(
                      child: OrderStatusRow(
                        title: "Deliver to · 2 stores, 1 driver",
                        icon: HeroiconsOutline.mapPin,
                        iconBackgroundColor: kPrimaryColor,
                        value:
                            cart!.destinationAddress?.name ??
                            "Current location",
                      ),
                    ),
                    for (int i = 0; i < _pickupOrder.length; i++)
                      _storeCard(i + 1, _pickupOrder[i], currency),
                    _summaryCard(currency),
                    _paymentCard(currency),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: kDefaultPadding,
        children: [
          Icon(Icons.error_outline, color: kSecondaryColor, size: 48),
          Text(_invoiceError!, textAlign: TextAlign.center),
          CustomButton(
            title: "Try again",
            press: _getInvoice,
            color: kSecondaryColor,
          ),
        ],
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(bottom: getProportionateScreenHeight(12)),
    padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding * .75)),
    decoration: BoxDecoration(
      color: kWhiteColor,
      borderRadius: BorderRadius.circular(kDefaultPadding),
    ),
    child: child,
  );

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: kBlackColor,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          SizedBox(width: kDefaultPadding / 2),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _storeCard(int pickup, String storeId, String? currency) {
    final side = _sideByStore[storeId] ?? {};
    final payment = side['order_payment'] ?? {};
    final storeName = side['store']?['name'] ?? "Store $pickup";
    final items = storeId == cart!.storeId
        ? cart!.items ?? []
        : combo!.second.items ?? [];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderStatusRow(
            title: "Pickup $pickup",
            icon: HeroiconsOutline.buildingStorefront,
            iconBackgroundColor: kPrimaryColor,
            value: Service.capitalizeFirstLetters(storeName),
          ),
          Divider(color: kPrimaryColor),
          for (final item in items)
            _row(
              "${item.quantity} × ${Service.capitalizeFirstLetters(item.itemName ?? '')}",
              "$currency ${(item.price ?? 0).toStringAsFixed(2)}",
            ),
          Divider(color: kPrimaryColor),
          _row(
            "Items",
            "$currency ${_money(payment['total_cart_price'])}",
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String? currency) {
    final itemsTotal = _sideByStore.values.fold<double>(
      0,
      (sum, side) =>
          sum + ((side['order_payment']?['total_cart_price'] as num?) ?? 0),
    );
    return _card(
      child: Column(
        children: [
          _row(
            "Items (2 stores)",
            "$currency ${itemsTotal.toStringAsFixed(2)}",
          ),
          _row(
            "Delivery",
            "$currency ${_money(invoice!['combined_delivery_price'])}",
          ),
          Divider(color: kPrimaryColor),
          _row(
            Provider.of<ZLanguage>(context, listen: false).total,
            "$currency ${_total.toStringAsFixed(2)}",
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(String? currency) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment method",
            style: TextStyle(fontWeight: FontWeight.bold, color: kBlackColor),
          ),
          _paymentOption(
            selected: !_useWallet,
            title: "Cash on delivery",
            subtitle: _cashNotAccepted
                ? "Not accepted by one of the stores"
                : null,
            onTap: _cashNotAccepted || _paid
                ? null
                : () => setState(() => _useWallet = false),
          ),
          _paymentOption(
            selected: _useWallet,
            title: "Wallet",
            subtitle: "Balance: $currency ${walletBalance.toStringAsFixed(2)}",
            onTap: _paid ? null : () => setState(() => _useWallet = true),
          ),
          Text(
            "Other payment methods are not available yet for orders from 2 stores.",
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: kGreyColor),
          ),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required bool selected,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    enabled: onTap != null,
    onTap: onTap,
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: onTap == null && !selected ? kGreyColor : kSecondaryColor,
    ),
    title: Text(title),
    subtitle: subtitle != null ? Text(subtitle) : null,
  );

  String _money(dynamic value) =>
      ((value as num?) ?? 0).toDouble().toStringAsFixed(2);
}
```

### 5.5 `lib/combo/widgets/store_conflict_dialog.dart`

Shared "different store" dialog with **Cancel / Clear / Order from both stores**.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/utils/constants.dart';

/// Shown when an item comes from a store other than the one in the cart.
///
/// [allowCombo] adds "Order from both stores". [comboFull] means two stores
/// are already in the cart, so only clearing is possible.
/// The dialog closes itself before calling [onClear] / [onCombo].
Future<void> showStoreConflictDialog({
  required BuildContext context,
  required bool allowCombo,
  required bool comboFull,
  required VoidCallback onClear,
  required VoidCallback onCombo,
}) {
  final lang = Provider.of<ZLanguage>(context, listen: false);
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: kPrimaryColor,
      title: Text(lang.warning),
      content: Text(
        comboFull
            ? lang.comboStoreLimit
            : allowCombo
            ? lang.comboItemsFound
            : lang.itemsFound,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: kDefaultPadding / 4,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            lang.cancel,
            style: TextStyle(color: kBlackColor, fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onClear();
          },
          child: Text(
            lang.clear,
            style: TextStyle(
              color: allowCombo ? kGreyColor : kSecondaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (allowCombo)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onCombo();
            },
            child: Text(
              lang.orderFromBothStores,
              style: TextStyle(
                color: kSecondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    ),
  );
}
```

### 5.6 `lib/combo/widgets/combo_store_section.dart`

Cart section for the second store: items, +/− quantity, remove, subtotal, "Add more?".

```dart
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zmall/combo/models/combo_cart.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/notifications/notification_store.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/store/components/image_container.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/order_status_row.dart';

/// Cart section for the second store of a combo order.
///
/// Edits [comboCart] in place, then calls [onChanged] so the parent can save
/// it and update totals.
class ComboStoreSection extends StatelessWidget {
  const ComboStoreSection({
    super.key,
    required this.comboCart,
    required this.storeName,
    required this.onChanged,
    this.onReturnFromStore,
  });

  final ComboCart comboCart;
  final String storeName;
  final VoidCallback onChanged;
  final VoidCallback? onReturnFromStore;

  @override
  Widget build(BuildContext context) {
    final items = comboCart.second.items ?? [];
    final currency = Provider.of<ZMetaData>(context, listen: false).currency;
    final subtotal = items.fold<double>(0, (sum, i) => sum + (i.price ?? 0));

    return Padding(
      padding: EdgeInsets.only(
        top: getProportionateScreenHeight(kDefaultPadding / 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: getProportionateScreenHeight(kDefaultPadding / 3),
        children: [
          Container(
            padding: EdgeInsets.all(
              getProportionateScreenWidth(kDefaultPadding / 2),
            ),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(kDefaultPadding),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OrderStatusRow(
                    title: "Second store · same delivery",
                    iconBackgroundColor: kPrimaryColor,
                    icon: HeroiconsOutline.buildingStorefront,
                    fontSize: getProportionateScreenHeight(14),
                    value: storeName.isNotEmpty
                        ? Service.capitalizeFirstLetters(storeName)
                        : "Store 2",
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        kDefaultPadding / 1.5,
                      ),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationStore(
                          storeId: comboCart.second.storeId!,
                        ),
                      ),
                    ).then((_) => onReturnFromStore?.call());
                  },
                  child: Text(
                    "Add more?",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          for (int index = 0; index < items.length; index++)
            _itemRow(context, index, currency),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(kDefaultPadding / 2),
              ),
              child: Text(
                "Subtotal: $currency ${subtotal.toStringAsFixed(2)}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kGreyColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, int index, String? currency) {
    final item = comboCart.second.items![index];
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding / 2),
        vertical: getProportionateScreenHeight(kDefaultPadding / 4),
      ),
      decoration: BoxDecoration(
        color: kPrimaryColor,
        border: Border.all(color: kWhiteColor, width: 2),
        borderRadius: BorderRadius.circular(kDefaultPadding),
      ),
      child: Row(
        children: [
          ImageContainer(url: item.imageURL),
          SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 2)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: getProportionateScreenHeight(kDefaultPadding / 5),
              children: [
                Text(
                  Service.capitalizeFirstLetters(item.itemName ?? ""),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                  softWrap: true,
                ),
                Text(
                  "$currency ${(item.price ?? 0).toStringAsFixed(2)}",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: kGreyColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.noteForItem.isNotEmpty) Text(item.noteForItem),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: item.quantity != 1 ? kSecondaryColor : kGreyColor,
                    ),
                    onPressed: () {
                      if (item.quantity == 1) {
                        Service.showMessage(
                          context: context,
                          title: "Minimum order quantity is 1!",
                          error: true,
                        );
                        return;
                      }
                      _setQuantity(index, item.quantity! - 1);
                    },
                  ),
                  Text(
                    "${item.quantity}",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: kBlackColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: kSecondaryColor),
                    onPressed: () => _setQuantity(index, item.quantity! + 1),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  comboCart.second.items!.removeAt(index);
                  onChanged();
                },
                child: Text(
                  Provider.of<ZLanguage>(context).remove,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 12,
                    color: kSecondaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setQuantity(int index, int quantity) {
    final item = comboCart.second.items![index];
    final unitPrice = item.price! / item.quantity!;
    item.quantity = quantity;
    item.price = unitPrice * quantity;
    onChanged();
  }
}
```

## 6. Changed files (diffs)

Unified diff against `HEAD`: lines starting with `+` were added and lines starting with `-` were removed.

### 6.1 `lib/item/components/body.dart`

Item screen. A different-store item now goes through `_handleOtherStore`: it merges into the combo's second store, or shows the new dialog. Clear also removes `combo_cart`.

```diff
diff --git a/lib/item/components/body.dart b/lib/item/components/body.dart
index a3a1011..8324d76 100644
--- a/lib/item/components/body.dart
+++ b/lib/item/components/body.dart
@@ -2,6 +2,8 @@ import 'package:cached_network_image/cached_network_image.dart';
 import 'package:flutter/material.dart';
 import 'package:provider/provider.dart';
 import 'package:zmall/utils/constants.dart';
+import 'package:zmall/combo/models/combo_cart.dart';
+import 'package:zmall/combo/widgets/store_conflict_dialog.dart';
 import 'package:zmall/custom_widgets/custom_button.dart';
 import 'package:zmall/item/components/photo_viewer.dart';
 import 'package:zmall/login/login_screen.dart';
@@ -336,7 +338,11 @@ class _BodyState extends State<Body> {
                                   Navigator.of(context).pop();
                                 });
                               } else {
-                                _showDialog(item, destination, storeLocation);
+                                _handleOtherStore(
+                                  item,
+                                  destination,
+                                  storeLocation,
+                                );
                               }
                             } else {
                               Service.showMessage(
@@ -935,43 +941,70 @@ class _BodyState extends State<Body> {
     );
   }
 
-  void _showDialog(item, destination, storeLocation) {
-    showDialog(
+  /// Item is from a store other than the cart's: merge into the combo's
+  /// second store, or ask whether to clear or order from both stores.
+  Future<void> _handleOtherStore(
+    Item item,
+    DestinationAddress destination,
+    StoreLocation storeLocation,
+  ) async {
+    if (await ComboCart.addToSecondStoreIfMatches(
+      widget.item['store_id'],
+      item,
+    )) {
+      if (!mounted) return;
+      Navigator.of(context).pop();
+      return;
+    }
+    final comboFull = await ComboCart.load() != null;
+    final allowCombo = await ComboCart.canStartWith(cart);
+    if (!mounted) return;
+    _showDialog(
+      item,
+      destination,
+      storeLocation,
+      allowCombo: allowCombo,
+      comboFull: comboFull,
+    );
+  }
+
+  void _showDialog(
+    item,
+    destination,
+    storeLocation, {
+    bool allowCombo = false,
+    bool comboFull = false,
+  }) {
+    showStoreConflictDialog(
       context: context,
-      builder: (_) => AlertDialog(
-        backgroundColor: kPrimaryColor,
-        title: Text(Provider.of<ZLanguage>(context).warning),
-        content: Text(Provider.of<ZLanguage>(context).itemsFound),
-        actions: [
-          TextButton(
-            onPressed: () => Navigator.pop(context),
-            child: Text(
-              Provider.of<ZLanguage>(context).cancel,
-              style: TextStyle(color: kBlackColor, fontWeight: FontWeight.bold),
-            ),
-          ),
-          TextButton(
-            onPressed: () {
-              setState(() {
-                Service.remove('cart');
-                Service.remove('aliexpressCart');
-                cart = Cart();
-                addToCart(item, destination, storeLocation);
-              });
-              Navigator.of(context)
-                ..pop()
-                ..pop();
-            },
-            child: Text(
-              Provider.of<ZLanguage>(context).clear,
-              style: TextStyle(
-                color: kSecondaryColor,
-                fontWeight: FontWeight.bold,
-              ),
-            ),
-          ),
-        ],
-      ),
+      allowCombo: allowCombo,
+      comboFull: comboFull,
+      onClear: () {
+        setState(() {
+          Service.remove('cart');
+          Service.remove('aliexpressCart');
+          ComboCart.clear();
+          cart = Cart();
+          addToCart(item, destination, storeLocation);
+        });
+        Navigator.of(context).pop();
+      },
+      onCombo: () async {
+        await ComboCart.start(
+          userData: userData,
+          storeId: widget.item['store_id'],
+          item: item,
+          storeLocation: storeLocation,
+          destination: destination,
+        );
+        if (!mounted) return;
+        Service.showMessage(
+          context: context,
+          title: Provider.of<ZLanguage>(context, listen: false).comboAdded,
+          error: false,
+        );
+        Navigator.of(context).pop();
+      },
     );
   }
 }
```

### 6.2 `lib/product/product_screen.dart`

Store product list. Same change as the item screen. Shows a message instead of closing the screen.

```diff
diff --git a/lib/product/product_screen.dart b/lib/product/product_screen.dart
index 90eb7be..c5fa30b 100644
--- a/lib/product/product_screen.dart
+++ b/lib/product/product_screen.dart
@@ -12,6 +12,8 @@ import 'package:zmall/custom_widgets/custom_button.dart';
 import 'package:zmall/item/item_screen.dart';
 import 'package:zmall/login/login_screen.dart';
 import 'package:zmall/models/cart.dart';
+import 'package:zmall/combo/models/combo_cart.dart';
+import 'package:zmall/combo/widgets/store_conflict_dialog.dart';
 import 'package:zmall/models/language.dart';
 import 'package:zmall/models/metadata.dart';
 import 'package:zmall/services/service.dart';
@@ -594,7 +596,12 @@ class _ProductScreenState extends State<ProductScreen> {
             error: false,
           );
         } else {
-          _showDialog(cartItem, destination, storeLocation, item['store_id']);
+          _handleOtherStore(
+            cartItem,
+            destination,
+            storeLocation,
+            item['store_id'],
+          );
         }
       } else {
         Service.showMessage(
@@ -1225,50 +1232,70 @@ class _ProductScreenState extends State<ProductScreen> {
     }
   }
 
-  void _showDialog(item, destination, storeLocation, storeId) {
-    showDialog(
+  /// Item is from a store other than the cart's: merge into the combo's
+  /// second store, or ask whether to clear or order from both stores.
+  Future<void> _handleOtherStore(
+    Item item,
+    DestinationAddress destination,
+    StoreLocation storeLocation,
+    String storeId,
+  ) async {
+    if (await ComboCart.addToSecondStoreIfMatches(storeId, item)) {
+      if (!mounted) return;
+      Service.showMessage(
+        context: context,
+        title: "Item added to cart",
+        error: false,
+      );
+      return;
+    }
+    final comboFull = await ComboCart.load() != null;
+    final allowCombo = await ComboCart.canStartWith(cart);
+    if (!mounted) return;
+    _showDialog(
+      item,
+      destination,
+      storeLocation,
+      storeId,
+      allowCombo: allowCombo,
+      comboFull: comboFull,
+    );
+  }
+
+  void _showDialog(
+    item,
+    destination,
+    storeLocation,
+    storeId, {
+    bool allowCombo = false,
+    bool comboFull = false,
+  }) {
+    showStoreConflictDialog(
       context: context,
-      builder: (BuildContext alertContext) {
-        return AlertDialog(
-          backgroundColor: kPrimaryColor,
-          title: Text(Provider.of<ZLanguage>(context).warning),
-          content: Text(Provider.of<ZLanguage>(context).itemsFound),
-          actions: [
-            TextButton(
-              child: Text(
-                Provider.of<ZLanguage>(context).cancel,
-                style: TextStyle(
-                  color: kBlackColor,
-                  fontWeight: FontWeight.bold,
-                ),
-              ),
-              onPressed: () {
-                Navigator.of(alertContext).pop();
-              },
-            ),
-            TextButton(
-              child: Text(
-                Provider.of<ZLanguage>(context).clear,
-                style: TextStyle(
-                  color: kSecondaryColor,
-                  fontWeight: FontWeight.bold,
-                ),
-              ),
-              onPressed: () {
-                setState(() {
-                  cart!.toJson();
-                  Service.remove('cart');
-                  Service.remove('aliexpressCart');
-                  cart = Cart();
-                  addToCart(item, destination, storeLocation, storeId);
-                });
-
-                Navigator.of(alertContext).pop();
-                // Future.delayed(Duration(seconds: 2));
-                // Navigator.of(context).pop();
-              },
-            ),
-          ],
+      allowCombo: allowCombo,
+      comboFull: comboFull,
+      onClear: () {
+        setState(() {
+          Service.remove('cart');
+          Service.remove('aliexpressCart');
+          ComboCart.clear();
+          cart = Cart();
+          addToCart(item, destination, storeLocation, storeId);
+        });
+      },
+      onCombo: () async {
+        await ComboCart.start(
+          userData: userData,
+          storeId: storeId,
+          item: item,
+          storeLocation: storeLocation,
+          destination: destination,
+        );
+        if (!mounted) return;
+        Service.showMessage(
+          context: context,
+          title: Provider.of<ZLanguage>(context, listen: false).comboAdded,
+          error: false,
         );
       },
     );
```

### 6.3 `lib/notifications/notification_store.dart`

Store screen opened from a notification or "Add more?". Same change, plus a `language.dart` import.

```diff
diff --git a/lib/notifications/notification_store.dart b/lib/notifications/notification_store.dart
index 31363ba..fb30041 100644
--- a/lib/notifications/notification_store.dart
+++ b/lib/notifications/notification_store.dart
@@ -10,6 +10,9 @@ import 'package:zmall/custom_widgets/custom_button.dart';
 import 'package:zmall/item/item_screen.dart';
 import 'package:zmall/login/login_screen.dart';
 import 'package:zmall/models/cart.dart';
+import 'package:zmall/combo/models/combo_cart.dart';
+import 'package:zmall/combo/widgets/store_conflict_dialog.dart';
+import 'package:zmall/models/language.dart';
 import 'package:zmall/models/metadata.dart';
 import 'package:zmall/services/service.dart';
 import 'package:zmall/utils/pagination_controller.dart';
@@ -347,7 +350,7 @@ class _NotificationStoreState extends State<NotificationStore> {
                                     error: false,
                                   );
                                 } else {
-                                  _showDialog(
+                                  _handleOtherStore(
                                     cartItem,
                                     destination,
                                     storeLocation,
@@ -521,52 +524,70 @@ class _NotificationStoreState extends State<NotificationStore> {
     }
   }
 
-  void _showDialog(item, destination, storeLocation, storeId) {
-    showDialog(
+  /// Item is from a store other than the cart's: merge into the combo's
+  /// second store, or ask whether to clear or order from both stores.
+  Future<void> _handleOtherStore(
+    Item item,
+    DestinationAddress destination,
+    StoreLocation storeLocation,
+    String storeId,
+  ) async {
+    if (await ComboCart.addToSecondStoreIfMatches(storeId, item)) {
+      if (!mounted) return;
+      Service.showMessage(
+        context: context,
+        title: "Item added to cart",
+        error: false,
+      );
+      return;
+    }
+    final comboFull = await ComboCart.load() != null;
+    final allowCombo = await ComboCart.canStartWith(cart);
+    if (!mounted) return;
+    _showDialog(
+      item,
+      destination,
+      storeLocation,
+      storeId,
+      allowCombo: allowCombo,
+      comboFull: comboFull,
+    );
+  }
+
+  void _showDialog(
+    item,
+    destination,
+    storeLocation,
+    storeId, {
+    bool allowCombo = false,
+    bool comboFull = false,
+  }) {
+    showStoreConflictDialog(
       context: context,
-      builder: (BuildContext alertContext) {
-        return AlertDialog(
-          backgroundColor: kPrimaryColor,
-          title: Text("Warning"),
-          content: Text(
-            "Item(s) from a different store found in cart! Would you like to clear your cart?",
-          ),
-          actions: [
-            TextButton(
-              child: Text(
-                "Cancel",
-                style: TextStyle(
-                  color: kBlackColor,
-                  fontWeight: FontWeight.bold,
-                ),
-              ),
-              onPressed: () {
-                Navigator.of(alertContext).pop();
-              },
-            ),
-            TextButton(
-              child: Text(
-                "Clear",
-                style: TextStyle(
-                  color: kSecondaryColor,
-                  fontWeight: FontWeight.bold,
-                ),
-              ),
-              onPressed: () {
-                setState(() {
-                  cart!.toJson();
-                  Service.remove('cart');
-                  Service.remove('aliexpressCart');
-                  cart = Cart();
-                  addToCart(item, destination, storeLocation, storeId);
-                });
-
-                Navigator.of(alertContext).pop();
-                // Future.delayed(Duration(seconds: 2));
-                // Navigator.of(context).pop();
-              },
-            ),
-          ],
+      allowCombo: allowCombo,
+      comboFull: comboFull,
+      onClear: () {
+        setState(() {
+          Service.remove('cart');
+          Service.remove('aliexpressCart');
+          ComboCart.clear();
+          cart = Cart();
+          addToCart(item, destination, storeLocation, storeId);
+        });
+      },
+      onCombo: () async {
+        await ComboCart.start(
+          userData: userData,
+          storeId: storeId,
+          item: item,
+          storeLocation: storeLocation,
+          destination: destination,
+        );
+        if (!mounted) return;
+        Service.showMessage(
+          context: context,
+          title: Provider.of<ZLanguage>(context, listen: false).comboAdded,
+          error: false,
         );
       },
     );
```

### 6.4 `lib/cart/components/body.dart`

Cart screen. Loads `combo_cart`, shows `ComboStoreSection` as the last list row and includes store 2 in the total. If store 1 is emptied, store 2 becomes the normal cart. Clear also removes the combo.

```diff
diff --git a/lib/cart/components/body.dart b/lib/cart/components/body.dart
index a096ee8..68be359 100644
--- a/lib/cart/components/body.dart
+++ b/lib/cart/components/body.dart
@@ -17,6 +17,9 @@ import 'package:zmall/custom_widgets/custom_button.dart';
 import 'package:zmall/delivery/delivery_screen.dart';
 import 'package:zmall/lunch_home/lunch_home_screen.dart';
 import 'package:zmall/models/cart.dart';
+import 'package:zmall/combo/models/combo_cart.dart';
+import 'package:zmall/combo/services/combo_service.dart';
+import 'package:zmall/combo/widgets/combo_store_section.dart';
 import 'package:zmall/models/language.dart';
 import 'package:zmall/models/metadata.dart';
 import 'package:zmall/notifications/notification_store.dart';
@@ -36,6 +39,8 @@ class _BodyState extends State<Body> with TickerProviderStateMixin {
   bool isLocationServicesEnabled = false;
   Cart? cart;
   AliExpressCart? aliexpressCart;
+  ComboCart? comboCart;
+  String comboStoreName = '';
   bool _loading = true;
   double price = 0;
   var appClose;
@@ -72,11 +77,70 @@ class _BodyState extends State<Body> with TickerProviderStateMixin {
     cart?.items?.forEach((item) {
       tempPrice += item.price!;
     });
+    comboCart?.second.items?.forEach((item) {
+      tempPrice += item.price!;
+    });
     setState(() {
       price = tempPrice;
     });
   }
 
+  Future<void> _loadComboCart() async {
+    final combo = await ComboCart.load();
+    if (!mounted) return;
+    setState(() {
+      comboCart = combo;
+    });
+    if (combo != null && comboStoreName.isEmpty) {
+      final data = await ComboService.getStoreDetail(
+        context,
+        storeId: combo.second.storeId!,
+      );
+      if (!mounted) return;
+      if (data != null && data['success'] == true) {
+        setState(() {
+          comboStoreName = data['store']['name'] ?? '';
+        });
+      }
+    }
+  }
+
+  void _onComboChanged() {
+    if (comboCart == null) return;
+    if (comboCart!.second.items!.isEmpty) {
+      ComboCart.clear();
+      setState(() {
+        comboCart = null;
+        comboStoreName = '';
+      });
+    } else {
+      comboCart!.save();
+      setState(() {});
+    }
+    calculatePrice();
+  }
+
+  /// When the first store is emptied, the second store becomes the normal
+  /// single-store cart.
+  void _promoteComboIfFirstEmpty() {
+    if (comboCart == null || cart == null || cart!.items!.isNotEmpty) return;
+    final second = comboCart!.second;
+    second.serverToken = cart!.serverToken;
+    setState(() {
+      cart = second;
+      storeID = second.storeId;
+      storeName = comboStoreName;
+      extraItems = null;
+      comboCart = null;
+      comboStoreName = '';
+    });
+    Service.save('cart', cart!.toJson());
+    ComboCart.clear();
+    _getStoreExtraItemList();
+    _getStoreDetail();
+    calculatePrice();
+  }
+
   void getCart() async {
     setState(() {
       _loading = true;
@@ -106,6 +170,7 @@ class _BodyState extends State<Body> with TickerProviderStateMixin {
         //   debugPrint("ALI CART NOT FOUND>>>");
         // }
         _getStoreExtraItemList();
+        await _loadComboCart();
 
         calculatePrice();
         if (cart != null && cart!.items!.isNotEmpty) {
@@ -596,7 +661,8 @@ class _BodyState extends State<Body> with TickerProviderStateMixin {
                   Expanded(
                     child: ListView.separated(
                       shrinkWrap: true,
-                      itemCount: cart!.toJson()['items'].length ?? 0,
+                      itemCount:
+                          cart!.items!.length + (comboCart != null ? 1 : 0),
                       padding: EdgeInsets.only(
                         left: getProportionateScreenWidth(kDefaultPadding / 2),
                         right: getProportionateScreenWidth(kDefaultPadding / 2),
@@ -609,6 +675,14 @@ class _BodyState extends State<Body> with TickerProviderStateMixin {
                             ),
                           ),
                       itemBuilder: (context, index) {
+                        if (index == cart!.items!.length) {
+                          return ComboStoreSection(
+                            comboCart: comboCart!,
+                            storeName: comboStoreName,
+                            onChanged: _onComboChanged,
+                            onReturnFromStore: getCart,
+                          );
+                        }
                         final item = cart!.items?[index];
                         final isLunchBox =
                             item?.itemName?.contains('ምሳቃ') ?? false;
@@ -854,6 +928,7 @@ class _BodyState extends State<Body> with TickerProviderStateMixin {
                                                 }
                                               });
                                               calculatePrice();
+                                              _promoteComboIfFirstEmpty();
                                             },
                                             child: Text(
                                               Provider.of<ZLanguage>(
@@ -1267,6 +1342,7 @@ class _BodyState extends State<Body> with TickerProviderStateMixin {
                   cart!.toJson();
                   Service.remove('cart');
                   Service.remove('aliexpressCart'); ////NEW
+                  ComboCart.clear();
                   cart = Cart();
                   addToCart(item, destination, storeLocation, storeId);
                 });
```

### 6.5 `lib/delivery/delivery_screen.dart`

Delivery screen. If a combo exists, `_addToCart` calls `_addToComboCart`: it blocks self-pickup, calls `combo_add_item_in_cart`, saves `combo_id` and the cart ids by `store_id`, then opens `ComboCheckoutScreen`.

```diff
diff --git a/lib/delivery/delivery_screen.dart b/lib/delivery/delivery_screen.dart
index 91c9836..ccb9dd92 100644
--- a/lib/delivery/delivery_screen.dart
+++ b/lib/delivery/delivery_screen.dart
@@ -9,6 +9,9 @@ import 'package:flutter/material.dart';
 import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
 import 'package:provider/provider.dart';
 import 'package:zmall/checkout/checkout_screen.dart';
+import 'package:zmall/combo/combo_checkout_screen.dart';
+import 'package:zmall/combo/models/combo_cart.dart';
+import 'package:zmall/combo/services/combo_service.dart';
 import 'package:zmall/utils/constants.dart';
 import 'package:zmall/services/core_services.dart';
 import 'package:zmall/custom_widgets/custom_button.dart';
@@ -384,6 +387,12 @@ class _DeliveryScreenState extends State<DeliveryScreen> {
     setState(() {
       _loading = true;
     });
+    final combo = await ComboCart.load();
+    if (!mounted) return;
+    if (combo != null) {
+      await _addToComboCart(combo);
+      return;
+    }
     var data = await addToCart();
     if (!mounted) return;
     if (data != null && data['success']) {
@@ -425,6 +434,83 @@ class _DeliveryScreenState extends State<DeliveryScreen> {
     }
   }
 
+  /// Combo order: sends both stores in one call, then opens combo checkout.
+  Future<void> _addToComboCart(ComboCart combo) async {
+    if (selfPickup) {
+      setState(() {
+        _loading = false;
+      });
+      Service.showMessage(
+        context: context,
+        title: "Self pickup is not available when ordering from 2 stores.",
+        error: true,
+        duration: 4,
+      );
+      return;
+    }
+    final data = await ComboService.addItemInCart(
+      context,
+      userData: userData,
+      first: cart!,
+      combo: combo,
+      destination: cart!.destinationAddress!,
+      username: isForOthers
+          ? receiverName
+          : "${userData['user']['first_name']} ${userData['user']['last_name']}",
+      phone: isForOthers ? receiverPhone : "${userData['user']['phone']}",
+    );
+    if (!mounted) return;
+    setState(() {
+      _loading = false;
+    });
+
+    if (data != null && data['success'] == true) {
+      combo.resetServerState();
+      combo.comboId = data['combo_id'];
+      // Map by store_id: the a/b labels change at the invoice step.
+      for (final side in ['store_a', 'store_b']) {
+        final sideData = data[side];
+        if (sideData is Map &&
+            sideData['store_id'] != null &&
+            sideData['cart_id'] != null) {
+          combo.cartIdByStore['${sideData['store_id']}'] =
+              '${sideData['cart_id']}';
+        }
+      }
+      if (combo.comboId == null || combo.cartIdByStore.length != 2) {
+        Service.showMessage(
+          context: context,
+          title: "Something went wrong. Please try again.",
+          error: true,
+        );
+        return;
+      }
+      await combo.save();
+      if (!mounted) return;
+      Navigator.push(
+        context,
+        MaterialPageRoute(builder: (context) => ComboCheckoutScreen()),
+      );
+    } else if (ComboService.isSessionExpired(data)) {
+      Service.showMessage(
+        context: context,
+        title: "${errorCodes['999']}!",
+        error: true,
+      );
+      await Service.saveBool('logged', false);
+      await Service.remove('user');
+      if (!mounted) return;
+      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
+    } else {
+      Service.showMessage(
+        context: context,
+        title: ComboService.errorText(data),
+        error: true,
+        duration: 5,
+      );
+    }
+  }
+
   Widget wrapperContainer({
     required List<Widget> children,
     double? height,
@@ -1262,6 +1348,8 @@ class _DeliveryScreenState extends State<DeliveryScreen> {
     }
 
     var body = json.encode(cart!.toJson());
+    debugPrint("[COMBO-DEBUG] add_item_in_cart URL: $url");
+    debugPrint("[COMBO-DEBUG] add_item_in_cart BODY: $body");
     try {
       http.Response response = await http
           .post(
@@ -1278,6 +1366,7 @@ class _DeliveryScreenState extends State<DeliveryScreen> {
               throw TimeoutException("The connection has timed out!");
             },
           );
+      debugPrint("[COMBO-DEBUG] add_item_in_cart RESPONSE: ${response.body}");
       if (mounted)
         setState(() {
           this.responseData = json.decode(response.body);
```

### 6.6 `lib/models/language.dart`

New strings (English and Chinese): `orderFromBothStores`, `comboItemsFound`, `comboStoreLimit`, `comboAdded`.

```diff
diff --git a/lib/models/language.dart b/lib/models/language.dart
index 340c4a5..b28705d 100644
--- a/lib/models/language.dart
+++ b/lib/models/language.dart
@@ -68,6 +68,12 @@ class ZLanguage extends ChangeNotifier {
   String itemsFound =
       "Item(s) from a different store found in cart! Would you like to clear your cart?";
   String clear = "Clear";
+  String orderFromBothStores = "Order from both stores";
+  String comboItemsFound =
+      "Your cart has items from another store. Order from both stores in one delivery, or clear your cart?";
+  String comboStoreLimit =
+      "You can order from at most 2 stores at once. Clear your cart to order from this store?";
+  String comboAdded = "Added. You are ordering from 2 stores in one delivery.";
   String addToCart = "Add to cart";
   String goToCart = "Go to Cart";
 
@@ -221,6 +227,12 @@ class ZLanguage extends ChangeNotifier {
       warning = "Warning";
       itemsFound =
           "Item(s) from a different store found in cart! Would you like to clear your cart?";
+      orderFromBothStores = "Order from both stores";
+      comboItemsFound =
+          "Your cart has items from another store. Order from both stores in one delivery, or clear your cart?";
+      comboStoreLimit =
+          "You can order from at most 2 stores at once. Clear your cart to order from this store?";
+      comboAdded = "Added. You are ordering from 2 stores in one delivery.";
       addToCart = "Add to cart";
       goToCart = "Go to Cart";
 
@@ -370,6 +382,10 @@ class ZLanguage extends ChangeNotifier {
       clear = "清空";
       warning = "提醒";
       itemsFound = "车库里已经有另一家商店的品目！确认先清空购物车？";
+      orderFromBothStores = "两家店一起下单";
+      comboItemsFound = "购物车里已有另一家商店的商品。两家店一起配送，还是清空购物车？";
+      comboStoreLimit = "一次最多只能从两家店下单。清空购物车后再从这家店下单？";
+      comboAdded = "已加入。您正在从两家店下单，一次配送。";
       addToCart = "加入购物库";
       goToCart = "购物库";
```

### 6.7 `lib/services/service.dart`

Logout (`clearUserData`) also removes `combo_cart`.

```diff
diff --git a/lib/services/service.dart b/lib/services/service.dart
index 8b0a58e..5d44791 100644
--- a/lib/services/service.dart
+++ b/lib/services/service.dart
@@ -135,6 +135,7 @@ class Service {
     await Service.saveBool('logged', false);
     await Service.remove('user');
     await Service.remove('cart');
+    await Service.remove('combo_cart');
     await Service.remove('aliexpressCart'); //NEW
     await Service.remove('images');
   }
```

### 6.8 `lib/services/core_services.dart`

Cache clear also removes `combo_cart`.

```diff
diff --git a/lib/services/core_services.dart b/lib/services/core_services.dart
index c8a785b..c8c9738 100644
--- a/lib/services/core_services.dart
+++ b/lib/services/core_services.dart
@@ -514,6 +514,7 @@ class CoreServices {
     await Service.saveBool('logged', false);
     await Service.remove('user');
     await Service.remove('cart');
+    await Service.remove('combo_cart');
     await Service.remove('aliexpressCart'); //
     await Service.remove('images');
     await Service.remove('p_items');
```

### 6.9 `lib/profile/components/body.dart`

Logout and delete-account paths (3 places) also remove `combo_cart`.

```diff
diff --git a/lib/profile/components/body.dart b/lib/profile/components/body.dart
index e2ff89d..bbccc93 100644
--- a/lib/profile/components/body.dart
+++ b/lib/profile/components/body.dart
@@ -175,6 +175,7 @@ class _BodyState extends State<Body> {
       await Service.saveBool('logged', false);
       await Service.remove('user');
       await Service.remove('cart');
+      await Service.remove('combo_cart');
       await Service.remove('aliexpressCart');
 
       ///newly added for aliexpress
@@ -232,6 +233,7 @@ class _BodyState extends State<Body> {
         await Service.saveBool('logged', false);
         await Service.remove('user');
         await Service.remove('cart');
+        await Service.remove('combo_cart');
         await Service.remove('aliexpressCart'); //NEW
         await Service.remove('images');
         Navigator.pushReplacementNamed(context, LoginScreen.routeName);
@@ -336,6 +338,7 @@ class _BodyState extends State<Body> {
       await Service.saveBool('logged', false);
       await Service.remove('user');
       await Service.remove('cart');
+      await Service.remove('combo_cart');
       await Service.remove('aliexpressCart');
       await Service.remove('images');
       await Service.remove('p_items');
```

## 7. Not done yet / open questions

| # | Item | Owner |
| --- | --- | --- |
| 1 | **Not tested** on a device or against `testbackend.zmall.et`. | Mobile |
| 2 | `order_from` value for mobile (`android`/`ios` is a guess). | Backend |
| 3 | **Pay succeeds but create fails:** the screen keeps the user there to retry create. There is no backend rollback yet. | Backend + product |
| 4 | Server rejections ("different city", "too far apart", "store not found") only show the message. There is no one-tap "keep one store" yet. The user removes the items in the cart. | Mobile |
| 5 | The cart badge probably counts only store 1 items (not checked). | Mobile |
| 6 | The orders list doesn't group the 2 orders by `combo_id` yet. | Mobile |
| 7 | Not available for combo: Telebirr / Wegagen / Kifiya cards, promo codes, tips, scheduled orders, self-pickup, AliExpress, laundry. | Backend / product |
| 8 | The invoice response contains store password hashes, bank account and wallet. The backend should remove those fields. | Backend (urgent) |
| 9 | Debug logs (`[COMBO] ... BODY`) print `server_token` in debug builds only. | Mobile |

## 8. How to test

1. Log in, then add an item from **store A**.
2. Open an item from **store B** (same city) and tap Add to cart. The dialog appears. Tap **Order from both stores**.
3. Open the cart. Store A items are on top, the "Second store · same delivery" section is below, and the total includes both.
4. Tap Checkout, pick an address, then Continue. Logcat shows `[COMBO] combo_add_item_in_cart`.
5. The combo checkout loads. Check that `store_a` in the invoice body is the store **farther** from the address.
6. Choose **Cash** and tap Place Order. Two order numbers are shown, then the report screen opens.
7. Check that the cart is empty afterwards and that both orders show in the admin panel with the same `combo_id`.

Also check:
- [ ] Wallet with too little balance shows a blocked message, and nothing is charged.
- [ ] A third store shows only Clear.
- [ ] Removing all store-1 items makes store 2 the normal cart (single-store checkout).
- [ ] Removing all store-2 items removes the combo.
- [ ] Self-pickup is blocked for combo.
- [ ] A normal single-store order still works (regression).

```bash
adb logcat -v brief flutter:I '*:S' | grep COMBO
```
