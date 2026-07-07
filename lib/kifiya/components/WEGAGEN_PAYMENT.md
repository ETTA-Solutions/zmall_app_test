# Wegagen Bank Payment Flow

This document explains how the Wegagen Bank USSD payment works in the app: the
request that is sent, how the response is interpreted, and how the app decides
which kind of order to create after a successful payment.

Files involved:
- `lib/kifiya/kifiya_screen.dart` — triggers the payment and creates the order
- `lib/kifiya/components/wegagen_ussd.dart` — performs the actual charge

---

## 1. High-level flow

```
KifiyaScreen (user taps "Continue")
        │
        │  Navigator.push(WegagenUssd(...))
        ▼
WegagenUssd screen
        │  initState() → _initPayment() → initPayment()  (HTTP POST)
        │
        ├─ approved  → Navigator.pop(context, true)
        └─ declined  → Navigator.pop(context, false)
        │
        ▼
KifiyaScreen .then((value) {...})
        │
        ├─ value == true  → create order (see §5)
        └─ value != true  → show "Payment not completed", reset method
```

Unlike other gateways (e.g. BoA, which needs a separate `_boaVerify()` polling
step), **Wegagen confirms the charge synchronously in its HTTP response**. So as
soon as the screen pops with `true`, the order is created directly.

---

## 2. How `WegagenUssd` is created (from KifiyaScreen)

In the `wegagen` branch of the payment chain, after `useBorsa()` succeeds and the
user confirms the dialog, the screen is pushed:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) {
      return WegagenUssd(
        title: "Wegagen Bank Payment",
        url: "https://testapp.zmall.et/admin/pay_payment_wegagen_ussd_pay",
        hisab: widget.price!,                                  // amount
        traceNo: uuid + "_" + widget.orderPaymentUniqueId!,    // unique ref
        phone: userData['user']['phone'],
        orderPaymentId: widget.orderPaymentId!,
      );
    },
  ),
).then((value) { ... });   // value is the true/false the screen pops with
```

Notes:
- `uuid` is incremented (`uuid = (int.parse(uuid) + 1).toString()`) before each
  attempt so retries get a fresh `traceNo`.
- `url` currently points at **`testapp.zmall.et`** (the test backend endpoint).

---

## 3. The request body

The request is built and sent in `wegagen_ussd.dart` → `initPayment()`.

### 3.1 Account number

```dart
final accountNo = _useTestAccount ? _testAccountNo : "251${widget.phone}";
```

- `_useTestAccount = true` and `_testAccountNo = "251947635677"` are a
  **temporary test override**. Wegagen's test system only recognizes specific
  registered accounts, so the code forces a known-good test account.
- In production, this must become `"251${widget.phone}"` (Ethiopia country code
  `251` + the user's phone) and `_useTestAccount` set to `false`.

### 3.2 Unique reference

```dart
final unique = "${widget.traceNo}_${DateTime.now().millisecondsSinceEpoch}";
```

Wegagen rejects a `referenceId` it has seen before (`"Duplicate reference_id"`),
so a millisecond timestamp is appended to guarantee uniqueness on every attempt.

### 3.3 Body sent to the backend

```dart
Map data = {
  "requestId":   "purchase-$unique",
  "referenceId": unique,
  "invoiceId":   unique,
  "accountNo":   accountNo,                  // 251947635677 in test mode
  "amount":      widget.hisab.toStringAsFixed(2),   // e.g. "150.00"
  "description": "ZMall order payment",
};
var body = json.encode(data);
```

### 3.4 The HTTP call

```dart
http.post(
  Uri.parse(widget.url),                     // the pay_payment_wegagen_ussd_pay URL
  headers: {
    "Content-Type": "application/json",
    "Accept":       "application/json",
  },
  body: body,
).timeout(Duration(seconds: 30), onTimeout: () {
  throw TimeoutException("The connection has timed out!");
});
```

On any error (network/timeout/parse), it shows a connection error and returns
`null`. Otherwise it returns the decoded JSON response.

---

## 4. How the response is interpreted

`_isApproved(data)` accepts **two response shapes**, because the gateway answer
and the backend-wrapped answer differ:

```dart
bool _isApproved(dynamic data) {
  if (data is! Map) return false;
  if (data['success'] == true) return true;                 // backend wrapper
  if (data['responseCode']?.toString() == "2001") return true;  // raw gateway code
  final state = (data['params'] is Map)
      ? data['params']['state']?.toString().toUpperCase()
      : null;
  return state == "APPROVED";                               // raw gateway state
}
```

Approved if **any** of these is true:
- `success == true`
- `responseCode == "2001"`
- `params.state == "APPROVED"`

If approved → shows "Payment approved. Creating your order..." then
`Navigator.pop(context, true)`.
If not → shows an error message (`message` / `responseMsg` / `errorCode`) then
`Navigator.pop(context, false)` after a short delay.

---

## 5. Choosing which order to create

Back in `KifiyaScreen`, the `.then((value) {...})` callback runs after the screen
pops:

```dart
if (value == true) {
  widget.isCourier!
      ? _createCourierOrder()
      : (aliexpressCart != null &&
              aliexpressCart!.cart.storeId == cart.storeId)
          ? _createAliexpressOrder()
          : _createOrder();
} else {
  Service.showMessage(... "Payment not completed ...", error: true);
  setState(() { kifiyaMethod = -1; });   // deselect payment method
}
```

This is a nested ternary — the decision order is:

| Priority | Condition | Method called | Meaning |
|----------|-----------|---------------|---------|
| 1 | `widget.isCourier == true` | `_createCourierOrder()` | This checkout is a courier/delivery order. |
| 2 | `aliexpressCart != null` **and** `aliexpressCart.cart.storeId == cart.storeId` | `_createAliexpressOrder()` | The cart is an AliExpress dropshipping cart for the current store. |
| 3 | otherwise | `_createOrder()` | A normal marketplace order. |

So courier wins first; if not courier, it checks whether the active cart is an
AliExpress cart matching the current store; otherwise it falls back to the
standard order.

### 5.1 `_createCourierOrder()`
Guards against double submission with `_placeOrder`, sets loading, then calls the
backend `createCourierOrder()`. No extra response branching here.

### 5.2 `_createAliexpressOrder()`
Calls `createAliexpressOrder()` first (places the order on AliExpress). It is
considered successful only if **all** of these hold:

```dart
data != null &&
data['success'] &&
data['data']['error_response'] == null &&
data['data']['aliexpress_ds_order_create_response']['result']['is_success']
```

On success it extracts the AliExpress order numbers and forwards them to the
normal order creator:

```dart
List<dynamic>? orderIds =
    data['data']['aliexpress_ds_order_create_response']['result']['order_list']['number'];
_createOrder(orderIds: orderIds);
```

So an AliExpress order is a **two-step** creation: place on AliExpress → then
record the order in ZMall's backend (passing the AliExpress order IDs).

### 5.3 `_createOrder({orderIds})`
The final/normal creator. Calls backend `createOrder(orderIds: orderIds)` and on
`data['success']`:
- shows "Order successfully created"
- clears `cart` and `aliexpressCart` from local storage
- navigates (replacement) to `ReportScreen` with the price and
  `orderPaymentUniqueId`.

On failure it maps `data['error_code']` to a human message via `errorCodes` and
resets the loading/place-order flags.

---

## 6. Key takeaways

- The **request body** is built entirely in `WegagenUssd.initPayment()`; the
  amount, a unique reference (timestamped to avoid duplicates), and the account
  number (currently forced to a **test account**).
- The screen returns a simple **`true`/`false`** to signal payment success.
- Payment is verified **synchronously** — no polling/verify step.
- The order type is chosen by a 3-way decision: **courier → AliExpress → normal**,
  and AliExpress orders chain into `_createOrder()` after the AliExpress call.
- All three methods are protected by the `_placeOrder` flag to prevent duplicate
  submissions.

> ⚠️ Before production: set `_useTestAccount = false` (so it uses the real
> `251${phone}` account) and point `url` at the production endpoint instead of
> `testapp.zmall.et`.
