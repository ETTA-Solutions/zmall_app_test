# Laundry Feature — Full Guide
> zmall_app · Last updated: 2026-06-02

---

## What is Laundry?

Laundry ("Laundry Pick & Drop") is a **service category**, not a separate feature.  
It is one of the delivery categories returned by the backend when the app loads.  
When the backend includes a category whose `delivery_name == "laundry"`, the app  
shows a **Laundry Pick & Drop banner** on the home screen.

Tapping it opens the regular **StoreScreen** filtered to laundry stores — same flow  
as ordering from any other store category (grocery, restaurant, etc.).

**Key distinction:** Laundry has NO separate API. It re-uses the standard category + store + order APIs.

---

## Where Laundry Lives in the Codebase

```
lib/
├── home/
│   └── components/
│       └── home_body.dart          ← Detects laundry category, shows banner (line 1021–2875)
├── store/
│   ├── store_screen.dart           ← Opens with laundry category
│   └── components/
│       └── body.dart               ← Lists laundry stores
├── product/                        ← Browse laundry products/services
├── item/                           ← View individual laundry item
└── checkout/                       ← Standard checkout flow
```

**No dedicated route** — laundry uses `/store` route with laundry's category ID.

---

## How Laundry is Detected

**File:** `lib/home/components/home_body.dart:1021`

```dart
void checkLaundryCategory(List categoryList) {
  laundryIndex = -1;
  for (int i = 0; i < categoryList.length; i++) {
    if (categoryList[i]['delivery_name'].toString().toLowerCase() == "laundry") {
      isLaundryActive = true;
      laundryIndex = i;
    }
  }
  if (laundryIndex == -1) {
    isLaundryActive = false;
  }
}
```

- If the category list contains `delivery_name == "laundry"` → show the Laundry section
- If not → section is hidden (`SizedBox.shrink()`)
- `laundryIndex` stores the position in the categories array so the category object can be passed to StoreScreen

---

## User Journey (Screen by Screen)

```
[Home Screen]
     │  API: POST /api/user/get_delivery_list_for_nearest_city  → get categories
     │  checkLaundryCategory() → finds laundry in the list
     │  Laundry banner is shown
     │
     │  user taps "Laundry Pick & Drop" banner
     ▼
[StoreScreen]  /store (with laundry category)
     │  Params passed:
     │    cityId: responseData['city']['_id']
     │    storeDeliveryId: categories[laundryIndex]['_id']
     │    category: categories[laundryIndex]
     │    latitude, longitude: user's location
     │    isStore: false
     │    companyId: -1
     │
     │  API: POST /api/user/get_company_list  (or get_store_list_by_company)
     ▼
[ProductScreen]  /product
     │  Browse laundry services/items
     ▼
[ItemScreen]  /item
     │  View individual laundry item detail
     ▼
[CartScreen]  /cart  → Checkout  → Payment
```

---

## API Calls Used by Laundry

### 1. Get Categories (includes laundry detection)
**When:** Home screen loads — this is where laundry is discovered  
**File:** `lib/services/core_services.dart:15`

```
POST {baseUrl}/api/user/get_delivery_list_for_nearest_city
Content-Type: application/json

REQUEST BODY:
{
  "latitude":     number,    // user's latitude
  "longitude":    number,    // user's longitude
  "country":      "string",  // e.g. "Ethiopia"
  "country_code": "string"   // e.g. "ET"
}

RESPONSE (success):
{
  "success": true,
  "city": {
    "_id": "string"          // city ID used for store queries
  },
  "deliveries": [
    {
      "_id":           "string",    // category/delivery ID → passed as storeDeliveryId
      "delivery_name": "string",    // e.g. "laundry", "grocery", "restaurant"
      "image_url":     "string",    // banner image path (relative to baseUrl)
      ...
    }
  ]
}
```

> Saved to local storage key: `'categories'`

---

### 2. Get Company List (loads laundry stores)
**When:** StoreScreen loads with laundry's category ID  
**File:** `lib/store/components/body.dart:798`

```
POST {baseUrl}/api/user/get_company_list
Content-Type: application/json

REQUEST BODY:
{
  "city_id":           "string",   // from city._id
  "store_delivery_id": "string",   // laundry category _id
  "latitude":          number,
  "longitude":         number
}

RESPONSE (success):
{
  "success": true,
  "stores": [
    {
      "_id":                  "string",
      "name":                 "string",
      "location":             [lat, lon],
      "store_count":          number,
      "company_id":           number,
      "delivery_name":        "string",
      "famous_products_tags": ["string"],
      "promo_tags":           "string",
      "store_tags":           "string",
      "is_active":            boolean
    }
  ]
}
```

---

### 3. Get Store List by Company (if company selected)
**When:** User picks a specific company inside the laundry category  
**File:** `lib/store/components/body.dart:685`

```
POST {baseUrl}/api/user/get_store_list_by_company
Content-Type: application/json

REQUEST BODY:
{
  "city_id":           "string",
  "store_delivery_id": "string",   // laundry category _id
  "latitude":          number,
  "longitude":         number,
  "company_id":        number      // selected company ID
}

RESPONSE:
{ same structure as get_company_list }
```

---

## Key Values for Laundry

| Value | What it means |
|-------|---------------|
| `delivery_name == "laundry"` | Identifies the laundry category in the API response |
| `isStore: false` | Passed to StoreScreen to indicate service (not product store) |
| `companyId: -1` | Default value when no specific company is pre-selected |
| Banner image fallback | `"images/laundry.png"` (local asset) used if no `image_url` from server |

---

## After Returning from Laundry

When the user navigates back from the Laundry/StoreScreen to home, the app refreshes:
- `_getPromotionalItems()` — reload Special for You items
- `getUserOrderCount()` — refresh order badge
- `_doLocationTask()` — update location
- `getNearByMerchants()` — reload nearby stores

---

## Related Files Quick Reference

| What you need | File |
|---------------|------|
| Laundry detection logic | `lib/home/components/home_body.dart:1021` |
| Laundry banner UI | `lib/home/components/home_body.dart:2812` |
| Store list screen | `lib/store/store_screen.dart` |
| Store list body/API | `lib/store/components/body.dart` |
| Category API | `lib/services/core_services.dart:15` |
