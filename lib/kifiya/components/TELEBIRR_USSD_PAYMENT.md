# Deep-Dive: Telebirr USSD Architecture & Payment Lifecycle

This document provides a comprehensive, deep-down technical explanation of the **Telebirr USSD Payment System** in the ZMall application. It details every layer of the implementation: from the GSM telecommunications protocol and gateway architecture, down to the Flutter UI state transitions, asynchronous recursive polling, security verifications, and backend order creation.

---

## 1. System Topology & Architecture

Telebirr USSD uses **Network-Initiated USSD (USSD Push)**. Unlike web-based payment gateways that load inside an in-app `WebView`, USSD runs directly over the GSM cellular signaling channel (SS7 / MAP protocol) to the user's SIM card.

Because the user types their PIN on their device's native operating system dialer, the mobile app cannot directly observe user input. The app bridges this gap using an **Out-of-Band Polling Architecture**.

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                         SYSTEM TOPOLOGY                                                │
└────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    [ Customer Handset ]
       │            ▲
       │ GSM USSD   │ Network-Initiated USSD Push
       │ PIN Dialog │ ("Pay ETB 250 to ZMall? Enter PIN")
       ▼            │
 ┌──────────────────────────┐
 │  Ethio Telecom Telebirr  │
 │       Core Network       │
 └───────▲──────────┬───────┘
         │          │
         │ API Push │ Server-to-Server Webhook / IPN
         │ Request  │ (Payment notification callback)
         │          ▼
 ┌───────┴──────────────────┐          ┌──────────────────────────┐
 │   Odoo Gateway Server    │          │      ZMall Backend       │
 │    (196.189.44.60:8069)  │          │      (API & Database)    │
 └───────▲──────────────────┘          └────────────▲─────────────┘
         │ HTTP POST                                │
         │ /telebirr/ussd/send_sms                  │ Polling HTTP POST:
         │                                          │ /admin/check_paid_order
         │                                          │ Order Creation HTTP POST:
         │                                          │ /api/user/create_order
         │                                          │
 ┌───────┴──────────────────────────────────────────┴─────────────┐
 │                      ZMall Flutter App                         │
 │                                                                │
 │   KifiyaScreen ──────► TelebirrUssd ──────► _boaVerify()       │
 │   (Pre-checks)        (Push & Poll)         (Order Creation)   │
 └────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Participating Components

| Component | Physical Host | Responsibility |
| :--- | :--- | :--- |
| **`KifiyaScreen`** | Client (Flutter App) | Handles payment selection, wallet locking (`useBorsa`), initiates trace numbers, and executes order creation. |
| **`TelebirrUssd`** | Client (Flutter App) | Renders the waiting UI, fires the USSD push, and executes the asynchronous recursive polling loop. |
| **Odoo Gateway** | `http://196.189.44.60:8069` | Middleware proxy/aggregator authenticating with Ethio Telecom and initiating the USSD push. |
| **Ethio Telecom Core** | Telebirr Infrastructure | Routes the USSD session to the customer's SIM, debits the wallet, and issues payment notifications. |
| **ZMall Backend** | Production API | Maintains order state, consumes payment webhooks, serves `/admin/check_paid_order`, and records orders. |

---

## 3. End-to-End Execution Flow (Chronological)

```
[KifiyaScreen]                      [TelebirrUssd]               [Odoo Gateway]         [Ethio Telecom]          [ZMall Backend]
      │                                    │                            │                      │                        │
      ├── 1. useBorsa() ───────────────────────────────────────────────────────────────────────────────────────────────►│ (Lock wallet)
      │◄── 2. { success: true } ───────────────────────────────────────────────────────────────────────────────────────┤
      │                                    │                            │                      │                        │
      ├── 3. Navigator.push ──────────────►│                            │                      │                        │
      │   (TelebirrUssd)                   │                            │                      │                        │
      │                                    ├── 4. initTelebirr() ──────►│                      │                        │
      │                                    │      (POST send_sms)       ├── 5. Push USSD ─────►│                        │
      │                                    │                            │                      ├── 6. Flash to phone ──► (Customer Phone)
      │                                    │                            │◄── 7. Ack ───────────┤                        │
      │                                    │◄── 8. { success: true } ───┤                      │                        │
      │                                    │                            │                      │                        │
      │                                    ├── 9. _verifyPayment() (Poll #1) ──────────────────────────────────────────►│
      │                                    │◄── 10. { success: false } ────────────────────────────────────────────────┤
      │                                    │                            │                      │                        │
      │                                    │    [Customer enters PIN on handset] ─────────────►│                        │
      │                                    │                            │                      ├── 11. Webhook (IPN) ──►│
      │                                    │                            │                      │   (Mark order PAID)    │
      │                                    │                            │                      │                        │
      │                                    ├── 12. _verifyPayment() (Poll #2) ─────────────────────────────────────────►│
      │                                    │◄── 13. { success: true } ─────────────────────────────────────────────────┤
      │                                    │                            │                      │                        │
      │                                    ├── 14. Navigator.pop()      │                      │                        │
      │◄── 15. .then() callback wakes ─────┘                            │                      │                        │
      │                                                                 │                      │                        │
      ├── 16. _boaVerify() (Authoritative check) ──────────────────────────────────────────────────────────────────────►│
      │◄── 17. { success: true } ──────────────────────────────────────────────────────────────────────────────────────┤
      │                                                                 │                      │                        │
      ├── 18. _validateCourierImagesBeforePayment() (Security check)    │                      │                        │
      │                                                                 │                      │                        │
      ├── 19. _createOrder() ──────────────────────────────────────────────────────────────────────────────────────────►│ (Creates Order)
      │◄── 20. { success: true, order: {...} } ────────────────────────────────────────────────────────────────────────┤
      │                                                                 │                      │                        │
      └── 21. Clear local cart & Navigator.pushReplacement(ReportScreen)
```

---

## 4. In-Depth Phase Breakdown

### Phase 1: Pre-Payment State & Trace Preparation (`KifiyaScreen`)

When the user taps **Pay** with Telebirr selected in `kifiya_screen.dart`:

1. **Wallet Synchronization (`useBorsa`)**:
   ```dart
   var data = await useBorsa();
   ```
   - Sends `POST /api/user/change_user_wallet_status`.
   - Prevents race conditions or double-spending where a user might attempt to use both wallet credits and Telebirr simultaneously.

2. **Idempotent Trace Construction**:
   ```dart
   var uniqueId = RandomDigits.getString(6);
   String uniqueIdString = uniqueId;
   traceNo: "${uniqueIdString}_${widget.orderPaymentUniqueId!}"
   ```
   - **Why this is required**: Telebirr’s gateway enforces strict idempotency. If a transaction fails or times out and the user retries with the exact same `orderPaymentUniqueId`, Telebirr will reject it with `"Duplicate trace_no"`.
   - By prefixing a cryptographically random 6-digit number, every attempt receives a distinct transaction reference while preserving the parent order ID for reconciliation.

---

### Phase 2: USSD Push Initialization (`TelebirrUssd`)

When `TelebirrUssd` mounts, `initState()` triggers `_initTelebirr()`.

#### The Request Payload:
```dart
Map data = {
  "traceNo": widget.traceNo,                         // e.g. "839102_64e8a1bc72..."
  "amount": widget.hisab,                            // Order price (double)
  "phone": "251${widget.phone}",                     // International E.164 without '+'
  "payerId": "22",                                   // Merchant ID
  "appId": "1234",                                   // Gateway Client ID
  "apiKey": "90e503b019a811ef9bc8005056a4ed36",       // Gateway API Secret Key
  "zmall": true,                                     // Client tag
  "channel": "zmalltest",                            // Gateway routing channel
};
```

#### HTTP Dispatch:
- **Target URL**: `http://196.189.44.60:8069/telebirr/ussd/send_sms`
- **Headers**: `Content-Type: application/json`, `Accept: application/json`
- **Timeout**: 10 seconds strict timeout.

#### Response Evaluation:
```dart
if (data != null && data['result'] != null && data['result']['success'] == true) {
  Service.showMessage(
    context: context,
    title: "${data['result']['message']}. Waiting for payment to be completed",
    error: false,
  );
  _verifyPayment(); // Start polling
} else {
  // Display error message from gateway
}
```
> [!NOTE]
> `initTelebirr()` returning `success == true` only indicates that the gateway accepted the message and initiated the USSD push to Ethio Telecom. It does **NOT** mean money has been deducted.

---

### Phase 3: The Asynchronous Recursive Polling Loop (`_verifyPayment`)

Because the customer enters their PIN inside their phone's native USSD dialog, the app must actively poll the ZMall server until the status changes.

```dart
void _verifyPayment() async {
  if (!mounted) return; // Exit guard 1: Widget destroyed
  _verifyAttempt++;

  var data = await verifyPayment();

  if (!mounted) return; // Exit guard 2: Widget destroyed during HTTP request

  if (data != null && data['success'] == true) {
    Navigator.pop(context); // SUCCESS EXIT: Dismiss waiting dialog
  } else {
    await Future.delayed(Duration(seconds: 2)); // Throttle
    if (mounted) {
      _verifyPayment(); // RECURSIVE CALL: Re-execute
    }
  }
}
```

#### Key Technical Properties:
1. **Asynchronous Recursion**:
   - The method does not block a thread or allocate stack frames indefinitely. Because it awaits `Future.delayed`, the execution context yields to the Dart Event Loop. When the 2-second timer fires, the function runs as a new microtask. Stack overflow is impossible.
2. **Lifecycle Immunity (`mounted`)**:
   - If the user presses the system Back button or abandons the flow, `mounted` becomes `false`. Both pre-request and post-delay checks terminate immediately, ensuring no memory leaks or dangling background requests.
3. **Polling Endpoint (`verifyPayment`)**:
   - Queries `POST ${baseUrl}/admin/check_paid_order`.
   - Body: `{"user_id": ..., "server_token": ..., "order_payment_id": ...}`.

---

### Phase 4: Parent Screen Verification (`_boaVerify`)

When `TelebirrUssd` is popped (either automatically on success or manually by user back navigation), the `Navigator.push(...).then(...)` callback fires in `KifiyaScreen`:

```dart
Navigator.push(...).then((value) {
  _boaVerify();
});
```

#### Why `_boaVerify()` is Critical:
`_boaVerify()` runs on the parent screen and serves as an **authoritative gatekeeper**:
* If the user closed the modal manually without paying, `_boaVerify()` queries `/admin/check_paid_order`. Finding `success == false`, it stops execution, displays an error snackbar, and resets the UI state via `useBorsa()`.
* If payment was genuine, it guarantees that order creation logic only runs in the persistent context of `KifiyaScreen`, independent of the child modal's lifecycle.

---

### Phase 5: Security Pre-Checks & Order Creation Routing

Upon confirmed payment in `_boaVerify()`, the system routes through strict invariants:

#### Step 1: Courier Image Pre-Flight Validation
```dart
bool imagesValid = await _validateCourierImagesBeforePayment();
if (!imagesValid) {
  Service.showMessage(
    context: context,
    title: "Payment verified but order could not be created due to missing images. Please contact support at 8707.",
    error: true,
  );
  return false;
}
```
If an order is a courier delivery and uploaded parcel images became corrupted, payment is flagged and the order is withheld to prevent dispatching incomplete delivery jobs.

#### Step 2: Three-Way Creation Priority
```dart
widget.isCourier!
    ? _createCourierOrder()
    : (aliexpressCart != null && aliexpressCart!.cart.storeId == cart.storeId)
        ? _createAliexpressOrder()
        : _createOrder();
```

| Order Mode | Target Function | Backend Endpoint | Behavior |
| :--- | :--- | :--- | :--- |
| **Courier** | `_createCourierOrder()` | `POST /api/user/create_order` (Multipart) | Uploads coordinates, recipient details, vehicle selection, and parcel images. |
| **AliExpress** | `_createAliexpressOrder()` | External AliExpress API + ZMall API | Places order on AliExpress dropshipping backend first; on success, forwards external order IDs to `_createOrder(orderIds)`. |
| **Standard** | `_createOrder()` | `POST /api/user/create_order` (JSON) | Creates normal food or grocery store marketplace order with items from cart. |

#### Step 3: State Cleanup & Transition
Upon receiving `data['success'] == true` from `createOrder`:
1. `Service.remove('cart')` — Clears cached cart data.
2. `Service.remove('aliexpressCart')` — Clears AliExpress cached cart data.
3. `Navigator.pushReplacementNamed(..., ReportScreen.routeName)` — Replaces the payment screen with the final receipt, preventing back-navigation from re-triggering payment.

---

## 5. Security Invariants & Fault Tolerance

| Scenario | Risk | Mitigation in Code |
| :--- | :--- | :--- |
| **Duplicate Submissions** | Double billing on network lag. | The `_placeOrder` boolean flag locks UI buttons immediately upon dispatch. |
| **Gateway Idempotency Rejection** | Telebirr rejects repeated attempts with same ref. | Appends 6-digit random digits: `${RandomDigits.getString(6)}_${orderPaymentUniqueId}`. |
| **Premature Back Navigation** | User cancels UI while payment is processing in background. | `_boaVerify()` checks `/admin/check_paid_order` regardless of how the screen was closed. |
| **Network Timeout** | Mobile drop-off during push initiation. | Explicit `10-second` timeout in `initTelebirr()` with graceful fallback message. |
| **Double-Spending Wallet Balance** | Using local wallet funds during external gateway session. | `useBorsa()` locks wallet balance before pushing `TelebirrUssd`. |
