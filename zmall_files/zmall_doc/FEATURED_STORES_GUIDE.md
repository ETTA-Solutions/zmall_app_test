# Featured Stores — Full Guide
> zmall_app · Last updated: 2026-06-02

---

## What is Featured Stores?

Featured Stores (also called **Promotional Stores**) is a curated list of stores  
shown on the home screen. These are stores that the admin has marked as "promoted" —  
they appear with special tags/badges (e.g., "trending", "top_rated", "new_on_zmall").

The backend returns stores tagged with promotional labels.  
The app fetches them at home load and caches them in local storage as `'s_items'`.

---

## Where Featured Stores Lives in the Codebase

```
lib/
├── home/
│   └── components/
│       └── home_body.dart                  ← Fetches & renders Featured Stores section
├── services/
│   └── core_services.dart:259             ← getPromotionalStores() API call
└── store/
    └── store_screen.dart                   ← Opens when user taps a featured store
```

**No dedicated folder** — Featured Stores is a section inside the home screen, not a standalone screen.

---

## User Journey (Screen by Screen)

```
[Home Screen loads]
     │  API: POST /api/user/get_promotion_store  → load featured stores
     │  Stores saved to local storage 's_items'
     │  Featured Stores horizontal scroll section displayed on home
     │
     │  user taps a featured store card
     ▼
[StoreScreen]  /store
     │  Opens the specific store (browse its products)
     ▼
[ProductScreen]  /product  → [ItemScreen]  /item  → [Cart]  → [Checkout]
```

---

## API Calls — Featured Stores

### 1. Get Promotional Stores
**When:** Home screen loads (called from `home_body.dart`)  
**File:** `lib/services/core_services.dart:259`

```
POST {baseUrl}/api/user/get_promotion_store
Content-Type: application/json

REQUEST BODY:
{
  "user_id":      "string",   // user._id
  "server_token": "string",   // user.server_token
  "latitude":     number,     // user's latitude
  "longitude":    number      // user's longitude
}

RESPONSE (success):
{
  "success": true,
  "promotional_stores": [
    {
      "_id":          "string",        // store ID
      "name":         "string",        // store name
      "location":     [lat, lon],      // [double, double]
      "promo_tags":   "string",        // comma-separated promotional tags
      "image_url":    "string",        // store image/logo path
      "is_active":    boolean,
      "store_tags":   "string",
      ...                              // all standard store fields
    }
  ]
}
```

> Saved to local storage key: `'s_items'`  
> Timeout: **20 seconds**

---

## Promotional Tags Reference

Tags found in `promo_tags` field (comma-separated string):

| Tag | Meaning |
|-----|---------|
| `24_7` | Open 24 hours, 7 days |
| `discount` | Has active discounts |
| `exclusive` | Exclusive to zmall |
| `healthy_option` | Healthy menu options |
| `holiday_special` | Holiday promotions active |
| `limited_offer` | Limited-time offer |
| `local_cuisine` | Local/traditional food |
| `most_popular` | Most ordered store |
| `new_on_zmall` | Recently joined zmall |
| `seasonal` | Seasonal menu |
| `store_closed` | Temporarily closed |
| `top_rated` | High user ratings |
| `top_selling` | Best-selling store |
| `trending` | Currently trending |
| `promotion` | General promotion flag |

Tag images are loaded from: `images/store_tags/{tag_name}.png`

---

## Key Code Points

**Where stores are fetched** — `lib/home/components/home_body.dart:817`
```dart
// Called inside _getPromotionalItems() during home load
CoreServices.getPromotionalStores(
  userId: userData['user']['_id'],
  serverToken: userData['user']['server_token'],
  ctx: context,
  latitude: latitude,
  longitude: longitude,
)
```

**Where `promotion` tag is detected** — `lib/home/components/home_body.dart:1230`
```dart
tag.toString().toLowerCase() == 'promotion'
```

**Store open/closed status** — checked via `Service.storeOpen()` using store's hours

---

## Featured Stores vs Regular Stores

| Aspect | Featured Stores | Regular Stores |
|--------|----------------|----------------|
| API | `/api/user/get_promotion_store` | `/api/user/get_company_list` |
| How shown | Horizontal scroll section on home | Listed inside StoreScreen |
| Tags | `promo_tags` (e.g., trending, top_rated) | `store_tags` |
| Selection | Admin-curated/promoted | All active stores |
| Cache key | `'s_items'` | No local cache |

---

## Related Files Quick Reference

| What you need | File |
|---------------|------|
| API call (getPromotionalStores) | `lib/services/core_services.dart:259` |
| Home section rendering | `lib/home/components/home_body.dart` |
| Store screen (opened on tap) | `lib/store/store_screen.dart` |
