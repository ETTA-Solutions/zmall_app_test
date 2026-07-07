# Telebirr In-App — Duplicate Orders

**Screen:** `lib/kifiya/kifiya_screen.dart`
**Component:** `lib/kifiya/components/telebirr_inapp.dart`
**Status:** Diagnosed — fix pending
**Also affects:** `lib_main/kifiya/kifiya_screen.dart` (identical copy)

---

## Summary

Paying with **Telebirr In-App** can create the **same order twice**. The flow has no
single-flight / idempotency guard on order creation, and this combines with two behaviors
that are unique to the Telebirr in-app path.

---

## Root cause

### 1. A fixed, reusable trace number

Unlike the card gateways (BOA, EthSwitch, Zemen, Dashen…) which increment `uuid` before
each attempt:

```dart
uuid = (int.parse(uuid) + 1).toString();
```

Telebirr in-app always uses a **constant** trace number:

```dart
"${kTelebirrInAppTraceKey}${widget.orderPaymentUniqueId!}"   // "ZTelebirrInApp" + orderPaymentUniqueId
```

- Created in `telebirr_inapp.dart:396` (`/telebirrInapp/create_order`)
- Polled in `kifiya_screen.dart:2130` (`/teleInapp/query`)

Both use the **same** `merch_order_id`, so every Telebirr attempt for a given cart queries
the **same** payment record.

### 2. The callback ignores the returned result and always polls

`kifiya_screen.dart:2104-2167`:

```dart
).then((value) async {
  // `value` is completely ignored — even if the user pressed Back / cancelled
  final isPaid = await pollTelebirrStatus(
    merchOrderId: "${kTelebirrInAppTraceKey}${widget.orderPaymentUniqueId!}",
  );
  if (isPaid) {
    ...
    _createOrder();   // no guard against being called again
  }
});
```

Compare with:
- **Wegagen** — checks `if (value == true)` before creating the order.
- **Card gateways** — verify through `_boaVerify()`.
- **Telebirr in-app** — polls **unconditionally**, regardless of the returned value.

### 3. No idempotency guard on order creation

None of `_createOrder`, `_createCourierOrder`, or `_createAliexpressOrder` check whether an
order was already placed, so nothing stops a second invocation.

---

## How two orders get created

Because the trace number is constant and the poll runs regardless of the returned value, any
**re-entry** into the flow re-confirms the **same** successful payment and creates **another**
order.

| Trigger | What happens |
|---|---|
| **Retry after a perceived failure** | User pays, thinks it failed (slow confirm), backs out, taps Telebirr again → second poll finds the *already-paid* record for the same `merch_order_id` → `_createOrder()` fires a second time. |
| **Double-tap on the "Continue" dialog button** | Two `Navigator.push` → two `TelebirrInApp` screens → two `.then` callbacks → two poll loops → both see `PAID` → two orders. |
| **Bottom "Place Order" button** | Stays active during the whole flow. Pressing it calls `_payOrderPayment()` — a completely separate order-creation path. |

---

## Fix

### 1. Add a re-entrancy guard (stops the duplicates)

Add to state:

```dart
bool _orderPlaced = false;
```

Guard the entry of each creation method:

```dart
void _createOrder({List<dynamic>? orderIds}) async {
  if (_orderPlaced) return;
  _orderPlaced = true;
  ...
}
```

Apply the same guard to `_createCourierOrder` and `_createAliexpressOrder`.
Reset `_orderPlaced = false` in the **failure** branches so a genuinely failed order can be
retried.

### 2. Stop ignoring the cancel result (Telebirr callback)

```dart
).then((value) async {
  if (value == false) {
    // user cancelled / backed out — do not poll or create an order
    setState(() => kifiyaMethod = -1);
    return;
  }
  final isPaid = await pollTelebirrStatus(...);
  ...
});
```

### 3. Disable the bottom "Place Order" button while a gateway flow is in progress

Gate it on `_placeOrder` so it cannot fire a second, parallel order-creation path.

---

## Files to update

- `lib/kifiya/kifiya_screen.dart`
- `lib_main/kifiya/kifiya_screen.dart` (identical copy — apply the same fix)

---

## Verification checklist

- [ ] Pay once with Telebirr in-app → exactly **one** order created.
- [ ] Pay, back out, re-open Telebirr in-app → **no** second order created.
- [ ] Double-tap "Continue" in the confirm dialog → only **one** order.
- [ ] Press bottom "Place Order" during the Telebirr flow → **no** extra order.
- [ ] A genuinely failed/cancelled payment can still be retried successfully.
