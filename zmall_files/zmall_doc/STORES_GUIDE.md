# Stores Feature — Full Guide
> zmall_app · Last updated: 2026-06-02

---

## What is Stores?

Stores is the **core shopping flow** of zmall. A user browses stores inside a  
selected category (e.g., grocery, restaurant, pharmacy), picks a store, browses  
its products, and places an order with delivery.

The `StoreScreen` is the gateway to ALL store-based shopping in the app.  
It is reused across categories: grocery, restaurant, pharmacy, laundry, etc.

---

## Where Stores Lives in the Codebase

```
lib/
├── store/
│   ├── store_screen.dart               ← Main store listing screen
│   └── components/
│       ├── body.dart                   ← Store list logic + API calls
│       ├── store_info.dart             ← Store info widget (name, distance, tags)
│       ├── custom_list_tile.dart       ← Store list tile UI
│       ├── image_container.dart        ← Store image widget
│       └── navigation_arrow.dart      ← Navigation UI component
├── product/                            ← Product listing inside a store
├── item/                               ← Single item detail
├── cart/                               ← Cart screen
└── checkout/                           ← Checkout screen
```

**Route:** `/store`

---

## User Journey (Screen by Screen)

```
[Home Screen / Search / Category tap]
     │  Passes: cityId, storeDeliveryId (category ID), latitude, longitude
     ▼
[StoreScreen]  /store
     │
     ├── If companyId == -1 (no company selected):
     │     API: POST /api/user/get_company_list  → load store groups/companies
     │
     └── If companyId > 0 (company selected):
           API: POST /api/user/get_store_list_by_company  → load stores for that company
     │
     │  Stores listed with: name, image, distance, open/closed badge, tags
     │  Filter by: open/closed status, search, famous_products_tags
     │
     │  user taps a store
     ▼
[ProductScreen]  /product
     │  Browse all products in this store
     │  Filter by category tabs
     ▼
[ItemScreen]  /item
     │  View single product detail
     │  Add to cart with quantity selector
     ▼
[CartScreen]  /cart
     │  Review cart items, quantities, store
     ▼
[CheckoutScreen]  /checkout
     │  Select delivery address, time, notes
     ▼
[KifiyaScreen]  /kifiya
     │  Select payment method & pay
     ▼
[OrdersScreen]  /orders → track active order
```

---

## All API Calls — Stores Feature

### 1. Get Company List
**When:** StoreScreen opens without a pre-selected company (`companyId == -1`)  
**File:** `lib/store/components/body.dart:798`

```
POST {baseUrl}/api/user/get_company_list
Content-Type: application/json

REQUEST BODY:
{
  "city_id":           "string",   // city._id from home response
  "store_delivery_id": "string",   // category/delivery _id (e.g., grocery, laundry)
  "latitude":          number,     // user's latitude
  "longitude":         number      // user's longitude
}

RESPONSE (success):
{
  "success": true,
  "stores": [
    {
      "_id":                  "string",
      "name":                 "string",
      "location":             [lat, lon],
      "store_count":          number,       // number of branches
      "company_id":           number,
      "delivery_name":        "string",     // e.g. "grocery"
      "famous_products_tags": ["string"],   // popular items list (for subtitle)
      "promo_tags":           "string",     // promotional labels
      "store_tags":           "string",     // general tags
      "is_active":            boolean,
      "image_url":            "string"
    }
  ]
}
```

---

### 2. Get Store List by Company
**When:** StoreScreen opens with a specific company (`companyId > 0`), OR user selects a company  
**File:** `lib/store/components/body.dart:685`

```
POST {baseUrl}/api/user/get_store_list_by_company
Content-Type: application/json

REQUEST BODY:
{
  "city_id":           "string",
  "store_delivery_id": "string",   // category/delivery _id
  "latitude":          number,
  "longitude":         number,
  "company_id":        number      // specific company to list stores for
}

RESPONSE (success):
{
  "success": true,
  "stores": [
    {
      // same structure as get_company_list response stores
    }
  ]
}
```

---

### 3. Get Category List (used to populate category filter)
**When:** Home loads; also used to populate the filter tabs in StoreScreen  
**File:** `lib/services/core_services.dart:15`

```
POST {baseUrl}/api/user/get_delivery_list_for_nearest_city
Content-Type: application/json

REQUEST BODY:
{
  "latitude":     number,
  "longitude":    number,
  "country":      "string",   // e.g. "Ethiopia"
  "country_code": "string"    // e.g. "ET"
}

RESPONSE (success):
{
  "success": true,
  "city": {
    "_id":  "string"          // city ID for all subsequent store queries
  },
  "deliveries": [
    {
      "_id":           "string",   // delivery/category ID → used as store_delivery_id
      "delivery_name": "string",   // e.g. "grocery", "restaurant", "laundry"
      "image_url":     "string",
      "is_active":     boolean
    }
  ]
}
```

---

## StoreScreen Parameters

When navigating to StoreScreen, these arguments are passed:

| Parameter | Type | Description |
|-----------|------|-------------|
| `cityId` | string | From `responseData['city']['_id']` |
| `storeDeliveryId` | string | The category `_id` (e.g., grocery category's `_id`) |
| `category` | object | Full category object from deliveries list |
| `latitude` | double | User's latitude |
| `longitude` | double | User's longitude |
| `isStore` | boolean | `true` for product stores, `false` for service stores (laundry etc.) |
| `companyId` | int | `-1` = load all companies, `>0` = load stores for that company |

---

## Store Open/Closed Logic

Store open/closed status is determined client-side by `Service.storeOpen()`:
- Checks store's operating hours against current local time
- Open stores shown first, closed stores shown at bottom with "Closed" badge
- `is_active: false` from server = permanently unavailable (hidden)

---

## Store Data Model

| Field | Type | Description |
|-------|------|-------------|
| `_id` | string | Store/company ID |
| `name` | string | Store name |
| `location` | [lat, lon] | Store GPS coordinates |
| `store_count` | number | Number of branches |
| `company_id` | number | Parent company ID |
| `delivery_name` | string | Category type |
| `famous_products_tags` | string[] | Popular items shown as subtitle tags |
| `promo_tags` | string | Promotional labels (same as Featured Stores) |
| `store_tags` | string | General classification tags |
| `is_active` | boolean | Whether store is active on platform |
| `image_url` | string | Store logo/image path |

---

## Related Files Quick Reference

| What you need | File |
|---------------|------|
| Store list screen | `lib/store/store_screen.dart` |
| Store API calls | `lib/store/components/body.dart:685` |
| Category list API | `lib/services/core_services.dart:15` |
| Store info widget | `lib/store/components/store_info.dart` |
| Product listing | `lib/product/` directory |
| Item detail | `lib/item/` directory |
