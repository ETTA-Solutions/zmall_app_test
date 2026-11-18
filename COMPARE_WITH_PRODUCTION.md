# Current app vs. safe/production app — risk map

- **Safe (production):** `/Users/apple/Desktop/etta/main_app/zmall_app` (v3.2.10+364)
- **Current:** `/Users/apple/Desktop/etta/order_refund_new_zmall` (v3.2.10+365, branch `paring_combo`)
- Method: `diff -r` on `lib/`, `pubspec.yaml`, `android/`, `ios/`. Whitespace/CRLF-only noise was filtered out (e.g. `cart.dart`, `constants.dart` look fully changed but are mostly `dart format` + line endings).
- Size: ~55 shared files changed, ~40 files new in current, 0 files removed from safe.

Use this as a regression checklist: everything in **A/B** touches logic that already worked in production.

---

## A. Highest risk — old behavior was changed, not just added

| # | Area | Safe (prod) | Current | What can break |
|---|------|-------------|---------|----------------|
| A1 | **Store product list API** (`product/product_screen.dart:1165`, `notifications/notification_store.dart:499`, `global/products/global_products.dart:588`) | `POST /api/user/get_store_product_item_list_paginated` with `page` | `POST /api/user/user_get_store_product_item_list` (no page) | The `page` param is no longer sent, so the whole menu loads in one call: slow or timing out for big stores, and infinite scroll/"load more" may stop working or duplicate. `getStoreProductList({int page})` still takes `page` but ignores it. Check if this was intentional (combo needs full list?) |
| A2 | **KifiyaScreen route** (`utils/routes.dart`) | `KifiyaScreen()` with no args; `OrderHistoryDetail.routeName` registered | Args read from `ModalRoute.settings.arguments` (`price`, `orderPaymentId`, `orderPaymentUniqueId`, `vehicleId`, `onlyCashless`, `userpickupWithSchedule`) | Any caller that does `pushNamed(KifiyaScreen.routeName)` without those args now gets price 0 / empty payment ids. **`OrderHistoryDetail.routeName` entry was removed** from routes, so any `pushNamed(OrderHistoryDetail.routeName)` will crash ("route not found"). |
| A3 | **Payment → order creation** (`kifiya/kifiya_screen.dart`, +~2800 changed lines) | Pay, then app calls `/api/user/create_order` (or courier/aliexpress variants) | New order settlement: `check_before_pay` → pay once → wait for backend-created order (`order_settlement_service.dart`). ZOORYA Telebirr USSD: **app does NOT call `create_order`** (`_zooryaTelebirrBackendCreatesOrder = true`, labelled TEST) | Duplicate orders or missing orders if backend and app both/neither create. User paid but no order if the "wait" times out (courier has a 6s grace then app creates). Back-button/closing the pay screen mid-way. Wallet, cash, CBE, Awash, Boa, etc. must still create orders the old way. |
| A4 | **Payment method list UI** (`kifiya_screen.dart`, `kifiya_method_container.dart`) | `GridView` + hard-coded image map per gateway name; fallback `default_payment.png` | New method container, new assets folder `images/payment/new_payment/` (declared in pubspec), `wallet` branch changed | Missing images for any gateway name; wrong gateway selected (index vs id); `payment_gateway[kifiyaMethod]['_id']` lookup was rewritten |
| A5 | **Telebirr in-app / USSD / Wegagen** (`kifiya/components/*`) | Old result handling (`code == 0` → pop after 2s), `data['result']['success']` | Rewritten handling; `telebirr_ussd.dart` also has **uncommitted** edits | Payment success not detected, screen not popping, stuck spinner. Wegagen: `invoiceId` / `requestId` building changed |
| A6 | **Cart / add-to-cart conflict** (`item/components/body.dart`, `product/product_screen.dart`, `cart/components/body.dart`, `notifications/notification_store.dart`, `aliexpress/*`, `services/service.dart`) | Different store in cart → "clear cart?" dialog (`itemsFound`) | Different store → distance check → combo (2-store) or clear. `Service.save('cart', cart!.toJson())` (was `cart`). Cart line backfills `odooProductId` | Stale/wrong cart shape in storage; users blocked by fail-closed distance API (`StoreDistancegetMax`): any API failure now blocks adding from a 2nd store. Re-entrancy guard `_comboDistanceCheckInProgress` |
| A7 | **Cart model** (`models/cart.dart`) | `json["is_schedule"]`, `json["delivery_for_other"]`, `username`, `phone`, `is_laundry_service` read raw | Null-safe defaults, plus new `isMcp`, `zmallOrderUrl` (`zmll_order_url` typo key also accepted) | Old saved carts still parse (good); but carts saved by the new app and read by an older build would be fine. Check `is_mcp` and `zmll_order_url` against what the backend actually returns |
| A8 | **Order detail constructor** (`orders/components/order_history_detail.dart`) | `orderId/userId/serverToken` all required | All optional; falls back to route arguments / saved user | Null ids → blank detail page; combo orders open a different screen (`combo_order_detail.dart`) |
| A9 | **Orders lists** (`orders/components/body.dart`, `orders_history.dart`, `order_detail.dart`, `order_rating.dart`) | Plain order list | Combo order cards/entries (`combo_order_card.dart`, `orders/models/combo_order_entry.dart`), Odoo-store flag | Order list rendering, status text, rating for old orders |
| A10 | **MCP / AI cart deep links** (`main.dart`, `mcp/mcp_cart_screen.dart`, `login/*`, `AndroidManifest.xml`) | `zmall://cart`, `testapp.zmall.et/ai-cart`, `/cart` | Adds `/go/cart`, `/cart`, `/ai-cart` on `testbackend.zmall.et`, `testapp.zmall.et`, **`app.zmall.et`**; `?next=` parsing; `target`/`flow` param; dedupe window 2s → **10s**; `McpCartScreen` takes `target`; cart consumed after login | Link opens wrong screen / opens twice; `app.zmall.et` links now claimed by the app (autoVerify needs assetlinks on that domain). Second link within 10s is ignored |
| A11 | **Tab bar / chatbot gating** (`utils/tab_screen.dart`, `home/home_screen.dart`) | Chatbot tab shown only if `user.is_chatbot_active == true` and logged in | Tab logic removed (no `is_chatbot_active` anywhere in current); **floating chatbot button on Home for everyone**, and `SupportChatScreen` route registered | Chatbot exposed to all users incl. guests. Backend flag is now ignored |
| A12 | **Clear cart / logout** (`services/service.dart`, `core_services.dart`, `profile/components/body.dart`) | Removes `cart` | Also removes `combo_cart` on clear/logout | Make sure no path leaves a combo cart behind (checkout success, order cancel) |
| A13 | **Delivery** (`delivery/delivery_screen.dart`, `checkout/checkout_screen.dart`, `courier/components/vehicle_screen.dart`) | `_clearCart`, vehicle list, `vehicles[0]['_id']` | Rewritten pickup/vehicle logic; checkout passes `vehicleId` differently; courier photo upload `/api/user/upload_courier_image`; Lunch-from-home sets `paid_by: 1`, `delivery_type: 2`, `order_type: 7` | Self-pickup + schedule, courier paid-by sender/receiver, vehicle id null |
| A14 | **Global stores / favorites** (`global/stores/components/body.dart`, `favorites/favorites_screen.dart`) | Inline open/close time loops | Refactored (open/close calc) | Store "open/closed" label correctness, favourites empty state |
| A15 | **Product screen sorting/search** (`product/product_screen.dart`) | Merge-sort by price (`merge`), `_searchResult` slivers | Removed/reworked | Sort by price, search result list, bottom padding |

## B. Config / build — can break the build or store release

| # | File | Safe | Current | Risk |
|---|------|------|---------|------|
| B1 | `pubspec.yaml` | Gradle 8.14, no local packages | **Gradle 9.3.1**, `dependency_overrides: flutter_inappwebview_android → packages/…`, `fl_location → packages/fl_location` (patched for AGP 9), new deps `google_fonts`, `qr_flutter` | Build/CI machines need Gradle 9 / AGP 9; patched plugin forks must be kept up to date; webview (payments) is running on a **patched fork** |
| B2 | `android/gradle/wrapper/gradle-wrapper.properties` | 8.14 | 9.3.1 | See B1 |
| B3 | `ios/Podfile` | `source 'https://github.com/CocoaPods/Specs.git'` | CDN source | Pod resolution differences; `Podfile.lock` and `project.pbxproj` differ, so do a clean `pod install` |
| B4 | `AndroidManifest.xml` | One deep-link block | Many more hosts incl. `app.zmall.et` (see A10) | App Links verification |
| B5 | Version | `+364` | `+365` | Bump again before release |
| B6 | `utils/constants.dart` | `BASE_URL = BASE_URL_TEST` | **Same: both point to `https://testbackend.zmall.et`** | Neither build points to prod (`BASE_URL_PROD`). Confirm which URL the production release uses before shipping |
| B7 | New hard-coded Odoo server (`constants.dart`) | none | `kZmallOdooBaseUrl = "http://196.191.117.85:9070"` (plain HTTP, raw IP), `kZmallOdooDatabase`, `kZmallBranchSlugs` (2 stores: ayat, mexico) | Works only because `usesCleartextTraffic=true` / `NSAllowsArbitraryLoads=true`; app-store review risk; if the IP changes the feature breaks. Store IDs hard-coded |
| B8 | `utils/backend_logger.dart` | Request/response logging **commented out** | **Enabled** (prints headers, body, response) | Logs tokens/personal data (`_safeText`, check it masks `server_token`); performance. Turn off for release |
| B9 | `.bak` files | 6 | 6 | Same set, so no change |

## C. New features added (nothing in prod depended on these, but they hook into shared code)

1. **Combo (two-store order)** — `lib/combo/*`, `models/combo_invoice.dart`, `models/combo_payment_context.dart`, `orders/components/combo_order_*.dart`. Hooks in: cart body, item body, product screen, notification store, `Service.clearCart`, checkout, kifiya. New API: `combo_get_order_cart_invoice`, `store distance max`, `log_failed_order`. New strings in `models/language.dart` (`comboAdded`, `comboStoreLimit`, …) — **English text used for all languages except Chinese**; check Amharic/other translations.
2. **New payment gateways** — ZOORYA-PAY (`/api/zooryapay/send_otp|pay|status`, M-Pesa, OTP, QR, USSD, Telebirr USSD screens), CyberSource (`/api/user/cybersource/pay|status` + webview), BirrLink (`/api/birrlink/generatepaymenturl|checktransactionstatus`), `order_settlement_service.dart`, `check_before_pay`.
3. **Chatbot/support chat** — big rewrite (`support_chat_screen.dart`, `chat_service.dart`, basket, checkout service, order cards, store carousel, product sheet); new APIs `/api/chatbot`, `/api/chatbot/chat_test`, `/api/directions/json`; `ChatMessage.showCartAction`.
4. **Subscription ("Zmall Pro")** — `profile/subscription/*`, `/api/user/get_subscription_detail`, new route `SubscriptionScreen`, Profile menu item.
5. **Odoo availability** — `services/zmall_availability_service.dart`, `/zmall_order/<slug>`, stock dialogs (`widgets/stock_availability_dialog.dart`, `stock_left_notification.dart`).
6. **UI widgets** — `CustomButton.enabled`, `LinearLoadingIndicator` layout, store list error message (debug vs release text).

## D. Uncommitted edits in the current branch (not even in git yet)

`lib/cart/components/body.dart` (+188, combo pairing strip), `lib/combo/services/combo_service.dart`, `lib/kifiya/components/telebirr_ussd.dart`, `lib/kifiya/zoorya_pay/zoorya_pay_mpesa_screen.dart`, `lib/main.dart`, `lib/search/search_screen.dart`, and new `lib/combo/widgets/combo_pairing_strip.dart`.

## E. Smoke-test checklist (old flows that must still pass)

1. Login/OTP (guest and returning user) → pending AI cart resume.
2. Browse store with a **large menu**: scroll, search, sort by price (A1, A15).
3. Add item from store A, then same store again (no dialog), then store B (combo/clear/blocked-by-distance dialogs) (A6).
4. Cart → checkout → each payment method: wallet, cash, Telebirr in-app, Telebirr USSD, CBE, Awash, Wegagen, Boa, Chapa/others — confirm **exactly one** order is created and cart is cleared (A3–A5).
5. Pay then kill app / back out mid-payment; reopen and check orders list.
6. Courier order with photo, self-pickup, scheduled order, laundry, AliExpress cart (A13).
7. Orders tab: active list, history, detail, rating; open detail from a push notification (A8, A9).
8. Deep links: `zmall://cart/{id}`, `https://…/go/cart/{id}`, `?next=` form, tapping twice (A10).
9. Logout → login as another user: no leftover `cart` / `combo_cart`.
10. Guest user: chatbot visibility (A11).
11. Fresh `flutter clean && flutter pub get`, Android release build on Gradle 9, iOS `pod install` + archive (B1–B3).
12. Confirm `BASE_URL` before release (B6) and that backend logger is off (B8).

## F. Fast ways to see exact diffs

```bash
cd /Users/apple/Desktop/etta
diff -rq main_app/zmall_app/lib order_refund_new_zmall/lib
diff -w --strip-trailing-cr main_app/zmall_app/lib/kifiya/kifiya_screen.dart order_refund_new_zmall/lib/kifiya/kifiya_screen.dart
```
