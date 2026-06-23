# ZMall API — Endpoint Reference

A complete catalog of the backend API calls in the app: full URLs, HTTP method, request bodies,
and the **exceptions** (calls that deviate from the common pattern — different host, different
base URL, GET vs POST, special error handling).

> Extracted from `lib/**` (the `http`-based call sites). Use this as the source-of-truth map when
> building the organized `dio` layer (see `api_dio_migration_plan.md`).

---

## 1. Hosts / base URLs

There is **not one base URL** — this is the single most important thing to get right in the
migration. Calls resolve their host in **four** different ways:

| # | Host source | Value | Used by |
|---|---|---|---|
| 1 | **`ZMetaData.baseUrl`** (runtime provider) | `BASE_URL_PROD` = `https://app.zmall.et` (or `BASE_URL_JUBA` = `https://juba.zmallapp.com`) | **Most** endpoints (the whole `/api/user/*`, `/api/admin/*`, `/admin/*` set) |
| 2 | **`BASE_URL` constant** (`constants.dart`) | `https://app.zmall.et` | ⚠️ Payment URLs in `kifiya_screen.dart` (santimpay, chapa, ettacard) and `mcp_cart_screen.dart` (`/api/ai/cart`). **Bypasses the runtime provider** — see Exceptions. |
| 3 | **External payment gateways** | `https://pgw.shekla.app/...` | Dashen MasterCard, AddisPay (in-app payment `api/checkout`) |
| 4 | **Google Maps API (direct)** | `https://maps.googleapis.com/maps/api/...` | Place autocomplete, place details, geocode, distance matrix |

**Convention in tables below:** unless a row says otherwise, the host is **#1 `ZMetaData.baseUrl`**
and the call is **POST** with `Content-Type: application/json`, `Accept: application/json`.

### Common auth fields
Most authenticated calls carry **`user_id`** + **`server_token`** (the session token) in the JSON
body — there is **no `Authorization` header / bearer token**. Identity is in the body.

---

## 2. Common request & error pattern

```dart
final url = "${ZMetaData.baseUrl}/api/user/<endpoint>";
final body = json.encode({ ...fields });
final res = await http.post(
  Uri.parse(url),
  headers: {"Content-Type": "application/json", "Accept": "application/json"},
  body: body,
).timeout(const Duration(seconds: 15 /* 10–30 varies */),
   onTimeout: () => throw TimeoutException(...));
return json.decode(res.body);   // catch (e) => return null
```

- **Timeouts:** vary per call — 10s, 15s, 20s, or 30s.
- **Error handling:** most `catch` blocks **return `null`** (and some show a snackbar / overlay).
  Business error codes (e.g. `999`, `2000` in `errorCodes`) come back **HTTP 200** in the body and
  are mostly **not** centrally handled (only `refund_service` maps them). See migration plan §3.6.
- **Logging:** several services wrap calls in `BackendLogger.request/response/error`
  (`core_services.dart` especially); most screens do not.

---

## 3. Endpoint catalog (by domain)

### 3.1 Auth & account
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/user/register` | `country_id, email, phone, first_name, last_name, password, country_phone_code, city, referral_code, address, is_phone_number_verified` | `register_screen`, `complete_profile_form` |
| POST | `/api/user/login` | `email, password, app_version, device_type` | `service.dart`, `otp_screen`, `register_screen` |
| POST | `/api/user/generate_otp_at_login` | `phone, password` | `login_screen`, `otp_screen`, `profile/body` |
| POST | `/api/user/verify_otp` | `code, phone` | `otp_screen`, `profile/body` |
| POST | `/api/user/otp_verification` | `email, phone, is_email_verified, is_phone_number_verified, user_id, server_token` | `profile/body` |
| POST | `/api/admin/simple_email_otp_verification` | `email` | `global.dart` |
| POST | `/api/user/forgot_password_with_otp` | `phone, …` | `forgot_password_screen`, `otp_screen` |
| POST | `/api/user/forgot_password` | `phone` *(currently commented)* | `update_password` |
| POST | `/api/user/reset_password` | `code, phone, password` | `update_password` |
| POST | `/api/user/logout` | `user_id, server_token` | `profile/body` |
| POST | `/api/admin/send_sms_with_message` | `code, phone, message, (email)` | `register_screen`, `profile/body`, `forgot_password` |
| POST | `/admin/approve_decline_user` | `user_id, is_approved, user_page_type` | `service.dart` (account delete/approve) |

### 3.2 User profile & device
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/user/get_detail` | `user_id, server_token` | many screens (`core_services`, `borsa`, `profile`, `chat_service`, `kifiya`) |
| POST | `/api/user/update` | `user_id, server_token, first_name, last_name, (old_password, new_password)` | `change_password`, `edit_profile` |
| POST | `/api/user/update_device_token` | `user_id, server_token, device_token` | `core_services` |

### 3.3 Home / discovery
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/user/get_delivery_list_for_nearest_city` | `latitude, longitude, country, country_code, (isGlobal)` — or with `delivery_type: 2` | `core_services` (categories vs services), `home_body`, `global_home` |
| POST | `/api/user/get_promotion_item` | `user_id, server_token, userLocation, (isGlobal)` | `core_services` |
| POST | `/api/user/get_promotion_store` | `user_id, server_token, latitude, longitude` | `core_services` |
| POST | `/api/user/get_company_list` | `city_id, store_delivery_id, latitude, longitude` | `core_services`, `store/body` |
| POST | `/api/user/get_company_list_front_page` | (similar) | `home_body` |
| POST | `/api/user/get_store_list_by_company` | `city_id, store_delivery_id, latitude, longitude, company_id` | `store/body`, `global/stores` |
| POST | `/api/user/get_misaka_list` | `city_id, store_delivery_id, latitude, longitude` | `misaka_store_list_screen` |
| POST | `/api/admin/get_item_information` | `item_id` | `home_body`, `splash_container` |
| POST | `/api/user/search_item_global` | `name` | `core_services` |
| POST | `/api/admin/add_user_and_store` | `store_id, (product_id), user_id, latitude, longitude, is_promotional, (last_opened)` | store/product open tracking |

### 3.4 Store / product / reviews
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/user/user_get_store_product_item_list` | `store_id` | cart, checkout, product, scanner, notification, global |
| POST | `/api/user/user_get_store_product_item_list_with_pagination` | `store_id, …` | `product_screen` |
| POST | `/api/user/user_get_store_product_item_available` | `store_id` | `cart/body` |
| POST | `/api/user/user_get_store_review_list` | `user_id, store_id` | `review_screen` |
| POST | `/api/user/get_favourite_store_list` | `user_id, server_token` | `favorites_screen`, `product_screen` |
| POST | `/api/user/add_favourite_store` | `user_id, store_id, …` | `product_screen` |
| POST | `/api/user/remove_favourite_store` | `user_id, store_id, …` | `product_screen` |

### 3.5 Cart
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/user/add_item_in_cart` | `user_id, user_type, store_id, city_id, destination_addresses[…], order_details[], pickup_addresses[…]` | `courier_screen`, `lunch_home` (courier/lunch delivery) |
| POST | `/api/user/add_item_in_cart_new` | (cart payload) | `delivery_screen` |
| POST | `/api/user/add_item_in_cart_new_for_aliexpress` | (cart payload) | `delivery_screen` |
| POST | `/api/user/clear_cart` | `user_id, cart_id, server_token` | `courier_screen`, `delivery_screen`, `global_delivery` |

### 3.6 Checkout / order creation
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/user/get_order_cart_invoice` | `user_id, store_id, total_time, total_distance, order_type, is_user_pick_up_order, total_item_count, is_user_drop_order, express_option, server_token, vehicle_id, tip` | `checkout_screen`, `global_checkout` |
| POST | `/api/user/get_courier_order_invoice` | `user_id, total_time, total_distance, is_user_pickup_order, total_item_count, is_user_drop_order, server_token, vehicle_id, city_id, country_id, is_round_trip` | `vehicle_screen`, `lunch_home` |
| POST | `/api/user/apply_promo_code` | `user_id, promo_code_name, order_payment_id, server_token` | `checkout_screen`, `global_checkout` |
| POST | `/api/store/get_vehicle_list` | `store_id, type, delivery_type, user_id, server_token, city_id, (user/store lat/long, use_calculation)` | `vehicle_screen`, `delivery_screen`, `lunch_home` |
| POST | `/api/user/create_order` | (full order payload: `product_count, product_id, …`) | `kifiya_screen`, `global_kifiya` |
| POST | `/api/user/log_failed_order` | (failed-order payload) | `kifiya_screen` |

### 3.7 Orders & history
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/user/get_orders` | `user_id, server_token, …` | `orders/body`, `home_body`, `chat_service` |
| POST | `/api/user/get_recent_orders` | `user_id, server_token` | `core_services` (proximity orders) |
| POST | `/api/user/get_order_status` | `user_id, server_token, order_id` | `order_detail`, `courier_detail` |
| POST | `/api/user/order_history` | `user_id, server_token, end_date, start_date` | `orders_history` |
| POST | `/api/user/order_history_detail` | `user_id, server_token, order_id` | `order_history_detail` |
| POST | `/api/user/show_invoice` | `user_id, server_token, order_id, is_user_show_invoice` | `order_detail`, `courier_detail` |
| POST | `/api/user/user_cancel_order` | `user_id, server_token, cancel_reason, order_id` | `order_detail`, `courier_detail` |
| POST | `/api/user/rating_to_store` | `user_id, server_token, order_id, user_review_to_store, user_rating_to_store` | `order_rating` |
| POST | `/api/user/rating_to_provider` | `user_id, server_token, order_id, user_review_to_provider, user_rating_to_provider` | `order_rating` |
| POST | `/api/user/get_provider_location` | `user_id, server_token, provider_id` | `provider_location` |

### 3.8 Wallet / top-up / payment gateways
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/user/get_payment_gateway` | `user_id, city_id, server_token, (store_delivery_id, device_type, app_version, is_user_pickup_with_schedule)` | `kifiya_screen`, `borsa`, `topup`, `amole`, `global_kifiya` |
| POST | `/api/user/send_otp` | `user_id, phone, type, token, country_phone_code` | `kifiya_screen`, `amole`, `topup` |
| POST | `/api/user/add_wallet_amount` | `user_id, payment_id, otp, type, server_token, wallet` | `kifiya_screen`, `topup` |
| POST | `/api/user/add_wallet_amount_new` | `user_id, payment_id, is_payment_paid, type, server_token, wallet` | `borsa` |
| POST | `/api/user/transfer_wallet_amount` | `user_id, top_up_user_phone, password, wallet, server_token` | `borsa` |
| POST | `/api/user/change_user_wallet_status` | `user_id, is_use_wallet, server_token` | `kifiya_screen`, `global_kifiya` |
| POST | `/api/admin/get_wallet_history_new` | `id, type, server_token, page, limit` | `borsa` |
| POST | `/api/user/pay_order_payment` | `user_id, otp, order_payment_id, payment_id, (order_type), is_payment_mode_cash, server_token, (store_delivery_id)` | `kifiya_screen`, `global_kifiya` |
| POST | `/admin/check_paid_order` | `user_id, server_token, order_payment_id` | USSD flows (`cbe_ussd`, `momo_ussd`, `telebirr_ussd`, `kifiya_*`) |

### 3.9 Payment provider URLs / gateways — ⚠️ host exceptions
| Method | Full URL | Request body | Notes |
|---|---|---|---|
| POST | **`$BASE_URL`** `/api/santimpay/generatepaymenturl` | (payment payload) | Uses **`BASE_URL` constant**, not the provider — `kifiya_screen:1578` |
| POST | **`$BASE_URL`** `/api/chapa/generatepaymenturl` | (payment payload) | `BASE_URL` constant — `kifiya_screen:1662` |
| POST | **`$BASE_URL`** `/admin/pay_payment_ettacard` | `card, pin, amount, description, trace_no, expiration_date` | `BASE_URL` constant — `kifiya_screen:1494`, `etta_card_screen` |
| POST | `…/admin/pay_payment_etswitch` | (card payload) | `kifiya_screen:3734` |
| POST | **`https://pgw.shekla.app/dashenMpgs/mastercard/api/checkout`** | (gateway payload) | **External host** — Dashen MasterCard (`kifiya_screen:1915`) |
| POST | **`https://pgw.shekla.app/addispay/api/checkout`** | (gateway payload) | **External host** — AddisPay (`kifiya_screen:2238`) |
| POST | `…/api/checkout` | (order payload) | `kifiya_screen`, `global_kifiya` |
| POST | `…` | `merch_order_id` | merchant order check — `kifiya_screen:160` |
| POST | `/admin/check_paid_order` (CBE USSD verify) | `trace_no, amount, phone` | `cbe_ussd:139` (provider-side) |

### 3.10 AliExpress
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/admin/aliexpress_product` | `feed_name` (or `{}`) | `ali_product_screen`, `global_ali_product_screen` |
| POST | `/admin/aliexpress_product_detail` | `access_token, product_id` | `ali_item_screen`, `global_ali_item_screen` |
| POST | `/admin/aliexpress_creat_order` | (order payload) | `kifiya_screen`, `global_kifiya` |

### 3.11 Events & World Cup
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/admin/generate_ticket_invoice` | `user_id, server_token, quantity, ticket_type_id` | `ticket_order_payment` |
| POST | `/api/admin/get_user_event_history` | `user_id, …` | `events_screen` |
| POST | `/api/admin/predict_game` | `user_id, server_token, game_id, home_score, away_score, away_win, home_win, draw, penalties, penalty_score` | `predict_screen` |
| POST | `/api/admin/get_prediction_history` | `start_date, end_date, search_field, search_value` | `predict_screen`, `my_prediction`, `available_games` |
| POST | `/api/admin/get_game_user_history` | `{}` (empty) | `my_prediction`, `available_games` |
| GET/POST | `/predictions` | — | `my_prediction:145` |

### 3.12 Magazine & Yearly Recap
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/user/get_magazine_list` | `year, user_id, is_show_recap, server_token, timestamp, is_global_user` | `magazine_service` |
| POST | `/api/user/magazine_interaction` | `year, user_id, magazine_id, server_token, type (view/like), timestamp, is_global_user` | `magazine_service` |
| POST | `/api/user/save_recap_info` | `year, user_id, is_show_recap, server_token, timestamp` | `recap_service` |
| POST | `/api/get_user_recap` | `user_id, server_token` | `core_services.getRecapServices` |

### 3.13 Refund (already a clean service)
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/api/user/send_refund_otp` | `user_id, phone` | `refund_service.generateOtp` — constant `kRefundGenerateOtpEndpoint` |
| POST | `/api/user/verify_refund_otp` | `user_id, phone, code` | `refund_service.verifyOtp` — `kRefundVerifyOtpEndpoint` |
| POST | `/api/admin/enable_wallet_refund` | `user_id, phone, amount, unique_id` | `refund_service.processRefund` — `kRefundProcessEndpoint` |

### 3.14 Support chat
| Method | Path | Request body | Notes |
|---|---|---|---|
| POST | `/chat_test` | `message, user_id, user_location, server_token` (and a `{message}` variant) | `chat_service` — non-`/api` path |

### 3.15 Ads
| Method | Path | Request body | Notes |
|---|---|---|---|
| GET/POST | `/admin/get_all_advertises` | — | `splash_screen` (list) |
| POST | `/admin/get_all_advertises/{adId}` | — | `core_services.saveAdClick` (click tracking) |
| POST | `/admin/orders_list` | `order_status, payment_status, page, …` | `core_services` *(currently commented)* |

### 3.16 AI / MCP cart — ⚠️ host & method exception
| Method | Full URL | Request body | Notes |
|---|---|---|---|
| **GET** | **`$BASE_URL`** `/api/ai/cart/{cartId}` | — (GET) | `mcp_cart_screen:58` — uses **`BASE_URL` constant** + **GET** (deep-link AI cart) |
| — | `/api/ai/cart` | — | referenced in `cart/body`, `splash_screen` |

### 3.17 Google Maps (direct, third-party) — ⚠️ host exception
| Method | Full URL | Query params | Notes |
|---|---|---|---|
| **GET** | `https://maps.googleapis.com/maps/api/place/autocomplete/json` | `input, location, key, sessiontoken, radius` | `place_service`, `location_screen` |
| **GET** | `https://maps.googleapis.com/maps/api/place/details/json` | `place_id, fields, key, sessiontoken, rankby` | `place_service` |
| **GET** | `https://maps.googleapis.com/maps/api/geocode/json` | `latlng, key, sessiontoken` | `place_service` |
| **GET** | `https://maps.googleapis.com/maps/api/distancematrix/json` | `origins, destinations, key` | `checkout_screen`, `vehicle_screen`, `global_checkout`, `lunch_home` |
| POST | `…/api/distancematrix/json` (proxy variant) | `locations:[{pickup:[…], destination:[…]}]` | `checkout_screen:1450` (server-side routing variant) |
| POST | (ML host) delivery-fee predictor | `model_id, cart_total, delivery_total, distance, hour, weekday` | `checkout_screen:1672` — **verify host** |

---

## 4. Exceptions — calls that deviate from the norm

These are the ones to handle deliberately in the `dio` migration (they break the "one client,
one base URL, POST+JSON, return null on error" assumption):

1. **`BASE_URL` constant instead of `ZMetaData.baseUrl`** — `kifiya_screen` payment URLs
   (santimpay, chapa, ettacard) and `mcp_cart_screen` (`/api/ai/cart`). These ignore the runtime
   region/test toggle. *Decide:* unify onto the provider, or keep a dedicated payment client.
2. **External hosts** — `https://pgw.shekla.app/...` (Dashen MasterCard, AddisPay). Need a
   separate `dio` instance / absolute URLs (migration plan §3.5).
3. **Google Maps direct** — `https://maps.googleapis.com/...`, **GET**, API-key in query. Belongs
   in its own client (different base URL, no JSON body, key handling).
4. **GET requests** — `/api/ai/cart/{cartId}` (MCP), all Google Maps calls, `/predictions`,
   ads list. Everything else is POST.
5. **Empty / minimal bodies** — `get_game_user_history` (`{}`), `appKeys` (no body),
   `search_item_global` (`{name}`), `get_item_information` (`{item_id}`).
6. **Non-`/api` paths** — `/chat_test` (support chat), `/admin/*` (no `/api` prefix:
   `check_paid_order`, `pay_payment_ettacard`, `aliexpress_*`, `get_all_advertises`,
   `approve_decline_user`, `orders_list`).
7. **Error-handling deviations:**
   - `refund_service` → structured `{success, error_type, message}` + `errorCodes` mapping (the model).
   - `core_services` → wrapped in `BackendLogger` + some show snackbars.
   - `checkout_screen` and most screens → inline `try/catch`, `return null`, ad-hoc UI messages;
     business error codes (`999`, `2000`, …) **not** centrally handled.
8. **Auth model** — identity is in the **body** (`user_id` + `server_token`), not an
   `Authorization` header. No interceptor-based token injection exists today.

---

## 5. Notes / to verify with backend

- The host for the **delivery-fee ML predictor** (`checkout_screen:1672`) — confirm URL.
- Whether `/api/distancematrix/json` (POST proxy) is a ZMall endpoint vs. the Google direct GET.
- Exact bodies for `create_order`, `log_failed_order`, and the gateway `api/checkout` payloads
  (large; read the specific call sites when implementing those services).
- Whether any endpoint returns business error codes as real non-200 statuses (affects
  `validateStatus` — see migration plan §3.6).
