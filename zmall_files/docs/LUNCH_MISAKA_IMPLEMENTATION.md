# LUNCH "ምሳቃ" BOX - Implementation Summary

## Overview

Implemented a new "LUNCH ምሳቃ BOX" service feature that displays misaka vendor stores in a dedicated list format, allowing users to browse and order lunch items from participating restaurants.

---

## What Was Implemented

### 1. **New Screen: MisakaStoreListScreen**

**File:** `lib/lunch_home/misaka_store_list_screen.dart`

- **Purpose:** Display lunch/misaka vendor stores in list format matching food store UX
- **Key Features:**
  - HTTP POST to `/api/user/get_misaka_store_list_by_company` endpoint
  - Safe error handling with retry fallback to `/api/user/get_company_list`
  - Real-time store open/closed status calculation
  - Navigation to `NotificationStore` for product browsing
  - Type-safe data handling for stores array
  - Backend logging for all API interactions

- **API Request Payload:**

  ```json
  {
    "city_id": "5b406b46d2ddf8062d11b788",
    "store_delivery_id": "5b406b24d2ddf8062d11b787",
    "latitude": 8.9996257,
    "longitude": 38.769873,
    "company_id": "<optional>"
  }
  ```

- **UI Components:**
  - `ModalProgressHUD` for loading indicator
  - `ListView.separated` with `CustomListTile` for store display
  - Store name, image, delivery time, ratings, status
  - Tap to navigate to store products

---

### 2. **Home Screen Integration**

**File:** `lib/home/components/home_body.dart` (Modified)

- **Detection Logic:**
  - Detects "lunch" service by checking English "lunch" keyword OR Amharic "ምሳ" token
  - Example: `bool isMisakaService = serviceName?.contains('lunch') ?? false || service['delivery_name']?.toString().contains('ምሳ') ?? false`

- **Navigation Updates:**
  - Section title displays: `'LUNCH "ምሳቃ" BOX'`
  - Routes to `MisakaStoreListScreen` when lunch service is tapped
  - Falls back to other service types for non-lunch services

- **Service Object Structure:**
  ```dart
  {
    '_id': 'store_delivery_id',
    'delivery_name': 'LUNCH "ምሳቃ" BOX',
    'company_id': '<optional>',
    // ... other fields
  }
  ```

---

## Architecture & Data Flow

### API Endpoints Used

1. **Primary:** `POST /api/user/get_misaka_store_list_by_company`
   - Returns stores with open/close schedules
   - Response includes: `success`, `message`, `stores[]`

2. **Fallback:** `POST /api/user/get_company_list`
   - Used when misaka endpoint fails or returns empty
   - Same payload structure

3. **Retry:** `POST /api/user/get_company_list` (without store_delivery_id)
   - Used when both endpoints return error_code 561
   - Broadens search by removing store filter

### Store Model

```dart
{
  "_id": "690ee8ab27941004286ef1e0",
  "name": "Test",
  "image_url": "",
  "delivery_time": 30,
  "delivery_time_max": 45,
  "user_rate": 0,
  "is_visible": true,
  "is_store_busy": false,
  "phone": "918800497",
  "store_time": [
    {
      "day": 0,      // 0=Sunday, 1=Monday, etc.
      "is_store_open": true,
      "is_store_open_full_time": true,
      "day_time": []
    }
  ],
  "location": [9.004937, 38.7668906],
  "address": "Addis Ababa, Ethiopia",
  "company_id": 752,
  "company_name": "HENO",
  "is_misaka": true,
  "distance": 0.676188904972892
}
```

### State Management

- **Provider:** `Provider<ZMetaData>` for base URL, city ID, location
- **Local State:** `_loading`, `stores`, `isOpen`, `responseData`
- **Cache:** Store data cached locally via `Service.read/save`

---

## Issues Fixed

### 1. **Missing app_open/app_close Values**

- **Problem:** `Service.storeOpen()` crashed when these keys were missing from storage
- **Fix:** Added safe defaults (00:00 to 23:59) with try-catch parsing
- **File:** `lib/services/service.dart` (lines 584-610)

### 2. **Undefined Variable Reference**

- **Problem:** else branch used undefined `appClose` variable
- **Fix:** Reuse pre-computed `zmallOpen`/`zmallClose` from outer scope
- **File:** `lib/services/service.dart` (lines 697-707)

### 3. **Type Safety for Stores Array**

- **Problem:** `List.from(result['stores'])` crashed when stores wasn't a List
- **Fix:** Added type checking for List, Map, null; graceful fallback
- **File:** `lib/lunch_home/misaka_store_list_screen.dart` (lines 107-122)

### 4. **Silent API Failures**

- **Problem:** Error 561 ("Store list not found") showed blank screen
- **Fix:** Added error message display using `errorCodes` map from constants
- **File:** `lib/lunch_home/misaka_store_list_screen.dart` (lines 128-134)

### 5. **Missing Request Logging**

- **Problem:** API payloads weren't visible in debug logs
- **Fix:** Added `BackendLogger` calls (request, response, error)
- **File:** `lib/lunch_home/misaka_store_list_screen.dart` (lines 66-73, 87-93, 100-102)

### 6. **No Retry Logic for 561 Errors**

- **Problem:** First failure meant no stores displayed
- **Fix:** Retry without `store_delivery_id` to broaden search
- **File:** `lib/lunch_home/misaka_store_list_screen.dart` (lines 84-95)

---

## Current Status

✅ **Completed:**

- MisakaStoreListScreen widget created and functional
- API integration with `/api/user/get_misaka_store_list_by_company`
- Fallback to `/api/user/get_company_list` with retry logic
- Home screen navigation routing to lunch service
- Store display with open/closed status
- Error handling with user-friendly messages
- Backend logging for debugging
- Type-safe data handling
- Service.storeOpen() safe defaults

✅ **Tested:**

- Stores load and display correctly
- Store open/closed status calculated properly
- Navigation to NotificationStore works
- Error messages shown when API fails
- No runtime crashes on missing data

---

## How to Use

### Trigger the Flow

1. **Open Home Screen**
2. **Look for "LUNCH ምሳቃ BOX" banner** in service list
3. **Tap the banner** → navigates to `MisakaStoreListScreen`
4. **View stores** with delivery time, ratings, distance, status
5. **Tap a store** → opens `NotificationStore` for product browsing
6. **Add items to cart** and checkout

### Expected Behavior

- Stores list loads within 3-5 seconds
- Open/closed status updates in real-time based on store schedule
- Store image, name, delivery time, ratings visible
- Distance calculated from user location
- Tap store → product list with images, prices, reviews
- Add to cart → checkout flow (same as regular stores)

---

## Backend Compatibility

**API Expectations:**

- Endpoint: `https://testapp.zmall.et/api/user/get_misaka_store_list_by_company`
- Method: POST
- Response format: `{"success": true, "message": <count>, "stores": [...]}`
- Error format: `{"success": false, "error_code": 561, "error": "<message>"}`

**Error Codes:**

- **561:** "Store list not found" (triggers retry without store_delivery_id)
- Other codes mapped via `errorCodes` map in `constants.dart`

---

## Files Modified

| File                                           | Changes                                          |
| ---------------------------------------------- | ------------------------------------------------ |
| `lib/lunch_home/misaka_store_list_screen.dart` | **NEW** - Complete screen implementation         |
| `lib/home/components/home_body.dart`           | Added lunch service detection & routing          |
| `lib/services/service.dart`                    | Fixed storeOpen() safe defaults & error handling |
| `lib/utils/backend_logger.dart`                | No changes (pre-existing)                        |

---

## Debug Commands

**View Request Payload:**

```
Look for: [MISAKA DEBUG] Request payload: {...}
```

**View API Logs:**

```
[BACKEND] [POST] https://testapp.zmall.et/api/user/get_misaka_store_list_by_company -> 200
[BACKEND] response: {"success":true,"message":308,"stores":[...]}
```

**View Retry Attempt:**

```
[MISAKA DEBUG] Both endpoints returned 561; retrying without store_delivery_id
```

---

## Future Enhancements

- [ ] Add store search/filter by cuisine
- [ ] Add store sorting (distance, rating, delivery time)
- [ ] Add favorites/bookmarks for quick reorder
- [ ] Add store reviews and ratings display
- [ ] Add promotional offers/discounts banner
- [ ] Add pre-order scheduling support
- [ ] Analytics tracking for lunch orders

---

## Support

**Issues?** Check:

1. Network connectivity
2. Backend API status (test with Postman)
3. Location permissions enabled
4. City ID properly set in metadata
5. Backend logs for error codes

**Debug Output:**

- Logs in Flutter DevTools Console
- API responses logged with `[BACKEND]` prefix
- Errors logged with `[BACKEND] [...] -> ERROR` prefix
