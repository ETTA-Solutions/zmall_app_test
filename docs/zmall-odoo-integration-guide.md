# Zmall × Odoo Integration — Complete Implementation Guide

A deep, end-to-end guide to how the Zmall Flutter app talks to the **Odoo ERP server**, how it decides *which* stores are Odoo-linked, how the `odoo_product_id` is found, carried, and persisted, and exactly what happens before checkout.

> This guide reflects the current working tree (branch `feature/zmall-odoo-availability`).

---

## Table of Contents

1. [The Big Picture](#1-the-big-picture)
2. [The Two Odoo Servers](#2-the-two-odoo-servers)
3. [The Endpoint Contract](#3-the-endpoint-contract)
4. [How the App Decides a Store Is "Odoo"](#4-how-the-app-decides-a-store-is-odoo)
5. [How the App Finds the Odoo Product Id](#5-how-the-app-finds-the-odoo-product-id)
6. [The Availability Service](#6-the-availability-service)
7. [The Cart Screen Flow (App → Odoo)](#7-the-cart-screen-flow-app--odoo)
8. [The Two Popups / Dialogs](#8-the-two-popups--dialogs)
9. [Response Parsing & the -1 Sentinel](#9-response-parsing--the--1-sentinel)
10. [Error Handling Rules](#10-error-handling-rules)
11. [File-by-File Inventory](#11-file-by-file-inventory)
12. [End-to-End Sequence Diagram](#12-end-to-end-sequence-diagram)
13. [Git History / How the Feature Evolved](#13-git-history--how-the-feature-evolved)
14. [What Is NOT in This Repo](#14-what-is-not-in-this-repo)
15. [Open Items & Gotchas](#15-open-items--gotchas)

---

## 1. The Big Picture

Zmall has **multiple physical branches**, each with its **own warehouse and its own stock** inside Odoo. The same product can be in stock at Branch A but sold out at Branch B.

**The problem the feature solves:** the app used to never check branch-level stock. A user could add items, go through checkout, place an order — and only later find out the branch was out of stock.

**The solution:** before checkout, the app asks the Odoo server *"does the branch for this store have enough of my cart items?"* If not → the app **blocks checkout** and shows the user why, with the option to auto-reduce the cart to what's actually available.

The Odoo-side endpoint was built by the backend senior, spec'd by a Postman collection. This repo contains the **Flutter client** side of that contract — plus the "You have X left" surplus notification on top.

```
FLUTTER APP ──POST /zmall_order/<branch_slug>──► ODOO SERVER
     │                                                │
     │  { products: [ {product_id, quantity} ] }      │ find pos.config by slug
     │◄──────────── 200 JSON ──────────────────────── │ look up warehouse
     │   { success, branch, can_checkout, products }  │ compute forecasted qty
     │
     can_checkout == true  → proceed to Delivery
     can_checkout == false → block + show "Item Stock Notice"
     forecasted > cart qty → show "You have X left"
```

---

## 2. The Two Odoo Servers

There are **two different Odoo servers** referenced in this app. Do not conflate them.

| Server | URL | Used for | Where |
|---|---|---|---|
| **Branch availability** | `http://196.191.117.85:9070` | `POST /zmall_order/<branch_slug>` — forecasted stock check | `lib/utils/constants.dart` → `kZmallOdooBaseUrl` |
| **Telebirr USSD** | `http://196.189.44.60:8069` | `POST /telebirr/ussd/send_sms` — unrelated Telebirr payment SMS | `lib/kifiya/kifiya_screen.dart:1981` |

This guide only covers the first one.

---

## 3. The Endpoint Contract

### The request

```
POST http://196.191.117.85:9070/zmall_order/<branch_slug>
Content-Type: application/json
Accept: application/json

{ "products": [ { "product_id": 101, "quantity": 5 } ] }
```

### Key rules (from the Postman design)

- **Branch is determined ONLY by the URL path segment** (`<branch_slug>`), never by the request body.
- `product_id` is an **Odoo `product.template` id** — NOT the Mongo `_id` the app normally uses everywhere else.
- Each branch is an Odoo `pos.config` record carrying a field `zmall_branch_slug` (e.g. `ayat`, `mexico`).
- `quantity` is the current cart quantity for that product.

### Response contract

```
200 → {
  success: bool,
  branch: string,
  can_checkout: bool,
  products: [ {
    product_id: int,
    quantity: int,            // echo of requested_quantity (may come as requested_quantity)
    available: bool,
    forecasted_quantity: double | int,   // -1 = sentinel "inventory check skipped"
    error?: string
  } ]
}

Per-item error (still HTTP 200):
  available=false, error="product not found" | "invalid quantity"

Top-level errors:
  404 → unknown branch slug   { success:false, error:"Unknown Zmall branch '...'" }
  400 → invalid JSON body
  503 → branch has no warehouse set (misconfiguration)

skip_inventory_check ON →
  available=true, forecasted_quantity=-1  (sentinel = "not checked"),
  but unknown product is STILL flagged.
```

---

## 4. How the App Decides a Store Is "Odoo"

A store is treated as an Odoo (POS) store **if and only if its `store_id` appears in the hard-coded branch slug map**.

### The map — `lib/utils/constants.dart:46-69`

```dart
/// Zmall branch availability check (Odoo).
/// This endpoint lives on the Odoo server, NOT the regular Zmall backend.
const String kZmallOdooBaseUrl = "http://196.191.117.85:9070";

/// JSON field on each item (from the store API) carrying the Odoo
/// product.template id used by the availability endpoint.
const String kZmallOdooProductIdField = "odoo_product_id";

/// Maps Zmall store_id -> Odoo pos.config.zmall_branch_slug.
const Map<String, String> kZmallBranchSlugs = {
  "5b3f76f2022985030cd3a437": "ayat",
  "5b406b24d2ddf8062d11b787": "mexico",
  "6a6b0c4a56bef41124383ca2": "mexico",
};

/// Resolves the Odoo branch slug for a Zmall store, or null if not POS-linked.
String? zmallBranchSlugForStore(String? storeId) {
  if (storeId == null || storeId.isEmpty) return null;
  return kZmallBranchSlugs[storeId.trim()];
}

bool isOdooAvailabilityStore(String? storeId) =>
    zmallBranchSlugForStore(storeId) != null;
```

### How it works

| Piece | What it does |
|---|---|
| `kZmallBranchSlugs` | **Single source of truth.** Maps Zmall Mongo `store_id` → Odoo `pos.config.zmall_branch_slug`. Currently: `5b3f76f2022985030cd3a437`→`ayat`, `5b406b24d2ddf8062d11b787`→`mexico`, `6a6b0c4a56bef41124383ca2`→`mexico`. Note two stores share the `mexico` branch. |
| `zmallBranchSlugForStore()` | Trims the incoming `store_id` then looks it up. Returns `null` for any store not in the map (non-POS store). |
| `isOdooAvailabilityStore()` | Convenience boolean wrapper. Currently defined but **not called anywhere** in `lib/` — the cart screen calls `zmallBranchSlugForStore` directly. |

### The consequence of the map

- Store **in** the map → branch slug found → availability check runs against Odoo, checkout can be blocked.
- Store **not** in the map → `zmallBranchSlugForStore` returns `null` → the app **silently skips** the Odoo check and **never blocks checkout**. Availability simply doesn't apply to that store.
- `kZmallDefaultBranchSlug` (an older `"ayat"` fallback) no longer exists in the current constants — there is **no fallback**; unmapped = skipped.

```dart
// lib/cart/components/body.dart:488-492
final String? branchSlug = zmallBranchSlugForStore(cart!.storeId);
if (branchSlug == null) {
  // Non-POS store — Odoo availability does not apply.
  return _CartAvailability(true, null);
}
```

---

## 5. How the App Finds the Odoo Product Id

Every `Item` in the cart carries an `odooProductId` (the Odoo `product.template` id). Finding it is a **3-layer fallback** plus a **7-key scan**, and once found it is **persisted** so it survives app restarts.

### 5.1 The `Item` model — `lib/models/cart.dart`

Field + constructor (lines 222, 232):

```dart
Item({ ..., this.odooProductId });
int? odooProductId;
```

Parsing in `Item.fromJson` (lines 243-245) — **three-way fallback**:

```dart
odooProductId: parseOdooProductId(json['odoo_product_id']) ??
    parseOdooProductId(json['pos_id']) ??
    extractOdooProductId(json),
```

Persistence in `Item.toJson` (lines 257-258) — written back so it survives `Service.save('cart', ...)`:

```dart
"odoo_product_id": odooProductId,
"pos_id": odooProductId,
```

### 5.2 `parseOdooProductId()` — `lib/models/cart.dart:262-267`

Tolerant int parser (accepts `int`, numeric strings, trims whitespace; returns `null` on anything else):

```dart
int? parseOdooProductId(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  final str = raw.toString().trim();
  return int.tryParse(str);
}
```

### 5.3 `extractOdooProductId()` — `lib/models/cart.dart:269-285`

Searches a raw API item map across **7 candidate keys** in priority order, for cases where the field name differs between APIs:

```dart
int? extractOdooProductId(Map<String, dynamic>? map) {
  if (map == null) return null;
  for (final key in [
    'odoo_product_id',
    'odoo_id',
    'pos_product_id',
    'template_id',
    'product_template_id',
    'odooProductId',
    'pos_id',
  ]) {
    final val = map[key];
    final parsed = parseOdooProductId(val);
    if (parsed != null) return parsed;
  }
  return null;
}
```

### 5.4 Where the id is picked up (all "add to cart" sites)

Every screen that constructs a cart `Item` extracts the id from the raw product/store JSON:

| File | Line | Code |
|---|---|---|
| `lib/product/product_screen.dart` | 570 | `odooProductId: extractOdooProductId(item)` |
| `lib/item/components/body.dart` | 311 | `odooProductId: extractOdooProductId(widget.item)` |
| `lib/global/items/components/body.dart` | 730-731 | `odooProductId: extractOdooProductId(widget.item)` |
| `lib/notifications/notification_store.dart` | 325 | `odooProductId: extractOdooProductId(item)` |
| `lib/cart/components/body.dart` | 1751 | `odooProductId: extractOdooProductId(extraItems[index])` (add-on / "Perfect Pairing" items) |

### 5.5 Backfill for legacy cart lines — `lib/services/service.dart:490-492`

When items are merged into an existing cart (`addOrMergeCartItem`), a missing `odooProductId` is backfilled onto previously-saved cart lines so older carts still get checked:

```dart
// service.dart — merge path
// if existing item lacks odooProductId, copy it from the incoming item
```

---

## 6. The Availability Service

File: **`lib/services/zmall_availability_service.dart`** (230 lines). All HTTP + parsing lives here.

### 6.1 `ZmallProductAvailability` — one product's result (lines 8-53)

```dart
class ZmallProductAvailability {
  final int productId;
  final int quantity;            // requested quantity echo
  final bool available;
  final double? forecastedQuantity;
  final String? error;
}
```

**The threshold rule** (lines 46-52) — this decides "enough for my cart?":

```dart
bool get isAvailableForRequestedQuantity {
  if (!available) return false;
  final double? forecasted = forecastedQuantity;
  if (forecasted == null) return true;
  if (forecasted < 0) return true;   // -1 sentinel = "skip inventory check"
  return forecasted >= quantity;
}
```

So an item passes when: server said `available=true` **AND** (forecasted missing → ok, OR forecasted `-1` → ok, OR forecasted ≥ requested qty).

### 6.2 `ZmallAvailabilityResult` — whole request result (lines 55-87)

```dart
class ZmallAvailabilityResult {
  final bool success;
  final String? branch;
  final bool canCheckout;
  final List<ZmallProductAvailability> products;
  final String? error;

  List<ZmallProductAvailability> get unavailableProducts =>
      products.where((p) => !p.available).toList();
}
```

### 6.3 `ZmallAvailabilityCheckResult` — result + raw HTTP (lines 89-106)

Used for debugging: carries `result`, `requestUrl`, `requestBody`, `statusCode` (`-1` on network exception), and `rawResponse`.

### 6.4 `check()` and `checkWithRaw()` (lines 108-229)

```dart
static Future<ZmallAvailabilityResult?> check({
  required String branchSlug,
  required List<Map<String, dynamic>> products,
  int timeoutSeconds = 15,
}) async {
  final raw = await checkWithRaw(branchSlug: branchSlug, products: products, timeoutSeconds: timeoutSeconds);
  return raw.result;   // null = network/timeout
}
```

`checkWithRaw` is the real implementation:
- URL: `"$kZmallOdooBaseUrl/zmall_order/$branchSlug"` → `http://196.191.117.85:9070/zmall_order/<slug>` (line 132)
- Body: pretty-printed JSON `{"products": products}` (lines 133-134)
- Headers: `Content-Type: application/json`, `Accept: application/json` (lines 148-151)
- `http.post(...).timeout(Duration(seconds: timeoutSeconds))` → throws `TimeoutException` (lines 145-159)
- Logs every exchange through `BackendLogger` (request / response / pretty JSON / errors)
- Non-200 → `ZmallAvailabilityResult(success:false, canCheckout:false, error: ...)` (lines 185-203)
- 200 → `ZmallAvailabilityResult.fromJson(jsonDecode(...))` (lines 205-214)
- Exception → `ZmallAvailabilityCheckResult(result: null, statusCode: -1, rawResponse: "Exception: $e")` (lines 215-228)

---

## 7. The Cart Screen Flow (App → Odoo)

File: **`lib/cart/components/body.dart`**. This is the heart of the integration.

### 7.1 Helper container — `_CartAvailability` (lines 36-41)

```dart
class _CartAvailability {
  const _CartAvailability(this.available, this.result);
  final bool? available;                        // true / false / null(unknown)
  final ZmallAvailabilityResult? result;        // raw result, used by the popups
}
```

### 7.2 The core check — `_fetchCartAvailability()` (lines 483-533)

Shared by both the tap-time gate and the silent auto-check. Returns:
- `available == true`  → all items available, checkout allowed
- `available == false` → block (out of stock OR missing Odoo ids)
- `available == null`  → could not verify (network/server error) — **do not hard-block**

```dart
Future<_CartAvailability> _fetchCartAvailability() async {
  if (cart == null || cart!.items == null || cart!.items!.isEmpty)
    return _CartAvailability(true, null);

  final String? branchSlug = zmallBranchSlugForStore(cart!.storeId);  // Odoo? which branch?
  if (branchSlug == null)
    return _CartAvailability(true, null);       // non-POS → skip

  // Build products[] from cart items using odooProductId
  for (final item in cart!.items!) {
    final int? odooProductId = item.odooProductId;
    if (odooProductId == null) { itemsMissingOdooId.add(item); continue; }
    products.add({ "product_id": odooProductId, "quantity": item.quantity ?? 1 });
  }

  if (itemsMissingOdooId.isNotEmpty)
    return _CartAvailability(false, null);      // hard-block: some items untrackable

  if (products.isEmpty)
    return _CartAvailability(true, null);

  final result = await ZmallAvailabilityService.check(branchSlug: branchSlug, products: products);

  if (result == null || !result.success)
    return _CartAvailability(null, null);       // network/error → don't hard-block

  return _CartAvailability(
    result.canCheckout &&
        result.products.every((p) => p.isAvailableForRequestedQuantity),
    result,
  );
}
```

### 7.3 Silent auto-check — `_refreshAvailability()` (lines 436-452)

Runs on cart load (`getCart`) and after **every** cart mutation (qty +/−, remove, stock adjustment). Locks/unlocks the Checkout button and surfaces the "You have X left" popup:

```dart
Future<void> _refreshAvailability() async {
  if (!mounted) return;

  final _CartAvailability availability = await _fetchCartAvailability();
  final bool? available = availability.available;
  final bool block = available != null && !available;
  if (!mounted) return;
  if (_checkoutBlocked != block) {
    setState(() => _checkoutBlocked = block);
  }
  _debugDumpCart(available);
  _maybeShowStockLeftNotification(availability.result);
}
```

### 7.4 Tap-time gate — `_checkAvailability()` (lines 344-434)

Runs when the user taps **Checkout**. Same branch/`products[]` build, then:

1. `branchSlug == null` → allow (not an Odoo store).
2. Items **missing** `odoo_product_id` → logs via `BackendLogger`, shows *"Some items are missing store inventory IDs. Remove them and add again from the product list."* → **block**.
3. `result == null` → *"Could not verify item availability. Please check your connection and try again."* → **block**.
4. `!result.success` → shows `result.error ?? "Availability check failed."` → **block**.
5. `!canCheckout || any item fails isAvailableForRequestedQuantity` → **`StockAvailabilityDialog`** (see §8) → **block until user adjusts or reviews**.
6. Otherwise → proceed to `DeliveryScreen`.

### 7.5 Checkout button UX (lines 698-799)

```
title: _checkoutBlocked ? "Out of stock"
      : _checkingAvailability ? "Checking stock..."
      : "Checkout"
enabled: !_checkoutBlocked
press: if (_checkingAvailability || _checkoutBlocked) {}  // no-op
       else {
         setState(_checkingAvailability = true);
         if (!await _checkAvailability()) return;   // blocked → stay on cart
         // location check, store open check...
         Navigator.pushNamed(context, DeliveryScreen.routeName);
       }
```

### 7.6 Stock adjustment (reducing the cart)

- **Per item** — `_applyStockAdjustment(item, maxAvailable)` (lines 578-593): sets qty to `maxAvailable`, recomputes price from unit price, saves cart, recalculates total, re-runs `_refreshAvailability()`.
- **Adjust All** — `_applyAllStockAdjustments(result)` (lines 595-612): loops every cart item, matches it to the result by `productId == odooId`, and for every item that is **not** available for the requested qty but has `forecasted_quantity > 0`, calls `_applyStockAdjustment(item, forecasted.toInt())`. Then re-checks.

```dart
void _applyAllStockAdjustments(ZmallAvailabilityResult result) {
  for (final item in cart!.items!) {
    final int? odooId = item.odooProductId;
    if (odooId == null) continue;
    for (final product in result.products) {
      if (product.productId == odooId && !product.isAvailableForRequestedQuantity) {
        final double forecasted = product.forecastedQuantity ?? 0;
        if (forecasted > 0) _applyStockAdjustment(item, forecasted.toInt());
        break;
      }
    }
  }
  _refreshAvailability();
}
```

### 7.7 "You have X left" surplus popup — `_maybeShowStockLeftNotification()` (lines 535-576)

When Odoo reports **more** stock than is currently in the cart (e.g. cart has 5, forecast is 10), the app tells the user *"You have 5 left"* — i.e. `forecasted_quantity − cart quantity` more units are available. A signature (`itemId:forecasted:cartQty` joined by `|`) is kept in `_lastStockLeftSignature` so the popup only fires once per state change (not on every rebuild/refresh).

```dart
void _maybeShowStockLeftNotification(ZmallAvailabilityResult? result) {
  if (!mounted || result == null || cart == null) return;

  final List<StockLeftItem> stockLeftItems = [];
  for (final item in cart!.items!) {
    final int? odooId = item.odooProductId;
    if (odooId == null) continue;
    for (final product in result.products) {
      if (product.productId == odooId) {
        final double forecasted = product.forecastedQuantity ?? 0;
        final int cartQty = item.quantity ?? 1;
        if (forecasted > cartQty) {
          stockLeftItems.add(StockLeftItem(
            item: item, forecastedQty: forecasted.toInt(), cartQty: cartQty));
        }
        break;
      }
    }
  }

  if (stockLeftItems.isEmpty) return;

  final String signature = stockLeftItems
      .map((s) => '${s.item.id}:${s.forecastedQty}:${s.cartQty}')
      .join('|');
  if (signature == _lastStockLeftSignature) return;
  _lastStockLeftSignature = signature;

  StockLeftNotification.show(context: context, items: stockLeftItems);
}
```

### 7.8 Debug dump — `_debugDumpCart()` (lines 456-476)

`kDebugMode`-only console dump printed with `debugPrintSynchronously` under `===== CART DEBUG =====`. Shows: `storeId` (trimmed), `branchSlug` (or `"NOT MAPPED: availability check is SKIPPED, checkout stays open"`), each item's qty + `odoo_product_id` (or `"null <-- cannot be checked"`), availability state (`UNKNOWN → not blocking` / `available → UNLOCKED` / `NOT available → LOCKED`), and `_checkoutBlocked`. Read this with `flutter run` (debug) to debug any store that "should" be checked but isn't.

---

## 8. The Two Popups / Dialogs

### 8.1 `StockAvailabilityDialog` — "Item Stock Notice" (out of stock)

File: **`lib/widgets/stock_availability_dialog.dart`** (379 lines).

- `StockItemIssue` (lines 6-20): `item`, `requestedQty`, `availableQty`, `isCompletelyOutOfStock`, `errorMessage`.
- **Issue building** (`show()`, lines 36-81): for each cart item with a non-null `odooProductId`, matches result products where `p.productId == odooId && !p.isAvailableForRequestedQuantity`. `available = forecasted > 0 ? forecasted.toInt() : 0`; `isCompletelyOutOfStock = available <= 0`.
- **UI**: orange `inventory_2` icon, title "Item Stock Notice", description *"Some items in your cart exceed available stock at the `{BRANCH}` branch."* Per item: name, "Requested: N", badge **"Out of stock"** (red) or **"In stock: N"** (green). Per-item **"Set to N"** button (calls `onAdjustItem(item, availableQty)`), footer **"Review Cart"** + **"Adjust All"** (only if at least one issue is partially available → `canAutoAdjustAny`).

### 8.2 `StockLeftNotification` — "Good News" / "You have X left" (surplus stock)

File: **`lib/widgets/stock_left_notification.dart`** (259 lines).

- `StockLeftItem` (lines 7-20): `item`, `forecastedQty`, `cartQty`, and `int get leftQty => forecastedQty - cartQty;` ← this is the "X" in "You have X left".
- **UI**: green `inventory_2` icon, title "Good News", per item: name + **"You have N left"** + badge **"In stock: N"**. Single **"OK"** button.

---

## 9. Response Parsing & the -1 Sentinel

### 9.1 Tolerant parsing — `ZmallProductAvailability.fromJson` (lines 17-34)

- `forecasted_quantity`: accepts `num` directly, or parses from a string; `null` stays `null`.
- `quantity`: accepts `requested_quantity` **or** `quantity`, as `int` or numeric string.
- `product_id`: `int` or numeric string; falls back to `0`.
- `available`: defaults to `false` if absent.

### 9.2 The `-1` sentinel

`forecasted_quantity = -1` is the server's **"inventory check skipped"** marker. `isAvailableForRequestedQuantity` treats it as available:

```dart
if (forecasted < 0) return true;   // -1 sentinel = "skip inventory check"
```

This means when a branch disables `skip_inventory_check`, every item passes the *quantity* check (but `available` must still be `true`, and unknown products are still flagged).

---

## 10. Error Handling Rules

| Situation | Result in app | Checkout |
|---|---|---|
| Store not in `kZmallBranchSlugs` | check skipped entirely | **allowed** |
| Item has no `odoo_product_id` | toast *"Some items are missing store inventory IDs..."* (tap-time) / silent block (auto-check) | **blocked** |
| Network error / timeout (`result == null`) | *"Could not verify item availability. Please check your connection and try again."* | **blocked** (tap-time) / not hard-blocked (auto-check → button stays enabled) |
| Server returns `success:false` | shows `result.error` | **blocked** |
| `can_checkout:false` or any item fails the quantity rule | **StockAvailabilityDialog** | **blocked until adjusted** |
| `forecasted_quantity > cart qty` | **StockLeftNotification** "You have X left" | unaffected (already available) |

Design intent: the **auto** check never hard-blocks on *network* problems (can't reach Odoo ≠ out of stock), it only locks the button when the server **positively** says there's a problem. The **tap-time** check is stricter — it blocks and shows a message so the user isn't surprised later.

---

## 11. File-by-File Inventory

### `lib/` (all Odoo code)

| File | Lines | Role |
|---|---|---|
| `lib/utils/constants.dart` | 46-69 | Odoo base URL, branch-slug map, `zmallBranchSlugForStore`, `isOdooAvailabilityStore` |
| `lib/models/cart.dart` | 222, 232, 243-245, 257-258, 262-285 | `Item.odooProductId`, `parseOdooProductId`, `extractOdooProductId`, JSON round-trip |
| `lib/services/zmall_availability_service.dart` | whole file | HTTP client + 3 result models + threshold logic |
| `lib/cart/components/body.dart` | 344-612, 1750 | check gate, auto-check, stock adjustment, "You have X left" popup, add-on items |
| `lib/widgets/stock_availability_dialog.dart` | whole file | "Item Stock Notice" out-of-stock sheet |
| `lib/widgets/stock_left_notification.dart` | whole file | "Good News / You have X left" surplus sheet |
| `lib/product/product_screen.dart` | 570 | extract `odooProductId` on add-to-cart |
| `lib/item/components/body.dart` | 311 | extract `odooProductId` on add-to-cart |
| `lib/global/items/components/body.dart` | 730-731 | extract `odooProductId` on add-to-cart |
| `lib/notifications/notification_store.dart` | 325 | extract `odooProductId` on add-to-cart |
| `lib/services/service.dart` | 490-492 | backfill `odooProductId` when merging legacy cart lines |
| `lib/kifiya/kifiya_screen.dart` | 1981 | ⚠️ unrelated Telebirr Odoo server |

### Docs & specs

| File | Role |
|---|---|
| `docs/zmall-branch-availability.md` | Original feature design doc (older; predates the surplus popup and the current constants) |
| `zmall_files/zmall_doc/STORES_COMPLETE_CODE_GUIDE.md` | Store API guide, documents `odoo_product_id` in the product JSON and add-to-cart wiring |
| `Zmall_Branch_Availability.postman_collection.json` | The API contract (base URL `http://localhost:8069`, branches `ayat`/`mexico`, all success + error cases) |

---

## 12. End-to-End Sequence Diagram

```
USER                  CART SCREEN (body.dart)              ODOO SERVER
 │  taps Checkout           │                                   │
 │─────────────────────────►│ _checkAvailability()             │
 │                          │  branchSlug = zmallBranchSlugForStore(storeId)
 │                          │  products = cart items → {product_id: odooProductId, quantity}
 │                          │                                   │
 │                          │  POST /zmall_order/<slug> ───────►│
 │                          │  {"products":[...]}              │ find pos.config by slug
 │                          │                                   │ look up warehouse stock
 │                          │  ◄──────────── 200 JSON ─────────│ {success, branch,
 │                          │                                   │  can_checkout, products[
 │                          │                                   │   {product_id, quantity,
 │                          │                                   │    available,
 │                          │                                   │    forecasted_quantity}]}
 │                          │
 │                          │  can_checkout == false ?
 │                          │     → StockAvailabilityDialog ──► │
 │◄─────────────────────────┤       "Set to N" / "Adjust All"   │
 │                          │     → auto-reduce cart qty to forecasted
 │                          │  forecasted > cart qty ?
 │                          │     → StockLeftNotification ─────►│
 │◄─────────────────────────┤       "You have 5 left"           │
 │                          │  all ok → navigate to Delivery    │
 │◄─────────────────────────┤                                   │
```

---

## 13. Git History / How the Feature Evolved

```
04736e4  backup: full working tree snapshot (Odoo + unrelated WIP)     Aug 16
8be469e  feat: Zmall branch availability check against Odoo            Aug 16   ← initial feature
5d880ea  docs: add stores complete code guide with odoo_product_id     Aug 16
8a74bab  feat: pass odoo_product_id from product, item, store and      Aug 16   ← wire id into 4 screens
         notification screens
a6d5ff1  Add zmall branch availability feature                         Aug 19   ← major update: dialog,
                                                                                 service rewrite, Postman,
                                                                                 backfill, constants
f37f539  odoo                                                          Aug 19   ← mostly chatbot feature;
                                                                                 constants touched (whitespace)
```

Uncommitted working-tree changes (current feature): the **"You have X left"** popup — `lib/widgets/stock_left_notification.dart` (new file) + `lib/cart/components/body.dart` (`_CartAvailability`, `_fetchCartAvailability`, `_maybeShowStockLeftNotification`, `_lastStockLeftSignature`).

---

## 14. What Is NOT in This Repo

- **The Odoo server code itself.** There are no `.py` files, no Odoo modules (`__manifest__.py`, `odoo/`), no `backend/` directory. The server-side implementation of `/zmall_order/<branch_slug>` lives on the backend senior's side and is **remote** (`http://196.191.117.85:9070`). Its contract is pinned by the Postman collection.
- **A test suite** for the feature. `test/widget_test.dart` is only the default counter smoke test.

---

## 15. Open Items & Gotchas

| # | Item | Notes |
|---|---|---|
| 1 | **Cleartext HTTP** | Both Odoo URLs are plain `http://`. Android may need a `usesCleartextTraffic` exception and iOS an ATS exception for devices to reach `196.191.117.85:9070`. |
| 2 | **Branch slug map is hard-coded** | Adding a new Odoo store requires editing `kZmallBranchSlugs` in `constants.dart`. Unmapped stores silently skip the check. |
| 3 | **Backend must send `odoo_product_id`** | Every item in the store/product/notification APIs must include it, or the item is blocked at checkout ("missing store inventory IDs"). |
| 4 | **Dead code** | `kZmallOdooProductIdField` and `isOdooAvailabilityStore()` are defined but never used elsewhere in `lib/`. |
| 5 | **`checkWithRaw`'s debug panel** | The doc comment mentions a debug panel caller, but none exists yet; only `check()` calls it. |
| 6 | **Stale doc reference** | Service + Postman reference `docs/superpowers/specs/2026-08-11-zmall-branch-availability-design.md`, but that path does not exist in the repo; the real design doc is `docs/zmall-branch-availability.md`. |
| 7 | **Two stores → same branch** | `5b406b24...` and `6a6b0c4a...` both map to `mexico`. |
| 8 | **Duplicate JSON key** | `Item.toJson` writes both `odoo_product_id` and `pos_id` with the same value (harmless redundancy for the backfill fallback). |
| 9 | **`-1` sentinel semantics** | If the server omits `forecasted_quantity` entirely, `null` is treated as available; `-1` means "skip check"; only `>= 0` is compared against quantity. |
| 10 | **One source of truth** | The decision "is this store Odoo?" is 100% the `kZmallBranchSlugs` map — nothing is fetched from the backend to decide it. |

---

## One-Line Summary

**Before:** the app never knew branch-level stock → orders could be placed for out-of-stock items.

**Now:** on the cart screen, before checkout, the app maps the store's `store_id` → branch slug via `kZmallBranchSlugs`, builds `{product_id, quantity}` from each cart item's persisted `odoo_product_id`, and asks Odoo `POST /zmall_order/<branch_slug>`. It **blocks checkout** and shows "Item Stock Notice" when stock is short (auto-reducing the cart to the forecasted quantity), and shows **"You have X left"** when Odoo forecasts more stock than is in the cart.