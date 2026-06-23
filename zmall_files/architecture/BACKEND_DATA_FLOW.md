# Backend Data Flow - How Categories & Services Come From Server

## Overview

When the app starts, it fetches fresh data from the backend server using **two separate API calls**, then saves the responses to local device storage for instant loading next time.

---

## 1. Categories API Call

### When It Happens

- **Triggers**: `getNearByMerchants()` function is called during home screen initialization
- **Location**: [line 1513-1525](lib/home/components/home_body.dart#L1513-L1525) in home_body.dart

### API Details

**Endpoint:**

```
POST https://[BASE_URL]/api/user/get_delivery_list_for_nearest_city
```

**Request Body (What App Sends):**

```json
{
  "latitude": 9.032,
  "longitude": 38.7469,
  "country": "Ethiopia",
  "country_code": "ET"
}
```

**Parameters Explanation:**
| Parameter | Example | Purpose |
|-----------|---------|---------|
| `latitude` | 9.0320 | User's current GPS latitude |
| `longitude` | 38.7469 | User's current GPS longitude |
| `country` | "Ethiopia" | Country name |
| `country_code` | "ET" | Country code (used for filtering) |

**Response (What Backend Returns):**

```json
{
  "success": true,
  "city": {
    "_id": "city_123",
    "name": "Addis Ababa",
    "latitude": 9.032,
    "longitude": 38.7469
  },
  "deliveries": [
    {
      "_id": "del_001",
      "delivery_name": "FOOD DELIVERY",
      "image_url": "https://images.zmall.com/food.png",
      "description": "Fast food delivery service",
      "storeCount": 150
    },
    {
      "_id": "del_002",
      "delivery_name": "Pharmacy",
      "image_url": "https://images.zmall.com/pharmacy.png",
      "description": "Pharmacy items delivery",
      "storeCount": 45
    },
    {
      "_id": "del_003",
      "delivery_name": "Laundry",
      "image_url": "https://images.zmall.com/laundry.png",
      "description": "Laundry cleaning service",
      "storeCount": 12
    }
  ],
  "error_code": 0
}
```

### What Happens After Response

```dart
// Step 1: Save to device cache
await Service.save('categories', json.decode(response.body));

// Step 2: Extract deliveries list
categories = responseData['deliveries'];

// Step 3: Check for special handling
checkLaundryCategory(categories);

// Step 4: UI renders categories
setState(() { categories = [...] });
```

### Full Code Flow

```dart
Future<dynamic> getCategoryList(double longitude, double latitude,
                                String countryCode, String countryName) async {
  // 1. Prepare request
  var url = "${baseUrl}/api/user/get_delivery_list_for_nearest_city";
  Map data = {
    "latitude": latitude,
    "longitude": longitude,
    "country": countryName,
    "country_code": countryCode,
  };

  try {
    // 2. Send to backend
    http.Response response = await http.post(
      Uri.parse(url),
      headers: { "Content-Type": "application/json" },
      body: json.encode(data),
    ).timeout(Duration(seconds: 15));

    // 3. Save response to cache
    await Service.save('categories', json.decode(response.body));

    // 4. Return response
    return json.decode(response.body);
  } catch (e) {
    // Show error if fails
    Service.showMessage(...);
    return null;
  }
}
```

---

## 2. Services API Call

### When It Happens

- **Triggers**: `getNearByServices()` function is called during home screen initialization
- **Location**: [line 1594-1603](lib/home/components/home_body.dart#L1594-L1603) in home_body.dart

### API Details

**Endpoint:**

```
POST https://[BASE_URL]/api/user/get_delivery_list_for_nearest_city
```

**⚠️ Same endpoint as categories, but different parameter!**

**Request Body (What App Sends):**

```json
{
  "country": "Ethiopia",
  "country_code": "ET",
  "longitude": 38.7469,
  "latitude": 9.032,
  "delivery_type": 2
}
```

**Key Difference:**

- **Categories call**: No `delivery_type` parameter (defaults to 1)
- **Services call**: `delivery_type: 2` (tells backend to return services instead)

**Response (What Backend Returns):**

```json
{
  "success": true,
  "city": {
    "_id": "city_123",
    "name": "Addis Ababa"
  },
  "deliveries": [
    {
      "_id": "srv_001",
      "delivery_name": "Lunch from Home",
      "image_url": "https://images.zmall.com/lunch.png",
      "description": "Homemade lunch orders",
      "famous_products_tags": ["lunch", "homemade", "daily"]
    },
    {
      "_id": "srv_002",
      "delivery_name": "Loyalty Card",
      "image_url": "https://images.zmall.com/loyalty.png",
      "description": "Loyalty rewards program",
      "famous_products_tags": ["rewards", "loyalty"]
    },
    {
      "_id": "srv_003",
      "delivery_name": "Proximity Orders",
      "image_url": "https://images.zmall.com/nearby.png",
      "description": "Order from nearby vendors",
      "famous_products_tags": ["proximity", "nearby", "orders near you"]
    },
    {
      "_id": "srv_004",
      "delivery_name": "Yearly Recap",
      "image_url": "https://images.zmall.com/recap.png",
      "description": "Your yearly summary",
      "famous_products_tags": ["recap", "wrapped", "yearly_recap"]
    }
  ],
  "error_code": 0
}
```

### What Happens After Response

```dart
// Step 1: Save to device cache
await Service.save('services', json.decode(response.body));

// Step 2: Extract deliveries list
services = servicesData['deliveries'];

// Step 3: Check for special features (only if user logged in)
if (userData != null && userData['user'] != null) {
  _showHolidayCelebration();
  checkProximityService(services);      // Finds "proximity" tag
  checkHolidaySplashService(services);  // Finds "recap" or "holiday_splash" tag
}

// Step 4: UI renders services
setState(() { services = [...] });
```

### Full Code Flow

```dart
Future<dynamic> getServicesList(double longitude, double latitude,
                                String countryCode, String countryName) async {
  // 1. Prepare request (with delivery_type: 2)
  var url = "${baseUrl}/api/user/get_delivery_list_for_nearest_city";
  Map data = {
    "country": countryName,
    "country_code": countryCode,
    "longitude": longitude,
    "latitude": latitude,
    "delivery_type": 2,  // ← Key difference!
  };

  try {
    // 2. Send to backend
    http.Response response = await http.post(
      Uri.parse(url),
      headers: { "Content-Type": "application/json" },
      body: json.encode(data),
    ).timeout(Duration(seconds: 15));

    // 3. Save response to cache
    await Service.save('services', json.decode(response.body));

    // 4. Return response
    return json.decode(response.body);
  } catch (e) {
    // Show error if fails
    Service.showMessage(...);
    return null;
  }
}
```

---

## 3. Complete Data Flow Timeline

```
App Starts
    ↓
initState() called
    ↓
├─ getCategories()
│   └─ Service.read('categories') → reads local cache
│       (instant, used for UI immediately)
│
├─ getNearByMerchants()
│   └─ getCategoryList()
│       └─ HTTP POST to backend
│           ↓
│           Backend processes location
│           ↓
│           Backend returns all delivery types for that city
│           ↓
│           Service.save('categories', response) → updates cache
│           ↓
│           setState() → UI updates with fresh data
│
└─ getServices()
    └─ Service.read('services') → reads local cache
        (instant, used for UI immediately)

    └─ getNearByServices()
        └─ getServicesList()
            └─ HTTP POST to backend (with delivery_type: 2)
                ↓
                Backend processes location
                ↓
                Backend returns all services for that city
                ↓
                Service.save('services', response) → updates cache
                ↓
                setState() → UI updates with fresh data
                ↓
                checkProximityService() → finds proximity orders
                ↓
                checkHolidaySplashService() → finds recap/holiday
```

---

## 4. Error Handling from Backend

### Error Codes Backend Can Return

| Error Code             | Meaning                       | App Action                              |
| ---------------------- | ----------------------------- | --------------------------------------- |
| `0` or `success: true` | Success ✅                    | Display data normally                   |
| `999`                  | User session expired          | Logout user, redirect to login          |
| `813`                  | Wrong location (e.g., abroad) | Show dialog, redirect to global version |
| Other                  | Generic error                 | Show error message to user              |

### Error Response Example

```json
{
  "success": false,
  "error_code": 999,
  "message": "User session expired"
}
```

### Code Handling Errors

```dart
if (responseData != null && responseData['error_code'] == 999) {
  // User logged out - clear everything
  await Service.saveBool('logged', false);
  await Service.remove('user');
  Navigator.pushReplacementNamed(context, LoginScreen.routeName);
}
else if (responseData['error_code'] == 813) {
  // User is abroad - redirect to global version
  showDialog(...);
  await Service.saveBool('is_global', true);
}
```

---

## 5. Network Timeout & Error Recovery

### Timeout Handling

```dart
http.post(...).timeout(
  Duration(seconds: 15),  // Wait max 15 seconds
  onTimeout: () {
    throw TimeoutException("Connection timed out!");
  }
);
```

### On Network Error

```dart
catch (e) {
  // Show error message
  Service.showMessage(
    context: context,
    title: "Something went wrong! Please check your internet connection!",
    error: true,
  );

  // App still works with cached data from last successful call
  return null;
}
```

---

## 6. How Backend Determines What to Return

### Backend Logic (Conceptual)

```
User Location: (9.0320, 38.7469) in Ethiopia

Backend checks:
1. Which city is near this location? → Addis Ababa
2. What delivery types are available in Addis Ababa?
   - If delivery_type not specified (or 1):
     → Return categories: FOOD DELIVERY, Pharmacy, Laundry
   - If delivery_type == 2:
     → Return services: Lunch from Home, Loyalty, Proximity, Recap
```

### Backend Database Structure (Conceptual)

```
Cities Collection
├─ _id: "city_123"
├─ name: "Addis Ababa"
├─ latitude: 9.0320
├─ longitude: 38.7469
└─ coverage_radius: 50km

Delivery Categories
├─ _id: "del_001"
├─ delivery_name: "FOOD DELIVERY"
├─ cities: ["city_123"]
├─ image_url: "..."
└─ store_count: 150

Services
├─ _id: "srv_001"
├─ delivery_name: "Lunch from Home"
├─ cities: ["city_123"]
├─ famous_products_tags: ["lunch", "homemade"]
├─ image_url: "..."
└─ active: true
```

---

## 7. What Can Backend Return

### Categories Response Includes

- ✅ List of available product categories
- ✅ City information
- ✅ Store count per category
- ✅ Image URLs for categories
- ✅ Success/error status

### Services Response Includes

- ✅ List of available services
- ✅ City information
- ✅ Tags for feature detection (proximity, recap, holiday, etc.)
- ✅ Image URLs for services
- ✅ Success/error status

### Both DO NOT Include

- ❌ Individual stores/restaurants (that's a separate API call)
- ❌ User-specific data (that's from `/api/user/get_user_detail`)
- ❌ Cart data (that's from `/api/cart/get_cart`)

---

## 8. Real Example: User in Addis Ababa

**User opens app at:**

- Location: Addis Ababa (9.0320, 38.7469)
- Country: Ethiopia (ET)
- Language: Amharic

**App sends to backend:**

```json
{
  "latitude": 9.032,
  "longitude": 38.7469,
  "country": "Ethiopia",
  "country_code": "ET"
}
```

**Backend returns (simplified):**

```json
{
  "success": true,
  "city": { "name": "Addis Ababa", "_id": "AAA_city" },
  "deliveries": [
    { "delivery_name": "FOOD DELIVERY", "storeCount": 150 },
    { "delivery_name": "Pharmacy", "storeCount": 45 },
    { "delivery_name": "Laundry", "storeCount": 12 }
  ]
}
```

**User sees on home screen:**

- 3 category cards (Food, Pharmacy, Laundry)
- Each can be tapped to see stores/restaurants
- Laundry gets special banner treatment

---

## 9. Real Example: User Abroad

**User opens app while traveling in:**

- Location: Cairo, Egypt (30.0444, 31.2357)
- Country: Egypt (EG)

**App sends to backend:**

```json
{
  "latitude": 30.0444,
  "longitude": 31.2357,
  "country": "Egypt",
  "country_code": "EG"
}
```

**Backend returns:**

```json
{
  "success": false,
  "error_code": 813,
  "message": "User is outside service area"
}
```

**App handles:**

- Shows dialog: "Proceed to ZMall Global"
- Sets `is_global: true`
- Redirects to global version of app
- Uses different API endpoints

---

## 10. Caching Strategy

### Cache Save Pattern

```dart
await Service.save('categories', json.decode(response.body));
await Service.save('services', json.decode(response.body));
```

### Cache Read Pattern

```dart
var data = await Service.read('categories');  // Fast, instant
if (data != null) {
  // Use cached data immediately
  categories = data['deliveries'];
}
```

### Cache Update Timing

1. **First load**: Cache empty → Show loading spinner
2. **After backend returns**: Cache updated → UI refreshes instantly
3. **Next app open**: Load from cache → Show UI immediately (no waiting)

---

## Summary for Backend Team

**Categories Endpoint Should Return:**

- Array of delivery types available in the user's city
- Each with: `_id`, `delivery_name`, `image_url`, descriptions
- Success status

**Services Endpoint Should Return:**

- Array of special services available in the user's city
- Each with: `_id`, `delivery_name`, `image_url`, `famous_products_tags`
- Tags enable feature detection (proximity, recap, holiday, etc.)
- Success status

**Both Endpoints Take:**

- `latitude`, `longitude` → determines city
- `country`, `country_code` → additional filtering
- Services call adds `delivery_type: 2` parameter

**Both Should Handle:**

- Invalid locations (error 813)
- Expired sessions (error 999)
- Network timeouts
- Return complete response in 15 seconds or timeout
