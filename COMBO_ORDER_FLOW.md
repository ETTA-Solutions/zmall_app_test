# Combo Order Flow — Full Implementation & API Reference

> **Scope** — Two-store, one-driver combo orders.  
> **Phase** — Phase 1 (Cash + Wallet only; digital gateway marked "Soon").  
> All `[COMBO-DEBUG]` log lines appear in the Flutter debug console **only in debug builds** (`kDebugMode`).

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Data Models](#2-data-models)
3. [Step-by-Step Flow](#3-step-by-step-flow)
   - [Step 0 — Cart Screen](#step-0--cart-screen)
   - [Step 1 — combo_add_item_in_cart](#step-1--combo_add_item_in_cart)
   - [Step 2a — Route Computation](#step-2a--route-computation)
   - [Step 2b — combo_get_order_cart_invoice](#step-2b--combo_get_order_cart_invoice)
   - [Step 3 — combo_pay_order_payment](#step-3--combo_pay_order_payment)
   - [Step 4 — combo_create_order](#step-4--combo_create_order)
4. [Debug Log Reference](#4-debug-log-reference)
5. [Error Handling & Edge Cases](#5-error-handling--edge-cases)
6. [File Map](#6-file-map)

---

## 1. Architecture Overview

```
Cart Screen
  └─▶ DeliveryScreen._addToComboCart()
        │  POST combo_add_item_in_cart
        └─▶ ComboCheckoutScreen
              │  Google Directions API (route)
              │  POST combo_get_order_cart_invoice
              └─▶ KifiyaScreen  (isCombo = true)
                    │  POST combo_pay_order_payment   (Step 3)
                    └─▶ POST combo_create_order       (Step 4 — retry ×3)
                          └─▶ ReportScreen
```

### Local storage keys

| Key | Type | Content |
|---|---|---|
| `cart` | Map | Primary store cart (JSON) |
| `combo_cart` | Map | `ComboCart` JSON — second store + server IDs |
| `combo_orders` | List | Persisted `{combo_id, order_ids, order_unique_ids, created_at}` records (max 50) |
| `failed_orders` | List | Failed-order telemetry records |

---

## 2. Data Models

### `ComboCart` — `lib/combo/models/combo_cart.dart`

Local state object. The first store stays in the normal `cart` key so all single-store screens remain unaffected.

```dart
class ComboCart {
  Cart second;                          // Second store full cart
  String? comboId;                      // From combo_add_item_in_cart
  String? originStoreId;               // Farther store (= store_a from invoice on)
  Map<String, String> cartIdByStore;   // storeId → cartId
  Map<String, String> orderPaymentIdByStore; // storeId → orderPaymentId
}
```

> **Why keyed by `store_id`?**  The server's `store_a`/`store_b` labels flip at invoice time based on route. Keying by `store_id` keeps everything stable.

`resetServerState()` — clears `cartIdByStore`, `orderPaymentIdByStore`, `originStoreId`, but **keeps** `comboId` so the server reuses the same combo on re-sync.

---

### `ComboRoute` — `lib/combo/combo_route.dart`

```dart
class ComboRoute {
  final String originStoreId;    // Farther store → picked up first
  final String waypointStoreId;  // Nearer store → picked up second
  final double totalDistance;    // Meters, whole trip (origin → waypoint → customer)
  final double totalTime;        // Seconds, whole trip
  final bool fromFallback;       // true if Directions API failed → haversine used
}
```

---

### `ComboInvoice` — `lib/models/combo_invoice.dart`

Parsed from `combo_get_order_cart_invoice` response. Never keep the raw JSON in state.

```dart
class ComboInvoice {
  final String comboId;
  final double combinedDelivery;   // combined_delivery_price
  final double combinedUserPay;    // combined_user_pay_payment  ← canonical total
  final StoreInvoice origin;       // = store_a (farther)
  final StoreInvoice secondary;    // = store_b (nearer)
}
```

**Convenience getters:** `onlyCashless`, `onlyScheduled`, `onlyPickup`, `anyStoreBusy`, `busyStoreName`, `etaLabel`, `vehicleId`, `vehicleName`.

**`validate()`** returns a human-readable error string if:
- `comboId` is empty
- Either `origin.success` or `secondary.success` is false
- Either `orderPaymentId` is empty

---

### `StoreInvoice` — one leg of the invoice

```dart
class StoreInvoice {
  final String orderPaymentId;         // order_payment._id
  final String orderPaymentUniqueId;   // order_payment.unique_id (int→String)
  final String cartId;                 // order_payment.cart_id
  final String storeId;                // order_payment.store_id
  final double orderPrice;             // total_order_price (items subtotal)
  final double deliveryPrice;          // total_delivery_price (half of combined)
  final double promo;                  // promo_payment
  final double userPay;                // user_pay_payment
  final String? vehicleId;             // vehicles[0]._id
  final String? vehicleName;           // vehicles[0].vehicle_name
  final StoreFlags store;              // Safe subset only — no private fields
}
```

---

### `StoreFlags` — safe subset of the store document

```dart
class StoreFlags {
  final String storeId, storeName, imageUrl;
  final List<double> location;         // [lat, lng]
  final bool onlyCashless, onlyScheduled, onlyPickup, isLaundry, isBusy;
  final double minOrderPrice;
  final int deliveryTime, deliveryTimeMax;
}
```

---

### `ComboPaymentContext` — `lib/models/combo_payment_context.dart`

Typed object passed to `KifiyaScreen`. Built from `ComboInvoice`.

```dart
class ComboPaymentContext {
  final String comboId;
  final ComboLeg storeA;               // Origin (farther store)
  final ComboLeg storeB;               // Waypoint (nearer store)
  final double combinedDeliveryPrice;
  final double combinedUserPay;
  final String? vehicleId;
}

class ComboLeg {
  final String storeId, storeName, cartId;
  final String orderPaymentId, orderPaymentUniqueId;
  final double userPay, orderPrice, deliveryPrice, promo;
}
```

`KifiyaScreen` unpacks all fields from `ComboPaymentContext` in its constructor initializer list, so `isCombo` is automatically `true` when `combo != null`.

---

## 3. Step-by-Step Flow

### Step 0 — Cart Screen

**File:** `lib/cart/components/body.dart`

On load, `getCart()` calls `_loadComboCart()` which reads `combo_cart` from local storage and fetches the second store's name via `user_get_store_product_item_list`.

When the user presses **Checkout**:
1. Location check
2. Store hours check
3. `_checkMinOrderPrice()` — validates primary store subtotal against `storeDetail.store.min_order_price`. Blocks with a message if not met.
4. `Navigator.pushNamed(context, DeliveryScreen.routeName)`

The combo info banner (`_comboBanner`) is shown at the top of the cart body when `comboCart != null`:

```
┌──────────────────────────────────────┐
│ 🛍  Ordering from 2 stores · 1 driver│
└──────────────────────────────────────┘
```

---

### Step 1 — `combo_add_item_in_cart`

**File:** `lib/delivery/delivery_screen.dart` → `_addToComboCart()`

**Trigger:** `_addToCart()` detects `ComboCart.load() != null` and detours to `_addToComboCart()`.

**Guard:** Self-pickup is blocked (`selfPickup == true` → error).

#### Request

```
POST /api/user/combo_add_item_in_cart
Content-Type: application/json
```

```json
{
  "user_id": "<userId>",
  "server_token": "<token>",
  "combo_id": "<existing_combo_id>",
  "destination_address": {
    "lat": 9.0250,
    "long": 38.7469,
    "name": "Bole Road, Addis Ababa"
  },
  "delivery_type": 1,
  "username": "Abebe Kebede",
  "phone": "0911234567",
  "store_a": {
    "store_id": "<primaryStoreId>",
    "items": [
      { "_id": "<itemId>", "quantity": 2, "price": 120.0 }
    ]
  },
  "store_b": {
    "store_id": "<secondStoreId>",
    "items": [
      { "_id": "<itemId>", "quantity": 1, "price": 85.0 }
    ]
  }
}
```

> `combo_id` is optional — omitted on the very first call, included on re-sync so the server reuses the same combo object.  
> `store_a`/`store_b` here are just "primary cart" / "second cart" — the **route origin** is determined later at invoice time.

#### Response (success)

```json
{
  "success": true,
  "combo_id": "combo_abc123",
  "store_a": {
    "store_id": "<primaryStoreId>",
    "cart_id": "cart_aaa111"
  },
  "store_b": {
    "store_id": "<secondStoreId>",
    "cart_id": "cart_bbb222"
  }
}
```

#### Response (failure)

```json
{
  "success": false,
  "error_code": 999,
  "error": "Session expired"
}
```

#### State after success

```
combo.comboId         = "combo_abc123"
combo.cartIdByStore   = {
  "<primaryStoreId>": "cart_aaa111",
  "<secondStoreId>":  "cart_bbb222"
}
```
→ `combo.save()` → push `ComboCheckoutScreen`

#### Debug logs

```
[COMBO-DEBUG] ▶ Step 1: addItemInCart
  first_store_id : <primaryStoreId>
  second_store_id: <secondStoreId>
  existing combo_id: (none)
  first_items_count : 3
  second_items_count: 2

[COMBO-SERVICE] combo_add_item_in_cart BODY: {...}
[COMBO-SERVICE] combo_add_item_in_cart RESPONSE: {...}

[COMBO-DEBUG] ◀ Step 1 response: {success: true, combo_id: combo_abc123, ...}

[COMBO-DEBUG] ✓ Step 1 validated:
  combo_id     : combo_abc123
  cartIdByStore: {<storeId1>: cart_aaa111, <storeId2>: cart_bbb222}
```

---

### Step 2a — Route Computation

**File:** `lib/combo/combo_checkout_screen.dart` → `_getInvoice()` → `computeComboRoute()`  
**Source:** `lib/combo/combo_route.dart`

Determines which store is the **origin** (farther from customer) using the haversine formula, then calls the Google Directions API:

```
GET https://maps.googleapis.com/maps/api/directions/json
  ?origin=<oLat,oLng>
  &destination=<custLat,custLng>
  &waypoints=<wLat,wLng>
  &mode=driving
  &key=<apiKey>
```

Sums both legs' `distance.value` (meters) and `duration.value` (seconds).

**Fallback** (Directions API fails or times out): Two straight-line haversine distances summed, `totalTime = distance/1000 * 120` (2 min/km). Sets `fromFallback: true`.

| `ComboRoute` field | Content |
|---|---|
| `originStoreId` | Farther store from customer — sent as `store_a` in invoice |
| `waypointStoreId` | Nearer store — sent as `store_b` in invoice |
| `totalDistance` | Meters (whole trip) |
| `totalTime` | Seconds (whole trip) |
| `fromFallback` | `true` if Directions API failed |

#### Debug logs

```
[COMBO-DEBUG] ▶ Step 2a: computeComboRoute
  store_1 id : <storeId1>  lat=9.0250 lng=38.7469
  store_2 id : <storeId2>  lat=9.0310 lng=38.7521
  customer    : lat=9.0100 lng=38.7380

[COMBO-DEBUG] ✓ Step 2a: route computed (fallback=false)
  origin_store_id  : <storeId1>
  waypoint_store_id: <storeId2>
  totalDistance    : 4820 m
  totalTime        : 892 s
```

---

### Step 2b — `combo_get_order_cart_invoice`

**File:** `lib/combo/combo_checkout_screen.dart` → `ComboService.getInvoice()`

#### Request

```
POST /api/user/combo_get_order_cart_invoice
Content-Type: application/json
```

```json
{
  "user_id": "<userId>",
  "server_token": "<token>",
  "combo_id": "combo_abc123",
  "order_type": 7,
  "total_time": 892,
  "total_distance": 4820,
  "store_a": {
    "store_id": "<originStoreId>",
    "cart_id":  "cart_aaa111"
  },
  "store_b": {
    "store_id": "<waypointStoreId>",
    "cart_id":  "cart_bbb222"
  }
}
```

> **Critical:** `store_a` must always be the **origin (farther) store** from this step on. This is determined by `computeComboRoute()`, not by which store was added first.

#### Response (success)

```json
{
  "success": true,
  "combo_id": "combo_abc123",
  "combined_delivery_price": 80.0,
  "combined_user_pay_payment": 365.0,
  "store_a": {
    "success": true,
    "order_payment": {
      "_id": "op_AAA",
      "unique_id": 470721,
      "store_id": "<originStoreId>",
      "cart_id": "cart_aaa111",
      "total_order_price": 240.0,
      "total_delivery_price": 40.0,
      "promo_payment": 0.0,
      "user_pay_payment": 280.0,
      "total_distance": 3.2,
      "total_time": 24.0
    },
    "store": {
      "_id": "<originStoreId>",
      "name": "Burger House",
      "image_url": "uploads/store/...",
      "location": [9.025, 38.746],
      "accept_only_cashless_payment": false,
      "accept_scheduled_order_only": false,
      "accept_user_pickup_delivery_only": false,
      "is_provide_laundry_service": false,
      "is_store_busy": false,
      "min_order_price": 50.0,
      "delivery_time": 20,
      "delivery_time_max": 35
    },
    "vehicles": [
      { "_id": "veh_001", "vehicle_name": "Motorbike" }
    ]
  },
  "store_b": {
    "success": true,
    "order_payment": {
      "_id": "op_BBB",
      "unique_id": 470722,
      "store_id": "<waypointStoreId>",
      "cart_id": "cart_bbb222",
      "total_order_price": 85.0,
      "total_delivery_price": 40.0,
      "promo_payment": 0.0,
      "user_pay_payment": 125.0,
      "total_distance": 1.6,
      "total_time": 12.0
    },
    "store": { "...": "..." },
    "vehicles": []
  }
}
```

> **`combined_user_pay_payment`** is the canonical total used everywhere (bottom bar, Kifiya price, wallet check). If it differs from `store_a.user_pay + store_b.user_pay` by more than 1 cent, the mismatch is logged but the server value wins.

#### Response (failure — partial)

```json
{
  "success": false,
  "store_a": { "success": false, "error": "Cart expired" },
  "store_b": { "success": true }
}
```

#### State after success

```
combo.orderPaymentIdByStore = {
  "<originStoreId>"  : "op_AAA",
  "<waypointStoreId>": "op_BBB"
}
combo.originStoreId = "<originStoreId>"
```
→ `combo.save()` → UI shows the 2-stop summary card

#### Debug logs

```
[COMBO-DEBUG] ▶ Step 2b: getInvoice
  combo_id    : combo_abc123
  store_a (origin)  : <originStoreId>  cart=cart_aaa111
  store_b (waypoint): <waypointStoreId> cart=cart_bbb222

[COMBO-SERVICE] combo_get_order_cart_invoice BODY: {...}
[COMBO-SERVICE] combo_get_order_cart_invoice RESPONSE: {...}

[COMBO-DEBUG] ◀ Step 2b response: {success: true, ...}

[COMBO-DEBUG] ✓ Step 2b invoice parsed:
  combo_id          : combo_abc123
  origin  store_id  : <originStoreId>  name="Burger House"
    orderPaymentId  : op_AAA
    orderPrice      : 240.0
    deliveryPrice   : 40.0
    userPay         : 280.0
    vehicleId       : veh_001
  waypoint store_id : <waypointStoreId>  name="Fresh Mart"
    orderPaymentId  : op_BBB
    orderPrice      : 85.0
    deliveryPrice   : 40.0
    userPay         : 125.0
  combinedDelivery  : 80.0
  combinedUserPay   : 365.0
  etaLabel          : 30-45 min
  onlyCashless      : false
  anyStoreBusy      : false

[COMBO-DEBUG] ▶ Step 3 — pushing KifiyaScreen
  price (combinedUserPay)         : 365.0
  orderPaymentId (origin)         : op_AAA
  orderPaymentUniqueId (origin)   : 470721
  storeA orderPaymentId (origin)  : op_AAA
  storeB orderPaymentId (waypoint): op_BBB
  storeA cartId                   : cart_aaa111
  storeB cartId                   : cart_bbb222
  vehicleId                       : veh_001
  onlyCashless                    : false
```

---

### Step 3 — `combo_pay_order_payment`

**File:** `lib/kifiya/kifiya_screen.dart` → `payOrderPayment()` combo branch → `ComboService.pay()`

Triggered after user selects Cash or Wallet (Phase 1 — Digital is greyed out as "Soon").

#### Request

```
POST /api/user/combo_pay_order_payment
Content-Type: application/json
Timeout: 40 s
```

```json
{
  "user_id": "<userId>",
  "server_token": "<token>",
  "store_a_order_payment_id": "op_AAA",
  "store_b_order_payment_id": "op_BBB",
  "is_payment_mode_cash": true,
  "order_type": 7,
  "otp": ""
}
```

> `is_payment_mode_cash` is always `true` for both cash and wallet. The wallet toggle is done beforehand via `change_user_wallet_status`.

#### Response (success)

```json
{
  "success": true
}
```

#### Response (failure)

```json
{
  "success": false,
  "error_code": 999,
  "error": "Session expired"
}
```

#### After success

`_payOrderPayment()` → `_createOrder()`

#### Debug logs

```
[COMBO-DEBUG] ▶ Step 3: combo_pay_order_payment
  storeA_order_payment_id: op_AAA
  storeB_order_payment_id: op_BBB
  otp: (empty)

[COMBO-SERVICE] combo_pay_order_payment BODY: {...}
[COMBO-SERVICE] combo_pay_order_payment RESPONSE: {...}

[COMBO-DEBUG] ◀ Step 3 response: {success: true}
```

---

### Step 4 — `combo_create_order`

**File:** `lib/kifiya/kifiya_screen.dart` → `createOrder()` combo branch → `ComboService.createOrder()`

**Retry loop:** 3 attempts with delays of 1 s then 2 s.  
- `null` response (network/timeout) → retry  
- Any non-null response (even `success: false`) → stop immediately (prevents duplicate orders)

#### Request

```
POST /api/user/combo_create_order
Content-Type: application/json
Timeout: 50 s
```

```json
{
  "user_id": "<userId>",
  "server_token": "<token>",
  "combo_id": "combo_abc123",
  "store_a_cart_id": "cart_aaa111",
  "store_b_cart_id": "cart_bbb222",
  "is_user_pick_up_order": false,
  "order_from": "android"
}
```

#### Response (success)

```json
{
  "success": true,
  "combo_id": "combo_abc123",
  "order_unique_ids": [470721, 470722],
  "store_a": {
    "order_id": "ord_AAA111",
    "success": true
  },
  "store_b": {
    "order_id": "ord_BBB222",
    "success": true
  }
}
```

#### Response (duplicate)

```json
{
  "success": true,
  "duplicate": true,
  "combo_id": "combo_abc123"
}
```
→ Shows "Order already placed" message. Cart is **not** cleared (order already exists).

#### Response (failure)

```json
{
  "success": false,
  "error": "One of the stores has closed",
  "store_a": { "success": false, "error": "Store closed" },
  "store_b": { "success": true }
}
```

#### State after success

```
Service.remove('cart')
ComboCart.clear()
combo_orders ← { combo_id, order_ids: ["ord_AAA111","ord_BBB222"],
                 order_unique_ids: [470721,470722], created_at: "..." }
Navigator.pushReplacement → ReportScreen(
  price: 365.0,
  orderPaymentUniqueId: "470721,470722"
)
```

#### After failure

```
_logFailedComboOrder(reason, amount)
  ├─ Service.save('failed_orders', [...record...])
  └─ POST /api/user/log_failed_order  (best-effort, 5 s timeout, silent fail)

After 3 s → showMessage("contact support at 8707, reference: 470721")
```

#### Debug logs

```
[COMBO-DEBUG] ▶ Step 4: combo_create_order attempt 1/3
  combo_id       : combo_abc123
  storeA_cart_id : cart_aaa111
  storeB_cart_id : cart_bbb222

[COMBO-SERVICE] combo_create_order BODY: {...}
[COMBO-SERVICE] combo_create_order RESPONSE: {...}

[COMBO-DEBUG] ◀ Step 4 attempt 1 response: {success: true, ...}

[COMBO-DEBUG] ✓ Step 4: order created successfully
  combo_id        : combo_abc123
  store_a order_id: ord_AAA111
  store_b order_id: ord_BBB222
  order_unique_ids: [470721, 470722]
```

Retry scenario:

```
[COMBO-DEBUG] ◀ Step 4 attempt 1 response: NULL (timeout/network) — will retry
[COMBO-DEBUG] ▶ Step 4: combo_create_order attempt 2/3
  ...
[COMBO-DEBUG] ◀ Step 4 attempt 2 response: {success: true, ...}
```

Failure scenario:

```
[COMBO-DEBUG] ✗ Step 4: order creation failed
  response: {success: false, error: "Store closed"}
  isCombo : true
```

---

## 4. Debug Log Reference

All combo log lines use the prefix `[COMBO-DEBUG]`.  
`ComboService._post()` uses `[COMBO-SERVICE]` (guarded by `kDebugMode`).

| Symbol | Meaning |
|---|---|
| `▶` | About to send request |
| `◀` | Response received |
| `✓` | Validation passed / success |
| `✗` | Failure |
| `⚠` | Warning (duplicate order, total mismatch) |

### Quick grep

```bash
# See all combo logs while running
flutter run 2>&1 | grep "\[COMBO"

# Failures only
flutter run 2>&1 | grep "\[COMBO-DEBUG\] ✗"

# Invoice detail only
flutter run 2>&1 | grep "\[COMBO-DEBUG\].*Step 2b"

# All steps in order
flutter run 2>&1 | grep "\[COMBO-DEBUG\].*Step [1234]"
```

---

## 5. Error Handling & Edge Cases

| Scenario | Where handled | Behaviour |
|---|---|---|
| Session expired (`error_code 999`) | All 4 steps | Force logout → `LoginScreen` |
| Self-pickup attempted | `_addToComboCart` | Error toast, stop |
| Store is busy | `_proceedToPayment` | Error toast, stop |
| Store is scheduled-only | `_proceedToPayment` | Error toast, stop |
| Store is pickup-only | `_proceedToPayment` | Error toast, stop |
| Invoice structural validation fails | `ComboInvoice.validate()` | Error view + "Try again" button |
| `combined_user_pay` server/client mismatch | `ComboInvoice.fromJson()` | Warning log, server value wins |
| `create_order` timeout (null response) | Retry loop | Wait 1 s / 2 s, retry up to 3× |
| `create_order` API error (non-null) | Retry loop | Stop immediately, no duplicate risk |
| `create_order` duplicate response | `_createOrder` | "Already placed" toast, cart NOT cleared |
| Payment taken but order failed | `_logFailedComboOrder` | Local + backend telemetry, deferred support message |
| Primary cart emptied while combo active | `_promoteComboIfFirstEmpty` | Second store becomes primary, combo cleared |
| Min order not met (primary store) | `_checkMinOrderPrice` | Error toast, blocks before `DeliveryScreen` |
| Directions API unavailable | `computeComboRoute` fallback | Haversine straight-line, `fromFallback=true` |

---

## 6. File Map

| File | Role |
|---|---|
| `lib/cart/components/body.dart` | Cart screen — combo detection, info banner, min-order check, price calculation |
| `lib/combo/models/combo_cart.dart` | Local state — second store cart + server IDs, persistence |
| `lib/combo/combo_route.dart` | Route engine — determines origin/waypoint, Directions API + fallback |
| `lib/combo/combo_checkout_screen.dart` | Invoice screen — fetches invoice, renders 2-stop summary, pushes `KifiyaScreen` |
| `lib/combo/services/combo_service.dart` | All HTTP calls — 4 combo endpoints + `errorText`, `isSessionExpired` |
| `lib/models/combo_invoice.dart` | Typed invoice — `ComboInvoice`, `StoreInvoice`, `StoreFlags`, `validate()` |
| `lib/models/combo_payment_context.dart` | Payment context — `ComboPaymentContext`, `ComboLeg` |
| `lib/delivery/delivery_screen.dart` | Entry point — detects combo cart, calls `addItemInCart`, pushes `ComboCheckoutScreen` |
| `lib/kifiya/kifiya_screen.dart` | Payment + order creation — pay (Step 3), create with retry loop (Step 4), telemetry |
| `lib/orders/models/combo_order_entry.dart` | Orders list — `OrderEntry`, `groupOrders`, `getComboStatus` |
| `lib/orders/components/combo_order_card.dart` | Combo order card widget |
| `lib/orders/components/order_detail.dart` | Order detail — combo cross-reference banner |
