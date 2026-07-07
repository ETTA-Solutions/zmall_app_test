# Telebirr In-App — Duplicate Orders: Issue, Cause & Fix

**Audience:** any developer touching the payment / order-creation flow.
**Screen:** `lib/kifiya/kifiya_screen.dart`
**Related widgets:** `lib/kifiya/components/telebirr_inapp.dart`, `lib/custom_widgets/custom_button.dart`
**Last updated:** 2026-07-07

> TL;DR — Paying with Telebirr in-app could create **two** orders for one payment. Root cause was
> multiple, unguarded paths reaching `create_order` at once (notably the always-tappable
> **Place Order** button), amplified by a **non-idempotent backend**. Fixed on the client by
> (1) moving the button under the loading barrier, (2) a single-flight guard on the Telebirr poll
> path, (3) sending an idempotency key (`order_payment_unique_id`) on every create call, and
> (4) bounding `pollTelebirrStatus` so it can no longer poll forever. The
> **backend must enforce that key** for the duplicate fix to be complete.

---

## 1. The issue

After completing a Telebirr **in-app** payment, the app sometimes created **two orders for a
single payment**.

**Confirmed reproduction (observed 2026-07-02):**

| Attempt | Order IDs created | Appeared first | Appeared second |
|---|---|---|---|
| 1 | 464316 + 464317 | 464317 | 464316 |
| 2 | 464318 + 464319 | 464319 | 464318 |

The reversed, ±1 IDs are the fingerprint of **two concurrent `create_order` requests**: the DB
assigns the auto-increment ids in one order, but the rows commit/appear in the other because the
two requests interleave.

---

## 2. How the Telebirr in-app flow works

1. User taps the **telebirr inapp** payment tile → `useBorsa()` → confirm dialog.
2. **Continue** → `Navigator.push(TelebirrInApp)` with a **fixed** trace number
   `"${kTelebirrInAppTraceKey}${orderPaymentUniqueId}"` (`constants.dart` → `"ZTelebirrInApp" + id`).
3. `TelebirrInApp` calls the native Telebirr SDK; the user pays; the screen pops.
4. Back in `kifiya_screen.dart`, the `.then(...)` callback runs `pollTelebirrStatus(...)`, which
   polls the backend until `PAID` / `FAILED`, the widget unmounts, or the attempt cap is hit
   (see Fix 4).
5. On `PAID`, it calls `_createOrder` / `_createCourierOrder` / `_createAliexpressOrder`, which
   `POST` to `create_order`.

**Important:** order creation is **100% client-driven** — the server-side Telebirr callback
(`confirmPayment` / `in_app_call_back`) is commented out in `telebirr_inapp.dart`. So a duplicate
requires the client to call `create_order` twice **or** a non-idempotent backend.

---

## 3. Root causes

| # | Cause | Detail |
|---|---|---|
| **C1** | **Always-tappable "Place Order" button** *(primary, confirmed)* | `CustomButton` wires `InkWell.onTap: press` **unconditionally** (`custom_button.dart:36-38`); `isLoading` only changes the visuals. The button lived in `Scaffold.bottomNavigationBar` — **outside** the `ModalProgressHUD` — so it stayed tappable during the payment. Its `press` runs `_payOrderPayment`, a **second, independent** creation path alongside the Telebirr poll path. |
| **C2** | **No single-flight guard on order creation** | `_createOrder` / `_createCourierOrder` / `_createAliexpressOrder` had no "already placed" check, so two paths could both create. |
| **C3** | **Fixed, reusable trace number** | Unlike card gateways (which increment `uuid` per attempt), Telebirr in-app always uses the same trace number, so any re-entry re-reads the same `PAID` transaction. |
| **C4** | **Callback polls unconditionally** | The `.then((value) …)` ignores the returned `value` and always polls the fixed trace number, so even cancel/back can re-confirm a prior payment. |
| **C5** | **Backend `create_order` is NOT idempotent** *(confirmed by the 464316/464317 evidence)* | Two calls for the same cart/payment produced two distinct orders — so every client-side race becomes a **hard** duplicate. |

`_placeOrder` is **not** a guard — it only drives the button's inline spinner (its single read is
`isLoading: paymentResponse != null && _placeOrder`). Likewise `ModalProgressHUD` only covers the
Scaffold **body**, so it never blocked a button sitting in `bottomNavigationBar`.

---

## 4. The fix (what changed on the client)

### Fix 1 — Move "Place Order" inside the `ModalProgressHUD`
The button was moved out of `Scaffold.bottomNavigationBar` and into the HUD's subtree (bottom of
the body `Column`, after an `Expanded`). Now the loading barrier covers it, so it cannot be tapped
while `_loading == true` (which spans the whole poll → create → navigate window).

### Fix 2 — Single-flight guard on the Telebirr poll path
Added `bool _orderPlaced` and used it in the Telebirr `.then` callback:

```dart
).then((value) async {
  if (_orderPlaced) return;                 // entry guard
  final isPaid = await pollTelebirrStatus(merchOrderId: "...");
  if (!mounted) return;
  if (_orderPlaced) return;                 // re-check after the await
  if (isPaid) {
    _orderPlaced = true;                    // claim before creating
    ...
    _createOrder(); // or _createCourierOrder() / _createAliexpressOrder()
  } else {
    ... // "payment not completed" + reset kifiyaMethod
  }
});
```

The entry check + post-`await` re-check ensure that even concurrent/re-entrant poll callbacks
create the order at most once.

### Fix 3 — Idempotency key on every create call
`order_payment_unique_id` (`= widget.orderPaymentUniqueId`, a value that is **constant across
retries**) is now sent on all three creation requests:

| Method | Endpoint | How it's sent |
|---|---|---|
| `createOrder` | `/api/user/create_order` | `"order_payment_unique_id": widget.orderPaymentUniqueId` |
| `createCourierOrder` | `/api/user/create_order` (multipart) | `..fields['order_payment_unique_id'] = widget.orderPaymentUniqueId!` |
| `createAliexpressOrder` | `/admin/aliexpress_creat_order` | `"order_payment_unique_id": widget.orderPaymentUniqueId` |

### Fix 4 — Bound `pollTelebirrStatus` (stop the endless poll)
Originally the poll loop was `while (mounted)` with **no attempt/time cap**. On a `PENDING`
payment or an unreachable endpoint it would poll **forever** (every few seconds, holding the
"Checking Telebirr payment…" spinner), hammering the query endpoint — a server-load problem, not a
duplicate one. The loop is now bounded by a **max-attempts** counter:

```dart
Future<bool> pollTelebirrStatus({
  required String merchOrderId,
  int intervalSeconds = 1,
  int maxAttempts = 6,          // ← new bound
}) async {
  ...
  var attempt = 0;
  while (mounted && attempt < maxAttempts) {   // was: while (mounted)
    attempt += 1;
    ... poll ...
    await Future.delayed(Duration(seconds: intervalSeconds));
  }
  if (mounted) setState(() => _loading = false);
  return false;   // attempts exhausted → "not confirmed"
}
```

Stop conditions: **PAID** (`true`), **FAILED/`success:false`** (`false`), **widget unmounted**, or
**`maxAttempts` reached** (`false`). The `catch` block still just logs and lets the loop retry, so a
network error/timeout consumes an attempt rather than looping forever.

**Notes / trade-offs:**
- Current values (`6 × 1s`) give ~6s of coverage when the endpoint is fast. **This may be too short**
  if the backend takes longer than that to flip to `PAID` after the user pays — it can produce a
  false "not completed". Tune `maxAttempts` / `intervalSeconds` to match how quickly the backend
  reflects a paid status (verify against real transactions).
- Max-attempts bounds the **request count** (good for server load) but not wall-clock time: under
  sustained failures each attempt can take up to the 10s per-request timeout, so the worst case is
  `~maxAttempts × (10s + intervalSeconds)`. Add a time deadline as a second bound if a strict
  wall-clock cap is needed.
- **Do not** call `pollTelebirrStatus` recursively from its own `catch` — that resets the attempt
  counter (defeating the bound) and, if not awaited, spawns overlapping concurrent poll loops. The
  `while` loop already handles retries.

---

## 5. ⚠️ Backend work required (the fix is NOT complete without this)

The idempotency key is only a hint until the backend enforces it. For each endpoint above:

1. **Enforce uniqueness atomically** — a DB **UNIQUE constraint/index** on
   `order_payment_unique_id`, or an atomic upsert (`INSERT … ON CONFLICT DO NOTHING`), or
   `SELECT … FOR UPDATE` in a transaction.
   **A plain check-then-insert is NOT enough** — two concurrent requests both pass the check
   before either inserts (exactly the 464316/464317 race).
2. **Return success-shaped on repeat** — a duplicate call must return the **existing** order with
   `success: true`, so the client navigates to `ReportScreen` normally instead of showing "failed"
   and looping into another retry.
3. The AliExpress service (`/admin/aliexpress_creat_order`) needs its **own** dedup on the same key
   to avoid duplicate *external* AliExpress orders (it is a different service from `create_order`).

---

## 6. Residual risk (until the backend enforces the key)

The client fixes close the reproduced bug, but these vectors still reach `create_order` twice and
will duplicate **only because the backend is non-idempotent**:

- **R1** — After a *failed/lost-response* create, the button re-enables and `_payOrderPayment`
  (which does **not** check `_orderPlaced`) can create again.
- **R2** — Double-tapping the button before `_loading` flips true (`_payOrderPayment` awaits image
  validation **before** `setState(_loading = true)`).
- **R3** — Leaving and re-entering the screen (fresh `KifiyaScreen` → `_orderPlaced` resets) +
  fixed trace number → poll re-confirms the old payment.

All three collapse to a single order once the backend honors `order_payment_unique_id`. This is
why the backend change is the durable fix.

> Note: `_orderPlaced` is intentionally **not reset** after a failed create in the current code, so
> the Telebirr poll path won't recreate. This is safe against duplicates but means a genuinely
> failed order can only be retried via the button path. Backend idempotency makes the retry safe
> either way.

---

## 7. Test checklist

- [ ] Pay with Telebirr in-app → exactly **one** order; Place Order is not tappable during the flow.
- [ ] Pay, then hammer **Place Order** repeatedly → still **one** order.
- [ ] Double-tap **Continue** in the confirm dialog → **one** order.
- [ ] Force a create failure (e.g., airplane mode at the create step), restore network, retry →
      **one** order (verify against backend once idempotency is live).
- [ ] Backend: two `create_order` calls with the same `order_payment_unique_id` (sequential **and**
      concurrent) → one order row; the second returns the existing order with `success: true`.
- [ ] Repeat all of the above for **courier** and **AliExpress** orders.
- [ ] Bounded poll: with the payment left PENDING (or endpoint unreachable), the poll stops after
      `maxAttempts` instead of spinning forever, and shows "not completed".
- [ ] Confirm the poll window is long enough for a *real* successful payment to be detected (no
      false "not completed").

---

## 8. File / line reference index

| Concern | Location |
|---|---|
| Fixed trace key constant | `lib/utils/constants.dart` (`kTelebirrInAppTraceKey`) |
| Telebirr `.then` callback + `_orderPlaced` guard | `lib/kifiya/kifiya_screen.dart` (`pollTelebirrStatus` call site) |
| `_orderPlaced` field | `lib/kifiya/kifiya_screen.dart` (state fields) |
| `pollTelebirrStatus` | `lib/kifiya/kifiya_screen.dart` |
| Place Order button (now inside HUD) | `lib/kifiya/kifiya_screen.dart` (body `Column`, after `Expanded`) |
| `_payOrderPayment` (button path, unguarded by `_orderPlaced`) | `lib/kifiya/kifiya_screen.dart` |
| `createOrder` payload + key | `lib/kifiya/kifiya_screen.dart` |
| `createCourierOrder` payload + key | `lib/kifiya/kifiya_screen.dart` |
| `createAliexpressOrder` payload + key | `lib/kifiya/kifiya_screen.dart` |
| `CustomButton` (`onTap` not gated by `isLoading`) | `lib/custom_widgets/custom_button.dart:36-38` |
| Disabled server callback (`confirmPayment`) | `lib/kifiya/components/telebirr_inapp.dart` |

---

## 9. Related docs

- `TELEBIRR_INAPP_DUPLICATE_ROOT_CAUSE.md` — the deeper hypothesis-by-hypothesis analysis and the
  confirmed reproduction evidence.
