# Zmall Branch Availability Check — Full Picture

## 1. The Big Picture (what this is all about)

Zmall has **multiple physical branches** (stores). Each branch has its **own warehouse and its own stock** in Odoo. The same product can be in stock at Branch A but sold out at Branch B.

The problem: **the old app didn't know about branch-level stock.** A user could add items to their cart, go through checkout, and only later discover items were out of stock.

The goal of this feature: **before the user checks out, ask Odoo "does the branch for this store have enough stock of my cart items?" If not → block checkout and tell the user.**

The backend senior built a new endpoint on the **Odoo server** to answer that question, and gave a Postman collection as the spec/contract for how to call it. My job was to implement the **Flutter app side** of that contract.

---

## 2. The Endpoint (from the Postman collection)

### The call
```
POST http://196.191.117.85:9070/zmall_order/<branch_slug>
Content-Type: application/json

{ "products": [ { "product_id": 101, "quantity": 5 } ] }
```

### Key rules (from the Postman design)
- **Branch is determined ONLY by the URL path segment** (`<branch_slug>`), never by the request body.
- `product_id` is an **Odoo `product.template` id** — NOT the Mongo `_id` the app normally uses.
- Each branch is a `pos.config` in Odoo with a field `zmall_branch_slug` (e.g. `ayat`, `mexico`).

### Response contract
```
200 → { success, branch, can_checkout, products: [ { product_id, quantity, available, forecasted_quantity, error? } ] }

Per-item error (still 200): available=false, error="product not found" / "invalid quantity"
404 → unknown branch slug
400 → invalid JSON body
503 → branch has no warehouse set (misconfiguration)
skip_inventory_check ON → available=true, forecasted_quantity=-1 (sentinel = "not checked")
```

---

## 3. How It Worked BEFORE (the old flow)

```
User taps "Checkout" on the cart screen
        │
        ▼
┌──────────────────────────────────────────────┐
│ Cart screen (body.dart)                      │
│  - checks location is on                     │
│  - checks store open/close time              │
│  - navigates to DeliveryScreen               │
└──────────────────────────────────────────────┘
        │
        ▼
Delivery screen → Checkout screen (checkout_screen.dart)
        │
        ▼
┌──────────────────────────────────────────────┐
│ Checkout screen                             │
│  - calls backend: POST /api/user/get_order_cart_invoice │
│  - shows invoice + total                    │
│  - user taps "Place Order"                  │
│  - order is created                         │
└──────────────────────────────────────────────┘

✗ No stock check anywhere. Order could be placed
  even if the branch was out of stock.
```

The only "backend" the app talked to was the **main Zmall backend** (`BASE_URL = https://app.zmall.et` in `lib/utils/constants.dart`). The Odoo server was never involved in checkout.

---

## 4. How It Works NOW (the new flow)

```
User taps "Checkout" on the cart screen
        │
        ▼
┌──────────────────────────────────────────────┐
│ Cart screen (body.dart)                     │
│  1. location on?                            │
│  2. store open?                             │
│  3. ★ NEW: _checkAvailability()             │
│       ├─ pick branch_slug from store        │
│       ├─ build products[] from cart items   │
│       │   (using item.odoo_product_id)      │
│       ├─ POST /zmall_order/<branch_slug>    │
│       │   → to Odoo server (196.191.117.85:9070) │
│       ├─ can_checkout == true ?  ── yes ──► proceed ▼
│       └─ NO → show "out of stock" message, BLOCK ─┘
└──────────────────────────────────────────────┘
        │
        ▼
Delivery screen → Checkout screen (unchanged)
        │
        ▼
Backend invoice + Place Order (unchanged — reverted)
```

**What changed: only one new step added to the cart screen's Checkout button.** The invoice/place-order process in `checkout_screen.dart` was touched and then reverted to original (not related for now).

---

## 5. New Code Pieces (what I added)

### 5.1 Config — `lib/utils/constants.dart`
```dart
/// Odoo server address (NOT the regular Zmall backend)
const String kZmallOdooBaseUrl = "http://196.191.117.85:9070";

/// JSON field on each item carrying the Odoo product.template id
const String kZmallOdooProductIdField = "odoo_product_id";

/// Fallback branch slug if store isn't in the map
const String kZmallDefaultBranchSlug = "ayat";

/// Maps Zmall store_id -> Odoo pos.config.zmall_branch_slug
const Map<String, String> kZmallBranchSlugs = {
  // "5b3f76f2022985030cd3a437": "ayat",   ← TODO: fill real store ids
  // "5b406b24d2ddf8062d11b787": "mexico",
};
```

### 5.2 Model — `lib/models/cart.dart`
Added `odooProductId` to `Item` (read from `odoo_product_id` in JSON, saved back to cart storage) so the Odoo id survives cart persistence.

### 5.3 New service — `lib/services/zmall_availability_service.dart`
Does the HTTP call + parsing. Returns:
- `result.success` — request processed
- `result.canCheckout` — safe to checkout
- `result.products` / `result.unavailableProducts` — per-item detail
- `result.error` — top-level error (404/400/503 message)
- `null` — network/timeout

### 5.4 Cart screen — `lib/cart/components/body.dart`
```dart
Future<bool> _checkAvailability() async {
  // 1. branch_slug = kZmallBranchSlugs[cart.storeId] ?? default
  // 2. build products: [{product_id: item.odooProductId, quantity: item.quantity}]
  //    (items without odoo_product_id are skipped)
  // 3. result = ZmallAvailabilityService.check(branchSlug, products)
  // 4. null → network error, block
  //    !success → show error, block
  //    !canCheckout → show "out of stock", block
  //    else → allow
}
```
Called before navigating to DeliveryScreen.

### 5.5 Item constructors (5 files)
`item/components/body.dart`, `product/product_screen.dart`, `global/items/components/body.dart`, `notifications/notification_store.dart`, `cart/components/body.dart` — all now pass `odooProductId: item['odoo_product_id']` when building cart items.

---

## 6. Flow Diagram (end to end, app → Odoo)

```
        FLUTTER APP                                   ODOO SERVER
┌──────────────────────────────┐        HTTP       ┌─────────────────────────┐
│ Cart screen                  │   POST /zmall_order│                        │
│ └─ _checkAvailability() ────┼──────────────────►│ find pos.config by slug │
│    products=[{product_id,    │   {products:[...]} │ look up warehouse       │
│    quantity}]               │                   │ compute forecasted qty   │
│                              │◄──────────────────│ return can_checkout etc │
│ can_checkout?                │      200 JSON     └─────────────────────────┘
│   yes → go to delivery       │
│   no  → block + show message │
└──────────────────────────────┘
```

---

## 7. What Still Needs To Be Done (open items)

| Item | Who | Status |
|---|---|---|
| Fill real `store_id → branch_slug` values in `kZmallBranchSlugs` | You + senior | ⬜ TODO |
| Backend adds `odoo_product_id` to each item in store/product API JSON | Senior (backend) | ⬜ TODO |
| Confirm `http://196.191.117.85:9070` is reachable from devices (HTTP cleartext may need `usesCleartextTraffic`/ATS exception) | You + senior | ⬜ TODO |
| Decide if the check should ALSO run at the invoice step | You + senior | Reverted for now |
| Test against the Postman collection cases | You | ⬜ TODO |

---

## 8. One-Line Summary

**Before:** app never knew branch stock → orders could be placed for out-of-stock items.

**Now:** on the cart screen, before checkout, the app asks the Odoo server `POST /zmall_order/<branch_slug>` whether the cart's items are available at that store's branch, and **blocks checkout if not**.