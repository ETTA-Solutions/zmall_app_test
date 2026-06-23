# Understanding getCategories() and getServices()

## Quick Overview

These two functions load **two different types of data** from local cache and display them on the home screen:

- **Categories** = Product types (Food, Pharmacy, Laundry)
- **Services** = Special features (Lunch from Home, Loyalty Card, Events)

---

## 1. getCategories() - Product Types

### What It Does

Loads the list of delivery categories (Food, Pharmacy, etc.) from local device storage.

### Code Line-by-Line

```dart
void getCategories() async {
  _getAppKeys();  // Step 1: Check for app updates

  var data = await Service.read('categories');  // Step 2: Read from device storage
  if (!mounted) return;  // Step 3: Exit if widget is destroyed
  if (data != null) {    // Step 4: Check if data exists
    setState(() {
      responseData = data;              // Save entire response
      categories = responseData['deliveries'];  // Extract the list of categories
    });
    checkLaundryCategory(categories);  // Step 5: Highlight Laundry if available
  }
}
```

### Data Structure Example

```
responseData = {
  "city": { "_id": "123", "name": "Addis Ababa" },
  "deliveries": [
    { "_id": "cat1", "delivery_name": "FOOD DELIVERY", "image_url": "food.png" },
    { "_id": "cat2", "delivery_name": "Pharmacy", "image_url": "pharmacy.png" },
    { "_id": "cat3", "delivery_name": "Laundry", "image_url": "laundry.png" }
  ]
}

// After extracting:
categories = [
  { "_id": "cat1", "delivery_name": "FOOD DELIVERY", ... },
  { "_id": "cat2", "delivery_name": "Pharmacy", ... },
  { "_id": "cat3", "delivery_name": "Laundry", ... }
]
```

### What Happens Next

1. Categories are displayed as **horizontal scrolling cards** on home screen
2. When user taps "Food", app shows a list of food restaurants
3. Laundry is handled specially - it gets its own section with a banner

---

## 2. getServices() - Special Features

### What It Does

Loads special features/services (Lunch from Home, Loyalty Card, etc.) from local device storage.

### Code Line-by-Line

```dart
void getServices() async {
  var data = await Service.read('services');  // Step 1: Read from device storage
  if (!mounted) return;  // Step 2: Exit if widget is destroyed
  if (data != null) {    // Step 3: Check if data exists
    setState(() {
      servicesData = data;              // Save entire response
      services = servicesData['deliveries'];  // Extract the list of services
    });

    // Step 4: Only if user is logged in
    if (userData != null && userData['user'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showHolidayCelebration();  // Show holiday popup
      });
      checkProximityService(services);    // Check for "Nearby Orders"
      checkHolidaySplashService(services);  // Check for "Recap" or "Holiday"
    }
  }
}
```

### Data Structure Example

```
servicesData = {
  "city": { "_id": "123", "name": "Addis Ababa" },
  "deliveries": [
    {
      "_id": "srv1",
      "delivery_name": "Lunch from Home",
      "famous_products_tags": ["lunch", "homemade"],
      "image_url": "lunch.png"
    },
    {
      "_id": "srv2",
      "delivery_name": "Loyalty Card",
      "famous_products_tags": ["rewards"],
      "image_url": "loyalty.png"
    },
    {
      "_id": "srv3",
      "delivery_name": "Events",
      "famous_products_tags": ["events"],
      "image_url": "events.png"
    }
  ]
}

// After extracting:
services = [
  { "_id": "srv1", "delivery_name": "Lunch from Home", ... },
  { "_id": "srv2", "delivery_name": "Loyalty Card", ... },
  { "_id": "srv3", "delivery_name": "Events", ... }
]
```

### Key Difference: Uses Tags

Services have `famous_products_tags` - labels that identify special behavior:

- **"proximity"** or **"nearby"** = "Nearby Orders" feature
- **"recap"** or **"wrapped"** = Yearly recap feature
- **"holiday_splash"** or **"promotion"** = Holiday promotion banner

---

## 3. Key Differences: Categories vs Services

| Aspect                  | Categories                                    | Services                                                               |
| ----------------------- | --------------------------------------------- | ---------------------------------------------------------------------- |
| **Purpose**             | Product types users can order from            | Special features/promotions                                            |
| **Examples**            | Food, Pharmacy, Laundry                       | Lunch from Home, Loyalty, Events                                       |
| **Display**             | Horizontal card row                           | Full-width banners in dynamic list                                     |
| **Action on Tap**       | Opens store list screen                       | Opens dedicated screen (StoreScreen or LunchHomeScreen)                |
| **Special Checks**      | `checkLaundryCategory()` - highlights Laundry | `checkProximityService()`, `checkHolidaySplashService()` - checks tags |
| **User Login Required** | No                                            | Yes (for special features)                                             |

---

## 4. Data Flow Diagram

### Categories Flow

```
Home Screen opens
    ↓
getCategories() runs
    ↓
Service.read('categories') → reads from device cache
    ↓
Extract: categories = responseData['deliveries']
    ↓
checkLaundryCategory() → finds if Laundry exists
    ↓
UI renders horizontal card row
    ↓
User taps "Food" → opens StoreScreen with category ID
```

### Services Flow

```
Home Screen opens
    ↓
getServices() runs
    ↓
Service.read('services') → reads from device cache
    ↓
Extract: services = servicesData['deliveries']
    ↓
If user logged in:
  - checkProximityService() → finds "Nearby Orders" tag
  - checkHolidaySplashService() → finds "Recap" or "Holiday" tag
  - _showHolidayCelebration() → shows popup
    ↓
UI renders dynamic list of banners
    ↓
User taps "Lunch from Home" → opens LunchHomeScreen
```

---

## 5. Where This Data Comes From

### Initial Load (First Time App Opens)

1. Fresh data fetched from backend API:
   - **Categories API**: `getCategoryList()` → `/api/user/get_delivery_list_for_nearest_city`
   - **Services API**: `getServicesList()` → `/api/user/get_delivery_list_for_nearest_city` (with `delivery_type: 2`)

2. Data saved to local cache:
   - `Service.save('categories', response)`
   - `Service.save('services', response)`

### Subsequent Loads (App Already Open)

- `getCategories()` and `getServices()` **read from cache** (fast, instant)
- Backend APIs still run in background to refresh cache
- When fresh data arrives, UI updates automatically

---

## 6. Important State Variables

### From getCategories()

```dart
categories        → List of delivery types
responseData      → Full API response including city info
isLaundryActive   → Boolean: is Laundry available?
laundryIndex      → Position of Laundry in categories list
```

### From getServices()

```dart
services          → List of special services
servicesData      → Full API response including city info
isProximityActive → Boolean: is "Nearby Orders" enabled?
proximityIndex    → Position of Nearby Orders service
isHolidaySplashActive → Boolean: is holiday feature active?
holidaySplashIndex    → Position of holiday service
```

---

## 7. Common Use Cases for Team

### "How do I add a new category like 'Groceries'?"

- Backend returns it in `delivery_name: "Groceries"`
- It automatically appears in categories list
- No code changes needed

### "How do I show a custom feature for certain users?"

- Use `famous_products_tags` array in services
- Add logic to `checkProximityService()` or similar
- Check if tag exists, then enable feature

### "Why doesn't my feature show?"

1. Check if data reached device cache (`Service.save()` was called)
2. Check if user is logged in (services require login)
3. Check if `famous_products_tags` contains required tag
4. Check if feature check function (`checkProximityService()`) is finding it

### "How do I test this locally?"

- Debug print after each step:

```dart
print("Categories loaded: $categories");
print("Services loaded: $services");
print("Laundry active: $isLaundryActive");
print("Proximity active: $isProximityActive");
```

---

## Summary

- **getCategories()** = Load delivery product types from cache
- **getServices()** = Load special features from cache
- Both read from **local device storage** (fast)
- Both then check/enable specific features based on tags
- UI automatically updates when setState() is called
- Fresh data from backend runs separately and updates cache
