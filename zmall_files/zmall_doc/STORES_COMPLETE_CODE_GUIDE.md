# ZMall Store Feature — Complete End-to-End Code Guide
> Derived directly from the source code in `lib/`. Every step below references the
> exact file + line so you can open it yourself.

---

## Table of Contents

1. [What "Store" Means Here](#1-what-store-means-here)
2. [File Map](#2-file-map)
3. [User Journey (End to End)](#3-user-journey-end-to-end)
4. [Step 1 — Navigate to StoreScreen](#4-step-1--navigate-to-storescreen)
5. [Step 2 — Fetch the Store List](#5-step-2--fetch-the-store-list)
6. [Step 3 — Render Stores: Open/Closed, Tags, Search](#6-step-3--render-stores-openclosed-tags-search)
7. [Step 4 — Tap a Store → ProductScreen](#7-step-4--tap-a-store--productscreen)
8. [Step 5 — Fetch the Products](#8-step-5--fetch-the-products)
9. [Step 6 — Add to Cart (Local, no API yet)](#9-step-6--add-to-cart-local-no-api-yet)
10. [Step 7 — Cart → DeliveryScreen](#10-step-7--cart--deliveryscreen)
11. [Step 8 — DeliveryScreen: Vehicles + POST Order to Backend](#11-step-8--deliveryscreen-vehicles--post-order-to-backend)
12. [Step 9 — Checkout: Store Detail + Distance + Invoice](#12-step-9--checkout-store-detail--distance--invoice)
13. [Step 10 — Payment (KifiyaScreen) + create_order](#13-step-10--payment-kifiyascreen--create_order)
14. [Complete API Endpoint Reference](#14-complete-api-endpoint-reference)
15. [Data Models (Cart payload structure)](#15-data-models-cart-payload-structure)
16. [Error Handling Patterns](#16-error-handling-patterns)
17. [Store vs Courier — The One-Line Difference](#17-store-vs-courier--the-one-line-difference)

---

## 1. What "Store" Means Here

Store is the **product-shopping flow** of ZMall. A user:

1. Browses **stores** inside a category (grocery, restaurant, pharmacy…)
2. Opens a store and browses its **products**
3. Adds products to a **cart**
4. Picks a delivery address + vehicle
5. Sends the cart to the backend (`delivery_type = 1` implicit)
6. Pays and the **order is created**

The whole flow is driven by `POST` calls built with `package:http` and a JSON body
encoded with `json.encode(...)`. There is no REST client/DI layer here — the 
backend calls are inline in each screen.

---

## 2. File Map

```
lib/
├── store/
│   ├── store_screen.dart           ← StoreScreen widget (route /store)
│   └── components/
│       ├── body.dart               ← Store list fetch + render + search/tags
│       ├── custom_list_tile.dart   ← Store row UI
│       └── image_container.dart    ← Store image UI
├── product/
│   └── product_screen.dart         ← Products of one store (+ search + paging)
├── item/
│   ├── item_screen.dart            ← Single product with specifications
│   └── components/body.dart        ← Item add-to-cart
├── cart/
│   └── components/body.dart        ← Cart review → DeliveryScreen
├── delivery/
│   └── delivery_screen.dart        ← Address + vehicle + POST order
├── checkout/
│   └── checkout_screen.dart        ← Invoice, promo, schedule, → payment
├── kifiya/
│   └── kifiya_screen.dart          ← Payment + create_order
├── models/
│   └── cart.dart                   ← Cart/Item/DestinationAddress/StoreLocation
└── services/
    ├── service.dart                ← storeOpen(), getPrice(), save/read helpers
    └── core_services.dart          ← getCategoryList() etc.
```

---

## 3. User Journey (End to End)

```
[Home / Category tap]
   │  passes: cityId, storeDeliveryId (category _id), latitude, longitude
   ▼
[1. StoreScreen]          GET store list
   │  POST /api/user/get_company_list            (no company selected)
   │  POST /api/user/get_store_list_by_company   (company selected)
   ▼
[2. ProductScreen]        GET products of one store
   │  POST /api/user/get_store_product_item_list_paginated
   │  POST /api/user/search_store_item_by_name   (while typing)
   ▼
[3. ItemScreen]           (only for products with specifications)
   │  add to cart → stored LOCALLY via Service.save('cart', ...)
   ▼
[4. CartScreen]
   ▼
[5. DeliveryScreen]       address + vehicle
   │  POST /api/store/get_vehicle_list
   │  POST /api/user/add_item_in_cart_new         ← order pushed to backend
   ▼
[6. CheckoutScreen]       invoice / promo / schedule
   │  POST /api/user/user_get_store_product_item_list   (store detail)
   │  GET  Google Distance Matrix                       (distance + time)
   │  POST /api/user/get_order_cart_invoice             (price)
   ▼
[7. KifiyaScreen]         payment
   │  POST /api/user/pay_order_payment
   │  POST /api/user/create_order                      (final order!)
   ▼
[8. OrdersScreen]         track the order
```

---

## 4. Step 1 — Navigate to StoreScreen

`StoreScreen` receives its parameters in its constructor
(`lib/store/store_screen.dart:13-26`):

```dart
StoreScreen({
  @required this.cityId,          // String?  — city._id from home response
  @required this.storeDeliveryId, // String?  — the category _id (grocery etc.)
  @required this.category,        // dynamic  — full category object
  @required this.latitude,        // double?  — user latitude
  @required this.longitude,       // double?  — user longitude
  @required this.isStore,         // bool?    — true = product store, false = service
  @required this.companyId,       // int?     — -1 = load all companies, >0 = one company
});
```

`StoreScreen.build` renders `Body` and passes all of these through
(`lib/store/store_screen.dart:120-133`):

```dart
body: Body(
  controller: controller,
  cityId: widget.cityId,
  storeDeliveryId: widget.storeDeliveryId,
  latitude: widget.latitude,
  longitude: widget.longitude,
  isStore: widget.isStore,
  category: widget.category,
  companyId: widget.companyId,
  filterOpenedStore: filterOpenedStore,
  onAllClosedChanged: _onAllClosedChanged,
  onSearching: _onSearching,
),
```

---

## 5. Step 2 — Fetch the Store List

### 5.1 Choosing the endpoint

In `BodyState.initState` (`lib/store/components/body.dart:72-78`):

```dart
@override
void initState() {
  super.initState();
  getAppKeys();
  widget.isStore! ? _getStoreListByCompany() : _getCompanyList();
  isLogged();
}
```

- `isStore == true`  → `_getStoreListByCompany()`  → `POST get_store_list_by_company`
- `isStore == false` → `_getCompanyList()`           → `POST get_company_list`

Both write the result into the state field `responseData` and then copy the
`stores` array out of it.

### 5.2 `get_company_list` — company groups (no company chosen)

Wrapper `_getCompanyList` (`lib/store/components/body.dart:130-165`):

```dart
void _getCompanyList() async {
  setState(() { _loading = true; });
  await getCompanyList(widget.cityId!, widget.storeDeliveryId!, widget.latitude!, widget.longitude!);
  if (responseData != null && responseData['success']) {
    stores = responseData['stores'];
    storeOpen(stores);      // computes open/closed per store
    getTags(stores);        // builds famous_products_tags filter chips
  } else if (mounted && responseData != null) {
    // show error from errorCodes map
  }
}
```

HTTP call `getCompanyList` (`lib/store/components/body.dart:798-910`):

```dart
var url = "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_company_list";
Map data = {
  "city_id": cityId,            // city._id
  "store_delivery_id": storeDeliveryId, // category _id
  "latitude": latitude,
  "longitude": longitude,
};
var body = json.encode(data);
http.Response response = await http.post(
  Uri.parse(url),
  headers: {"Content-Type": "application/json", "Accept": "application/json"},
  body: body,
).timeout(Duration(seconds: 15), onTimeout: () { throw TimeoutException(...); });

final decodedData = json.decode(response.body);
setState(() { this.responseData = decodedData; });
return decodedData;
```

Note: `getCompanyList` also uses `BackendLogger.request/response/error` to
log every call (`body.dart:815,850,882`).

**Request payload**

```json
{
  "city_id": "63f...abc",
  "store_delivery_id": "63f...grocery",
  "latitude": 9.010498,
  "longitude": 38.761886
}
```

**Response**

```json
{
  "success": true,
  "stores": [
    {
      "_id": "store123",
      "name": "Shola Supermarket",
      "location": [9.02, 38.75],
      "store_count": 3,
      "company_id": 42,
      "delivery_name": "grocery",
      "famous_products_tags": ["bread", "milk"],
      "promo_tags": "10% off",
      "store_tags": "supermarket",
      "is_active": true,
      "image_url": "/uploads/store123.png"
    }
  ]
}
```

### 5.3 `get_store_list_by_company` — stores of one company

Wrapper `_getStoreListByCompany` (`lib/store/components/body.dart:98-128`):

```dart
await getStoreListByCompany(widget.cityId!, widget.storeDeliveryId!,
    widget.latitude!, widget.longitude!, widget.companyId!);
if (responseData != null && responseData['success']) {
  stores = responseData['stores'];
  storeOpen(stores);
}
```

HTTP call `getStoreListByCompany` (`lib/store/components/body.dart:685-739`):

```dart
var url = "${baseUrl}/api/user/get_store_list_by_company";
Map data = {
  "city_id": cityId,
  "store_delivery_id": storeDeliveryId,
  "latitude": latitude,
  "longitude": longitude,
  "company_id": companyId,   // extra vs get_company_list
};
```

**Request payload**

```json
{
  "city_id": "63f...abc",
  "store_delivery_id": "63f...grocery",
  "latitude": 9.010498,
  "longitude": 38.761886,
  "company_id": 42
}
```

**Response** — same shape as `get_company_list`: `{ "success": true, "stores": [...] }`.

---

## 6. Step 3 — Render Stores: Open/Closed, Tags, Search

### 6.1 Open / closed logic

`storeOpen(stores)` delegates to `Service.storeOpen(stores)`
(`lib/store/components/body.dart:205-208`). It compares each store's operating
hours against the current local time and returns a `List<bool>` stored in
`isOpen`. Open stores are shown first; closed stores sink to the bottom with a
"Closed" badge.

### 6.2 Famous-product tag filters

`getTags(stores)` (`lib/store/components/body.dart:174-196`) walks every store's
`famous_products_tags`, counts occurrences, and builds the `tagFilters` chips.
`filterUsingTag()` (`body.dart:231-259`) then re-filters the store list locally
(no backend call).

### 6.3 Search (store list)

`onSearchTextChanged` (`lib/store/components/body.dart:662+`) filters the already
loaded `stores` in memory — no API for store-level search.

### 6.4 Rendering the list

`build` renders a `ListView` of `CustomListTile`s
(`lib/store/components/body.dart:274+`). Each tile's `press` callback handles
the navigation (see Step 4).

---

## 7. Step 4 — Tap a Store → ProductScreen

Inside the tile `press` (`lib/store/components/body.dart:594-653`):

```dart
if (stores[index]['store_count'] > 1) {
  // Company has multiple branches → open ANOTHER StoreScreen scoped to that company
  Navigator.push(context, MaterialPageRoute(builder: (context) {
    return StoreScreen(
      cityId: widget.cityId,
      storeDeliveryId: widget.storeDeliveryId,
      category: widget.category,
      latitude: widget.latitude,
      longitude: widget.longitude,
      isStore: true,
      companyId: stores[index]['company_id'],
    );
  }));
} else {
  if (isLoggedIn) storeClicked(stores[index]);   // analytics ping
  Navigator.push(context, MaterialPageRoute(builder: (context) {
    return ProductScreen(
      latitude: widget.latitude!,
      longitude: widget.longitude!,
      store: stores[index],            // the store object from the list
      location: stores[index]["location"],
      isOpen: isOpen[index],
    );
  }));
}
```

`storeClicked` (`lib/store/components/body.dart:912-937`) just pings the backend
for analytics — it does NOT affect the flow:

```dart
var url = "${baseUrl}/api/admin/add_user_and_store";
Map data = {
  "store_id": store['_id'],
  "user_id": userData['user']['_id'],
  "latitude": widget.latitude,
  "longitude": widget.longitude,
  "last_opened": "2020-04-17T06:45:55.873Z",
  "is_promotional": false,
};
// fire-and-forget POST, errors ignored
```

---

## 8. Step 5 — Fetch the Products

### 8.1 Paginated product list

`getStoreProductList` (`lib/product/product_screen.dart:1158-1201`):

```dart
var url = "${baseUrl}/api/user/get_store_product_item_list_paginated";
Map data = {"store_id": widget.store['_id'], "page": page.toString()};
var body = json.encode(data);
http.Response response = await http.post(Uri.parse(url),
  headers: {"Content-Type": "application/json", "Accept": "application/json"},
  body: body,
).timeout(Duration(seconds: 60), ...);
return json.decode(response.body);
```

**Request payload**

```json
{
  "store_id": "store123",
  "page": "1"
}
```

**Response**

```json
{
  "success": true,
  "products": [
    {
      "_id": "item1",
      "name": "Milk 1L",
      "image_url": ["/uploads/item1.png"],
      "price": 95.0,
      "specifications": [],
      "odoo_product_id": 55123,
      "store_id": "store123"
    }
  ],
  "total_pages": 5,
  "current_page": 1,
  "total_count": 124
}
```

Paging is handled by `_loadPage` (`product_screen.dart:1046-1096`) which reads
`result['products']`, computes total pages with `Service.calculateTotalPages`,
appends pages with `Service.appendPage`, and triggers
`productsPagination.checkAndLoadMoreIfNeeded()`.

### 8.2 Search products by name

`getStoreProductSearchList` (`lib/product/product_screen.dart:995-1043`):

```dart
var url = "${baseUrl}/api/user/search_store_item_by_name";
Map data = {
  "name": query,
  "page": page.toString(),
  "store_id": widget.store['_id'],
};
```

Same response shape as the paginated list.

### 8.3 Product tap

`_handleItemTap` (`lib/product/product_screen.dart:509-529`):

```dart
if (isLoggedIn) productClicked(item['_id']);   // analytics ping (add_user_and_store)
if (widget.isOpen!) {
  Navigator.push(... ItemScreen(item: item, location: widget.location));
} else {
  Service.showMessage(title: "Sorry the store is closed at this time!", error: true);
}
```

---

## 9. Step 6 — Add to Cart (Local, no API yet)

Two places add to cart — both build a `Cart` object and save it **locally** with
`Service.save('cart', cart!.toJson())`. Nothing hits the backend yet.

**ProductScreen** (`lib/product/product_screen.dart:531-616`):

```dart
if (item['specifications'] != null && item['specifications'].length > 0) {
  Navigator.push(... ItemScreen(item: item, location: widget.location)); // specs path
  return;
}
// no specs → build Item + add directly
final Item cartItem = Item(
  id: item['_id'],
  quantity: 1,
  specification: [],
  noteForItem: "",
  price: double.parse(Service.getPrice(item)),
  itemName: item['name'],
  imageURL: "${baseUrl}/${item['image_url'][0]}",
  odooProductId: item['odoo_product_id'],
);
final StoreLocation storeLocation = StoreLocation(
  long: widget.location[1], lat: widget.location[0],
);
final DestinationAddress destination = DestinationAddress(
  long: ZMetaData.longitude, lat: ZMetaData.latitude,
  name: "Current Location", note: "User current location",
);

if (cart != null && cart!.storeId == item['store_id']) {
  Service.addOrMergeCartItem(cart!, cartItem);   // same store → merge
  Service.save('cart', cart);
} else {
  _showDialog(...);                               // different store → confirm replace
}
```

`addToCart` (`lib/product/product_screen.dart:166-177`):

```dart
void addToCart(item, destination, storeLocation, storeId) {
  cart = Cart(
    userId: userData['user']['_id'],
    items: [item],
    serverToken: userData['user']['server_token'],
    destinationAddress: destination,
    storeId: storeId,
    storeLocation: storeLocation,
  );
  Service.save('cart', cart!.toJson());
}
```

**ItemScreen** (`lib/item/components/body.dart:173-183`) does the same, plus
builds an `Item` with the selected specifications (see Step 15 for the shape).

---

## 10. Step 7 — Cart → DeliveryScreen

Cart's checkout button pushes `DeliveryScreen` by named route
(`lib/cart/components/body.dart:539-541`):

```dart
Navigator.pushNamed(context, DeliveryScreen.routeName);
```

`DeliveryScreen` (`lib/delivery/delivery_screen.dart:29-35`) is a StatefulWidget
with `static String routeName = '/delivery'`.

---

## 11. Step 8 — DeliveryScreen: Vehicles + POST Order to Backend

### 11.1 initState

`lib/delivery/delivery_screen.dart:62-68`:

```dart
@override
void initState() {
  super.initState();
  getUser();       // load user + cart + location + vehicle list
  getLocations();  // load saved delivery addresses
}
```

`getUser()` (`delivery_screen.dart:214-229`) chains:

```dart
var data = await Service.read('user');      // read stored user
await getCart();                            // read stored cart
_doLocationTask();                          // GPS permission + current location
_getVehicleList();                          // fetch vehicles
```

### 11.2 Vehicle list fetch

`getVehicleList` (`lib/delivery/delivery_screen.dart:1305-1364`):

```dart
var url = "${baseUrl}/api/store/get_vehicle_list";
Map data = {
  "store_id": "",
  "type": 7,
  "delivery_type": 1,                 // <-- STORE (courier uses 2)
  "user_id": userData['user']['_id'],
  "server_token": userData['user']['server_token'],
  "city_id": ZMetaData.cityId,
  "user_latitude": cart!.storeLocation!.lat,
  "user_longitude": cart!.storeLocation!.long,
  "store_latitude": cart!.destinationAddress!.lat,
  "store_longitude": cart!.destinationAddress!.long,
  "use_calculation": true,
  "is_laundry": cart!.isLaundryService,
};
```

`_getVehicleList` (`delivery_screen.dart:126-170`) stores the list and auto-selects
the first vehicle:

```dart
vehicleList = data;
selectedVehicle = 0;
vehicleId = vehicleList['vehicles'][selectedVehicle]['_id'];
```

### 11.3 Submit → `addToCart()` → `POST add_item_in_cart_new`

The "submit" button first calls `CoreServices.getCategoryList(...)` to verify the
destination is a valid city (`delivery_screen.dart:982-998`) — if the backend
returns `error_code 813` it shows *"Destination address cannot be outside of
Addis Ababa"*. On success it calls `_addToCart()`.

`_addToCart` (`lib/delivery/delivery_screen.dart:382-426`):

```dart
var data = await addToCart();                    // THE order POST
if (data != null && data['success']) {
  userData['user']['cart_id'] = data['cart_id']; // save returned cart_id
  await Service.save('user', userData);
  Navigator.push(... CheckoutScreen(isForOthers, receiverName, receiverPhone, vehicleId));
} else {
  // error_code 999 → session expired → logout → LoginScreen
}
```

`addToCart` (`lib/delivery/delivery_screen.dart:1249-1303`):

```dart
Future<dynamic> addToCart() async {
  var url;
  if (aliexpressCart != null && aliexpressCart!.cart.storeId == cart!.storeId) {
    url = "${baseUrl}/api/user/add_item_in_cart_new_for_aliexpress";
  } else {
    url = "${baseUrl}/api/user/add_item_in_cart_new";
  }
  var body = json.encode(cart!.toJson());   // <-- whole Cart model serialized
  http.Response response = await http.post(Uri.parse(url), headers: {...}, body: body)
      .timeout(Duration(seconds: 15), ...);
  return json.decode(response.body);
}
```

**Full request payload** (`cart!.toJson()`, see `lib/models/cart.dart:58-72`):

```json
{
  "user_id": "user123",
  "items": [
    {
      "_id": "item1",
      "quantity": 2,
      "specification": [
        { "unique_id": 1, "list": [ { "unique_id": 11, "price": 10.0 } ] }
      ],
      "note_for_item": "",
      "price": 95.0,
      "item_name": "Milk 1L",
      "image_url": "/uploads/item1.png",
      "odoo_product_id": 55123
    }
  ],
  "server_token": "tok_abc",
  "destination_address": {
    "name": "Current Location",
    "long": 38.761886,
    "lat": 9.010498,
    "note": "User current location"
  },
  "store_id": "store123",
  "store_location": { "lat": 9.02, "long": 38.75 },
  "is_schedule": false,
  "schedule_start": null,
  "delivery_for_other": false,
  "is_open": true,
  "is_abroad": false,
  "username": "",
  "phone": "",
  "abroad_data": null
}
```

**Response**

```json
{
  "success": true,
  "cart_id": "cart789"
}
```

This is the moment the order data leaves the device. Everything before this was
local.

---

## 12. Step 9 — Checkout: Store Detail + Distance + Invoice

`CheckoutScreen` (`lib/checkout/checkout_screen.dart:25-42`) receives
`isForOthers`, `receiverName`, `receiverPhone`, `vehicleId`.

### 12.1 `getCart()` on init

`lib/checkout/checkout_screen.dart:114-138`:

```dart
var data = await Service.read('cart');
cart = Cart.fromJson(data);
_getStoreDetail();          // store settings (cashless/self-pickup/schedule)
_getTotalDistance(cart!);   // Google Distance Matrix (store → destination)
```

### 12.2 Store detail (settings that gate the UI)

`getStoreDetail` (`lib/checkout/checkout_screen.dart:1745-1804`):

```dart
var url = "${baseUrl}/api/user/user_get_store_product_item_list";
Map data = {"store_id": cart!.storeId};
```

Response drives flags: `accept_only_cashless_payment`, `accept_user_pickup_delivery_only`,
`accept_scheduled_order_only`, and `express_options` (for laundry).

### 12.3 Distance + time

`getTotalDistance` (`lib/checkout/checkout_screen.dart:1389+`) calls **Google Maps
Distance Matrix**:

```
GET https://maps.googleapis.com/maps/api/distancematrix/json
     ?origins={storeLat},{storeLong}
     &destinations={destLat},{destLong}
     &key=$apiKey
```

`_getTotalDistance` (`checkout_screen.dart:182-199`) reads
`rows[0].elements[0].distance.value` (meters) and `.duration.value` (seconds).
If the call fails it falls back to the **Haversine formula** via
`_fallbackHaversine` (`checkout_screen.dart:201-229`).

### 12.4 Order invoice (price)

`getCartInvoice` (`lib/checkout/checkout_screen.dart:1512-1595`):

```dart
var url = "${baseUrl}/api/user/get_order_cart_invoice";
Map data = {
  "user_id": cart!.userId,
  "store_id": cart!.storeId,
  "total_time": selfPickup ? 0 : time,
  "total_distance": selfPickup ? 0 : distance,
  "order_type": 7,
  "is_user_pick_up_order": selfPickup,
  "total_item_count": cart!.items?.length,
  "is_user_drop_order": !cart!.isLaundryService,
  "express_option": selectedExpressOption,
  "server_token": cart!.serverToken,
  "vehicle_id": widget.vehicleId,
  "tip": tip,
};
```

**Response** — `responseData['order_payment']` contains:

```json
{
  "success": true,
  "order_payment": {
    "_id": "pay123",
    "unique_id": "ZMA-99999",
    "total": 250.5,
    "total_order_price": 240.0,
    "total_delivery_price": 10.5,
    "user_pay_payment": 250.5,
    "promo_payment": 0
  },
  "vehicles": [ { "_id": "vehicle1", "vehicle_name": "Bike" } ]
}
```

On the "Place Order" tap, checkout pushes `KifiyaScreen` passing
`price`, `orderPaymentId`, `orderPaymentUniqueId`, `onlyCashless`, `vehicleId`,
and `userpickupWithSchedule` (`lib/checkout/checkout_screen.dart:420-469`).

---

## 13. Step 10 — Payment (KifiyaScreen) + create_order

### 13.1 Pay first

The payment gateway is chosen on screen; each method POSTs to its own endpoint
(e.g. `POST /api/user/pay_order_payment` for wallet — `lib/kifiya/kifiya_screen.dart:3154`).
After a successful payment the app calls `createOrder`.

### 13.2 `createOrder` — the final order

`createOrder` (`lib/kifiya/kifiya_screen.dart:3903-3999`):

```dart
var url = (_selectedPaymentMethod == "telebirr inapp" || ...)
  ? "${baseUrl}/api/user/create_order_for_telebirr_inapp"
  : "${baseUrl}/api/user/create_order";
Map data = {
  "user_id": userData['user']['_id'],
  "cart_id": userData['user']['cart_id'],        // returned by add_item_in_cart_new
  "is_schedule_order": cart.isSchedule,
  "schedule_order_start_at": (cart.scheduleStart != null && cart.isSchedule)
      ? cart.scheduleStart?.toUtc().toString() : "",
  "server_token": userData['user']['server_token'],
  "order_payment_unique_id": widget.orderPaymentUniqueId,  // idempotency key
  if (filteredOrderIds != null) "aliexpress_order_ids": filteredOrderIds,
};
http.post(...).timeout(Duration(seconds: 50), ...);
```

**Request payload**

```json
{
  "user_id": "user123",
  "cart_id": "cart789",
  "is_schedule_order": false,
  "schedule_order_start_at": "",
  "server_token": "tok_abc",
  "order_payment_unique_id": "ZMA-99999"
}
```

On success the user is redirected to `OrdersScreen` where the order is tracked.

> **Store vs courier note:** the courier variant of this same screen sends
> `delivery_type = "2"`, `vehicle_id`, and `paid_by` instead
> (`lib/kifiya/kifiya_screen.dart:3528-3540`). The store variant does not send
> `delivery_type` — the backend infers store orders from the `cart_id`/`items`.

---

## 14. Complete API Endpoint Reference

| Step | Method | Endpoint | File : Line | Purpose |
|------|--------|----------|-------------|---------|
| 2 | POST | `/api/user/get_company_list` | `lib/store/components/body.dart:798` | Load company groups |
| 2 | POST | `/api/user/get_store_list_by_company` | `lib/store/components/body.dart:685` | Load stores of a company |
| 4 | POST | `/api/admin/add_user_and_store` | `lib/store/components/body.dart:912` | Analytics (store tap) |
| 5 | POST | `/api/user/get_store_product_item_list_paginated` | `lib/product/product_screen.dart:1158` | Paginated products |
| 5 | POST | `/api/user/search_store_item_by_name` | `lib/product/product_screen.dart:995` | Product search |
| 8 | POST | `/api/store/get_vehicle_list` | `lib/delivery/delivery_screen.dart:1305` | Delivery vehicles |
| 8 | POST | `/api/user/add_item_in_cart_new` | `lib/delivery/delivery_screen.dart:1249` | Push order to backend |
| 8 | POST | `/api/user/add_item_in_cart_new_for_aliexpress` | `lib/delivery/delivery_screen.dart:1256` | Aliexpress variant |
| 8 | POST | `/api/user/clear_cart` | `lib/delivery/delivery_screen.dart:1199` | Clear cart |
| 9 | POST | `/api/user/user_get_store_product_item_list` | `lib/checkout/checkout_screen.dart:1745` | Store detail/settings |
| 9 | GET | Google Distance Matrix | `lib/checkout/checkout_screen.dart:1389` | Distance + duration |
| 9 | POST | `/api/user/get_order_cart_invoice` | `lib/checkout/checkout_screen.dart:1512` | Order price |
| 9 | POST | `/api/user/apply_promo_code` | `lib/checkout/checkout_screen.dart:1597` | Promo code |
| 10 | POST | `/api/user/pay_order_payment` | `lib/kifiya/kifiya_screen.dart:3154` | Pay with wallet |
| 10 | POST | `/api/user/create_order` | `lib/kifiya/kifiya_screen.dart:3903` | **Create final order** |
| 10 | POST | `/api/user/create_order_for_telebirr_inapp` | `lib/kifiya/kifiya_screen.dart:3524` | Create order (telebirr) |

---

## 15. Data Models (Cart payload structure)

All from `lib/models/cart.dart`.

### `Cart.toJson()` (`cart.dart:58-72`)

| Key | Type | Source |
|-----|------|--------|
| `user_id` | String | `userData['user']['_id']` |
| `items` | `List<Item>` | product(s) added |
| `server_token` | String | `userData['user']['server_token']` |
| `destination_address` | `DestinationAddress` | delivery address |
| `store_id` | String | the store |
| `store_location` | `StoreLocation` | store GPS |
| `is_schedule` | bool | schedule toggle |
| `schedule_start` | String? | ISO date or null |
| `delivery_for_other` | bool | gift / for-others |
| `is_open` | bool | store-open flag |
| `is_abroad` | bool | abroad order flag |
| `username` / `phone` | String | receiver for others |
| `abroad_data` | `AbroadData?` | abroad receiver info |

### `Item.toJson()` (`cart.dart:246-256`)

```json
{
  "_id": "item1",
  "quantity": 2,
  "specification": [ { "unique_id": 1, "list": [ { "unique_id": 11, "price": 10.0 } ] } ],
  "note_for_item": "",
  "price": 95.0,
  "item_name": "Milk 1L",
  "image_url": "/uploads/item1.png",
  "odoo_product_id": 55123
}
```

- `specification` holds chosen product options; each `ListElement` has
  `unique_id` + `price` (selected options add their price to the total).
- `odoo_product_id` links the item to the Odoo ERP product.

### `DestinationAddress.toJson()` (`cart.dart:205-210`)

```json
{ "name": "Current Location", "long": 38.761886, "lat": 9.010498, "note": "User current location" }
```

### `StoreLocation.toJson()` (`cart.dart:178-181`)

```json
{ "lat": 9.02, "long": 38.75 }
```

---

## 16. Error Handling Patterns

Every API call follows the same shape:

```dart
try {
  http.Response response = await http.post(...).timeout(Duration(seconds: N), onTimeout: () {
    throw TimeoutException("The connection has timed out!");
  });
  return json.decode(response.body);
} catch (e) {
  Service.showMessage(context: context, title: "Something went wrong...", error: true);
  return null;
} finally {
  if (mounted) setState(() { _loading = false; });
}
```

Special error codes:

| Code | Meaning | Handling |
|------|---------|----------|
| `999` | Session expired | Save `logged=false`, remove user, push `LoginScreen` |
| `813` | Destination outside service area | Show address error message |
| any other | Backend error | Looked up in `errorCodes` map → snackbar |

---

## 17. Store vs Courier — The One-Line Difference

- **Store** sends `delivery_type: 1` (in `get_vehicle_list` only) and the payload is
  the full **`Cart` model** (`items[]`, `store_id`, `destination_address`).
- **Courier** sends `delivery_type: 2` everywhere, with empty `store_id` and
  empty `order_details`, plus `pickup_addresses` + `destination_addresses`.
- The order list renders `CourierDetail` when `delivery_type == 2`, otherwise
  `OrderDetail` (`lib/orders/components/body.dart:144`).