# ZMall ↔ Odoo Stock Availability: How It Works & How to Port It

Reference implementation: branch **`abyi_cyber_source`**.
Target: any other branch (e.g. `ai_mcp_combo`), which still uses the **old hardcoded-slug** version.

---

## 1. What it does

For stores linked to an Odoo POS branch (e.g. *Mexico*, *Ayat*), the cart asks the Odoo server
whether each item is in stock **before checkout**. If something isn't available:

- the Checkout button turns into **"Out of stock"** and is disabled,
- tapping checkout shows a **StockAvailabilityDialog** that lets the user lower quantities to what's available,
- raising a quantity above the Odoo forecast shows a **"Limited Stock"** notification.

Stores that aren't linked to Odoo (no order URL) skip the check entirely.

---

## 2. Where the Odoo URL comes from (backend-driven)

The ZMall backend returns the Odoo endpoint for the store in
`POST {baseUrl}/api/user/user_get_store_product_item_list` (body `{"store_id": "<id>"}`):

```json
{
  "success": true,
  "zmll_order_url": "http://196.191.117.85:9090/zmall_order/mexico",
  "store": { "zmll_order_url": "http://196.191.117.85:9090/zmall_order/mexico", ... },
  "products": [ ... ]
}
```

- Key is **`zmll_order_url`** (backend typo, kept as-is). `zmall_order_url` is accepted too.
- It is read from the root **or** from `store`.
- If the backend sends nothing, the store isn't treated as an Odoo store (unless it's in the hardcoded fallback map; see §4).

---

## 3. The Odoo request

```
POST http://196.191.117.85:9090/zmall_order/<branch_slug>
Content-Type: application/json
Accept: application/json
X-Odoo-Database: zmall_odoo        <-- REQUIRED
```

Body:

```json
{ "products": [ { "product_id": 123, "quantity": 2 } ] }
```

`product_id` is the **Odoo** product id (see §6), not the ZMall item id.

Response:

```json
{
  "success": true,
  "branch": "mexico",
  "can_checkout": true,
  "products": [
    { "product_id": 123, "requested_quantity": 2, "available": true, "forecasted_quantity": 20 }
  ]
}
```

### ⚠️ The `X-Odoo-Database` header

The Odoo server hosts several databases. Without the header it can't pick one and returns:

```
HTTP 404: "No database is selected and the requested URL was not found in the server-wide controllers."
```

Verified with curl:

| Request | Result |
|---|---|
| no header | **404** HTML page |
| `?db=zmall_odoo` query param | **404** (doesn't work) |
| `X-Odoo-Database: zmall_odoo` | **200** `{"success": true, ...}` |

Quick test:

```bash
curl -X POST http://196.191.117.85:9090/zmall_order/mexico \
  -H 'Content-Type: application/json' \
  -H 'X-Odoo-Database: zmall_odoo' \
  -d '{"products":[]}'
```

(Backend alternative: configure Odoo `dbfilter` / a single DB so the header isn't needed. Keeping the header in the app does no harm.)

### Availability rule per product

```dart
bool get isAvailableForRequestedQuantity {
  if (!available) return false;
  if (forecasted == null) return true;
  if (forecasted < 0) return true;      // -1 = "skip inventory check"
  return forecasted >= quantity;
}
```

The cart can check out only if `can_checkout == true` **and** every product passes the rule above.

---

## 4. Flow end-to-end

```
Product screen (_loadPage)
  └─ user_get_store_product_item_list ──► extractOrderUrl(result)
        ├─ ZmallAvailabilityService.setStoreOrderUrl(storeId, url)   (in-memory cache)
        └─ if cart is for this store: cart.zmallOrderUrl = url; save cart

Product screen (addToCart): new Cart gets zmallOrderUrl from the cache

Cart screen
  ├─ getStoreDetail() (same endpoint) ──► extractOrderUrl ──► cache + cart.zmallOrderUrl
  │     └─ _refreshAvailability()            (silent, locks the button)
  ├─ quantity +/- / remove ──► _refreshAvailability(showStockLeftNotification: true on +)
  └─ Checkout tap ──► _checkAvailability()   (shows errors / StockAvailabilityDialog)
```

### URL resolution order (`_resolveOdooOrderUrl` in cart body)

1. `storeDetail` response → `extractOrderUrl(storeDetail)`
2. `cart.zmallOrderUrl` (persisted in the saved cart as `zmll_order_url`)
3. in-memory cache `ZmallAvailabilityService.getStoreOrderUrl(storeId)`
4. fallback: hardcoded `kZmallBranchSlugs[storeId]` → `"$kZmallOdooBaseUrl/zmall_order/<slug>"`
5. none → **non-POS store, skip check** (return available)

If nothing resolves and `storeDetail` hasn't loaded yet, `_checkAvailability()` calls `getStoreDetail()` once and tries again.

### Result handling

| Situation | `_refreshAvailability` (silent) | `_checkAvailability` (on Checkout tap) |
|---|---|---|
| Non-Odoo store | available | proceed |
| An item has no Odoo product id | **block** | red message "Some items are missing store inventory IDs…", stop |
| Network error / `result == null` | don't block (`null`) | red "Could not verify item availability…", stop |
| `success == false` / HTTP ≠ 200 | don't block | red message with `error` from Odoo, stop |
| Out of stock / not enough | **block** → button "Out of stock" | `StockAvailabilityDialog` (adjust one / adjust all), stop |
| All OK | unblock | continue checkout |

Adjusting stock (`_applyStockAdjustment`) sets the quantity to the forecast, scales the price by the unit price, saves the cart, recalculates, and re-checks availability.

---

## 5. Files & exact code (from `abyi_cyber_source`)

### 5.1 `lib/utils/constants.dart`

```dart
/// Fallback only; the real URL (incl. port 9090) comes from the backend.
const String kZmallOdooBaseUrl = "http://196.191.117.85:9070";

/// Odoo database name, sent as the `X-Odoo-Database` header. Without it the
/// Odoo server can't pick a database and returns 404 for /zmall_order/<slug>.
const String kZmallOdooDatabase = "zmall_odoo";

/// Fallback map store_id -> Odoo branch slug (used only if backend sends no URL).
const Map<String, String> kZmallBranchSlugs = {
  "6a6b069856bef41124383c9e": "ayat",
  "6a6b0c4a56bef41124383ca2": "mexico",
};

String? zmallBranchSlugForStore(String? storeId) { ... }   // unchanged
bool isOdooStoreByName(String? storeName) { ... }          // unchanged
```

> Note: backend URLs use port **9090**; the fallback constant is still **9070**. Change it to 9090 if the fallback is needed.

### 5.2 `lib/models/cart.dart`: `Cart` gets `zmallOrderUrl`

```dart
Cart({ ..., this.zmallOrderUrl });
String? zmallOrderUrl;

// fromJson
zmallOrderUrl: json["zmll_order_url"] ?? json["zmall_order_url"],

// toJson
"zmll_order_url": zmallOrderUrl,
```

(`Item.odooProductId`, `parseOdooProductId`, `extractOdooProductId` already exist on both branches.)

### 5.3 `lib/services/zmall_availability_service.dart`

Replace the `ZmallAvailabilityService` class (the model classes `ZmallProductAvailability` /
`ZmallAvailabilityResult` are unchanged):

```dart
class ZmallAvailabilityService {
  /// In-memory cache mapping store_id -> zmll_order_url
  static final Map<String, String> _storeOrderUrlCache = {};

  static void setStoreOrderUrl(String storeId, String url) {
    if (storeId.isNotEmpty && url.isNotEmpty) {
      _storeOrderUrlCache[storeId.trim()] = url.trim();
    }
  }

  static String? getStoreOrderUrl(String storeId) =>
      _storeOrderUrlCache[storeId.trim()];

  /// Reads zmll_order_url / zmall_order_url from the root or from `store`.
  static String? extractOrderUrl(dynamic data) {
    if (data == null || data is! Map) return null;
    final dynamic root = data['zmll_order_url'] ?? data['zmall_order_url'];
    if (root is String && root.trim().isNotEmpty) return root.trim();
    if (data['store'] is Map) {
      final store = data['store'] as Map;
      final dynamic storeUrl =
          store['zmll_order_url'] ?? store['zmall_order_url'];
      if (storeUrl is String && storeUrl.trim().isNotEmpty) {
        return storeUrl.trim();
      }
    }
    return null;
  }

  /// [orderUrl]: full URL from the backend, a path ("/zmall_order/x"),
  /// or a bare slug. Falls back to [branchSlug].
  static Future<ZmallAvailabilityResult?> check({
    String? orderUrl,
    String? branchSlug,
    required List<Map<String, dynamic>> products,
    int timeoutSeconds = 15,
  }) async {
    final String? rawUrl = (orderUrl != null && orderUrl.trim().isNotEmpty)
        ? orderUrl.trim()
        : (branchSlug != null && branchSlug.trim().isNotEmpty)
            ? branchSlug.trim()
            : null;
    if (rawUrl == null) return null;

    final String url;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      url = rawUrl;
    } else if (rawUrl.startsWith('/')) {
      url = "$kZmallOdooBaseUrl$rawUrl";
    } else {
      url = "$kZmallOdooBaseUrl/zmall_order/$rawUrl";
    }

    final requestBody = jsonEncode({"products": products});
    final headers = <String, String>{
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-Odoo-Database": kZmallOdooDatabase,
    };
    final stopwatch = Stopwatch()..start();

    try {
      BackendLogger.request(method: 'POST', url: url, headers: headers, body: requestBody);
      final response = await http
          .post(Uri.parse(url), headers: headers, body: requestBody)
          .timeout(Duration(seconds: timeoutSeconds), onTimeout: () {
        throw TimeoutException("The connection has timed out!");
      });
      BackendLogger.response(
        method: 'POST', url: url, statusCode: response.statusCode,
        duration: stopwatch.elapsed, body: response.body,
      );

      if (response.statusCode != 200) {
        Map<String, dynamic>? decoded;
        try { decoded = jsonDecode(response.body) as Map<String, dynamic>; } catch (_) {}
        return ZmallAvailabilityResult(
          success: false,
          canCheckout: false,
          error: decoded?["error"] ??
              "Availability check failed (HTTP ${response.statusCode})",
        );
      }
      return ZmallAvailabilityResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      BackendLogger.error(method: 'POST', url: url,
          error: '${stopwatch.elapsed.inMilliseconds} ms -> $e');
      return null;
    }
  }
}
```

### 5.4 `lib/product/product_screen.dart`

Add the import:

```dart
import 'package:zmall/services/zmall_availability_service.dart';
```

`addToCart`: seed the new cart with the cached URL:

```dart
void addToCart(item, destination, storeLocation, storeId) {
  final String? cachedOdooUrl =
      ZmallAvailabilityService.getStoreOrderUrl(storeId.toString());
  cart = Cart(
    ...,
    zmallOrderUrl: cachedOdooUrl,
  );
  Service.save('cart', cart!.toJson());
}
```

`_loadPage`: right after `getStoreProductList` succeeds:

```dart
if (result != null && result['success'] == true) {
  final String? odooUrl = ZmallAvailabilityService.extractOrderUrl(result);
  if (odooUrl != null && odooUrl.isNotEmpty && widget.store['_id'] != null) {
    final String sId = widget.store['_id'].toString();
    ZmallAvailabilityService.setStoreOrderUrl(sId, odooUrl);
    if (cart != null && cart!.storeId == sId) {
      cart!.zmallOrderUrl = odooUrl;
      Service.save('cart', cart!.toJson());
    }
  }
  ...
```

### 5.5 `lib/cart/components/body.dart`

**a) After `getStoreDetail()` succeeds** (in the method that loads store detail):

```dart
if (data != null && data['success'] == true) {
  final String? odooUrl = ZmallAvailabilityService.extractOrderUrl(data);
  if (odooUrl != null && odooUrl.isNotEmpty && cart?.storeId != null) {
    ZmallAvailabilityService.setStoreOrderUrl(cart!.storeId!, odooUrl);
    cart!.zmallOrderUrl = odooUrl;
  }
  setState(() { storeDetail = data; ... });
  Service.save('cart', cart!.toJson());
  Service.save('aliexpressCart', aliexpressCart?.toJson());
  _refreshAvailability();          // <-- new
}
```

**b) New helper:**

```dart
String? _resolveOdooOrderUrl() {
  String? url = ZmallAvailabilityService.extractOrderUrl(storeDetail);
  if (url != null && url.isNotEmpty) return url;

  if (cart?.zmallOrderUrl != null && cart!.zmallOrderUrl!.isNotEmpty) {
    return cart!.zmallOrderUrl;
  }

  if (cart?.storeId != null) {
    url = ZmallAvailabilityService.getStoreOrderUrl(cart!.storeId!);
    if (url != null && url.isNotEmpty) return url;
  }

  final String? fallbackSlug = zmallBranchSlugForStore(cart?.storeId);
  if (fallbackSlug != null && fallbackSlug.isNotEmpty) {
    return "$kZmallOdooBaseUrl/zmall_order/$fallbackSlug";
  }
  return null;
}
```

**c) `_checkAvailability()`**: replace the slug lookup at the top:

```dart
// OLD
final String? branchSlug = zmallBranchSlugForStore(cart!.storeId);
if (branchSlug == null) { return true; }

// NEW
String? orderUrl = _resolveOdooOrderUrl();
if (orderUrl == null && storeDetail == null) {
  final data = await getStoreDetail();
  if (data != null && data['success'] == true) {
    if (mounted) setState(() => storeDetail = data);
    final String? odooUrl = ZmallAvailabilityService.extractOrderUrl(data);
    if (odooUrl != null && odooUrl.isNotEmpty && cart?.storeId != null) {
      ZmallAvailabilityService.setStoreOrderUrl(cart!.storeId!, odooUrl);
      cart!.zmallOrderUrl = odooUrl;
    }
    orderUrl = _resolveOdooOrderUrl();
  }
}
if (orderUrl == null) {
  // Non-POS store: Odoo availability does not apply.
  return true;
}
```

Further down in the same method:

```dart
BackendLogger.error(method: 'POST', url: orderUrl, ...);   // was '$kZmallOdooBaseUrl/zmall_order/$branchSlug'

final result = await ZmallAvailabilityService.check(
  orderUrl: orderUrl,                                     // was branchSlug: branchSlug
  products: products,
);
```

**d) `_fetchCartAvailability()`**: same swap:

```dart
final String? orderUrl = _resolveOdooOrderUrl();          // was zmallBranchSlugForStore(...)
if (orderUrl == null) return _CartAvailability(true, null);
...
final result = await ZmallAvailabilityService.check(
  orderUrl: orderUrl,
  products: products,
);
```

`_refreshAvailability`, `_maybeShowStockLeftNotification`, `_applyStockAdjustment`,
`_applyAllStockAdjustments`, `StockAvailabilityDialog` (`lib/widgets/stock_availability_dialog.dart`)
and the Checkout button (`_checkoutBlocked` → "Out of stock") are **the same on both branches**;
no change needed.

---

## 6. Odoo product id on cart items

Each cart `Item` carries `odooProductId`, taken from the product JSON when the item is added
(`odooProductId: extractOdooProductId(item)` in `product_screen.dart`). Keys tried, in order:

`odoo_product_id`, `odoo_id`, `pos_product_id`, `template_id`, `product_template_id`, `odooProductId`, `pos_id`

Saved in the cart as both `odoo_product_id` and `pos_id`. If any item in an Odoo store has no id,
checkout is blocked with *"Some items are missing store inventory IDs. Remove them and add again from the product list."*

---

## 7. Porting checklist (to another branch)

- [ ] `constants.dart`: add `kZmallOdooDatabase = "zmall_odoo"` (optionally fix fallback port to 9090)
- [ ] `cart.dart`: add `zmallOrderUrl` field + `fromJson` / `toJson` (`zmll_order_url`)
- [ ] `zmall_availability_service.dart`: cache, `extractOrderUrl`, `check(orderUrl:, branchSlug:)`, **`X-Odoo-Database` header**
- [ ] `product_screen.dart`: import, `addToCart` seeds URL, `_loadPage` stores URL
- [ ] `cart/components/body.dart`: store URL after `getStoreDetail` + `_refreshAvailability()`, add `_resolveOdooOrderUrl`, switch `_checkAvailability` and `_fetchCartAvailability` to `orderUrl`
- [ ] Search for other callers of `ZmallAvailabilityService.check(branchSlug: ...)`: still valid, since `branchSlug` stays as a fallback param
- [ ] `flutter analyze`
- [ ] Test: Mexico store → add item → cart shows normal Checkout; set quantity above stock → "Out of stock" + dialog; logs show `POST .../zmall_order/mexico` with HTTP 200

### ⚠️ Don't copy these (unrelated test changes on `abyi_cyber_source`)

The same files on `abyi_cyber_source` also contain **store-closed bypasses** that are not part of this feature:

- `cart/components/body.dart`: `if (true) {` replacing the `now.isAfter(zmallOpen) && now.isBefore(zmallClose)` check
- `models/cart.dart`: `AbroadCart.isOpen: true` instead of `json['is_open']`
- `services/service.dart`: `isStoreOpen` / `storeOpen` always return `true`

Copy section by section as above. **Don't** `git checkout abyi_cyber_source -- <file>` for these files, or you'll bring the bypasses along.
