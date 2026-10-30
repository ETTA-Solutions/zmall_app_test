# Combo Order — Mobile Implementation Guide

| | |
| --- | --- |
| **App** | ZMall user app (Flutter), branch `new_combo` |
| **As of** | 2026-10-01 |
| **Sources** | *Combo Order Mobile Implementation Spec.docx* · `endpoint.docx` (live requests captured from web delivery against `testbackend.zmall.et`) · current code in `lib/` |
| **Status** | Backend `combo_*` endpoints are **live on test** and working from web. The mobile app has **no combo code yet**. |

---

## Contents

1. [What a combo order is](#1-what-a-combo-order-is)
2. [How the app works today (single-store)](#2-how-the-app-works-today-single-store)
3. [Target flow (combo)](#3-target-flow-combo)
4. [Endpoint reference with real payloads](#4-endpoint-reference-with-real-payloads)
5. [Distance & route algorithm](#5-distance--route-algorithm)
6. [Mobile implementation plan (file by file)](#6-mobile-implementation-plan-file-by-file)
7. [Error handling](#7-error-handling)
8. [Driver app](#8-driver-app)
9. [Testing](#9-testing)
10. [Open issues & findings](#10-open-issues--findings)
11. [Checklist](#11-checklist)

---

## 1. What a combo order is

A customer orders from **two stores in one checkout**, and **one driver delivers both in one trip**.

Backend design rules (from the spec):

- A combo is **not** a new data model. It is **two ordinary single-store Orders** that share a `combo_id`.
- The `combo_*` endpoints are thin wrappers. Each one calls the existing single-store logic once per store:

| Combo endpoint | Wraps (×2) |
| --- | --- |
| `combo_add_item_in_cart` | `add_item_in_cart` |
| `combo_get_order_cart_invoice` | `get_order_cart_invoice` |
| `combo_pay_order_payment` | `pay_order_payment` |
| `combo_create_order` | `create_order` |

- Single-store ordering stays **unchanged**.
- After creation, each Order has `combo_id` and `combo_pickup_sequence` (`1` = first pickup / origin, `2` = second pickup / waypoint).

---

## 2. How the app works today (single-store)

### 2.1 Flow

```
Item / Product screen ──(local only, no API)──► Service.save('cart')
        │ item from a different store → "clear your cart?" dialog
        ▼
DeliveryScreen ── POST /api/user/add_item_in_cart_new ──► cart_id
        ▼
CheckoutScreen ── distance (geohash → Distance Matrix → haversine)
               ── POST /api/user/get_order_cart_invoice ──► order_payment
        ▼
KifiyaScreen ── POST /api/user/pay_order_payment
             ── POST /api/user/create_order   (or create_order_for_telebirr_inapp)
```

### 2.2 Where each step lives

| Step | File | Function / line | Notes |
| --- | --- | --- | --- |
| Cart model | `lib/models/cart.dart` | `class Cart` | **One** `storeId`, one `storeLocation`, `items`, `destinationAddress` |
| Create cart | `lib/item/components/body.dart` | `addToCart()` :173 | Local only: `Service.save('cart', cart.toJson())` |
| Create cart | `lib/product/product_screen.dart` | `addToCart()` :166 | Local only |
| Add / merge | `lib/services/service.dart` | `addOrMergeCartItem()` :464 | Merges by item + specs |
| Same-store check | `lib/item/components/body.dart` :331, `lib/product/product_screen.dart` :586 | `if (cart!.storeId == item['store_id'])` | |
| Conflict dialog | `lib/item/components/body.dart` | `_showDialog()` :938 | Text: `lib/models/language.dart:69`. Copies also in `global/items/components/body.dart`, `notifications/notification_store.dart`, `scanner/components/scanned_store.dart` |
| **First server call** | `lib/delivery/delivery_screen.dart` | `_addToCart()` :382 → `addToCart()` :1249 | `add_item_in_cart_new` (or `_for_aliexpress`), saves `cart_id` into `userData['user']['cart_id']` |
| Distance | `lib/checkout/checkout_screen.dart` | `_getTotalDistanceGeoHash` → `_getTotalDistance` (Distance Matrix, :1389) → `_fallbackHaversine` | **One leg** store → customer |
| Store detail | `lib/checkout/checkout_screen.dart` | `getStoreDetail()` :1745 | Reuse to get `store.location` |
| Invoice | `lib/checkout/checkout_screen.dart` | `getCartInvoice()` :1512 | `get_order_cart_invoice` |
| Pay | `lib/kifiya/kifiya_screen.dart` | `payOrderPayment()` :3113 | One `order_payment_id` |
| Create order | `lib/kifiya/kifiya_screen.dart` | ~:3880 | `create_order`, idempotency key `order_payment_unique_id` |
| Base URL | `lib/utils/constants.dart:44` | `BASE_URL = BASE_URL_TEST` | via `Provider.of<ZMetaData>(context).baseUrl` |

### 2.3 What blocks combo today

- `Cart` can hold only one store, so adding a second store destroys the first cart.
- Distance covers one leg only. There is no waypoint and no origin choice.
- Invoice, pay and create each take a single `cart_id` / `order_payment_id`.
- No `combo_id` exists anywhere in the app.

---

## 3. Target flow (combo)

```
Item screen
  ├─ same store            → merge (unchanged)
  └─ different store        → dialog: [Order From Both Stores]  [Clear cart]
                                     │
                                     ▼
                     ComboCart (local) { first: Cart, second: Cart }
                                     │  still no API per item
                                     ▼
DeliveryScreen ── 1. combo_add_item_in_cart ──► combo_id, cart_id × 2
                     (server rejects: different city / too far apart)
                                     ▼
CheckoutScreen ── fetch both store.location
               ── haversine(store → customer) → FARTHER store = origin
               ── Google Directions: origin → waypoint → customer
               ── RELABEL: store_a = origin, store_b = waypoint  (fixed from here on)
               ── 2. combo_get_order_cart_invoice ──► order_payment × 2, combined totals
                                     ▼
Payment (wallet / cash only)
               ── 3. combo_pay_order_payment
               ── 4. combo_create_order ──► order_id × 2
                                     ▼
Clear ComboCart → success screen (2 orders, 1 combo)
```

> **Labels change between step 1 and step 2.** In step 1, `store_a` is just the store the customer tapped first.
> From step 2 onward, `store_a` **must** be the geographic origin (the farther store). Driver dispatch searches for
> drivers around `store_a`.

---

## 4. Endpoint reference with real payloads

These requests were captured from web delivery against the test backend.
`server_token` is masked. Large store objects are trimmed to the fields the app uses.

All calls: `POST {baseUrl}/api/user/<endpoint>`, headers `Content-Type: application/json`, `Accept: application/json`.

### 4.1 `combo_add_item_in_cart`

Builds both carts in one call. Called **once**, from the delivery screen.

**Request**

```json
{
  "user_id": "69eb547031dafab4ce1f1d5f",
  "server_token": "<server_token>",
  "destination_address": {
    "name": "Custom Location",
    "long": 38.7701506,
    "lat": 8.9999798,
    "note": ""
  },
  "delivery_type": 1,
  "username": "Kirubel Woldemichael",
  "phone": "944140745",
  "store_a": {
    "store_id": "63d9146526a10835da38a598",
    "items": [
      {
        "_id": "63d9150526a10835da38a5bd",
        "quantity": 1,
        "specification": [],
        "note_for_item": "",
        "price": 250,
        "item_name": "Brownie",
        "image_url": "https://testbackend.zmall.et/store_items/63d9150526a10835da38a5bdNXY0.jpg"
      }
    ]
  },
  "store_b": {
    "store_id": "66434399ff1c5d52db7bf524",
    "items": [
      {
        "_id": "66434415ff1c5d52db7bf530",
        "quantity": 1,
        "specification": [
          {
            "unique_id": 1,
            "name": "choose",
            "list": [{ "unique_id": 20109, "price": 1100, "name": "250g" }]
          }
        ],
        "note_for_item": "",
        "price": 2200,
        "item_name": "Guada Kulate with Berbere",
        "image_url": "https://testbackend.zmall.et/store_items/66434415ff1c5d52db7bf5308hre.jpg"
      }
    ]
  }
}
```

| Field | Required | Source in app |
| --- | --- | --- |
| `user_id`, `server_token` | yes | `userData['user']['_id']`, `['server_token']` |
| `phone`, `username` | yes, unless `is_superapp` | `userData['user']` |
| `is_superapp` | no | |
| `combo_id` | no | Omit on the first call. Send it on a re-sync. |
| `delivery_type` | yes | `1` = store delivery |
| `destination_address` | yes | `{name, long, lat, note}`, same as `Cart.destinationAddress` |
| `store_a` / `store_b` | yes | `{store_id, items, cart_unique_token?}`. `items` uses the same shape as `Item.toJson()` |

**Response**

```json
{
  "success": true,
  "combo_id": "6abe67e59b318a14825a1baa",
  "store_a": {
    "success": true,
    "is_laundary_store": false,
    "message": 952,
    "cart_id": "6abe67e59b318a14825a1bb2",
    "city_id": "5b406b46d2ddf8062d11b788",
    "user_id": "69eb547031dafab4ce1f1d5f",
    "server_token": "<server_token>",
    "store_id": "63d9146526a10835da38a598"
  },
  "store_b": {
    "success": true,
    "is_laundary_store": false,
    "message": 952,
    "cart_id": "6abe67e59b318a14825a1bbe",
    "city_id": "5b406b46d2ddf8062d11b788",
    "user_id": "69eb547031dafab4ce1f1d5f",
    "server_token": "<server_token>",
    "store_id": "66434399ff1c5d52db7bf524"
  }
}
```

**Save:** `combo_id`, plus `cart_id` for each `store_id`. Map cart ids by **store_id**, not by `a`/`b`, because the labels change in the next step.

---

### 4.2 `combo_get_order_cart_invoice`

Prices both carts and returns one combined delivery fee.

**Request.** `store_a` is now the **origin** (Guada, the farther store), so the labels are swapped compared with 4.1:

```json
{
  "user_id": "69eb547031dafab4ce1f1d5f",
  "server_token": "<server_token>",
  "combo_id": "6abe67e59b318a14825a1baa",
  "order_type": 7,
  "total_time": 282,
  "total_distance": 863,
  "store_a": { "store_id": "66434399ff1c5d52db7bf524", "cart_id": "6abe67e59b318a14825a1bbe" },
  "store_b": { "store_id": "63d9146526a10835da38a598", "cart_id": "6abe67e59b318a14825a1bb2" }
}
```

| Field | Required | Notes |
| --- | --- | --- |
| `combo_id` | yes | From 4.1 |
| `store_a` / `store_b` | yes | `{store_id, cart_id}`. **`store_a` = origin** (section 5) |
| `total_time` | yes | **seconds**, whole trip (both legs). The server stores minutes: 282 s → `4.7` |
| `total_distance` | yes | **meters**, whole trip. The server stores km: 863 m → `0.863` |
| `order_type` | yes | `7` (same as single-store) |
| `express_option` | no | e.g. `"normal"` |

**Response (key fields)**

```json
{
  "success": true,
  "combo_id": "6abe67e59b318a14825a1baa",
  "combined_delivery_price": 146.22,
  "combined_user_pay_payment": 1496.22,
  "store_a": {
    "success": true,
    "message": 113,
    "server_time": "2026-10-01T14:02:13.522Z",
    "timezone": "Africa/Nairobi",
    "order_payment": {
      "_id": "6abe67e591cbd91c93955c04",
      "cart_id": "6abe67e59b318a14825a1bbe",
      "combo_id": "6abe67e59b318a14825a1baa",
      "store_id": "66434399ff1c5d52db7bf524",
      "vehicle_id": "5b406c5dd2ddf8062d11b78a",
      "currency_code": "ETB",
      "total_distance": 0.863,
      "total_time": 4.7,
      "total_item_count": 1,
      "total_cart_price": 1100,
      "total_order_price": 1100,
      "total_delivery_price": 73.11,
      "total_service_price": 73.11,
      "promo_payment": 0,
      "tip": 0,
      "user_pay_payment": 1173.11,
      "total": 1173.11,
      "is_payment_mode_cash": true,
      "is_payment_paid": false,
      "is_store_pay_delivery_fees": false,
      "express_option": "normal",
      "unique_id": 603122
    },
    "store": {
      "_id": "66434399ff1c5d52db7bf524",
      "name": "GUADA/ጓዳ",
      "location": [8.9992927, 38.7694498],
      "city_id": "5b406b46d2ddf8062d11b788",
      "image_url": "store_profiles/66434399ff1c5d52db7bf524JMCz.jpg",
      "address": "Bole behind, Sur Construction, አዲስ አበባ, Ethiopia",
      "accept_only_cashless_payment": false
    },
    "vehicles": [{ "_id": "5b406c5dd2ddf8062d11b78a", "vehicle_name": "MOTOR BIKE" }]
  },
  "store_b": {
    "success": true,
    "message": 113,
    "order_payment": {
      "_id": "6abe67e591cbd91c93955c11",
      "cart_id": "6abe67e59b318a14825a1bb2",
      "store_id": "63d9146526a10835da38a598",
      "total_cart_price": 250,
      "total_delivery_price": 73.11,
      "user_pay_payment": 323.11,
      "total": 323.11,
      "unique_id": 603123
    },
    "store": {
      "_id": "63d9146526a10835da38a598",
      "name": "SUMI'S CAKE (Relocating We'll be back soon!)",
      "location": [9.0000198, 38.7702638]
    }
  }
}
```

**How the totals add up**

| | Store A (Guada) | Store B (Sumi's) | Combined |
| --- | --- | --- | --- |
| Items (`total_cart_price`) | 1,100.00 | 250.00 | 1,350.00 |
| Delivery (`total_delivery_price`, 50/50 split) | 73.11 | 73.11 | **146.22** (`combined_delivery_price`) |
| Customer pays (`user_pay_payment`) | 1,173.11 | 323.11 | **1,496.22** (`combined_user_pay_payment`) |

**Save:** `store_a.order_payment._id` and `store_b.order_payment._id` for 4.3.
**Show:** both item breakdowns, one delivery fee (`combined_delivery_price`), one total (`combined_user_pay_payment`).

---

### 4.3 `combo_pay_order_payment`

Settles both sides with one method. **Wallet or cash only** in this phase.

**Request**

```json
{
  "user_id": "69eb547031dafab4ce1f1d5f",
  "server_token": "<server_token>",
  "store_a_order_payment_id": "6abe67e69b318a14825a1bcf",
  "store_b_order_payment_id": "6abe67e69b318a14825a1bdc",
  "is_payment_mode_cash": true,
  "otp": ""
}
```

| Field | Required | Notes |
| --- | --- | --- |
| `store_a_order_payment_id` / `store_b_order_payment_id` | yes | From 4.2, keeping the same a/b as the invoice |
| `is_payment_mode_cash` | yes | `true` = cash, `false` = wallet |
| `order_type` | spec: yes | Web does not send it. Send `7` to be safe |
| `otp` | no | When OTP is enabled for the user |
| `store_delivery_id` | no | |

**Response**

```json
{
  "success": true,
  "combo_id": "6abe67e6990ff8e719e586d5",
  "store_a": { "success": true, "message": 116, "is_payment_paid": true },
  "store_b": { "success": true, "message": 116, "is_payment_paid": true }
}
```

`success` is `true` only if **both** sides paid. For wallet, the server checks the **combined** amount first and returns
`error_code: "YOUR_WALLET_AMOUNT_NEGATIVE"` before charging either side.

---

### 4.4 `combo_create_order`

Turns both paid carts into real Orders.

**Request**

```json
{
  "user_id": "69eb547031dafab4ce1f1d5f",
  "server_token": "<server_token>",
  "combo_id": "6abe67e6990ff8e719e586d5",
  "store_a_cart_id": "6abe67e6990ff8e719e586e9",
  "store_b_cart_id": "6abe67e6990ff8e719e586dd",
  "is_user_pick_up_order": false,
  "order_from": "web"
}
```

| Field | Required | Notes |
| --- | --- | --- |
| `combo_id` | yes | |
| `store_a_cart_id` / `store_b_cart_id` | yes | **Origin store's cart = `store_a_cart_id`** |
| `order_from` | | Web sends `"web"`. Mobile should send its own value (confirm with backend, e.g. `"android"` / `"ios"`) |
| `is_user_pick_up_order` | | `false` |
| `order_type`, `is_schedule_order`, `schedule_order_start_at`, `order_start_at`, `delivery_type`, `paid_by`, `tip` | optional | Forwarded to both sides, same as single-store `create_order` |

**Response**

```json
{
  "success": true,
  "combo_id": "6abe67e6990ff8e719e586d5",
  "order_unique_ids": [470721, 470722],
  "store_a": { "success": true, "order_id": "6abe69c2990ff8e719e5871d", "message": 241 },
  "store_b": { "success": true, "order_id": "6abe69c2990ff8e719e58732", "message": 241 }
}
```

Show `order_unique_ids` to the customer (e.g. "Orders #470721 and #470722").

### 4.5 Message codes seen

| `message` | Meaning |
| --- | --- |
| 952 | Item(s) added to cart |
| 113 | Invoice generated |
| 116 | Payment done |
| 241 | Order created |

---

## 5. Distance & route algorithm

### 5.1 Steps

1. **Get both store coordinates.** Cart items don't include them, so use `store.location` = `[lat, lng]`. Either fetch
   it with the store-detail call (`getStoreDetail()` already exists in `checkout_screen.dart`), or keep the
   `storeLocation` each local `Cart` already holds.
2. **Pick the origin.** Compute the haversine distance from each store to the customer.
   - **Farther** store → **origin** → `store_a` from now on.
   - **Nearer** store → **waypoint** → `store_b`.
   - This is optimal, not a shortcut. The only two routes are S1→S2→C and S2→S1→C, and the S1↔S2 leg is the same in
     both. So the shorter route is the one whose last leg (store → customer) is shorter.
3. **Call Google Directions once:** `origin=origin`, `waypoints=waypoint`, `destination=customer`, `mode=driving`.
   - `total_distance = legs[0].distance.value + legs[1].distance.value` (meters)
   - `total_time = legs[0].duration.value + legs[1].duration.value` (seconds)
4. **Fallback:** if Directions fails, use haversine(origin→waypoint) + haversine(waypoint→customer), with time at
   about 120 s/km (the same estimate `_fallbackHaversine` uses today). Never block checkout because of this call.
5. **Relabel and keep the labels.** Use `store_a` = origin in invoice, pay and create.

### 5.2 Worked example (from `endpoint.docx`)

| Point | Lat, Lng | Haversine to customer |
| --- | --- | --- |
| Customer | 8.9999798, 38.7701506 | — |
| GUADA (`66434399…`) | 8.9992927, 38.7694498 | ≈ 108 m → **farther → origin (`store_a`)** |
| SUMI'S CAKE (`63d91465…`) | 9.0000198, 38.7702638 | ≈ 13 m → nearer → waypoint (`store_b`) |

The customer tapped Sumi's first, so it was `store_a` in 4.1. In 4.2 Guada correctly becomes `store_a`.
Route total: 863 m, 282 s.

### 5.3 Dart reference

```dart
// lib/combo/combo_route.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class ComboRoute {
  final String originStoreId;   // -> store_a
  final String waypointStoreId; // -> store_b
  final double totalDistance;   // meters
  final double totalTime;       // seconds
  final bool fromFallback;
  ComboRoute(this.originStoreId, this.waypointStoreId, this.totalDistance,
      this.totalTime, this.fromFallback);
}

double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const p = 0.017453292519943295;
  final a = 0.5 -
      cos((lat2 - lat1) * p) / 2 +
      cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
  return 12742000 * asin(sqrt(a));
}

Future<ComboRoute> computeComboRoute({
  required String storeIdX, required double xLat, required double xLng,
  required String storeIdY, required double yLat, required double yLng,
  required double custLat, required double custLng,
  required String apiKey,
}) async {
  final dx = haversineMeters(xLat, xLng, custLat, custLng);
  final dy = haversineMeters(yLat, yLng, custLat, custLng);
  final xIsOrigin = dx >= dy; // farther store goes first

  final oId = xIsOrigin ? storeIdX : storeIdY;
  final wId = xIsOrigin ? storeIdY : storeIdX;
  final oLat = xIsOrigin ? xLat : yLat, oLng = xIsOrigin ? xLng : yLng;
  final wLat = xIsOrigin ? yLat : xLat, wLng = xIsOrigin ? yLng : xLng;

  try {
    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$oLat,$oLng&destination=$custLat,$custLng'
        '&waypoints=$wLat,$wLng&mode=driving&key=$apiKey';
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    final data = json.decode(res.body);
    if (data['status'] == 'OK') {
      final legs = data['routes'][0]['legs'] as List;
      double dist = 0, time = 0;
      for (final leg in legs) {
        dist += (leg['distance']['value'] as num).toDouble();
        time += (leg['duration']['value'] as num).toDouble();
      }
      return ComboRoute(oId, wId, dist, time, false);
    }
  } catch (_) {}

  // Fallback: two straight-line legs, ~2 min per km
  final dist = haversineMeters(oLat, oLng, wLat, wLng) +
      haversineMeters(wLat, wLng, custLat, custLng);
  return ComboRoute(oId, wId, dist, dist / 1000 * 120, true);
}
```

> **Watch the coordinate order.** `store.location` is `[lat, lng]`. `destination_address` uses `lat` / `long` keys.

---

## 6. Mobile implementation plan (file by file)

### 6.1 New files

```
lib/combo/
├── models/combo_cart.dart        # ComboCart + persistence
├── services/combo_service.dart   # the 4 HTTP calls
├── combo_route.dart              # section 5.3
└── combo_checkout_screen.dart    # invoice + payment + create (or a mode in CheckoutScreen)
```

### 6.2 `ComboCart` model

```dart
// lib/combo/models/combo_cart.dart
class ComboCart {
  String? comboId;                     // from combo_add_item_in_cart
  Cart first;                          // first store tapped
  Cart second;                         // second store
  Map<String, String> cartIdByStore;   // store_id -> cart_id (labels change later!)
  String? originStoreId;               // set after distance calc = store_a
  Map<String, String> orderPaymentIdByStore; // from invoice

  ComboCart({this.comboId, required this.first, required this.second,
      Map<String, String>? cartIdByStore, this.originStoreId,
      Map<String, String>? orderPaymentIdByStore})
      : cartIdByStore = cartIdByStore ?? {},
        orderPaymentIdByStore = orderPaymentIdByStore ?? {};

  String get waypointStoreId =>
      originStoreId == first.storeId ? second.storeId! : first.storeId!;

  Map<String, dynamic> toJson() => {
        'combo_id': comboId,
        'first': first.toJson(),
        'second': second.toJson(),
        'cart_id_by_store': cartIdByStore,
        'origin_store_id': originStoreId,
        'order_payment_id_by_store': orderPaymentIdByStore,
      };

  factory ComboCart.fromJson(Map<String, dynamic> j) => ComboCart(
        comboId: j['combo_id'],
        first: Cart.fromJson(j['first']),
        second: Cart.fromJson(j['second']),
        cartIdByStore: Map<String, String>.from(j['cart_id_by_store'] ?? {}),
        originStoreId: j['origin_store_id'],
        orderPaymentIdByStore:
            Map<String, String>.from(j['order_payment_id_by_store'] ?? {}),
      );
}
```

- Storage key: `Service.save('combo_cart', comboCart.toJson())`. The existing `'cart'` key stays untouched, so every
  single-store screen keeps working.
- Clear `combo_cart` after `combo_create_order` succeeds, or when the user empties it.

### 6.3 `ComboService`, following the codebase's existing `http.post` pattern

```dart
// lib/combo/services/combo_service.dart
class ComboService {
  static Future<Map<String, dynamic>?> _post(
      BuildContext context, String path, Map body, {int timeout = 30}) async {
    final url = '${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/$path';
    try {
      final res = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: json.encode(body))
          .timeout(Duration(seconds: timeout),
              onTimeout: () => throw TimeoutException('The connection has timed out!'));
      return json.decode(res.body);
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> addItemInCart(BuildContext c, Map user,
          ComboCart cc, DestinationAddress dest) =>
      _post(c, 'combo_add_item_in_cart', {
        'user_id': user['_id'],
        'server_token': user['server_token'],
        'username': '${user['first_name']} ${user['last_name']}',
        'phone': user['phone'],
        if (cc.comboId != null) 'combo_id': cc.comboId,
        'delivery_type': 1,
        'destination_address': dest.toJson(),
        'store_a': {'store_id': cc.first.storeId, 'items': cc.first.items!.map((i) => i.toJson()).toList()},
        'store_b': {'store_id': cc.second.storeId, 'items': cc.second.items!.map((i) => i.toJson()).toList()},
      });

  static Future<Map<String, dynamic>?> getInvoice(BuildContext c, Map user,
          ComboCart cc, ComboRoute r, {String? expressOption}) =>
      _post(c, 'combo_get_order_cart_invoice', {
        'user_id': user['_id'],
        'server_token': user['server_token'],
        'combo_id': cc.comboId,
        'order_type': 7,
        'total_time': r.totalTime,
        'total_distance': r.totalDistance,
        if (expressOption != null) 'express_option': expressOption,
        'store_a': {'store_id': r.originStoreId,   'cart_id': cc.cartIdByStore[r.originStoreId]},
        'store_b': {'store_id': r.waypointStoreId, 'cart_id': cc.cartIdByStore[r.waypointStoreId]},
      });

  static Future<Map<String, dynamic>?> pay(BuildContext c, Map user,
          ComboCart cc, {required bool cash, String otp = ''}) =>
      _post(c, 'combo_pay_order_payment', {
        'user_id': user['_id'],
        'server_token': user['server_token'],
        'store_a_order_payment_id': cc.orderPaymentIdByStore[cc.originStoreId],
        'store_b_order_payment_id': cc.orderPaymentIdByStore[cc.waypointStoreId],
        'is_payment_mode_cash': cash,
        'order_type': 7,
        'otp': otp,
      }, timeout: 40);

  static Future<Map<String, dynamic>?> createOrder(BuildContext c, Map user,
          ComboCart cc, {required String orderFrom}) =>
      _post(c, 'combo_create_order', {
        'user_id': user['_id'],
        'server_token': user['server_token'],
        'combo_id': cc.comboId,
        'store_a_cart_id': cc.cartIdByStore[cc.originStoreId],
        'store_b_cart_id': cc.cartIdByStore[cc.waypointStoreId],
        'is_user_pick_up_order': false,
        'order_from': orderFrom,
      }, timeout: 50);
}
```

> Confirm the user name fields (`first_name` / `last_name`) against the stored `user` object before use.

### 6.4 Changes to existing files

| File | Change |
| --- | --- |
| `lib/item/components/body.dart` (`_showDialog`) | Add **"Order From Both Stores"**: build a `ComboCart(first: existingCart, second: newCart)` and save `combo_cart`. Keep "Clear cart". If a combo already exists and a **third** store is added, show the clear dialog. |
| `lib/product/product_screen.dart`, `lib/global/items/components/body.dart`, `lib/notifications/notification_store.dart`, `lib/scanner/components/scanned_store.dart` | Same dialog change. Best: move the dialog into one shared widget first. |
| `lib/models/language.dart` | New strings: "Order From Both Stores", "Both stores must be in the same city…", "These two stores are too far apart…" |
| Cart screen (`lib/cart/components/body.dart`) | When `combo_cart` exists, show two store sections with per-store subtotals and quantity edits. Emptying one store drops back to a single-store `cart`. |
| `lib/delivery/delivery_screen.dart` (`_addToCart`) | If `combo_cart` exists, call `ComboService.addItemInCart`. Save `combo_id` and `cartIdByStore` from `store_a.store_id → store_a.cart_id` and the same for `store_b`. Show server errors (section 7). |
| `lib/checkout/checkout_screen.dart` | Combo mode: get both store locations → `computeComboRoute` → set `originStoreId` → `ComboService.getInvoice`. Save `orderPaymentIdByStore` from each side's `order_payment.store_id → order_payment._id`. Render the two breakdowns plus the combined total. **Hide self-pickup.** |
| `lib/kifiya/kifiya_screen.dart` | Combo mode: show **only wallet and cash**. Call `ComboService.pay`. If `success` is true, call `ComboService.createOrder`. Then remove `combo_cart` and show both `order_unique_ids`. |
| Orders list / detail | Group orders that share `combo_id` (show "Combo · 2 stores"). |

### 6.5 Rules to keep

- Never send per-item API calls. Sync once at the delivery screen.
- Map ids **by store_id**. The `a`/`b` labels from 4.1 mean nothing after the distance calc.
- Don't recalculate the origin after the invoice. If the address changes, run the route **and** the invoice again.
- When re-syncing (the user goes back and edits the cart), send the existing `combo_id` to `combo_add_item_in_cart`.

---

## 7. Error handling

| When | Server says | App should |
| --- | --- | --- |
| add_item | `store_a.store_id and store_a.items are required` (or `store_b`) | Bug. Log it and show a generic error |
| add_item | `store_a and store_b must be different stores` | Merge into a single-store cart |
| add_item / invoice | `Store not found` | Show the message. Remove that store from the combo |
| add_item / invoice | `Both stores must be in the same city for a combo order` | Show the message. Offer to keep one store |
| add_item | `These two stores are too far apart for a combo order` | Same as above |
| invoice | `total_time and total_distance (for the whole combined trip) are required` | Bug: the route was not computed |
| invoice | `Failed to compute invoice for one or both stores` + per-side detail | Show which store failed |
| pay | `store_a_order_payment_id and store_b_order_payment_id are required` | Bug |
| pay | `Order_payment not found` | Run the invoice again |
| pay (wallet) | `error_code: "YOUR_WALLET_AMOUNT_NEGATIVE"` | "Not enough wallet balance." Offer cash or top-up. Nothing was charged |
| create | `Failed to create one or both orders` + per-side detail | **No rollback.** Show which side failed. **Don't** clear `combo_cart`. Tell the user to contact support (see 10) |
| any | `error_code: 999` | Log out (same as existing screens) |
| any | timeout / `null` | Existing "Something went wrong! Check your internet…" message |

---

## 8. Driver app

The driver app is a separate repo. It needs **no new endpoints**, because a combo is one Request whose
`pickup_addresses` has 2 entries.

**Spec says is missing**
- About 30 places read `pickup_addresses[0]`, which ignores the second store.
- The status flow is linear, and ARRIVED / PICKED_ORDER can't repeat.
- The map has fixed `"Pickup"` / `"Dropoff"` markers.

**Target status chain (combo only)**

```
ACCEPTED → COMING → ARRIVED (store 1) → PICKED_ORDER (store 1)
→ COMING (store 2) → DELIVERY_MAN_ARRIVED_STORE_2 → DELIVERY_MAN_PICKED_ORDER_STORE_2
→ STARTED_DELIVERY → ARRIVED_AT_DESTINATION → COMPLETE
```

**Changes:** a combo branch in `updateOrderStatus()`, button labels that name the store ("ARRIVED — STORE 2"), a
geofence on the active stop, and map markers built from a stop list with camera bounds covering every stop.

> **Observed on the test phone (2026-10-01):** an installed driver build already logs
> `[DeliveryStop] buildStops: total stops built = 3 (2 pickup(s), 1 dropoff(s))`. So multi-stop parsing has already
> started in the driver repo. Check that repo before following this section.

---

## 9. Testing

### 9.1 Replay with curl

Run the calls in order. Each one uses ids from the previous response.

```bash
BASE=https://testbackend.zmall.et      # or BASE_URL_TEST from lib/utils/constants.dart
U=69eb547031dafab4ce1f1d5f
T=<server_token>

# 1. cart
curl -s -X POST $BASE/api/user/combo_add_item_in_cart -H 'Content-Type: application/json' -d @add.json
#    -> combo_id, store_a.cart_id, store_b.cart_id

# 2. invoice (store_a = FARTHER store)
curl -s -X POST $BASE/api/user/combo_get_order_cart_invoice -H 'Content-Type: application/json' -d '{
 "user_id":"'$U'","server_token":"'$T'","combo_id":"<combo_id>","order_type":7,
 "total_time":282,"total_distance":863,
 "store_a":{"store_id":"<origin_store>","cart_id":"<origin_cart>"},
 "store_b":{"store_id":"<waypoint_store>","cart_id":"<waypoint_cart>"}}'
#    -> store_a.order_payment._id, store_b.order_payment._id

# 3. pay (cash)
curl -s -X POST $BASE/api/user/combo_pay_order_payment -H 'Content-Type: application/json' -d '{
 "user_id":"'$U'","server_token":"'$T'",
 "store_a_order_payment_id":"<op_a>","store_b_order_payment_id":"<op_b>",
 "is_payment_mode_cash":true,"otp":""}'

# 4. create
curl -s -X POST $BASE/api/user/combo_create_order -H 'Content-Type: application/json' -d '{
 "user_id":"'$U'","server_token":"'$T'","combo_id":"<combo_id>",
 "store_a_cart_id":"<origin_cart>","store_b_cart_id":"<waypoint_cart>",
 "is_user_pick_up_order":false,"order_from":"android"}'
```

> The 4.3 / 4.4 samples in `endpoint.docx` come from a **different run** than 4.1 / 4.2 (different `combo_id`).
> Don't mix ids across runs.

### 9.2 Seeing the requests from the phone

```bash
adb devices
adb -s <device> logcat -v brief flutter:I '*:S'
```

In Android Studio, filter Logcat by `com.zmall.user`.

### 9.3 Test cases

- [ ] Two stores in the same city: all four calls succeed and two orders are created.
- [ ] Stores in different cities: rejected at `combo_add_item_in_cart`.
- [ ] Stores farther apart than the admin limit: rejected.
- [ ] Tap the **nearer** store first: the invoice must still send the **farther** store as `store_a` (example in 5.2).
- [ ] Directions API fails (bad key or offline): the haversine fallback is used and checkout still works.
- [ ] `combined_delivery_price` = sum of both `total_delivery_price`. `combined_user_pay_payment` = sum of both `user_pay_payment`.
- [ ] Wallet with too little balance: `YOUR_WALLET_AMOUNT_NEGATIVE`, and neither side is charged.
- [ ] Cash: both sides `is_payment_paid: true`.
- [ ] Both orders have `combo_pickup_sequence` 1 (origin) and 2 (waypoint), checked in the admin panel.
- [ ] Edit the cart after sync: re-sync with the same `combo_id`.
- [ ] Remove all items of one store: the app falls back to a normal single-store order.
- [ ] Single-store orders are unaffected (regression).
- [ ] Driver (once the backend states ship): both stops on the map, two separate pickups, delivery available only after both.

---

## 10. Open issues & findings

| # | Issue | Owner |
| --- | --- | --- |
| 1 | **Partial create failure.** One order is created and the other fails, with no rollback. Recovery behavior is not yet defined. | Backend / product |
| 2 | **50/50 delivery split** is temporary and only for testing. A final pricing rule is pending. | Product |
| 3 | **External gateways** (Telebirr, Wegagen, Kifiya cards) are not supported for combo in this phase. | Backend |
| 4 | **Price mismatch in the sample.** The Guada item was sent with `price: 2200` (spec option 1100), but the invoice shows `total_cart_price: 1100`. Confirm how `price` should be sent for items with specifications. | Backend + mobile |
| 5 | **`order_from` for mobile.** Web sends `"web"`. Agree on the mobile value. | Backend |
| 6 | **Idempotency.** Single-store `create_order` uses `order_payment_unique_id` to stop duplicates. Ask whether `combo_create_order` supports it too. | Backend |
| 7 | **Interaction with other flows.** AliExpress, self-pickup, scheduled orders, "order for others", promo codes and tips are not defined for combo. Suggest blocking combo for these at first. | Product |
| 8 | **🔒 Data leak.** The invoice response returns each store's full record, including the `password` hash (unsalted MD5: Guada's `e10adc39…` = `123456`), `bank_account_number`, `wallet` balance and `email`. The backend should return only the fields the app needs. | Backend (urgent) |
| 9 | **🔒 Token in a document.** `endpoint.docx` has a real `server_token` in plain text. Rotate it, and mask tokens in shared docs. | Team |

---

## 11. Checklist

**Mobile (user app)**
- [ ] `lib/combo/models/combo_cart.dart` + the `combo_cart` storage key
- [ ] Shared store-conflict dialog with "Order From Both Stores" (replace all copies)
- [ ] Cart screen shows two store sections
- [ ] Delivery screen calls `combo_add_item_in_cart`, saves `combo_id` and `cartIdByStore`
- [ ] `combo_route.dart`: haversine origin choice, Directions with waypoint, fallback
- [ ] Checkout: combo invoice, two breakdowns, combined total, no self-pickup
- [ ] Payment: wallet / cash only, `combo_pay_order_payment`
- [ ] `combo_create_order`, success screen with both order numbers, clear the combo cart
- [ ] Partial-failure handling (keep the cart, show which side failed)
- [ ] Orders list groups orders by `combo_id`
- [ ] Translations in `language.dart`

**Backend (asks)**
- [ ] Strip sensitive store fields from the invoice response
- [ ] Decide the partial-failure recovery
- [ ] Confirm `order_from` and idempotency for combo
- [ ] Ship `DELIVERY_MAN_ARRIVED_STORE_2` / `DELIVERY_MAN_PICKED_ORDER_STORE_2`

**Driver app**
- [ ] Multi-stop status chain, labels, geofence, map markers (section 8)
