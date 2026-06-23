# zmall_doc — API & Feature Documentation
> zmall_app · Last updated: 2026-06-02

This folder contains complete guides for every major feature in the zmall app.  
Each guide explains: what the feature is, all API calls with exact request/response fields,  
the screen flow, and key file locations.

---

## Feature Guides

| Guide | What it covers |
|-------|---------------|
| [COURIER_FULL_GUIDE.md](./COURIER_FULL_GUIDE.md) | Package delivery service (person-to-person), vehicle selection, all 8 API endpoints |
| [EVENTS_GUIDE.md](./EVENTS_GUIDE.md) | Event browsing & ticket purchase via Telebirr WebView |
| [LAUNDRY_GUIDE.md](./LAUNDRY_GUIDE.md) | Laundry Pick & Drop service category detection and store flow |
| [FEATURED_STORES_GUIDE.md](./FEATURED_STORES_GUIDE.md) | Promotional/featured stores on home screen, promo tags reference |
| [SPECIAL_FOR_YOU_GUIDE.md](./SPECIAL_FOR_YOU_GUIDE.md) | Personalized promotional product recommendations on home screen |
| [STORES_GUIDE.md](./STORES_GUIDE.md) | Core store browsing flow (all categories: grocery, restaurant, pharmacy, etc.) |
| [PREDICT_AND_WIN_GUIDE.md](./PREDICT_AND_WIN_GUIDE.md) | Sports match prediction feature + Borsa wallet overview |

---

## API Endpoints Quick Reference

| Endpoint | Method | Feature | Purpose |
|----------|--------|---------|---------|
| `/api/user/clear_cart` | POST | Courier | Clear cart before new order |
| `/api/user/add_item_in_cart` | POST | Courier | Create courier cart entry |
| `/api/store/get_vehicle_list` | POST | Courier | Get Bike/Car/Van options |
| `maps.googleapis.com/distancematrix` | GET | Courier | Calculate distance & time |
| `/api/user/get_courier_order_invoice` | POST | Courier | Get final delivery price |
| `/api/user/get_order_status` | POST | Courier | Poll live order status |
| `/api/user/show_invoice` | POST | Courier | Mark order complete |
| `/api/user/user_cancel_order` | POST | Courier | Cancel an order |
| `/api/admin/get_user_event_history` | POST | Events | Load all events |
| `/api/admin/generate_ticket_invoice` | POST | Events | Generate ticket invoice |
| `/api/user/get_delivery_list_for_nearest_city` | POST | Categories/Laundry/Stores | Get all service categories |
| `/api/user/get_promotion_item` | POST | Special for You | Load promotional products |
| `/api/user/get_promotion_store` | POST | Featured Stores | Load promoted stores |
| `/api/user/get_company_list` | POST | Stores | Load store groups/companies |
| `/api/user/get_store_list_by_company` | POST | Stores | Load stores for a company |
| `/api/admin/get_game_user_history` | POST | Predict & Win | Load all games |
| `/api/admin/get_prediction_history` | POST | Predict & Win | Load user's predictions |
| `/api/admin/predict_game` | POST | Predict & Win | Submit score prediction |

---

## Key Concepts

| Concept | Value | Meaning |
|---------|-------|---------|
| `delivery_type` | `1` | Regular store order delivery |
| `delivery_type` | `2` | Courier (person-to-person parcel) |
| `user_type` | `7` | Courier destination user type |
| Cache key `'categories'` | — | Local storage for category list |
| Cache key `'p_items'` | — | Local storage for promotional items |
| Cache key `'s_items'` | — | Local storage for promotional stores |
| `delivery_name == "laundry"` | — | Identifies laundry in category list |
| `promo_tags` | string | Comma-separated store promotional labels |
