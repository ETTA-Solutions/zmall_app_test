# ZMall: Chatbot Item Selection to Payment Screen Flow

This document details the end-to-end technical flow, APIs, request/response schemas, calculations, destination handling, invoice generation, and Flutter navigation code to transition a user from selecting an item in the **Chatbot** all the way to the **Payment Screen (`KifiyaScreen`)**.

---

## 1. High-Level Flow Architecture

```
┌────────────────────────────────────────────────────────┐
│ 1. Chatbot Item Selection                              │
│    - User picks item & quantity in chat UI             │
│    - Retrieve/Resolve Destination Address & Store Info │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ 2. Sync Cart to Backend Database                       │
│    POST /api/user/add_item_in_cart_new                 │
│    - Creates/updates active cart in backend & local DB │
│    - Returns: cart_id                                  │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ 3. Fetch Delivery Vehicles                             │
│    POST /api/store/get_vehicle_list                    │
│    - Determines valid delivery vehicle (e.g. Motorbike)│
│    - Returns: vehicleId                                │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ 4. Distance & ETA Calculation                          │
│    - Google Maps Distance Matrix API                   │
│    - Fallback: Geodesic Haversine Calculation          │
│    - Yields: distance (meters), time (seconds)         │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ 5. Order Invoice Generation                            │
│    POST /api/user/get_order_cart_invoice               │
│    - Analyzes store taxes, delivery fee, item total    │
│    - Returns: order_payment._id, unique_id, price      │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ 6. Direct Navigation to Payment Screen                 │
│    Route: '/kifiya' (KifiyaScreen)                     │
│    - Passes orderPaymentId, unique_id, price, vehicle  │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ 7. Payment Screen Execution (Kifiya)                   │
│    - POST /api/user/get_payment_gateway                │
│    - User completes payment (Telebirr, CBE, Chapa, etc)│
│    - POST /api/user/create_order                       │
└────────────────────────────────────────────────────────┘
```

---

## 2. Prerequisites & Session Data

Before triggering the checkout flow from chat, retrieve the user session and store/destination context:

```dart
// 1. User Session from local storage
final userRaw = await Service.read('user');
final user = userRaw is Map ? userRaw : jsonDecode(userRaw.toString());

final String userId = user['user']?['_id'] ?? user['_id'];
final String serverToken = user['user']?['server_token'] ?? user['server_token'];

// 2. City ID & Base URL
final String baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
final String cityId = Provider.of<ZMetaData>(context, listen: false).cityId.toString();
```

---

## 3. Step-by-Step API Specifications

### Step 1: Destination Address & Cart Payload

Destination address can be obtained from:
1. User's saved addresses in `userData['user']['address']`
2. Current device GPS coordinates via `FlLocation`

#### Cart Data Structure (`Cart.toJson()`)
```json
{
  "user_id": "64a1b2c3d4e5f67890123456",
  "server_token": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "store_id": "64a1b2c3d4e5f67890abcdef",
  "is_mcp": true,
  "items": [
    {
      "_id": "64a1b2c3d4e5f67890fedcba",
      "quantity": 1,
      "item_name": "Special Burger",
      "price": 350.0,
      "image_url": "https://example.com/item.jpg",
      "specification": [],
      "note_for_item": "No onions"
    }
  ],
  "destination_address": {
    "name": "Bole Atlas, Addis Ababa",
    "lat": 9.010498,
    "long": 38.761886,
    "note": "Building 4, Apt 2B"
  },
  "store_location": {
    "lat": 9.021054,
    "long": 38.752041
  },
  "is_schedule": false,
  "delivery_for_other": false,
  "is_laundry_service": false
}
```

---

### Step 2: Sync Cart to Backend

Synchronize the selected items to the backend cart so that an active cart document exists for this user.

- **Endpoint:** `POST /api/user/add_item_in_cart_new`
- **Headers:**
  ```http
  Content-Type: application/json
  Accept: application/json
  ```
- **Body:** The Cart JSON object shown in Step 1.
- **Success Response:**
  ```json
  {
    "success": true,
    "message": 1001,
    "cart_id": "65b89a01c234e56789012345",
    "cart": { ... }
  }
  ```
- **Local Persistence Action:**
  Update local user session with `cart_id`:
  ```dart
  if (user['user'] is Map) {
    user['user']['cart_id'] = responseData['cart_id'];
  } else {
    user['cart_id'] = responseData['cart_id'];
  }
  await Service.save('user', user);
  await Service.save('cart', cartJson);
  ```

---

### Step 3: Fetch Available Delivery Vehicles

Determine which vehicle type is eligible to deliver the order.

- **Endpoint:** `POST /api/store/get_vehicle_list`
- **Headers:**
  ```http
  Content-Type: application/json
  Accept: application/json
  ```
- **Request Body:**
  ```json
  {
    "store_id": "",
    "type": 7,
    "delivery_type": 1,
    "user_id": "64a1b2c3d4e5f67890123456",
    "server_token": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "city_id": "60a1b2c3d4e5f67890111111",
    "user_latitude": 9.021054,
    "user_longitude": 38.752041
  }
  ```
- **Response:**
  ```json
  {
    "success": true,
    "vehicles": [
      {
        "_id": "5f1a2b3c4d5e6f7a8b9c0d1e",
        "name": "Motorbike",
        "delivery_price": 50.0
      },
      {
        "_id": "5f1a2b3c4d5e6f7a8b9c0d2f",
        "name": "Car",
        "delivery_price": 100.0
      }
    ]
  }
  ```
- **Vehicle Selection Logic:**
  ```dart
  String vehicleId = "";
  for (var v in vehiclesList) {
    final name = (v['name'] ?? '').toString().toLowerCase();
    if (name.contains('motor') || name.contains('bike')) {
      vehicleId = v['_id'].toString();
      break;
    }
  }
  if (vehicleId.isEmpty && vehiclesList.isNotEmpty) {
    vehicleId = vehiclesList[0]['_id'].toString();
  }
  ```

---

### Step 4: Distance & Travel Time Calculation

Calculate distance (in meters) and duration (in seconds) between the merchant store and user's destination.

#### 1. Google Maps Distance Matrix API:
- **Request:**
  ```http
  GET https://maps.googleapis.com/maps/api/distancematrix/json?origins={storeLat},{storeLng}&destinations={destLat},{destLng}&key={GOOGLE_MAPS_API_KEY}
  ```
- **Response:**
  ```json
  {
    "status": "OK",
    "rows": [
      {
        "elements": [
          {
            "status": "OK",
            "distance": { "text": "3.5 km", "value": 3500 },
            "duration": { "text": "12 mins", "value": 720 }
          }
        ]
      }
    ]
  }
  ```

#### 2. Haversine Fallback (when Google API fails or times out):
```dart
final distanceMeters = AddressValidationService.calculateDistanceInMeters(
  storeLat, storeLng, destLat, destLng,
);
// Urban estimate: ~2 minutes per kilometer (120 seconds per 1000m)
final timeSeconds = (distanceMeters / 1000) * 120;
```

---

### Step 5: Generate Order Cart Invoice

The order invoice calculates delivery fees, tax, discounts, and yields the final payable amount with the unique payment tokens.

- **Endpoint:** `POST /api/user/get_order_cart_invoice`
- **Headers:**
  ```http
  Content-Type: application/json
  Accept: application/json
  ```
- **Request Body:**
  ```json
  {
    "user_id": "64a1b2c3d4e5f67890123456",
    "store_id": "64a1b2c3d4e5f67890abcdef",
    "total_time": 720.0,
    "total_distance": 3500.0,
    "order_type": 7,
    "is_user_pick_up_order": false,
    "total_item_count": 1,
    "is_user_drop_order": true,
    "express_option": 0,
    "server_token": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "vehicle_id": "5f1a2b3c4d5e6f7a8b9c0d1e",
    "tip": 0
  }
  ```
- **Response Schema:**
  ```json
  {
    "success": true,
    "is_distance_alarm": false,
    "order_payment": {
      "_id": "65b89c99e234e56789054321",
      "unique_id": 984521,
      "total_order_price": 350.0,
      "total_delivery_price": 60.0,
      "total_item_tax": 52.5,
      "total_service_tax": 0.0,
      "user_pay_payment": 462.5,
      "is_promo_for_delivery_service": false
    },
    "vehicles": [ ... ]
  }
  ```

> [!WARNING]
> If `is_distance_alarm == true`, the merchant is too far for delivery. Show a warning to the user to choose another branch or pickup instead.

---

### Step 6: Navigation to Payment Screen (`KifiyaScreen`)

Extract parameters from the invoice response:
- `price`: `order_payment['user_pay_payment']` (as `double`)
- `orderPaymentId`: `order_payment['_id']` (as `String`)
- `orderPaymentUniqueId`: `order_payment['unique_id'].toString()` (as `String`)
- `vehicleId`: `vehicleId`

#### Method A: Named Route Navigation
```dart
Navigator.pushNamed(
  context,
  KifiyaScreen.routeName, // '/kifiya'
  arguments: {
    'price': invoiceData['order_payment']['user_pay_payment'].toDouble(),
    'orderPaymentId': invoiceData['order_payment']['_id'],
    'orderPaymentUniqueId': invoiceData['order_payment']['unique_id'].toString(),
    'vehicleId': vehicleId,
    'onlyCashless': false,
    'userpickupWithSchedule': false,
  },
);
```

#### Method B: Direct MaterialPageRoute Navigation
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => KifiyaScreen(
      price: invoiceData['order_payment']['user_pay_payment'].toDouble(),
      orderPaymentId: invoiceData['order_payment']['_id'],
      orderPaymentUniqueId: invoiceData['order_payment']['unique_id'].toString(),
      vehicleId: vehicleId,
      onlyCashless: false,
      userpickupWithSchedule: false,
    ),
  ),
);
```

---

## 4. Payment Screen Details (`KifiyaScreen`)

Once on `KifiyaScreen`, the user selects their preferred payment method.

### 1. Fetch Payment Gateways
- **Endpoint:** `POST /api/user/get_payment_gateway`
- **Request Body:**
  ```json
  {
    "user_id": "64a1b2c3d4e5f67890123456",
    "city_id": "60a1b2c3d4e5f67890111111",
    "server_token": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "store_delivery_id": "65b89c99e234e56789054321",
    "is_user_pickup_with_schedule": false,
    "vehicleId": "5f1a2b3c4d5e6f7a8b9c0d1e",
    "device_type": "android",
    "app_version": "2.x.x"
  }
  ```
- Returns gateways: `Cash`, `Wallet`, `Telebirr`, `CBE Birr`, `SantimPay`, `Chapa`, `EthSwitch`, `Dashen MasterCard`, `Wegagen USSD`, etc.

### 2. Cash / Wallet / Gateway Settlement
- **Endpoint:** `POST /api/user/pay_order_payment`
  ```json
  {
    "user_id": "<USER_ID>",
    "order_payment_id": "<ORDER_PAYMENT_ID>",
    "payment_id": "<PAYMENT_GATEWAY_ID>",
    "is_payment_mode_cash": true,
    "server_token": "<SERVER_TOKEN>",
    "otp": ""
  }
  ```

### 3. Final Order Creation
- **Endpoint:**
  - Standard/USSD/Cash: `POST /api/user/create_order`
  - Telebirr In-App: `POST /api/user/create_order_for_telebirr_inapp`
- **Request Body:**
  ```json
  {
    "user_id": "64a1b2c3d4e5f67890123456",
    "cart_id": "65b89a01c234e56789012345",
    "is_schedule_order": false,
    "schedule_order_start_at": "",
    "server_token": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "order_payment_unique_id": "984521"
  }
  ```

---

## 5. Complete Reusable Helper Function for Chatbot

You can copy and embed this ready-to-use method directly in your chatbot service or widget:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/kifiya/kifiya_screen.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/address_validation_service.dart';
import 'package:zmall/services/service.dart';

Future<void> checkoutFromChat({
  required BuildContext context,
  required String storeId,
  required Map<String, dynamic> storeLocation, // {'lat': double, 'long': double}
  required Map<String, dynamic> destinationAddress, // {'name': String, 'lat': double, 'long': double}
  required List<Map<String, dynamic>> items, // [{' _id': ..., 'quantity': 1, 'price': ..., 'item_name': ... }]
}) async {
  try {
    // 1. Get user session
    final userRaw = await Service.read('user');
    if (userRaw == null) {
      Service.showMessage(context: context, title: "Please log in first", error: true);
      return;
    }
    final user = userRaw is Map ? userRaw : jsonDecode(userRaw.toString());
    final String userId = user['user']?['_id'] ?? user['_id'];
    final String serverToken = user['user']?['server_token'] ?? user['server_token'];
    final String baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final String cityId = Provider.of<ZMetaData>(context, listen: false).cityId.toString();

    // 2. Prepare Cart payload & Sync to backend DB
    final cartPayload = {
      "user_id": userId,
      "server_token": serverToken,
      "store_id": storeId,
      "is_mcp": true,
      "items": items,
      "destination_address": destinationAddress,
      "store_location": storeLocation,
      "is_schedule": false,
      "delivery_for_other": false,
      "is_laundry_service": false,
    };

    final addCartRes = await http.post(
      Uri.parse('$baseUrl/api/user/add_item_in_cart_new'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode(cartPayload),
    );
    final addCartData = jsonDecode(addCartRes.body);
    if (addCartData['success'] != true) {
      Service.showMessage(context: context, title: "Failed to update cart", error: true);
      return;
    }

    // Save cart_id locally
    final cartId = addCartData['cart_id']?.toString() ?? '';
    if (user['user'] is Map) user['user']['cart_id'] = cartId;
    await Service.save('user', user);
    await Service.save('cart', cartPayload);

    // 3. Fetch Delivery Vehicles
    final vehicleRes = await http.post(
      Uri.parse('$baseUrl/api/store/get_vehicle_list'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        "store_id": "",
        "type": 7,
        "delivery_type": 1,
        "user_id": userId,
        "server_token": serverToken,
        "city_id": cityId,
        "user_latitude": storeLocation['lat'],
        "user_longitude": storeLocation['long'],
      }),
    );
    final vehicleData = jsonDecode(vehicleRes.body);
    String vehicleId = '';
    if (vehicleData['vehicles'] is List && (vehicleData['vehicles'] as List).isNotEmpty) {
      for (var v in vehicleData['vehicles']) {
        final name = (v['name'] ?? '').toString().toLowerCase();
        if (name.contains('motor') || name.contains('bike')) {
          vehicleId = v['_id'].toString();
          break;
        }
      }
      if (vehicleId.isEmpty) {
        vehicleId = vehicleData['vehicles'][0]['_id'].toString();
      }
    }

    // 4. Calculate Distance & Time
    final double storeLat = (storeLocation['lat'] as num).toDouble();
    final double storeLng = (storeLocation['long'] as num).toDouble();
    final double destLat = (destinationAddress['lat'] as num).toDouble();
    final double destLng = (destinationAddress['long'] as num).toDouble();

    final distanceMeters = AddressValidationService.calculateDistanceInMeters(
      storeLat, storeLng, destLat, destLng,
    );
    final timeSeconds = (distanceMeters / 1000) * 120; // 2 min/km

    // 5. Generate Order Invoice
    final invoiceRes = await http.post(
      Uri.parse('$baseUrl/api/user/get_order_cart_invoice'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        "user_id": userId,
        "store_id": storeId,
        "total_time": timeSeconds,
        "total_distance": distanceMeters,
        "order_type": 7,
        "is_user_pick_up_order": false,
        "total_item_count": items.length,
        "is_user_drop_order": true,
        "express_option": 0,
        "server_token": serverToken,
        "vehicle_id": vehicleId,
        "tip": 0,
      }),
    );
    final invoiceData = jsonDecode(invoiceRes.body);

    if (invoiceData['success'] != true || invoiceData['order_payment'] == null) {
      Service.showMessage(context: context, title: "Failed to generate invoice", error: true);
      return;
    }

    if (invoiceData['is_distance_alarm'] == true) {
      Service.showMessage(context: context, title: "This branch is too far for delivery.", error: true);
      return;
    }

    final orderPayment = invoiceData['order_payment'];
    final double price = (num.tryParse(orderPayment['user_pay_payment']?.toString() ?? '0') ?? 0.0).toDouble();
    final String paymentId = orderPayment['_id']?.toString() ?? '';
    final String uniqueId = orderPayment['unique_id']?.toString() ?? '';

    // 6. Direct Navigation to Kifiya Payment Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KifiyaScreen(
          price: price,
          orderPaymentId: paymentId,
          orderPaymentUniqueId: uniqueId,
          vehicleId: vehicleId,
          onlyCashless: false,
          userpickupWithSchedule: false,
        ),
      ),
    );
  } catch (e) {
    Service.showMessage(context: context, title: "Error proceeding to checkout: $e", error: true);
  }
}
```
