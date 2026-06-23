# KifiyaScreen — Deep Guide

**File:** `lib/kifiya/kifiya_screen.dart` (3790 lines)  
**Route:** `/kifiya`  
**Purpose:** The single payment screen for all order types. Loads available payment gateways from the backend, lets the user pick one, drives the payment flow, and creates the final order.

---

## 1. Widget Parameters (Constructor)

```dart
KifiyaScreen({
  this.vehicleId,             // String? — courier vehicle ID
  this.onlyCashless = false,  // bool   — restrict to digital only (no cash)
  this.price,                 // double? — total amount to pay
  this.isCourier = false,     // bool   — courier order vs store order
  this.orderPaymentId,        // String? — payment record ID (for verification)
  this.orderPaymentUniqueId,  // String? — unique trace key for payment gateways
  this.userpickupWithSchedule,// bool?  — user scheduled pickup flag
})
```

| Parameter | Where it comes from |
|---|---|
| `price` | Checkout screen, calculated from cart total |
| `isCourier` | Passed by courier checkout or delivery screen |
| `vehicleId` | `vehicles[0]._id` from API response, via DeliveryScreen |
| `orderPaymentId` | Backend payment record `_id` |
| `orderPaymentUniqueId` | Unique string used as trace ID for all payment gateways |
| `onlyCashless` | Set by store when only digital payments are accepted |
| `userpickupWithSchedule` | Passed from checkout when user schedules a pickup |

---

## 2. State Variables

| Variable | Type | Purpose |
|---|---|---|
| `_loading` | `bool` | Controls `ModalProgressHUD` overlay (spinner) |
| `_placeOrder` | `bool` | Secondary loading flag when order is being placed |
| `kifiyaMethod` | `int` | Index of selected payment method (`-1` = nothing selected) |
| `paymentResponse` | `dynamic` | Full response from `get_payment_gateway` API |
| `orderResponse` | `dynamic` | Response from `create_order` API |
| `userData` | `dynamic` | Logged-in user from SharedPreferences |
| `cart` | `Cart` | Store cart model |
| `courierCart` | `dynamic` | Courier cart from SharedPreferences |
| `aliexpressCart` | `AliExpressCart?` | AliExpress cart model |
| `imagePath` | `List<String>` | Paths to courier package photos |
| `services` | `dynamic` | Service/delivery data (for courier `pay_order_payment`) |
| `paidBySender` | `bool` | Courier: `true` = sender pays, `false` = receiver pays |
| `isCourierSchedule` | `bool` | Whether courier order is scheduled |
| `courierScheduleDate` | `String` | Schedule date string |
| `currentBalance` | `double` | User's wallet balance |
| `uuid` | `String` | Starts as `orderPaymentUniqueId`, incremented on retry |
| `aliExpressAccessToken` | `dynamic` | AliExpress OAuth token |
| `linearProgressIndicator` | `Widget` | Custom loading message widget |

---

## 3. Initialization Flow

```
initState()
  └─ getUser()                         ← reads 'user' + 'ali_access_token' from SharedPreferences
       └─ getCart()
            ├─ [isCourier == true]
            │    reads 'courier' from SharedPreferences
            │    └─ _getPaymentGateway()
            │    └─ getServices()      ← reads 'services' from SharedPreferences
            │    └─ getImages()        ← reads 'images' from SharedPreferences
            │    └─ getCourierKefay()  ← reads 'courier_paid_by_sender' bool
            │    └─ getCourierSchedule()     ← reads 'is_schedule' bool
            │    └─ getCourierScheduleDate() ← reads 'schedule_start' string
            │
            └─ [isCourier == false]
                 reads 'cart' + 'aliexpressCart' from SharedPreferences
                 └─ _getPaymentGateway()

_getPaymentGateway()
  └─ getPaymentGateway()   ← API call → sets paymentResponse
       └─ useBorsa()       ← immediately called on success (reset wallet usage status)
```

---

## 4. UI Structure

```
Scaffold
├── AppBar: "Payments" (localized)
└── Body: ModalProgressHUD (spinner when _loading = true)
     └── [shows only when paymentResponse != null]
          ├── Price + Balance row (from paymentResponse['wallet'])
          ├── [courier only] Attached image thumbnails preview
          ├── "Select Payment Method" label
          ├── [onlyCashless] "Only digital payments accepted" hint
          └── GridView (3 columns) of KifiyaMethodContainer tiles
               └── each tile: logo image + payment name, tappable
└── BottomNavigationBar
     └── CustomButton "Place Order"
          └── onPress → _payOrderPayment(otp: "")
```

The payment grid comes from `paymentResponse['payment_gateway']` array. Each item has a `name` field used to match the right logo and trigger the right flow.

---

## 5. All Payment Methods & Their Flows

Every payment method except Cash/Wallet first calls `useBorsa()` before opening any screen. This tells the backend whether to use wallet balance.

| Payment Name | How It Works | Verification |
|---|---|---|
| **cash** | Place Order button directly | `payOrderPayment(otp: "")` |
| **wallet** | Place Order button directly | `payOrderPayment(otp: "")` |
| **telebirr reference** | Opens `KifiyaVerification` screen | Returns success → `createOrder()` |
| **boa** | Opens `CyberSource` WebView | Returns → `_boaVerify()` |
| **amole** | Opens `AmoleScreen` (OTP entry) | Returns OTP → `payOrderPayment(otp: value)` |
| **ethswitch** | Opens `EthSwitchScreen` WebView | Returns → `_ethSwitchVerify()` → `_boaVerify()` |
| **etta card** | Opens `EttaCardScreen` WebView | Returns → `_boaVerify()` |
| **santimpay** | Opens `SantimPay` screen | Returns → `_boaVerify()` |
| **chapa** | Opens `ChapaScreen` | Returns → `_boaVerify()` |
| **cbe birr** | Opens `CbeUssd` screen | Returns → `_boaVerify()` |
| **tele birr** | Opens `TelebirrUssd` screen (USSD) | Returns → `_boaVerify()` |
| **dashen mastercard** | Opens `DashenMasterCard` screen | Returns → `_boaVerify()` |
| **starpay** | Opens `StarPayScreen` | Returns → `_boaVerify()` |
| **telebirr inapp** | Opens `TelebirrInApp` screen | Returns → `_boaVerify()` → fallback: `pollTelebirrStatus()` |
| **addis pay** | Opens `AddisPay` screen | Returns → `_boaVerify()` |
| **yagoutpay** | Opens `YagoutPay` screen | Returns → `_boaVerify()` |
| **zemen** | Opens `Telebirr` WebView (Zemen URL) | Returns → `_boaVerify()` |
| **dashen** | Opens `Telebirr` WebView (Dashen URL) | Returns → `_boaVerify()` |

---

## 6. Complete Payment Flow (Big Picture)

```
User taps payment tile
    │
    ├── useBorsa()                  ← toggle wallet usage on backend
    │
    ├── [if cash / wallet]
    │    User taps "Place Order"
    │         └── _payOrderPayment(otp: "")
    │
    └── [all other methods]
         Open payment sub-screen
              └── Sub-screen completes
                   │
                   ├── [Amole] returns OTP
                   │    └── _payOrderPayment(otp: value)
                   │         └── payOrderPayment() API → /api/user/pay_order_payment
                   │              └── success → createOrder() or createCourierOrder()
                   │
                   ├── [EthSwitch] returns traceNo
                   │    └── _ethSwitchVerify(traceNo)
                   │         └── ethSwitchVerify() API → /admin/pay_payment_etswitch
                   │              └── success → _boaVerify()
                   │
                   └── [all others] return normally
                        └── _boaVerify()
                             └── boaVerify() API → /admin/check_paid_order
                                  └── success → createOrder() or createCourierOrder()
                                       └── success → navigate to ReportScreen
                                       └── fail   → showError + _logFailedOrderAfterPayment()
```

**Telebirr InApp special case:** After `_boaVerify()` fails (payment may still be processing), it waits 3 seconds then calls `pollTelebirrStatus()` which polls `https://pgw.shekla.app/teleInapp/query` every 3 seconds until paid/failed.

---

## 7. All API Calls

### `getPaymentGateway()` — line 2674
```
POST /api/user/get_payment_gateway
Timeout: 20s
```
```json
{
  "user_id": "...",
  "city_id": "...",
  "server_token": "...",
  "store_delivery_id": "<orderPaymentId>",
  "is_user_pickup_with_schedule": false,
  "vehicleId": "<vehicleId>",
  "device_type": "android",
  "app_version": "<appVersion>"
}
```
**Response:** Sets `paymentResponse` which contains `payment_gateway` array (list of methods) and `wallet` (user balance).

---

### `useBorsa()` — line 2833
```
POST /api/user/change_user_wallet_status
Timeout: 20s
```
```json
{
  "user_id": "...",
  "is_use_wallet": true,
  "server_token": "..."
}
```
`is_use_wallet` is `true` only when `kifiyaMethod` index points to the "wallet" payment method.

---

### `payOrderPayment()` — line 2739
```
POST /api/user/pay_order_payment
Timeout: 40s
```

**Store:**
```json
{
  "user_id": "...",
  "otp": "",
  "order_payment_id": "...",
  "payment_id": "<payment_gateway[index]._id>",
  "is_payment_mode_cash": false,
  "server_token": "..."
}
```

**Courier (adds `order_type` and `store_delivery_id`):**
```json
{
  "user_id": "...",
  "otp": "",
  "order_payment_id": "...",
  "payment_id": "<payment_gateway[index]._id>",
  "order_type": 7,
  "is_payment_mode_cash": false,
  "server_token": "...",
  "store_delivery_id": "<services.deliveries[0]._id>"
}
```
`is_payment_mode_cash` is `true` when selected method name is "wallet" or "cash".

---

### `boaVerify()` — line 3656
```
POST /admin/check_paid_order
Timeout: 30s
```
```json
{
  "user_id": "...",
  "server_token": "...",
  "order_payment_id": "..."
}
```
Called after every external payment screen returns. If success → triggers order creation.

---

### `ethSwitchVerify()` — line 3722
```
POST /admin/pay_payment_etswitch
Timeout: 30s
```
```json
{
  "user_id": "...",
  "server_token": "...",
  "trace_no": "uuid_orderPaymentUniqueId"
}
```

---

### `createOrder()` — line 3465 (Store)
```
POST /api/user/create_order
Content-Type: application/json
Timeout: 50s
```
```json
{
  "user_id": "...",
  "cart_id": "<user.cart_id>",
  "is_schedule_order": false,
  "schedule_order_start_at": "",
  "server_token": "...",
  "aliexpress_order_ids": ["..."]
}
```
`aliexpress_order_ids` only added if AliExpress cart matches current store.

---

### `createCourierOrder()` — line 3086 (Courier)
```
POST /api/user/create_order
Content-Type: multipart/form-data
Timeout: 40s
```
```
user_id                 = "..."
server_token            = "..."
cart_id                 = "<courierCart.cart_id>"
delivery_type           = "2"
paid_by                 = "1" (sender) | "2" (receiver)
is_schedule_order       = "true" | "false"
schedule_order_start_at = "<date>" | ""
vehicle_id              = "<widget.vehicleId>"
file                    = <binary image>   (0 or more, optional)
```
Images are validated with `ImageUploadService.validateBatch()` before upload. Invalid images are skipped; if ALL fail, order is aborted.

---

### `createAliexpressOrder()` — line 3360
```
POST /admin/aliexpress_creat_order
Content-Type: application/json
Timeout: 50s
```
```json
{
  "access_token": "<aliExpressAccessToken>",
  "full_name": "...",
  "mobile_no": "...",
  "product_items": [
    {
      "product_count": 1,
      "product_id": 12345,
      "sku_attr": "itemId_string",
      "product_price": { "price": 99.99 }
    }
  ]
}
```
Called BEFORE `createOrder()` for AliExpress items. On success, passes `order_ids` to `createOrder()`.

---

### `sendMaregagecha()` — line 2896
```
POST /api/user/send_otp
Timeout: 20s
```
```json
{
  "user_id": "...",
  "phone": "...",
  "type": "<admin_type>",
  "token": "<server_token>",
  "country_phone_code": "..."
}
```

---

### `amoleAddToBorsa()` — line 2958
```
POST /api/user/add_wallet_amount
Timeout: 20s
```
```json
{
  "user_id": "...",
  "payment_id": "<payment_gateway[0]._id>",
  "otp": "...",
  "type": "<admin_type>",
  "server_token": "...",
  "wallet": 100.0
}
```

---

### `userDetails()` — line 3615
```
POST /api/user/get_detail
Timeout: 30s
```
```json
{
  "user_id": "...",
  "server_token": "..."
}
```
Called by `_userDetails()` to refresh user balance after wallet operations.

---

### `pollTelebirrStatus()` — line 119
```
POST https://pgw.shekla.app/teleInapp/query    ← external URL, NOT baseUrl
Timeout: 10s per attempt, polls every 3s
```
```json
{ "merch_order_id": "<kTelebirrInAppTraceKey><orderPaymentUniqueId>" }
```
Returns when status contains "PAID"/"SUCCESS" with `success: true`, or "FAILED", or widget is disposed.

---

### `_logFailedOrderAfterPayment()` — line 3039
```
POST /api/user/log_failed_order
Timeout: 5s (best-effort, silent fail)
```
Also saves to `failed_orders` in SharedPreferences. Triggered when payment succeeded but order creation failed, so support team can issue refunds.

---

## 8. `uuid` / `traceNo` Logic

The `uuid` starts as `widget.orderPaymentUniqueId` and is incremented when the user retries:
```dart
uuid = (int.parse(uuid) + 1).toString();
```

| Method | TraceNo format |
|---|---|
| BOA / EthSwitch / ETTA Card / Zemen / Dashen | `uuid + "_" + orderPaymentUniqueId` |
| Tele Birr USSD | `RandomDigits.getString(6) + "_" + orderPaymentUniqueId` |
| AddisPay / YagoutPay | `orderPaymentUniqueId + "_" + RandomDigits.getString(6)` |
| Telebirr InApp | `kTelebirrInAppTraceKey + orderPaymentUniqueId` |
| SantimPay / Chapa | `uuid + "_" + orderPaymentUniqueId` |

This avoids duplicate payment IDs when the user retries after a failed attempt.

---

## 9. Security & Image Validation

### Before payment (pre-validation)
`_validateCourierImagesBeforePayment()` (line 373) runs BEFORE calling `payOrderPayment()` or `_boaVerify()`:
- Skip if not courier
- Skip if no images attached
- Uses `ImageUploadService.validateBatch()` to check: file exists, accessible, valid format, within size limit
- If ALL fail → abort, clear images from storage, show error
- If SOME fail → abort, clear images, show error
- Only continues if ALL valid

### During order creation (createCourierOrder)
`ImageUploadService.validateBatch()` runs again during upload:
- If all fail → abort order
- If some fail → skip bad ones, warn user, upload valid ones

### After payment failure
`_logFailedOrderAfterPayment()` always runs if payment went through but order creation failed:
- Saves locally to `failed_orders` in SharedPreferences
- Sends to `/api/user/log_failed_order` (silent fail if network down)
- Shows user: "Contact support at 8707. Ref: `orderPaymentUniqueId`"

---

## 10. Error Handling

| Error Code | Meaning | Action |
|---|---|---|
| `999` | Session expired / invalid token | Logs out, removes 'user' from storage, redirects to LoginScreen |
| Other codes | Mapped via `errorCodes` map | Shows localized error message |
| `null` response | Network/timeout | Shows "Something went wrong" |
| `TimeoutException` | API call exceeded timeout | Shows error, logs |

---

## 11. Order Creation Decision Tree

After payment is verified:

```
widget.isCourier == true
    → _createCourierOrder()

widget.isCourier == false AND aliexpressCart != null AND storeIds match
    → _createAliexpressOrder()
         └── on success → _createOrder(orderIds: aliOrderIds)

widget.isCourier == false AND no AliExpress
    → _createOrder()
```

On successful order creation:
- Store: `Service.remove('cart')` + `Service.remove('aliexpressCart')` → navigate to `ReportScreen`
- Courier: `Service.remove('images')` → navigate to `ReportScreen(isCourier: true)`

---

## 12. Component Files (sub-screens)

All in `lib/kifiya/components/`:

| File | Payment |
|---|---|
| `telebirr_screen.dart` | Telebirr / Zemen / Dashen (WebView wrapper) |
| `telebirr_inapp.dart` | Telebirr In-App SDK |
| `telebirr_ussd.dart` | Tele Birr USSD |
| `amole_screen.dart` | Amole OTP entry |
| `cbe_ussd.dart` | CBE Birr USSD |
| `cyber_source.dart` | BOA CyberSource WebView |
| `dashen_master_card.dart` | Dashen Mastercard |
| `ethswitch_screen.dart` | EthSwitch WebView |
| `etta_card_screen.dart` | ETTA Loyalty Card WebView |
| `santimpay_screen.dart` | SantimPay |
| `chapa_screen.dart` | Chapa |
| `addis_pay.dart` | Addis Pay |
| `yagoutpay.dart` | YagoutPay |
| `starpay_screen.dart` | StarPay |
| `kifiya_method_container.dart` | Payment tile widget (logo + name) |

`lib/kifiya/kifiya_verification.dart` — Telebirr Reference verification screen.

---

## 13. SharedPreferences Keys Used

| Key | Type | Content |
|---|---|---|
| `user` | JSON | Full user object (id, token, wallet, etc.) |
| `cart` | JSON | Store cart |
| `courier` | JSON | Courier cart (cart_id, etc.) |
| `aliexpressCart` | JSON | AliExpress cart |
| `ali_access_token` | String | AliExpress OAuth token |
| `services` | JSON | Delivery services list (courier only) |
| `images` | JSON | List of courier image file paths |
| `courier_paid_by_sender` | bool | Who pays courier fee |
| `is_schedule` | bool | Is courier order scheduled |
| `schedule_start` | String | Courier schedule start date |
| `failed_orders` | JSON | List of failed orders (for support) |
