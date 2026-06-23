# Special for You — Full Guide
> zmall_app · Last updated: 2026-06-02

---

## What is "Special for You"?

"Special for You" is a **personalized product recommendation section** on the home screen.  
It shows promotional items (individual products, not whole stores) that are curated  
based on the user's location. These are products from nearby stores that the admin  
has marked as "promoted".

The section is labeled **"Special for you"** in the UI and appears as a horizontal  
scroll of product cards on the home screen.

---

## Where Special for You Lives in the Codebase

```
lib/
├── home/
│   └── components/
│       └── home_body.dart              ← Fetches & renders the "Special for you" section
│                                         (around line 2271–2380)
├── services/
│   └── core_services.dart:200         ← getPromotionalItems() API call
└── item/                               ← Opens when user taps a product
```

**No dedicated folder** — it is a section inside the home screen.

---

## User Journey (Screen by Screen)

```
[Home Screen loads]
     │  API: POST /api/user/get_promotion_item  → load promotional products
     │  Items sorted by distance to their store
     │  Saved to local storage 'p_items'
     │  "Special for you" horizontal scroll section displayed
     │
     │  user taps a product card
     ▼
[ItemScreen]  /item
     │  Shows full product detail
     │  User can add to cart
     ▼
[CartScreen]  /cart  → Checkout  → Payment
```

---

## API Call — Special for You

### Get Promotional Items
**When:** Home screen loads  
**File:** `lib/services/core_services.dart:200`

```
POST {baseUrl}/api/user/get_promotion_item
Content-Type: application/json

REQUEST BODY:
{
  "user_id":      "string",        // user._id
  "server_token": "string",        // user.server_token
  "userLocation": [lat, lon],      // [double, double] — user's GPS coordinates
  "isGlobal":     boolean          // optional — only included for global/abroad users
}

RESPONSE (success):
{
  "success": true,
  "promotional_items": [
    {
      "_id":              "string",    // item/product ID
      "name":             "string",    // product name
      "price":            number,      // price in ETB
      "image_url":        "string",    // product image path
      "store_id":         "string",    // which store sells this
      "store_location":   [lat, lon],  // store coordinates (used for distance sort)
      ...                              // all standard item/product fields
    }
  ]
}
```

> Saved to local storage key: `'p_items'`  
> Timeout: **20 seconds**

---

## How Items Are Sorted

After the API response, the app **sorts items by distance** from the user:

**File:** `lib/home/components/home_body.dart:757`

```dart
// Sort promotional items by distance to store
List<dynamic> items = List.from(data['promotional_items']);
// items sorted ascending by distance between user location and store_location
data['promotional_items'] = items;  // sorted list replaces original
```

Closest store items appear first in the "Special for you" section.

---

## Where the Section is Called

**File:** `lib/home/components/home_body.dart`

```dart
// Called during home initialization
CoreServices.getPromotionalItems(
  userId: userData['user']['_id'],
  serverToken: userData['user']['server_token'],
  ctx: context,
  userLocation: [latitude, longitude],
)
```

- Called at home load: line ~735
- Called again after returning from a store: `_getPromotionalItems()`
- Also called from guest/cached load at line ~861

---

## Key Difference: Special for You vs Featured Stores

| Aspect | Special for You | Featured Stores |
|--------|----------------|----------------|
| Unit | Individual **products/items** | Whole **stores** |
| API | `/api/user/get_promotion_item` | `/api/user/get_promotion_store` |
| Cache key | `'p_items'` | `'s_items'` |
| Sort | By distance to store | Not sorted by distance |
| Tap goes to | ItemScreen | StoreScreen |

---

## Related Files Quick Reference

| What you need | File |
|---------------|------|
| API call (getPromotionalItems) | `lib/services/core_services.dart:200` |
| Home section UI | `lib/home/components/home_body.dart:2271` |
| Item detail screen | `lib/item/` directory |
