# Telebirr In-App — Duplicate Orders: Root-Cause Analysis

**Screen:** `lib/kifiya/kifiya_screen.dart`
**Component:** `lib/kifiya/components/telebirr_inapp.dart`
**Button widget:** `lib/custom_widgets/custom_button.dart`
**Analysis date:** 2026-07-02
**Status:** Analysis only — **no code changed**. This document explains *why* the duplication
can happen so it can be reproduced and confirmed before a fix is chosen.

> Note: the code currently contains one orphaned, unused field — `bool _orderPlaced = false;`
> at `kifiya_screen.dart:72` — left over from an earlier experiment. It is **not referenced
> anywhere** and has no effect on behavior. Mentioned only so it isn't mistaken for an active guard.

---

## 0. CONFIRMED reproduction (observed 2026-07-02)

**Report:** After paying with Telebirr in-app, the user tapped **Place Order** and **two orders
were created**:

| Attempt | Order IDs created | Order that appeared first | Order that appeared second |
|---|---|---|---|
| 1 | 464316 + 464317 | **464317** | 464316 |
| 2 | 464318 + 464319 | **464319** | 464318 |

**Interpretation — this confirms H3 + H2 + H7:**

- **Two independent creation paths fired for one payment:** the **poll path**
  (`.then` → `pollTelebirrStatus` → `_createOrder`) *and* the **button path**
  (**Place Order** → `_payOrderPayment` → `_createOrder`). The bottom button was live the whole
  time because `CustomButton` wires `onTap: press` unconditionally (`custom_button.dart:36-38`;
  `isLoading` only changes the visual). → **H3 confirmed as the real-world trigger.**
- **No single-flight guard** let both reach `create_order`. → **H2 confirmed.**
- **The higher id appears first** (317 before 316, 319 before 318), consistently ±1 across both
  attempts. This is the fingerprint of two **concurrent** `create_order` requests: the DB assigns
  the auto-increment ids at one instant, but the row that commits/displays first is not the
  lower-id one because the two transactions interleave. The two paths are asymmetric — the
  **Place Order** path does an extra `pay_order_payment` round-trip *before* its `create_order`,
  while the poll path calls `create_order` immediately — so id-assignment order ≠ completion order.
- **The backend created two distinct orders for the same cart/payment.** → **H7 confirmed: the
  server `create_order` is NOT idempotent** on `cart_id` / `order_payment_id`. This is why the
  client race becomes a hard duplicate rather than a no-op retry.

**Takeaway:** the dominant, reproducible cause is **H3 (always-tappable Place Order button) + H2
(no guard)**, made permanent by **H7 (non-idempotent backend)**. H1/H4/H5 remain valid secondary
vectors (retry / double-tap / cancel-then-poll) but were not required for this reproduction.

---

## 1. What "duplicate order" means here

A duplicate happens when the order-creation endpoint succeeds **twice** for a single payment:

- `POST /api/user/create_order` — called from `_createOrder` (`kifiya_screen.dart:502`),
  `_createCourierOrder` → `createCourierOrder` (`:460` / multipart at `:3234`), or
  `_createAliexpressOrder` (`:474`).

There is **no server callback** creating the order (the pgw `in_app_call_back` /
`confirmPayment` path is commented out in `telebirr_inapp.dart:354-388`). So order creation is
**100% client-driven**. That means a duplicate order requires **either**:

- **(A)** the client calls `create_order` more than once for the same cart, **or**
- **(B)** the backend `create_order` is not idempotent and a single logical order maps to two rows.

Everything below explains how (A) is reachable, and why (B) turns near-misses into hard duplicates.

---

## 2. The Telebirr in-app flow (as currently written)

1. User taps the **telebirr inapp** grid tile → `press` handler runs (no re-entrancy guard).
2. `useBorsa()` (`:2049` area) → on success shows a confirm dialog.
3. User taps **Continue** (`onPressed`, `:2098`):
   - `Navigator.of(context).pop()` closes the dialog.
   - `Navigator.push(TelebirrInApp(...))` with a **fixed** trace number.
4. `TelebirrInApp.initState` → `getRreceiveCode()` (`telebirr_inapp.dart:390`) →
   `POST /telebirrInapp/create_order` → native `placeOrder` / `placeOrderIOS`.
5. User pays in telebirr; native SDK returns a code; the screen pops after a 2s delay
   (`telebirr_inapp.dart:65-102, 143-184`), returning either a **Map** (`_paymentResult`) or **`false`**.
6. Back in `kifiya_screen.dart` the `.then((value) async { ... })` callback (`:2115`):
   - **ignores `value` entirely**,
   - calls `pollTelebirrStatus(merchOrderId: <fixed trace>)` (`:2138`),
   - if `isPaid` → branches to `_createCourierOrder` / `_createAliexpressOrder` / `_createOrder`
     (`:2155-2166`) — **none of which have a duplicate guard**.
7. `pollTelebirrStatus` (`:126`) loops `while (mounted)` against `/teleInapp/...query`
   (`:155`), returning `true` on `PAID/SUCCESS + success==true`, `false` on `FAILED/FAIL` or
   `success==false`, and **loops forever otherwise** (PENDING / unknown status) until the
   widget unmounts.

---

## 3. Root-cause hypotheses (ranked)

### H1 — Fixed, reusable trace number lets the poll re-confirm the *same* payment  ⭐ primary

The trace number is a **constant** for a given order-payment:

```
traceNo = "${kTelebirrInAppTraceKey}${orderPaymentUniqueId}"   // constants.dart:323 → "ZTelebirrInApp" + id
```

Used for `create_order` (`telebirr_inapp.dart` init) **and** for the poll query
(`kifiya_screen.dart:2108` and `:2141`). Unlike the card gateways — which do
`uuid = (int.parse(uuid) + 1)` before every attempt (e.g. BOA `:1303`, EthSwitch `:1397`,
Zemen, Dashen, Wegagen) — Telebirr in-app **never varies** its trace number.

**Consequence:** every time the flow is entered for this cart, `pollTelebirrStatus` queries the
**same** `merch_order_id` and sees the **latest** Telebirr transaction state. If a payment ever
succeeded for that id, *any subsequent entry* into the flow will read `PAID` and proceed to create
another order — even if the user is only "retrying" because they thought the first attempt failed.

This is the single behavior that most distinguishes Telebirr in-app from the gateways that do
**not** duplicate.

---

### H2 — No idempotency / single-flight guard on order creation

`_createOrder`, `_createCourierOrder`, and `_createAliexpressOrder` do not check whether an order
has already been submitted for this session. Nothing prevents a second confirmed-payment branch
(or a second poll loop) from calling them again. Combined with H1, the second confirmation has a
direct, unguarded path to a second `create_order`.

---

### H3 — The bottom "Place Order" button is always tappable (parallel creation path)  ✅ CONFIRMED (see §0)

`CustomButton` wires `InkWell.onTap: press` **unconditionally** (`custom_button.dart:36-38`);
`isLoading` only changes the *visual* (spinner vs text) — it does **not** disable the tap.

The bottom bar button (`kifiya_screen.dart:2786`) calls `_payOrderPayment(otp: "")`, which is a
**completely separate** order-creation path from the Telebirr tile flow. Because the Telebirr tile
sets `kifiyaMethod` to the selected index, `_payOrderPayment` (`:590`) will run
`payOrderPayment(...)` and then `_createOrder`/`_createCourierOrder`.

So a user who: taps the Telebirr tile → pays → then also taps **Place Order** (still enabled,
even mid-load) gets **two** orders: one from the poll branch, one from `_payOrderPayment`.

---

### H4 — Concurrent poll loops from double-tap / re-push

Nothing debounces the confirm dialog's **Continue** button or the tile itself:

- Double-tapping **Continue** can fire `Navigator.push(TelebirrInApp)` twice → two screens → two
  `.then` callbacks → two `pollTelebirrStatus` loops keyed to the **same** merch id → both return
  `PAID` → two orders.
- Double-tapping the **tile** stacks two `useBorsa()` calls / two dialogs.

H1 makes this worse: both concurrent loops query the same fixed id and both succeed.

---

### H5 — The callback ignores the returned `value`, so it polls even after cancel/back

The `.then((value) …)` at `:2115` never inspects `value`, even though `TelebirrInApp` returns a
meaningful result: **`false`** on the Back button (`telebirr_inapp.dart:265`) and on hard errors
(`:97, :101, :177, :183`), or a **Map** on SDK completion.

Because it always polls the fixed trace number regardless, a user who **backs out** of the
in-app screen after having paid on a *prior* attempt still triggers a poll that reads `PAID` and
creates another order. (Caveat: this must not be "fixed" by blindly skipping on `value == false`
— `false` is also returned on generic errors where the payment may actually have succeeded, so
the poll is genuinely needed there. See §6.)

---

### H6 — Poll loops "forever" on PENDING (timing amplifier, not a direct cause)

`pollTelebirrStatus` only exits on `PAID/SUCCESS`, `FAILED/FAIL`, or unmount (`:193-208`,
`:159`). On a `PENDING`/unknown status it keeps polling every `intervalSeconds`. This widens the
time window during which the screen stays mounted and interactive — increasing the odds that H3
(Place Order tap) or H4 (re-tap) fire while a confirmation is still pending.

---

### H7 — Backend `create_order` idempotency (systemic amplifier)  ✅ CONFIRMED non-idempotent (see §0)

`createOrder` (`:3587`) posts `cart_id: userData['user']['cart_id']` (`:3613`); the courier path
posts `courierCart['cart_id']` (`:3234`). The local cart is only removed **after** a successful
`_createOrder` (`Service.remove('cart')`), and the **server-side** `cart_id` is what the backend
uses. If `/api/user/create_order` does not treat a repeated call for the same
`cart_id` / `order_payment_id` as already-fulfilled, then any of H1–H5 produces a **hard**
duplicate rather than a harmless retry. Conversely, a properly idempotent backend would collapse
all of the above into a single order. **This is the most important thing to confirm.**

---

## 4. Most-likely reproduction narratives

1. **Retry-after-perceived-failure (H1 + H2 [+ H7]):**
   User pays; the poll is slow / the confirm screen lingers on PENDING; user backs out and taps
   Telebirr again; the second poll reads the already-`PAID` fixed trace id and creates a second
   order.

2. **Tile + Place Order (H3 + H2 [+ H7]):**
   User pays via the Telebirr tile; while the poll/creation is in flight, the still-enabled
   bottom **Place Order** button is tapped, running `_payOrderPayment` → a second order.

3. **Double-tap Continue (H4 + H2 [+ H7]):**
   Two `TelebirrInApp` pushes → two poll loops on the same trace id → two orders.

---

## 5. Why other gateways don't duplicate the same way

- **Card gateways (BOA, EthSwitch, Zemen, Dashen, Wegagen, etc.)** increment `uuid` before each
  attempt, so a retry uses a **new** trace number and verification (`_boaVerify`) is tied to a
  fresh attempt — a stale success can't be re-read the way H1 allows.
- **Wegagen** additionally gates on `if (value == true)` before creating the order (`:2524` area).
- **Telebirr in-app** is the only path combining: fixed trace number + always-poll + ignore
  returned value + no creation guard.

---

## 6. How to confirm each hypothesis (no code change required)

- **H1 / H5:** Reproduce the retry-after-failure path on a test order; watch the existing
  `debugPrint('###[Telebirr] pollTelebirrStatus result: $isPaid')` (`:2144`) and
  `debugPrint('DATA>>>: $data')` (`:177`). If a *second* entry logs `isPaid: true` for the same
  `merch_order_id`, H1/H5 are confirmed.
- **H3:** With a Telebirr order in flight, tap the bottom **Place Order** and check the server for
  a second `create_order` / `pay_order_payment` call.
- **H4:** Rapidly double-tap **Continue**; check for two `TelebirrInApp` pushes / two poll logs.
- **H7:** On the backend, send two `create_order` requests with the same `cart_id` /
  `order_payment_id` and observe whether two orders are persisted. This determines whether the
  client races are cosmetic or produce real duplicates.

(All of the above are observational — they rely on logs and server records, not code edits.)

---

## 7. Fix directions (for later — not applied here)

- **Client:** a single-flight guard so order creation runs at most once per confirmed payment;
  gate the bottom **Place Order** button (and the tile) while a flow is in progress; keep polling
  as the source of truth but never re-create if an order is already placed.
- **Backend (most durable):** make `create_order` idempotent on `order_payment_id` /
  `cart_id` so repeated calls return the existing order instead of creating a new one. This
  neutralizes every client-side race above.

---

## 8. File / line reference index

| Concern | Location |
|---|---|
| Fixed trace key constant | `lib/utils/constants.dart:323` |
| Trace number used (push) | `lib/kifiya/kifiya_screen.dart:2108` |
| Trace number used (poll) | `lib/kifiya/kifiya_screen.dart:2141` |
| `.then` ignores `value`, always polls | `lib/kifiya/kifiya_screen.dart:2115-2178` |
| `pollTelebirrStatus` loop / exits | `lib/kifiya/kifiya_screen.dart:126-214` |
| `_createOrder` (no guard) | `lib/kifiya/kifiya_screen.dart:502` |
| `_createCourierOrder` (no guard) | `lib/kifiya/kifiya_screen.dart:460` |
| `_createAliexpressOrder` (no guard) | `lib/kifiya/kifiya_screen.dart:474` |
| `_payOrderPayment` (parallel path) | `lib/kifiya/kifiya_screen.dart:590` |
| Bottom "Place Order" button | `lib/kifiya/kifiya_screen.dart:2786` |
| `CustomButton` tap not gated by `isLoading` | `lib/custom_widgets/custom_button.dart:36-38` |
| `create_order` cart_id (server-driven) | `lib/kifiya/kifiya_screen.dart:3613`, `:3234` |
| Disabled server callback (`confirmPayment`) | `lib/kifiya/components/telebirr_inapp.dart:354-388` |
| Orphan unused `_orderPlaced` field | `lib/kifiya/kifiya_screen.dart:72` |
