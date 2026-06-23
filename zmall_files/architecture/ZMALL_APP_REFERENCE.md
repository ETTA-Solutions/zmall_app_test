# ZMall App — Complete Technical Reference

## Overview

ZMall is a Flutter-based multi-country e-commerce & courier app supporting **Ethiopia** and **South Sudan**. It includes shopping, courier services, AI cart, payments, and support chat.

- **Version**: 3.2.7+359
- **Base URL (Test)**: `https://testapp.zmall.et`
- **Base URL (South Sudan)**: `https://juba.zmallapp.com`

---

## Authentication

### Login

**POST** `/api/user/login`
**Full URL (Test)** `https://testapp.zmall.et/api/user/login`
**Full URL (South Sudan)** `https://juba.zmallapp.com/api/user/login`

```json
{
  "email": "9XXXXXXXX",
  "password": "yourPassword",
  "app_version": "3.2.7",
  "device_type": "android"
}
```

**Response**: `{ "success": true, "_id": "...", "server_token": "...", "first_name": "...", "wallet": 0 }`

---

### OTP Verification

**POST** `/api/user/verify_otp`

```json
{
  "phone": "9XXXXXXXX",
  "otp": "123456"
}
```

---

### Register

**POST** `/api/user/register`

```json
{
  "country_id": "...",
  "email": "9XXXXXXXX",
  "phone": "9XXXXXXXX",
  "first_name": "John",
  "last_name": "Doe",
  "password": "Pass@1234",
  "areaCode": "+251",
  "address": "Addis Ababa",
  "city": "Addis Ababa"
}
```

---

### Auth Headers (for all authenticated requests)

```
server_token: <user_server_token>
user_id: <user_id>
```

---

### Update Device Token

**POST** `/api/user/update_device_token`

```json
{
  "user_id": "...",
  "server_token": "...",
  "device_token": "<FCM token>"
}
```

---

## User & Profile

### Get User Details

**POST** `/api/user/get_detail`

```json
{ "user_id": "...", "server_token": "..." }
```

### Delete Account

**POST** `/admin/approve_decline_user`

```json
{ "user_id": "...", "is_approved": false, "user_page_type": "user" }
```

---

## Home / Discovery

### Get Nearest Delivery List (Stores)

**POST** `/api/user/get_delivery_list_for_nearest_city`

```json
{
  "latitude": 9.010498,
  "longitude": 38.761886,
  "country": "Ethiopia",
  "country_code": "+251",
  "isGlobal": false
}
```

### Get Services List (Couriers)

Same endpoint with added:

```json
{ "delivery_type": 2 }
```

### Get Company / Store List

**POST** `/api/user/get_company_list`

```json
{
  "city_id": "5b406b46d2ddf8062d11b788",
  "store_delivery_id": "...",
  "latitude": 9.010498,
  "longitude": 38.761886
}
```

### Get Promotional Items

**POST** `/api/user/get_promotion_item`

```json
{
  "user_id": "...",
  "server_token": "...",
  "userLocation": [9.010498, 38.761886],
  "isGlobal": false
}
```

### Get Promotional Stores

**POST** `/api/user/get_promotion_store`

```json
{
  "user_id": "...",
  "server_token": "...",
  "latitude": 9.010498,
  "longitude": 38.761886
}
```

---

## Search & Filtering

### Global Item Search

**POST** `/api/user/search_item_global`

```json
{ "name": "burger" }
```

| Filter      | Method      | Notes                                        |
| ----------- | ----------- | -------------------------------------------- |
| Item name   | Server-side | Pass in `name` field                         |
| Price range | Client-side | `min_price` / `max_price` applied on results |
| Store name  | Client-side | Local similarity scoring on returned list    |
| Location    | Server-side | `latitude`, `longitude`, `city_id`           |

---

## Store & Products

### Get Store Product / Item List

**POST** `/api/user/user_get_store_product_item_list`

```json
{ "store_id": "..." }
```

**Response includes**: items, specifications, express options, payment modes, store hours, ratings

---

## Cart

### Add Item to Cart

**POST** `/api/user/add_item_in_cart`

```json
{
  "user_id": "...",
  "server_token": "...",
  "store_id": "...",
  "destination_addresses": [
    { "name": "Home", "lat": 9.01, "long": 38.76, "note": "" }
  ],
  "pickup_addresses": [{ "lat": 9.02, "long": 38.77 }],
  "order_details": [
    {
      "id": "item_id",
      "quantity": 2,
      "specification": [],
      "note_for_item": "",
      "price": 150.0
    }
  ]
}
```

### AI Cart Deep Link

**GET** `/api/ai/cart/{cartId}`

Triggered via deep link `zmall://cart/{cartId}`. Loads a pre-built cart into McpCartScreen.

### Cart Data Model

```
Cart {
  userId            String
  items             List<Item>
  serverToken       String
  destinationAddress  DestinationAddress
  storeId           String
  storeLocation     StoreLocation
  isSchedule        bool
  scheduleStart     DateTime
  isForOthers       bool
  userName          String
  phone             String
  isLaundryService  bool
}

Item {
  id              String
  quantity        int
  specification   List<Specification>
  noteForItem     String
  price           double
  itemName        String
  imageURL        String
}

DestinationAddress {
  name  String
  lat   double   (default: 9.010498)
  long  double   (default: 38.761886)
  note  String
}
```

---

## Checkout & Orders

### Get Order Cart Invoice

**POST** `/api/user/get_order_cart_invoice`

```json
{ "user_id": "...", "server_token": "...", "cart_id": "..." }
```

**Response**:

```json
{
  "order_payment": {
    "total": 300,
    "user_pay_payment": 280,
    "delivery_charge": 20
  }
}
```

### Apply Promo Code

**POST** `/api/user/apply_promo_code`

```json
{
  "user_id": "...",
  "server_token": "...",
  "cart_id": "...",
  "promo_code": "SAVE10"
}
```

### Create Order

**POST** `/api/user/create_order`

```json
{
  "user_id": "...",
  "server_token": "...",
  "cart_id": "...",
  "is_schedule_order": false,
  "schedule_order_start_at": "2026-05-26T10:00:00.000Z"
}
```

### Create Courier Order (Multipart Form)

**POST** `/api/user/create_order`

```
user_id
server_token
cart_id
delivery_type: "2"
paid_by: "1" (cash) | "2" (mobile)
is_schedule_order: "false"
vehicle_id: "..."
image files (multipart)
```

### Get Orders (History)

**POST** `/api/user/get_orders`

```json
{ "user_id": "...", "server_token": "..." }
```

---

## Payments

| Method          | Details                                                                                     |
| --------------- | ------------------------------------------------------------------------------------------- |
| Cash            | `paid_by: 1`                                                                                |
| Wallet          | Deducted from `wallet` balance in user profile                                              |
| Telebirr In-App | POST `https://pgw.shekla.app/telebirrInapp/create_order` with receiveCode, appId, shortCode |
| Mobile (Kifiya) | Native method channel on iOS / Android                                                      |

---

## Refunds

| Step           | Endpoint                                   |
| -------------- | ------------------------------------------ |
| Generate OTP   | **POST** `/api/user/send_refund_otp`       |
| Verify OTP     | **POST** `/api/user/verify_refund_otp`     |
| Process Refund | **POST** `/api/admin/enable_wallet_refund` |

> OTP countdown: **60 seconds**

---

## Proximity Orders

**POST** `/api/user/get_recent_orders`

```json
{ "user_id": "...", "server_token": "..." }
```

- Returns recent orders that can be matched with nearby deliveries
- Default radius: **5 km** (Haversine formula, client-side)

---

## Notifications

- **Provider**: Firebase Cloud Messaging (FCM)
- **Topic subscription**: Country name (`Ethiopia`, `SouthSudan`)
- **AI Cart notification**: type `ai_cart` with `cart_id` → opens McpCartScreen
- **In-App**: Firebase In-App Messaging for promotions

---

## Deep Links

| Scheme                         | Path                | Action       |
| ------------------------------ | ------------------- | ------------ |
| `zmall://`                     | `cart/{cartId}`     | Open AI cart |
| `https://testapp.zmall.et`     | `/ai-cart/{cartId}` | Open AI cart |
| `https://testapp.zmall.et`     | `/cart/{cartId}`    | Open AI cart |
| `https://zmall-web.vercel.app` | `/ai-cart/{cartId}` | Open AI cart |

**Flow**:

1. Parse `cartId` from URI
2. Check auth → redirect to login if needed (saves `pending_ai_cart`)
3. Fetch cart from `/api/ai/cart/{cartId}`
4. Load into McpCartScreen
5. Duplicate store conflict → shows dialog

**ADB test command**:

```bash
adb shell am start -a android.intent.action.VIEW -d "zmall://cart/{cartId}"
```

---

## App Configuration

### Get App Keys

**POST** `/api/admin/get_app_keys`

**Response**:

```json
{
  "app_keys": {
    "message_flag": true,
    "message": "Maintenance notice...",
    "app_open_time": "08:00",
    "app_close_time": "23:00",
    "is_ios_user_app_force_update": false,
    "ios_user_app_version_code": "3.2.7"
  }
}
```

---

## Support Chat (AI Bot)

**POST** `/chat_test`

```json
{
  "message": "I need help",
  "user_id": "...",
  "server_token": "...",
  "user_location": [9.01, 38.76],
  "session_id": "optional",
  "order_id": "optional"
}
```

---

## User Recap

**POST** `/api/get_user_recap`

```json
{ "user_id": "...", "server_token": "..." }
```

Returns yearly wrapped / statistics data for the user.

---

## Standard Response Structures

### Success

```json
{
  "success": true,
  "data": {}
}
```

### Error

```json
{
  "success": false,
  "error_code": "999",
  "message": "Invalid server token",
  "error": "Human readable error"
}
```

---

## Error Codes

| Range     | Area                         |
| --------- | ---------------------------- |
| 501–506   | Registration errors          |
| 511–513   | Login / auth errors          |
| 521–541   | User / data errors           |
| 544–560   | Promo / discount errors      |
| 651–665   | Order errors                 |
| 801–814   | Country / city errors        |
| 961–965   | Cart errors                  |
| 999       | Invalid server token         |
| 2000      | Token expired                |
| 2001–2003 | Transaction / balance errors |

---

## Country Configuration

| Country     | City ID                    | Area Code | Currency |
| ----------- | -------------------------- | --------- | -------- |
| Ethiopia    | `5b406b46d2ddf8062d11b788` | `+251`    | ብር       |
| South Sudan | `62fef290ae93d51e87b468ab` | `+211`    | SSP      |

---

## Validation Rules

| Field        | Rule                                                        |
| ------------ | ----------------------------------------------------------- |
| Phone        | Regex `^[9][0-9]{8}$` — starts with 9, 9 digits total       |
| Password     | 8+ chars, 1 uppercase, 1 lowercase, 1 digit, 1 special char |
| Min distance | 0.1 meters (address validation threshold)                   |

---

## Key Screens

| Screen            | Route               | Purpose                           |
| ----------------- | ------------------- | --------------------------------- |
| SplashScreen      | `/splash`           | App init, auth check              |
| LoginScreen       | `/login`            | Phone + password login, biometric |
| OtpScreen         | `/otpScreen`        | OTP verification with auto-fill   |
| RegisterScreen    | `/register`         | New user signup                   |
| HomeScreen        | `/home`             | Main feed                         |
| StoreScreen       | `/store`            | Store product listing             |
| ItemScreen        | `/item`             | Item detail + add to cart         |
| CartScreen        | `/cart`             | Cart management                   |
| CheckoutScreen    | `/checkout`         | Invoice, promo code, scheduling   |
| KifiyaScreen      | `/kifiya`           | Payment selection                 |
| CourierScreen     | `/courier`          | Courier service ordering          |
| CourierCheckout   | `/courier-checkout` | Courier order confirmation        |
| McpCartScreen     | `/mcp-cart`         | AI cart deep link handler         |
| OrderHistory      | `/orders`           | Past orders                       |
| BorsaScreen       | `/borsa`            | Wallet / Telebirr                 |
| ProfileScreen     | `/profile`          | User profile                      |
| FavoritesScreen   | `/favorites`        | Saved stores                      |
| EventsScreen      | `/events`           | Promotions / events               |
| ServiceLogsScreen | `/service-logs`     | Debug logs (max 200 entries)      |
| FAQScreen         | `/faq`              | Help & FAQ                        |

---

## Key Services

| Service        | File                              | Responsibility                                                                   |
| -------------- | --------------------------------- | -------------------------------------------------------------------------------- |
| `Service`      | `lib/services/service.dart`       | Biometric auth, cart merge, store hours, proximity, secure storage, service logs |
| `CoreServices` | `lib/services/core_services.dart` | API wrappers, FCM setup, promotions, app config, cache clearing                  |

---

_Generated from ZMall Flutter codebase — v3.2.7+359_
