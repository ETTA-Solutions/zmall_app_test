# Courier Feature — Full Guide
> zmall_app · Last updated: 2026-06-02

---

## What is Courier?

Courier is a **person-to-person package delivery service** inside the zmall app.  
It is **NOT** a food/product order from a store. Instead, the user sends a physical item  
(a parcel, document, box, etc.) from one address to another, using a delivery rider.

Key identifier: `delivery_type = 2`  
(Regular store delivery uses `delivery_type = 1`)

---

## Where Courier Lives in the Codebase

```
lib/
├── courier/
│   ├── courier_screen.dart          ← Step 1: Enter sender/receiver & addresses
│   └── components/
│       ├── vehicle_screen.dart      ← Step 2: Pick vehicle, upload photos, see price
│       ├── locations_list.dart      ← Address picker widget (reused in both steps)
│       └── category_card.dart       ← Vehicle card UI
├── courier_checkout/
│   ├── courier_checkout_screen.dart ← Step 3: Review order summary
│   └── components/
│       └── checkout_detail_row.dart ← Summary row widget
├── orders/
│   └── components/
│       └── courier_detail.dart      ← Step 5: Track active courier order
└── services/
    ├── address_validation_service.dart  ← Validates pickup ≠ dropoff (>100m apart)
    └── image_upload_service.dart        ← Validates item photos
```

---

## User Journey (Screen by Screen)

```
[Home Screen]
     │  tap "Courier" card
     ▼
[1. CourierScreen]  /courier
     │  • Enter PICKUP address  (where to collect from)
     │  • Enter DROPOFF address (where to deliver to)
     │  • Enter SENDER name + phone  (pre-filled from profile)
     │  • Enter RECEIVER name + phone
     │  • Enter item description
     │  • Validate: pickup & dropoff must be >100m apart
     │  • API: POST /api/user/add_item_in_cart
     ▼
[2. VehicleScreen]  (pushed from CourierScreen, no named route)
     │  • API: POST /api/store/get_vehicle_list  → show Bike / Car / Van
     │  • User selects vehicle
     │  • User toggles round-trip option
     │  • User uploads up to 2 item photos
     │  • API: GET Google Distance Matrix → calculate km + minutes
     │  • API: POST /api/user/get_courier_order_invoice → get final price
     ▼
[3. CourierCheckout]  /courier_checkout
     │  • Displays: pickup address, dropoff address, sender info, receiver info, price
     │  • "Place Order" button → goes to payment
     ▼
[4. KifiyaScreen]  /kifiya  (payment, isCourier=true)
     │  • User pays via Telebirr / Amole / CBE USSD / etc.
     │  • Creates the actual confirmed order
     ▼
[5. CourierDetail]  (inside Orders screen → Active tab)
     │  • Shows live order status
     │  • "Track My Order" → opens Google Maps with rider's real-time location
     │  • Can cancel if status ≥ 109 (Not Answered / Rejected)
```

---

## All API Calls — Courier Feature

### 1. Clear Cart (optional pre-step)
**When:** If user already has items in cart from a different session  
**File:** `lib/courier/courier_screen.dart:678`

```
POST {baseUrl}/api/user/clear_cart
Content-Type: application/json

REQUEST BODY:
{
  "user_id":      "string",   // user._id
  "cart_id":      "string",   // user.cart_id
  "server_token": "string"    // user.server_token
}

RESPONSE:
{
  "success": true
}
```

---

### 2. Add Courier to Cart
**When:** User taps "Next" on CourierScreen after filling all fields  
**File:** `lib/courier/courier_screen.dart:727`

```
POST {baseUrl}/api/user/add_item_in_cart
Content-Type: application/json

REQUEST BODY:
{
  "user_id":           "string",          // user._id
  "user_type":         number,            // user.admin_type
  "store_id":          "",                // always empty for courier
  "city_id":           "string",          // from ZMetaData.cityId
  "delivery_type":     2,                 // ALWAYS 2 for courier
  "cart_unique_token": "string",          // user.server_token
  "server_token":      "string",          // user.server_token
  "total_cart_price":  "0",
  "total_item_tax":    0,
  "order_details":     [],                // always empty for courier

  "pickup_addresses": [
    {
      "user_type":       number,          // user.admin_type
      "address_type":    "pickup",
      "address":         "string",        // street address text
      "location":        [lat, lon],      // [double, double]
      "delivery_status": 0,
      "city":            "string",        // user.city
      "user_details": {
        "name":                "string",  // sender name
        "phone":               "string",  // 9-digit phone
        "email":               "",
        "country_phone_code":  "string"   // e.g. "+251"
      },
      "note": "string"                    // item description
    }
  ],

  "destination_addresses": [
    {
      "user_type":       7,               // ALWAYS 7 for courier destination
      "address_type":    "destination",
      "address":         "string",        // dropoff street address
      "location":        [lat, lon],      // [double, double]
      "delivery_status": 0,
      "city":            "string",        // user.city
      "user_details": {
        "name":                "string",  // receiver name
        "phone":               "string",  // 9-digit phone
        "email":               "",
        "country_phone_code":  "string"   // e.g. "+251"
      },
      "note": "string"                    // item description
    }
  ]
}

RESPONSE (success):
{
  "success": true,
  "cart": { ... }       // cart object (used downstream)
}

RESPONSE (error):
{
  "success": false,
  "error_code": number  // 999 = session expired → redirect to login
}
```

---

### 3. Get Vehicle List
**When:** VehicleScreen loads; fetches available delivery vehicles  
**File:** `lib/courier/components/vehicle_screen.dart:1165`

```
POST {baseUrl}/api/store/get_vehicle_list
Content-Type: application/json

REQUEST BODY:
{
  "store_id":     "",         // always empty for courier
  "type":         7,          // user type 7 = courier
  "delivery_type": 2,         // courier delivery type
  "user_id":      "string",   // user._id
  "server_token": "string",   // user.server_token
  "city_id":      "string"    // from ZMetaData.cityId
}

RESPONSE (success):
{
  "success": true,
  "vehicles": [
    {
      "_id":          "string",   // vehicle ID (used for invoice)
      "vehicle_name": "string",   // e.g. "Bike", "Car", "Van"
      "image_url":    "string",   // photo URL for display
      "capacity":     number,     // weight/size capacity
      "price_per_km": number      // base rate
    }
  ]
}
```

---

### 4. Get Distance & Duration (Google Maps)
**When:** After vehicle selected; to calculate price  
**File:** `lib/courier/components/vehicle_screen.dart:1227`

```
GET https://maps.googleapis.com/maps/api/distancematrix/json
    ?origins={pickup_lat},{pickup_lon}
    &destinations={dropoff_lat},{dropoff_lon}
    &key={GOOGLE_API_KEY}

RESPONSE (success):
{
  "rows": [
    {
      "elements": [
        {
          "distance": { "value": number },   // meters → used as `distance`
          "duration": { "value": number }    // seconds → used as `time`
        }
      ]
    }
  ]
}
```

---

### 5. Get Courier Invoice (Calculate Price)
**When:** After distance is known; to get the final delivery price  
**File:** `lib/courier/components/vehicle_screen.dart:1263`

```
POST {baseUrl}/api/user/get_courier_order_invoice
Content-Type: application/json

REQUEST BODY:
{
  "user_id":             "string",   // user._id
  "server_token":        "string",   // user.server_token
  "vehicle_id":          "string",   // selected vehicle._id
  "city_id":             "string",   // from ZMetaData.cityId
  "country_id":          "string",   // user.country_id
  "total_distance":      number,     // meters (from Distance Matrix)
  "total_time":          number,     // seconds (from Distance Matrix)
  "total_item_count":    number,     // quantity (user-entered, default 1)
  "is_user_pickup_order": false,
  "is_user_drop_order":   true,
  "is_round_trip":        boolean    // user toggle (default false)
}

RESPONSE (success):
{
  "success": true,
  "order_payment": {
    "_id":       "string",   // payment ID (passed to KifiyaScreen)
    "unique_id": "string",   // human-readable order ID
    "total":     number      // final price in ETB (shown in checkout)
  },
  "vehicles": [
    {
      "_id":          "string",   // confirmed vehicle ID
      "vehicle_name": "string"
    }
  ]
}
```

---

### 6. Get Order Status (Active Tracking)
**When:** CourierDetail screen polls for live status updates  
**File:** `lib/orders/components/courier_detail.dart:824`

```
POST {baseUrl}/api/user/get_order_status
Content-Type: application/json

REQUEST BODY:
{
  "user_id":      "string",   // user._id
  "server_token": "string",   // user.server_token
  "order_id":     "string"    // courierData._id
}

RESPONSE (success):
{
  "success": true,
  "order": {
    "_id":                                      "string",
    "unique_id":                                "string",
    "order_status":                             number,    // see Order Status Codes
    "delivery_status":                          number,    // see Delivery Status Codes
    "total_order_price":                        number,
    "confirmation_code_for_complete_delivery":  "string",  // 4-digit code
    "pickup_addresses":   [{ ...address... }],
    "destination_addresses": [{ ...address... }],
    "store_image":        "string",   // URL
    "provider_id":        "string"    // rider's user ID
  }
}
```

---

### 7. Show Invoice (Mark Complete)
**When:** Order is delivered; user taps "Show Invoice"  
**File:** `lib/orders/components/courier_detail.dart:687`

```
POST {baseUrl}/api/user/show_invoice
Content-Type: application/json

REQUEST BODY:
{
  "user_id":              "string",   // user._id
  "server_token":         "string",   // user.server_token
  "order_id":             "string",   // courierData._id
  "is_user_show_invoice": true        // ALWAYS true
}

RESPONSE (success):
{
  "success": true,
  "order": { ...final order state... }
}
```

---

### 8. Cancel Order
**When:** User taps "Cancel" button (only available in certain statuses)  
**File:** `lib/orders/components/courier_detail.dart:881`

```
POST {baseUrl}/api/user/user_cancel_order
Content-Type: application/json

REQUEST BODY:
{
  "user_id":       "string",   // user._id
  "server_token":  "string",   // user.server_token
  "order_id":      "string",   // courierData._id
  "cancel_reason": "string"    // user-typed reason
}

RESPONSE (success):
{
  "success": true
}
```

---

## Order Status Codes

These values come back in `order.order_status` and `order.delivery_status`.

| Code | Meaning |
|------|---------|
| 1    | Waiting (order placed, not yet accepted) |
| 3    | Order accepted by rider |
| 7    | Preparing / Rider heading to pickup |
| 9    | Rider at pickup location |
| 11   | Pickup confirmed / In transit |
| 19   | Delivering (rider heading to dropoff) |
| 23   | Delivered / Near dropoff |
| 25   | Completed |
| 109  | Not Answered |
| 111  | Rejected by rider |

> Cancel button is shown when: `delivery_status >= 109`

---

## Key Constants & Values

| Constant | Value | Meaning |
|----------|-------|---------|
| `delivery_type` | `2` | Identifies an order as courier (not store) |
| `user_type` (destination) | `7` | Courier-specific user type |
| `address_type` (pickup) | `"pickup"` | Marks the collection point |
| `address_type` (destination) | `"destination"` | Marks the delivery point |
| Min address distance | `100 meters` | Pickup & dropoff must be >100m apart |
| Max item photos | `2` | Photos uploaded via image_upload_service |
| Timeout per request | `10–20 seconds` | All HTTP calls |

---

## Address Validation Logic

**File:** `lib/services/address_validation_service.dart`

Before proceeding from CourierScreen, the app validates that the two addresses  
are physically different locations using the **Haversine formula**:

```
distance = 2R × arcsin( √[ sin²(Δlat/2) + cos(lat1)·cos(lat2)·sin²(Δlon/2) ] )
```

- If distance < 100 meters → show error "Pickup and dropoff must be different locations"
- If either address is not yet set → skip validation (allow user to continue)

---

## Data Flow Diagram

```
CourierScreen
  ├── reads user profile → pre-fills sender name/phone
  ├── user sets pickup (lat/lon + address text)
  ├── user sets dropoff (lat/lon + address text)
  ├── user fills receiver name/phone + description
  ├── validates distance (AddressValidationService)
  ├── POST /api/user/add_item_in_cart
  └── on success → navigate to VehicleScreen(orderDetail, userData)

VehicleScreen
  ├── POST /api/store/get_vehicle_list → show vehicles
  ├── user picks vehicle
  ├── user toggles round-trip
  ├── user uploads 0–2 photos (ImageUploadService)
  ├── GET Google Distance Matrix → distance + time
  ├── POST /api/user/get_courier_order_invoice → total price
  └── on success → navigate to CourierCheckout(orderDetail, userData, cartInvoice)

CourierCheckout
  ├── displays summary (addresses, contacts, price)
  └── "Place Order" → navigate to KifiyaScreen(
          price: cartInvoice.order_payment.total,
          orderPaymentId: cartInvoice.order_payment._id,
          orderPaymentUniqueId: cartInvoice.order_payment.unique_id,
          isCourier: true,
          vehicleId: cartInvoice.vehicles[0]._id
      )

KifiyaScreen (isCourier=true)
  ├── user selects payment method
  ├── validates courier images if any
  ├── processes payment
  └── creates confirmed order → navigate to OrdersScreen

CourierDetail (inside OrdersScreen > Active tab)
  ├── POST /api/user/get_order_status  (polls on timer)
  ├── shows status badge + progress
  ├── "Track My Order" → opens Google Maps with rider location
  ├── POST /api/user/show_invoice  (on delivery)
  └── POST /api/user/user_cancel_order  (if cancellable)
```

---

## Courier vs Regular Store Delivery — Differences

| Aspect | Regular Delivery | Courier |
|--------|-----------------|---------|
| `delivery_type` | 1 | 2 |
| `store_id` | actual store ID | `""` (empty) |
| `order_details` | list of product items | `[]` (empty) |
| Pickup | store location | user-defined address |
| What's delivered | store products | user's own package |
| Vehicle selection | fixed / not applicable | user chooses Bike/Car/Van |
| Item photos | not required | up to 2 photos |
| Sender/receiver | implicit (user ↔ store) | explicit forms for both |
| Price basis | item prices + delivery fee | distance × vehicle rate |

---

## Special Variant: "Lunch from Home"

**File:** `lib/lunch_home/lunch_home_screen.dart`  
**Route:** `/lunch_home`

This is a courier order with `delivery_type = 2` but with a special note field  
set to `"Lunch from Home"`. It uses the same API endpoints as regular courier  
but is presented differently on the home screen as a separate service card.

---

## Related Files Quick Reference

| What you need | File |
|---------------|------|
| Main entry screen | `lib/courier/courier_screen.dart` |
| Vehicle picker + price calc | `lib/courier/components/vehicle_screen.dart` |
| Address list widget | `lib/courier/components/locations_list.dart` |
| Vehicle card UI | `lib/courier/components/category_card.dart` |
| Order review screen | `lib/courier_checkout/courier_checkout_screen.dart` |
| Active order tracking | `lib/orders/components/courier_detail.dart` |
| Address distance validation | `lib/services/address_validation_service.dart` |
| Photo validation | `lib/services/image_upload_service.dart` |
| Payment screen (courier mode) | `lib/kifiya/kifiya_screen.dart` |
| Route definitions | `lib/utils/routes.dart` |
| Home screen courier card | `lib/home/components/home_body.dart` |
| Constants (status codes, etc.) | `lib/utils/constants.dart` |
