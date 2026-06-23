# delivery_type: 1 vs delivery_type: 2 Explained

## Quick Answer

- **`delivery_type: 1` (or not specified)** = Return **CATEGORIES** (Food, Pharmacy, Laundry)
- **`delivery_type: 2`** = Return **SERVICES** (Lunch from Home, Loyalty, Proximity Orders, Recap)

Both use the **same backend endpoint**, but the `delivery_type` parameter tells backend **which data to return**.

---

## Side-by-Side Code Comparison

### getCategoryList() - delivery_type: 1 (implicit/default)

```dart
Future<dynamic> getCategoryList(
  double longitude,
  double latitude,
  String countryCode,
  String countryName,
) async {
  var url = "${baseUrl}/api/user/get_delivery_list_for_nearest_city";

  Map data = {
    "latitude": latitude,
    "longitude": longitude,
    "country": countryName,
    "country_code": countryCode,
    // ⚠️ NO delivery_type specified - backend defaults to 1
  };

  var body = json.encode(data);

  http.Response response = await http.post(
    Uri.parse(url),
    headers: {"Content-Type": "application/json"},
    body: body,
  ).timeout(Duration(seconds: 15));

  // Save to cache
  await Service.save('categories', json.decode(response.body));

  return json.decode(response.body);
}
```

**Request JSON sent to backend:**

```json
{
  "latitude": 9.032,
  "longitude": 38.7469,
  "country": "Ethiopia",
  "country_code": "ET"
}
```

**Backend returns CATEGORIES:**

```json
{
  "success": true,
  "deliveries": [
    {
      "_id": "del_001",
      "delivery_name": "FOOD DELIVERY",
      "image_url": "food.png",
      "storeCount": 150
    },
    {
      "_id": "del_002",
      "delivery_name": "Pharmacy",
      "image_url": "pharmacy.png",
      "storeCount": 45
    },
    {
      "_id": "del_003",
      "delivery_name": "Laundry",
      "image_url": "laundry.png",
      "storeCount": 12
    }
  ]
}
```

---

### getServicesList() - delivery_type: 2 (explicit)

```dart
Future<dynamic> getServicesList(
  double longitude,
  double latitude,
  String countryCode,
  String countryName,
) async {
  var url = "${baseUrl}/api/user/get_delivery_list_for_nearest_city";

  Map data = {
    "country": countryName,
    "country_code": countryCode,
    "longitude": longitude,
    "latitude": latitude,
    "delivery_type": 2,  // ✅ Explicitly set to 2
  };

  var body = json.encode(data);

  http.Response response = await http.post(
    Uri.parse(url),
    headers: {"Content-Type": "application/json"},
    body: body,
  ).timeout(Duration(seconds: 15));

  // Save to cache
  await Service.save('services', json.decode(response.body));

  return json.decode(response.body);
}
```

**Request JSON sent to backend:**

```json
{
  "country": "Ethiopia",
  "country_code": "ET",
  "longitude": 38.7469,
  "latitude": 9.032,
  "delivery_type": 2
}
```

**Backend returns SERVICES:**

```json
{
  "success": true,
  "deliveries": [
    {
      "_id": "srv_001",
      "delivery_name": "Lunch from Home",
      "image_url": "lunch.png",
      "famous_products_tags": ["lunch", "homemade"]
    },
    {
      "_id": "srv_002",
      "delivery_name": "Loyalty Card",
      "image_url": "loyalty.png",
      "famous_products_tags": ["rewards"]
    },
    {
      "_id": "srv_003",
      "delivery_name": "Proximity Orders",
      "image_url": "nearby.png",
      "famous_products_tags": ["proximity", "nearby"]
    },
    {
      "_id": "srv_004",
      "delivery_name": "Yearly Recap",
      "image_url": "recap.png",
      "famous_products_tags": ["recap", "wrapped"]
    }
  ]
}
```

---

## Key Differences Table

| Aspect                            | delivery_type: 1                 | delivery_type: 2                     |
| --------------------------------- | -------------------------------- | ------------------------------------ |
| **Parameter**                     | Not specified (implicit default) | Explicitly set to `2`                |
| **API Call**                      | `getCategoryList()`              | `getServicesList()`                  |
| **Data Returned**                 | CATEGORIES (product types)       | SERVICES (special features)          |
| **Examples**                      | Food, Pharmacy, Laundry          | Lunch, Loyalty, Proximity, Recap     |
| **Field: `famous_products_tags`** | Not present                      | Present (used for feature detection) |
| **Cache Key**                     | `'categories'`                   | `'services'`                         |
| **Requires Login**                | No                               | Yes (for feature activation)         |

---

## How Backend Decides What to Return

### Conceptual Backend Logic

```
Backend receives request:

IF delivery_type == 1 OR delivery_type is not specified:
  Query from "delivery_categories" table
  Return: FOOD DELIVERY, Pharmacy, Laundry, Courier, etc.

ELSE IF delivery_type == 2:
  Query from "services" table
  Return: Lunch from Home, Loyalty Card, Proximity Orders, Recap, etc.

ELSE:
  Return error
```

### Backend Database Structure (Conceptual)

```
TABLE: delivery_categories (delivery_type: 1)
┌─────────┬─────────────────┬───────────────────┐
│ _id     │ delivery_name   │ image_url         │
├─────────┼─────────────────┼───────────────────┤
│ del_001 │ FOOD DELIVERY   │ food.png          │
│ del_002 │ Pharmacy        │ pharmacy.png      │
│ del_003 │ Laundry         │ laundry.png       │
│ del_004 │ Courier         │ courier.png       │
└─────────┴─────────────────┴───────────────────┘

TABLE: services (delivery_type: 2)
┌─────────┬──────────────────┬──────────────────┬────────────────────────┐
│ _id     │ delivery_name    │ image_url        │ famous_products_tags   │
├─────────┼──────────────────┼──────────────────┼────────────────────────┤
│ srv_001 │ Lunch from Home  │ lunch.png        │ ["lunch", "homemade"]  │
│ srv_002 │ Loyalty Card     │ loyalty.png      │ ["rewards"]            │
│ srv_003 │ Proximity Orders │ nearby.png       │ ["proximity", "nearby"]│
│ srv_004 │ Yearly Recap     │ recap.png        │ ["recap", "wrapped"]   │
└─────────┴──────────────────┴──────────────────┴────────────────────────┘
```

---

## Real-World Example Flow

### App Initialization

```
App starts
  ↓
initState() called
  ↓
├─ Call getCategories()
│   └─ Service.read('categories') → reads cache
│       └─ Immediately displays 3 category cards
│
├─ Call getNearByMerchants()
│   └─ Calls getCategoryList(lat, lon, country_code, country_name)
│       └─ Sends: { lat, lon, country, country_code }  ← NO delivery_type
│           ↓
│           Backend sees: delivery_type not specified
│           ↓
│           Backend defaults to: delivery_type = 1
│           ↓
│           Backend queries: SELECT * FROM delivery_categories
│           ↓
│           Backend returns: FOOD DELIVERY, Pharmacy, Laundry
│           ↓
│           Cache updated: Service.save('categories', ...)
│           ↓
│           UI refreshes with fresh data
│
└─ Call getServices()
    └─ Service.read('services') → reads cache
        └─ Immediately displays service banners

    └─ Call getNearByServices()
        └─ Calls getServicesList(lat, lon, country_code, country_name)
            └─ Sends: { lat, lon, country, country_code, delivery_type: 2 }
                ↓
                Backend sees: delivery_type = 2
                ↓
                Backend queries: SELECT * FROM services
                ↓
                Backend returns: Lunch, Loyalty, Proximity, Recap
                ↓
                Cache updated: Service.save('services', ...)
                ↓
                UI refreshes with fresh data
                ↓
                checkProximityService() → finds "proximity" tag
                ↓
                checkHolidaySplashService() → finds "recap" tag
```

---

## What Gets Displayed

### Categories (delivery_type: 1) on Home Screen

```
┌─────────────────────────────────────┐
│ Home Screen                         │
├─────────────────────────────────────┤
│  ┌────────┐ ┌────────┐ ┌────────┐  │
│  │ FOOD   │ │PHARMACY│ │LAUNDRY │  │
│  │🍔      │ │💊      │ │👕      │  │
│  └────────┘ └────────┘ └────────┘  │
│                                     │
│  (Horizontal scrolling row)         │
└─────────────────────────────────────┘
```

When user taps "FOOD":

- Stores/restaurants for that category open
- Shows all Food Delivery stores

---

### Services (delivery_type: 2) on Home Screen

```
┌──────────────────────────────────────┐
│ Home Screen (Below Categories)       │
├──────────────────────────────────────┤
│  📍 Proximity Orders                  │
│  ╔══════════════════════════════════╗ │
│  ║ Order from nearby vendors!       ║ │
│  ╚══════════════════════════════════╝ │
│                                      │
│  🎁 Loyalty Card                     │
│  ╔══════════════════════════════════╗ │
│  ║ Earn rewards with every order!   ║ │
│  ╚══════════════════════════════════╝ │
│                                      │
│  📅 Yearly Recap                     │
│  ╔══════════════════════════════════╗ │
│  ║ View your 2025 food summary!     ║ │
│  ╚══════════════════════════════════╝ │
│                                      │
│  (Full-width vertical list)          │
└──────────────────────────────────────┘
```

When user taps "Proximity Orders":

- Opens special screen with nearby vendor orders
- Uses special timer-based refresh (every 30 seconds)

---

## Code Locations in home_body.dart

### Where delivery_type: 1 is used (implicit)

**Location:** [Line 3519-3575](lib/home/components/home_body.dart#L3519-L3575) - `getCategoryList()` function

```dart
Map data = {
  "latitude": latitude,
  "longitude": longitude,
  "country": countryName,
  "country_code": countryCode,
  // ❌ NO delivery_type - defaults to 1
};
```

### Where delivery_type: 2 is used (explicit)

**Location:** [Line 3577-3600](lib/home/components/home_body.dart#L3577-L3600) - `getServicesList()` function

```dart
Map data = {
  "country": countryName,
  "country_code": countryCode,
  "longitude": longitude,
  "latitude": latitude,
  "delivery_type": 2,  // ✅ Explicitly set
};
```

---

## What Backend Team Needs to Know

### If `delivery_type` Parameter is Missing or 1:

Return delivery **categories** from your database:

```json
{
  "success": true,
  "deliveries": [
    {"_id": "...", "delivery_name": "FOOD DELIVERY", ...},
    {"_id": "...", "delivery_name": "Pharmacy", ...}
  ]
}
```

### If `delivery_type` Parameter is 2:

Return special **services** from your database:

```json
{
  "success": true,
  "deliveries": [
    {
      "_id": "...",
      "delivery_name": "Lunch from Home",
      "famous_products_tags": ["lunch", "homemade"]
    },
    {
      "_id": "...",
      "delivery_name": "Proximity Orders",
      "famous_products_tags": ["proximity", "nearby"]
    }
  ]
}
```

### Default Behavior

If backend receives a request without `delivery_type`, it should assume `delivery_type: 1` (return categories).

---

## Summary

| Item                       | delivery_type: 1                              | delivery_type: 2                                    |
| -------------------------- | --------------------------------------------- | --------------------------------------------------- |
| **When sent**              | `getCategoryList()` in `getNearByMerchants()` | `getServicesList()` in `getNearByServices()`        |
| **What returned**          | Product categories (Food, Pharmacy, Laundry)  | Special services (Lunch, Loyalty, Proximity, Recap) |
| **Cache key**              | `'categories'`                                | `'services'`                                        |
| **UI display**             | Horizontal card row                           | Vertical banner list                                |
| **Require tags**           | No                                            | Yes - uses `famous_products_tags`                   |
| **User must be logged in** | No                                            | Yes - for special features                          |
