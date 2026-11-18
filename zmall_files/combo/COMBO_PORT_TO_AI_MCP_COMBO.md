# Combo Order Port: `order_details` → `ai_mcp_combo`

**Date:** 2026-10-29
**Source:** `main_app/zmall_app`, branch `order_details` (HEAD `2ca021c`)
**Target:** `order_refund_new_zmall`, branch `ai_mcp_combo` (HEAD `ba20131`)
**Common ancestor:** `273f824` (feat: update payment and order details UI)
**Status:** Applied to the working tree, **not committed**. `flutter analyze lib` → **0 errors** (159 info/warnings, baseline was 167).

---

## 1. What was ported

All combo-order work from the 7 source commits after the common ancestor:

| Commit | Message |
|---|---|
| `e2c333f` | latest_branch |
| `51ec651` | final_combo |
| `7604f37` | latest |
| `ae806f8` | loading |
| `8d0aed1` | loading_finished |
| `6391121` | before adding order_detail_by_combom |
| `2ca021c` | add order detail screen changes |

Combo order = one checkout covering **two stores, one driver**. The user adds items from store A, then from store B. The app checks the distance between the stores, keeps both carts in a `ComboCart`, builds one combined invoice, and pays once. The orders list then groups the two child orders into one combo card.

### Method

- **Files the target had not touched since the ancestor** were copied from the source as they are.
- **Files both branches changed** were 3-way merged (`git merge-file`, base = `273f824`).
- Some target files had been converted from CRLF to LF. For those, base and source were normalized to LF before merging so the merge didn't conflict on every line.
- Each file keeps its original line endings.

---

## 2. New files (15 code/asset + 7 docs)

### Combo module — `lib/combo/`

| File | Lines | Purpose |
|---|---|---|
| `combo/combo_checkout_screen.dart` | 586 | `ComboCheckoutScreen`: loads the combined invoice for both stores, handles wallet use, then opens payment (`_getInvoice`, `_proceedToPayment`). |
| `combo/combo_route.dart` | 112 | `ComboRoute`: navigation helpers to enter the combo flow. |
| `combo/models/combo_cart.dart` | 139 | `ComboCart`: holds store A + store B carts, persisted under the `combo_cart` key. `load()`, `canStartWith()`, `resetServerState()`. |
| `combo/services/combo_service.dart` | 280 | `ComboService`: all combo API calls (see §5). |
| `combo/widgets/combo_store_section.dart` | 219 | Cart section showing one store's items in a combo, with quantity controls. |
| `combo/widgets/combo_too_far_dialog.dart` | 100 | Dialog shown when the two stores are farther apart than the allowed maximum. |
| `combo/widgets/store_conflict_dialog.dart` | 98 | "Your cart has items from another store" dialog: *Order from both stores* or *Clear cart*. |

### Models

| File | Lines | Purpose |
|---|---|---|
| `models/combo_invoice.dart` | 319 | `ComboInvoice`, `StoreInvoice`, `StoreFlags`: parse the combined invoice response; `validate()`. |
| `models/combo_payment_context.dart` | 113 | `ComboPaymentContext` + `ComboLeg`: combo id, per-store cart id and order-payment id, passed to the payment screen. |
| `orders/models/combo_order_entry.dart` | 313 | `OrderEntry`, `groupOrders()`: groups raw orders into single or combo entries (using `combo_id` and the locally saved `combo_orders`). `getComboStatus()` / `ComboStatusInfo`: combined status of the two child orders. |

### UI

| File | Lines | Purpose |
|---|---|---|
| `orders/components/combo_order_card.dart` | 213 | `ComboOrderCard`: order-list card for a 2-store combo (stacked store images, combined status). |

### Assets

| File | Purpose |
|---|---|
| `images/payment/wegagen_real.png` | New Wegagen logo used by `wegagen_ussd.dart`. |

### Documentation

`COMBO_CONCEPTUAL_ARCHITECTURE.md`, `COMBO_ORDER_FLOW.md`, `UI_FIX_SUMMARY.md` (repo root), and in `zmall_files/combo/`: `COMBO_MOBILE_CHANGES.md` / `_tmp.html`, `COMBO_ORDER_IMPLEMENTATION.md` / `_tmp.html`.

---

## 3. Modified files (22)

`+/-` = lines added/removed relative to `ai_mcp_combo` HEAD.

### Add-to-cart entry points: start a combo

| File | +/- | Change |
|---|---|---|
| `item/components/body.dart` | +168 / −38 | `_handleOtherStore()`: when the item is from a different store, check the store distance (`ComboService.StoreDistancegetMax`), then show `StoreConflictDialog` or `ComboTooFarDialog`. Re-entrancy guard `_comboDistanceCheckInProgress`. Fails closed: missing location or API error blocks the combo. |
| `product/product_screen.dart` | +164 / −45 | Same `_handleOtherStore()` flow for the product screen. |
| `notifications/notification_store.dart` | +142 / −47 | Same flow for adding from the notification store screen. |

### Cart → delivery → checkout

| File | +/- | Change |
|---|---|---|
| `cart/components/body.dart` | +141 / −16 | Shows both stores (`ComboStoreSection`). Adds `_checkMinOrderPrice()` (min-order check before checkout) and `_promoteComboIfFirstEmpty()` (if store A becomes empty, store B becomes the main cart). Removing an item keeps the cart while a combo exists. **Merged** with target's availability and location logic (see §4). |
| `delivery/delivery_screen.dart` | +230 / −25 | `_addToCart()` routes to `_addToComboCart()` when a `ComboCart` exists: re-checks distance, sends both stores in one call (`combo_add_item_in_cart`), then opens `ComboCheckoutScreen`. |
| `checkout/checkout_screen.dart` | +4 / −1 | `[COMBO-DEBUG]` logging of the `get_order_cart_invoice` request and response. |

### Payment

| File | +/- | Change |
|---|---|---|
| `kifiya/kifiya_screen.dart` | +359 / −27 | New `isCombo`, `comboId`, `combo` (`ComboPaymentContext`) params, plus per-store order-payment and cart ids. Pays and creates the order via `combo_pay_order_payment` / `combo_create_order`. Detects duplicate orders. Step-by-step `[COMBO-DEBUG]` logs. |
| `kifiya/components/kifiya_method_container.dart` | +34 / −1 | New `isSoon` flag: dims the payment method and shows a "Soon" badge. |
| `kifiya/components/telebirr_inapp.dart` | +79 / −141 | Simplified Telebirr in-app result handling: pops back with `false` after 2 s on failure. |
| `kifiya/components/wegagen_ussd.dart` | +10 / −7 | Uses `wegagen_real.png`; formatting only otherwise. |

### Orders

| File | +/- | Change |
|---|---|---|
| `orders/components/body.dart` | +292 / −141 | Active orders list is built from `groupOrders()`. Combo entries render as `ComboOrderCard`; tapping one opens a bottom sheet to pick which store's order to open (`_showComboOrderPicker`). **Merged**: target's `isOdooStoreByName` status rule re-applied. |
| `orders/components/orders_history.dart` | +149 / −111 | History list uses the same `groupOrders()` / `ComboOrderCard` grouping. |
| `orders/components/order_history_detail.dart` | +1176 / −736 | Combo-aware history detail: `_isCombo`, `_comboStores`, `_comboTotals`. "Combo Order (2 Stores · 1 Driver)" header listing both order numbers; per-store sections and combined totals. |
| `orders/components/order_detail.dart` | +84 / −0 | Combo banner ("Part of a combo order (2 stores · 1 driver)") when the order has `combo_id` or `order_payment_detail.combo_id`. |

### Cleanup, strings, misc

| File | +/- | Change |
|---|---|---|
| `models/language.dart` | +16 | New strings (EN + ZH): `orderFromBothStores`, `comboItemsFound`, `comboStoreLimit`, `comboAdded`. |
| `profile/components/body.dart` | +3 | Clears `combo_cart` on logout / account actions. |
| `services/core_services.dart` | +1 | Clears `combo_cart` together with `cart`. |
| `services/service.dart` | +2 / −2 | Clears `combo_cart`; `showMessage` uses `error == true` for the error colour. |
| `home/components/home_body.dart` | +6 / −3 | Home loading indicator: `LinearLoadingIndicator` → `CircularProgressIndicator`. |
| `widgets/linear_loading_indicator.dart` | +30 / −27 | Rework of the loading indicator widget. |
| `store/components/body.dart` | +2 | Comment only. |
| `main.dart` | +3 | Comment only. |

---

## 4. Conflicts resolved by hand

| File | Target (`ai_mcp_combo`) had | Source (`order_details`) had | Resolution |
|---|---|---|---|
| `cart/components/body.dart`: imports | `stock_availability_dialog`, `stock_left_notification`, `_CartAvailability` class | Removed `linear_loading_indicator` import | **Kept target**. Combo imports came in via the clean part of the merge. |
| `cart/components/body.dart`: checkout button | Location-services check → `_checkAvailability()` → store-hours bypass (`if (true)`) | Min-order check before `DeliveryScreen` | **Combined**: target's flow, with the source's `_checkMinOrderPrice()` added inside the open branch. |
| `cart/components/body.dart`: remove item | `Service.save('cart', cart!.toJson())` | Keep or clear the cart depending on `comboCart` | **Source** (combo-aware). |
| `cart/components/body.dart`: after remove | `_refreshAvailability()` | `_promoteComboIfFirstEmpty()` | **Both**, in that order. |
| `delivery/delivery_screen.dart` (2 hunks) | `🔎 [MAIN CHECKOUT]` debug prints | `[COMBO-DEBUG]` debug prints | **Kept target**. Debug output only. |
| `utils/constants.dart` (2 hunks) | Sample JSON comment, `BASE_URL = BASE_URL_TEST`, Odoo `kZmallOdooBaseUrl`, `kZmallBranchSlugs`, `isOdooStoreByName()` | `BASE_URL = BASE_URL_TEST` | **Kept target**. File ends up unchanged. |
| `orders/components/body.dart` | `isOdooStoreByName(...)` status rule on the old list item | Whole list rewritten around `OrderEntry` / `ComboOrderCard` | **Source version**, with the Odoo rule re-applied on `order['store_name']`. |

---

## 5. Backend endpoints used by the combo flow

All under `{baseUrl}/api/user/`:

| Endpoint | Used for |
|---|---|
| `combo_add_item_in_cart` | Send both store carts (`store_a`, `store_b`) in one request |
| `combo_get_order_cart_invoice` | Combined invoice (`ComboInvoice`) |
| `combo_pay_order_payment` | Pay once for both `store_a_order_payment_id` / `store_b_order_payment_id` |
| `combo_create_order` | Create both child orders under one `combo_id` |
| `get_combo_max_store_distance` | Max allowed distance between the two stores (`combo_max_store_distance_km`) |
| `change_user_wallet_status`, `get_payment_gateway`, `get_detail` | Wallet toggle, gateways, user/store details during combo checkout |

Local storage keys: `combo_cart` (active combo), `combo_orders` (used to group orders in lists).

---

## 6. Intentionally NOT ported

| Item | Reason |
|---|---|
| `ios/build/**`, `ios/Runner/Frameworks/build/**` (~330 files), `android/build/**` | Build cache, not source |
| `ios/Podfile`, `Podfile.lock`, `Podfile.backup`, `Runner.xcodeproj/*`, `ImageNotification/NotificationService.m` | iOS project config, not combo |
| `pubspec.yaml` (`3.2.10+364` → `+367`, `enable-swift-package-manager: false`), `pubspec.lock` | Version bump / build config |
| `.gitignore` (`.widget_preview/`), `analysis_options.yaml` (exclude platform dirs) | Tooling only |

---

## 7. Verification and next steps

- [x] No conflict markers left in `lib/`
- [x] `flutter analyze lib`: 0 errors
- [ ] Run the app. Test: add from store A → add from store B → distance dialog → cart → delivery → combo checkout → payment → orders list combo card → order detail banner
- [ ] Check that the cart checkout order (location → availability → min-order) behaves as intended
- [ ] Remove or guard `[COMBO-DEBUG]` / `🔎 [MAIN CHECKOUT]` logs before release
- [ ] Commit on `ai_mcp_combo`
- [ ] Optional cleanup: `git update-ref -d refs/remotes/mainapp/order_details` (temporary ref used for the merge)
