# Combo Order: Code Review

| | |
|---|---|
| **Date** | 2026-10-19 |
| **Branch / commit** | `order_details` @ `2ca021c` |
| **Reviewed against** | `zmall_files/combo_order/COMBO_ORDER_IMPLEMENTATION_PLAN_v2.md` and the backend guide `zmall_files/combo/COMBO_ORDER_IMPLEMENTATION.md` |
| **Method** | Code reading plus `flutter analyze` on the combo files (no issues). The app was **not** run against the backend. |

---

## 1. Verdict

**The happy path is correct.** Cash and wallet for two stores goes add → route → invoice → pay → create → success, and every request body matches the web contract. The data model, the origin rule, the units and the invoice parsing are all done right.

**It is not ready to ship yet.** There are **4 high-severity issues**:

- 3 can create a mismatch between money and orders (a paid order that doesn't exist, or an order created twice).
- 1 breaks the existing "Clear cart" flow for single-store users.

Fix those 4 first. The medium and low items can follow.

| Severity | Count |
|---|---|
| High | 4 |
| Medium | 5 |
| Low | 8 |

---

## 2. What is implemented correctly

These were checked against the plan and are correct:

| Area | What was verified | Where |
|---|---|---|
| Model | The first store stays in `cart` and the second store goes in `combo_cart`. Ids are keyed by `store_id`, never by A/B position. Corrupt JSON clears the key instead of crashing. | `lib/combo/models/combo_cart.dart` |
| Re-sync | Changing items clears `cart_id`s and `order_payment_id`s but keeps `combo_id`. `combo_id` is sent again on the next add call. | `combo_cart.dart:134`, `combo_service.dart:235` |
| Add call | The body matches the contract: `destination_address`, `delivery_type: 1`, `username`/`phone` (the receiver when ordering for others), `store_a`/`store_b` items, and no `store_location`. The client checks that `combo_id` and both `cart_id`s are present before continuing. | `delivery_screen.dart:547-602` |
| Self-pickup | Blocked for combos. | `delivery_screen.dart:423` |
| Origin rule | The store farther from the customer is `store_a` (Haversine). | `combo_route.dart:31-58` |
| Route | Uses Google Directions with the second store as a waypoint and sums the legs. It falls back to two Haversine legs at about 2 min/km. Units are **meters and seconds**, as the contract requires. | `combo_route.dart` |
| Invoice parsing | Parsed into a typed `ComboInvoice`. **Only safe fields are copied from the store object**; the raw store map, with the password hash and bank data, is never kept (Q24). The client checks the `combined_user_pay_payment` sum and validates per-store `success` and the ids. | `lib/models/combo_invoice.dart` |
| Totals | `combinedUserPay` is used for the bottom bar, the Kifiya `price` and the wallet check. Item subtotals come from the invoice, not from local prices (Q25). | `combo_checkout_screen.dart:254, 314, 535` |
| Store flags | Cashless is OR'd across both stores. A busy, scheduled-only or pickup-only store blocks Place Order with a message. | `combo_checkout_screen.dart:259-293` |
| Payment methods | Phase 1 shows only Cash and Wallet in combo mode. Other gateways are hidden. | `kifiya_screen.dart:1315-1322` |
| Pay call | `store_a_order_payment_id` is the origin and `store_b` the waypoint, taken from the latest invoice. No `payment_id` is sent, as on the web. | `combo_service.dart:270-284` |
| Create call | Sends `combo_id`, both `cart_id`s in origin order, `is_user_pick_up_order: false`, and `order_from` = `ios`/`android` (Q23). | `combo_service.dart:287-301` |
| After success | Clears `cart`, `aliexpressCart` and `combo_cart`. Saves `{combo_id, order_ids, order_unique_ids}` to `combo_orders` (capped at 50). The success screen shows both order numbers. | `kifiya_screen.dart:608-665` |
| Logout / clear cache | `combo_cart` is removed alongside `cart` everywhere the user is logged out. | `service.dart:137`, `core_services.dart:517`, `profile/components/body.dart:178,236,341` |
| Cart screen | Shows a second store section. When store 1 is emptied, store 2 becomes the normal cart. When store 2 is emptied, the combo is removed. | `cart/components/body.dart:144-180` |
| Orders grouping | Groups orders by `combo_id` from the order, then from `order_payment_detail`, then from the local `combo_orders`. Handles both active and history field shapes. | `orders/models/combo_order_entry.dart:143` |
| Derived status | Covers both cancelled, one cancelled, both completed, driver assigned, and the less advanced store's status. | `combo_order_entry.dart:199` |
| Logging | Every combo `debugPrint` is silenced in release builds, so the raw invoice is never logged in production. | `main.dart:28-30` |
| Translations | `comboItemsFound`, `comboStoreLimit`, `orderFromBothStores` and `comboAdded` exist in EN, AM and ZH. | `models/language.dart` |
| Secrets | The API sample files with the real user token are not in git. | (none) |

### Deliberate differences from the plan (acceptable)

- **Storage layout:** the plan had one `ComboCart` with `storeA`/`storeB`. The code keeps store 1 in `cart` and store 2 in `combo_cart`, so existing screens keep working without changes. This is a reasonable choice.
- **No combo detail screen:** instead of a `ComboOrderDetail` screen, tapping a combo opens a store picker, and each child order opens the normal `OrderDetail`. This is simpler, but see **M2** (cancel).
- **Extra endpoint:** `get_combo_max_store_distance` (`combo_service.dart:350`) is not in the plan or the backend guide. Confirm the backend team owns it. See **H4**.

---

## 3. High-severity findings

### H1. A payment that one store didn't record is treated as fully paid

**File:** `lib/kifiya/kifiya_screen.dart:810`

```dart
if (data != null && data['success']) {
  widget.isCombo ? _createOrder() : ...
```

**Problem:** the combo pay response has a separate `is_payment_paid` for each store. The code only checks the top-level `success`.

**Impact:** if store B's payment wasn't recorded, the app still calls `combo_create_order`. Plan §3.3 / §12.3 says not to.

**Fix:**

```dart
final paid = data != null && data['success'] == true &&
    (!widget.isCombo ||
     (data['store_a']?['is_payment_paid'] == true &&
      data['store_b']?['is_payment_paid'] == true));
```

If `paid` is false for a combo: don't create the order, name the store that failed (`ComboService.errorText` already does this), and call `_logFailedComboOrder`.

### H2. A partial order creation is treated as a full success

**File:** `lib/kifiya/kifiya_screen.dart:577`

**Problem:** the success branch checks only the top-level `data['success']`, then:

- clears `combo_cart`
- saves whatever order ids came back
- shows "Order successfully created"

**Impact:** the backend guide (§7, §10 #1) says creation has **no rollback**. If one store fails:

- The user sees success, but only one order exists.
- Money for both stores may already have been taken.
- The cart is gone, so the user can't recover.

**Fix:** for combos, require `store_a.success == true && store_b.success == true`. If only one is true:

- keep `combo_cart`
- save the one `order_id` to `combo_orders`
- show "Your order from {store} was placed; {other} could not be placed. Please contact support (8707) with reference {combo_id}."
- call `_logFailedComboOrder`

### H3. A timed-out create is retried automatically with no idempotency key

**File:** `lib/kifiya/kifiya_screen.dart:4160-4190`

**Problem:** `combo_create_order` is retried up to 3 times whenever the response is `null`. A `null` comes from a timeout, a network error, **or** a body that isn't JSON (for example an HTML 502 page).

**Impact:** a timeout doesn't mean the server failed. It may have created both orders and the reply was lost. `combo_create_order` has no idempotency key (backend guide §10 #6), so a retry can create **a second pair of orders**.

**Fix (until the backend confirms idempotency):**

- Make at most **one** automatic retry.
- Before retrying, call `get_orders` and check whether there are orders with this `combo_id`. If there are, treat the call as a success.
- Ask the backend to accept `order_payment_unique_id`, or the `combo_id` itself, as the idempotency key.

### H4. The distance check runs before the "different store" dialog and can block "Clear cart"

**Files and lines:**

| File | Lines |
|---|---|
| `lib/item/components/body.dart` | 972-1041 |
| `lib/product/product_screen.dart` | 1252-1327 |
| `lib/notifications/notification_store.dart` | 536-606 |

**Problem:** `_handleOtherStore` calls `get_combo_max_store_distance` and compares the stores **before** deciding anything else.

**Impact:**

1. **A single-store user can't replace their cart.** They add an item from a far-away store and get "Stores Are Too Far Apart". The old Cancel / **Clear** dialog never appears, so they have to go to the cart screen and clear it by hand. This is a regression.
2. **If the API fails or times out, the user can't add the item at all.** They get "Could not verify store distance", even if they only wanted to clear the cart.
3. **Items from search are always blocked.** Search opens `ItemScreen` with `location: [0.0, 0.0]` (`search/search_screen.dart:614`). `(0, 0)` isn't null, so the check measures about 1,000 km and shows "too far".
4. **Every extra item from store 2 makes another API call.** The check runs before `addToSecondStoreIfMatches`.
5. **Adding a 3rd store can show the wrong dialog.** It may show "too far" instead of "at most 2 stores".

**Fix:**

- Show the conflict dialog first.
- Run the distance check **only inside `onCombo`**, after the user picks "Order from both stores".
- Skip it when the item belongs to the existing second store.
- Treat `(0, 0)` as unknown. Fetch the store location with `user_get_store_product_item_list`, or let the server decide: `combo_add_item_in_cart` already returns "These two stores are too far apart".
- The three files contain the same code. Move it into one helper in `lib/combo/` so the fix is made once.

---

## 4. Medium-severity findings

### M1. Two cart-clearing sites don't remove `combo_cart`

| Site | What happens |
|---|---|
| `lib/aliexpress/ali_item_screen.dart:693` ("Clear" in the AliExpress dialog) | Removes `cart` and `aliexpressCart` but not `combo_cart`. |
| `lib/mcp/mcp_cart_screen.dart:222` (`commitCart`, "Replace your cart?") | Writes a new `cart` without removing `combo_cart`. |

**Impact:** the old store 2 stays attached to the new cart. The next checkout becomes a combo between the new store and a store the user thought they had removed.

**Fix:** call `ComboCart.clear()` at both sites. Better still, add `Service.clearAllCarts()` and use it everywhere (plan §7.3).

### M2. Half of a combo can be cancelled

**File:** `lib/orders/components/order_detail.dart:808`

**Problem:** each child opens the normal `OrderDetail`, which shows **Cancel** whenever `order_status == 3`.

**Impact:** a user can cancel store A while store B goes ahead, and the driver is still sent for one pickup. Plan §13.5 says partial cancel is not offered in Phase 1, and the backend has no combo cancel rule yet (Q17).

**Fix:** hide Cancel when `_resolveComboId() != null`, and show "Contact support to cancel a multi-store order". Do this until the backend defines combo cancellation.

### M3. Combo history depends on a backend field that isn't documented

**File:** `lib/orders/components/order_history_detail.dart:68-83`

**Problem:** the combo layout only appears when `order_history_detail` returns `combo.stores[]` and `combo.totals`. Neither the plan nor the backend guide documents this field.

**Impact:** if the backend doesn't send it, tapping a combo in history (`orders_history.dart:167`) opens **only the first child**. Store B's items, rating and invoice can't be reached.

**Fix:**

- Confirm the response shape with the backend and add it to the backend guide.
- If `combo` is missing, fall back to opening each child, the same way the active orders sheet does.

### M4. The support reference after a failed create is the wrong id

**File:** `lib/kifiya/kifiya_screen.dart:689, 719`

**Problem:** the message says "contact support … with reference: `${widget.orderPaymentUniqueId}`". For a combo that is only the origin store's payment number.

**Impact:** support can't find store B's payment from it.

**Fix:** use `widget.comboId` for combos.

### M5. A "duplicate" create response leaves the user on the payment screen

**File:** `lib/kifiya/kifiya_screen.dart:578`

**Problem:** if `combo_create_order` ever returns `duplicate: true`, the code shows a message but does nothing else. The cart isn't cleared and the user isn't taken to the success screen. This copies the single-store bug that plan §12.3 says not to copy.

**Fix:** for combos, handle a duplicate exactly like a success.

---

## 5. Low-severity findings

| # | File:line | Issue | Fix |
|---|---|---|---|
| L1 | `combo/combo_checkout_screen.dart:434` | When ordering for someone else, "Your Delivery Summary" shows the user's own name and phone, not the receiver's. The server does get the receiver. `ComboCheckoutScreen` takes no receiver parameters. | Pass `isForOthers`, `receiverName` and `receiverPhone` from `DeliveryScreen`, as `CheckoutScreen` does. |
| L2 | `delivery/delivery_screen.dart:568` | `is_laundary_store` isn't checked after `combo_add_item_in_cart`. A per-store `success: false` is only caught indirectly, because a `cart_id` is missing. | Check both, as in plan §10.4. |
| L3 | `delivery/delivery_screen.dart:531` | If either store location is missing, the distance check is **skipped** (fail-open), but the comment says fail-closed. | Make the behavior match the comment, or change the comment. The server checks the distance anyway. |
| L4 | `delivery/delivery_screen.dart` | The vehicle picker is still shown in combo mode, but the chosen vehicle is never sent. The server picks it. | Hide the picker when a combo exists (plan §10.2). |
| L5 | `orders/models/combo_order_entry.dart:60` | `hour + 3` for UTC+3 can give 24, 25 or 26 without moving to the next day. | Use `DateTime.parse(raw).toLocal()` or `add(Duration(hours: 3))`. |
| L6 | `orders/components/order_history_detail.dart:414` | If a store entry has no `is_user_rated_to_store`, it falls back to the parent order's flag, so store B can show as rated because store A was rated. | Fall back to `false`. |
| L7 | `kifiya_screen.dart:1444` | The wallet balance is only checked against the total when a store is cashless-only. Otherwise a partial wallet balance is sent, and how the server splits it across two payments is unknown (Q11). | Allow the wallet for combos only when `wallet >= price`. |
| L8 | `test/` | There are no unit tests for `groupOrders`, `getComboStatus`, `ComboInvoice.fromJson` or `computeComboRoute`'s origin choice (plan §17). They are pure functions and easy to test. | Add tests. |

**Minor clean-up:**

- `ComboService.StoreDistancegetMax` should follow Dart naming, for example `getMaxStoreDistance`.
- `combo_service.dart:363-386` prints with box-drawing debug lines. They are silenced in release, but noisy.
- Item rows in the combo checkout show local prices, while the subtotal comes from the invoice. When the server price differs (Q25), the rows won't add up to the subtotal. Consider showing quantity and name only.

---

## 6. Still open with the backend

These come from the plan and the backend guide. The code works around them, but they still need answers:

| # | Question | Blocks |
|---|---|---|
| 1 | What happens to the money when creation partly fails? | H2 wording, support process |
| 2 | Is `combo_create_order` idempotent, and on which key? | H3 |
| 3 | Combo cancel rules / `combo_cancel_order` | M2 |
| 4 | The shape of `combo` in `order_history_detail` | M3 |
| 5 | Who owns `get_combo_max_store_distance`, and its response field (the code tries 5 different key names) | H4 |
| 6 | 🔒 Strip private store fields from the invoice response | Security, still urgent |
| 7 | The 50/50 delivery split is temporary | Display only |

---

## 7. Recommended order of work

1. **H1, H2, M5:** per-store success checks in the pay and create handlers of `kifiya_screen.dart`. These are small changes in one file.
2. **H3:** limit automatic retries to one and check `get_orders` first.
3. **H4:** move the distance check into `onCombo`, as one shared helper used by the 3 add-to-cart screens.
4. **M1, M2, M4:** one-line fixes.
5. **M3:** confirm the history contract with the backend.
6. The low-severity items, and unit tests for the pure functions.

**Re-test after the fixes:**

| Test | Expected result |
|---|---|
| Cash combo | Two orders, both order numbers on the success screen, and the cart is empty |
| Wallet combo with too little balance | `YOUR_WALLET_AMOUNT_NEGATIVE` message, and no order is created |
| Item from a far-away store with a single-store cart | The **Clear** option still works |
| Item from search | The combo isn't blocked by `(0, 0)` |
| Remove store 1's last item | Store 2 becomes the normal cart |
| AliExpress "Clear" or MCP "Replace" with an active combo | No leftover store 2 |
| Combo order at status 3 | No Cancel button on either child |
| Kill the network during "Creating order…" | No duplicate orders, and a clear message is shown |
