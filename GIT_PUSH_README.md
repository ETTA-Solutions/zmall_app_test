# ZMall — Release Notes for Git Push

**Branch:** `mpessa_Create_order` → target `main`
**App version:** `3.2.10+365` (see `pubspec.yaml`)

This document explains how the app currently works for the features in this branch, so a reviewer can understand them without reading all the code:

1. [Combo orders (two stores, one driver)](#1-combo-orders-two-stores-one-driver)
2. [Payment integration (ZOORYA-PAY, M-PESA, CyberSource, Cash, …)](#2-payment-integration)
3. [Create order: what changed (the new flow is NOT the same as before)](#3-create-order-what-changed)
4. [Odoo branch stock availability and order status](#4-odoo-branch-stock-availability-and-order-status)
5. [MCP / ChatGPT cart (deep link into the app)](#5-mcp--chatgpt-cart)
6. [AI support chatbot](#6-ai-support-chatbot)
7. [Before release: open items](#7-before-release-open-items)
8. [Push guide](#8-push-guide)

> All endpoints below are relative to the region base URL from the `ZMetaData` provider
> (`Provider.of<ZMetaData>(context).baseUrl`), unless a full URL is given.

---

## 1. Combo orders (two stores, one driver)

A customer can order from **two stores in one order**. One driver picks up at the farther store first, then the nearer store, then delivers to the customer.

### Flow

```
Cart Screen
  └─▶ DeliveryScreen._addToComboCart()
        │  POST /api/user/combo_add_item_in_cart        → combo_id, cart ids
        └─▶ ComboCheckoutScreen
              │  Google Directions API (pick-up order, distance)
              │  GET  /api/user/get_combo_max_store_distance (too-far check)
              │  POST /api/user/combo_get_order_cart_invoice → store_a / store_b payment ids
              └─▶ KifiyaScreen (isCombo = true)
                    │  POST /api/user/combo_pay_order_payment   (Step 3)
                    └─▶ POST /api/user/combo_create_order       (Step 4, retry up to 3×)
                          └─▶ ReportScreen (receipt)
```

### How it works

- The **first store** stays in the normal `cart` key, so every single-store screen keeps working unchanged. The **second store** and the server IDs live in `combo_cart` (`ComboCart`).
- `ComboCart` keys cart IDs and payment IDs **by `store_id`**, because the server's `store_a` / `store_b` labels can swap at invoice time depending on the route.
- `ComboRoute` decides the order of pick-up: the farther store is the *origin*, the nearer one is the *waypoint*.
- If the two stores are too far apart, `ComboTooFarDialog` is shown. If the user adds a store that conflicts with the cart, `StoreConflictDialog` is shown.
- **Create-order retry:** `combo_create_order` is retried only when the response is `null` (network error or timeout), with 1 s then 2 s waits. If the server answered at all, even with `success: false`, the app stops, so an order is never created twice.
- After success, `{combo_id, order_ids, order_unique_ids, created_at}` is saved to the `combo_orders` key (max 50) so the orders screen can group them.
- Combo payment now uses the same ZOORYA-PAY method list as a normal order. The old "cash and wallet only" filter is commented out in `kifiya_screen.dart`.

### Key files

| File | Purpose |
|---|---|
| `lib/combo/services/combo_service.dart` | All `combo_*` API calls, `errorText()`, `isSessionExpired()` |
| `lib/combo/models/combo_cart.dart` | Local combo state (`combo_cart` key) |
| `lib/combo/combo_route.dart` | Pick-up order and distance |
| `lib/combo/combo_checkout_screen.dart` | Combo checkout and invoice |
| `lib/combo/widgets/` | Store sections, too-far dialog, store-conflict dialog |
| `lib/models/combo_payment_context.dart` | Data passed into `KifiyaScreen` |
| `lib/orders/models/combo_order_entry.dart` | Combo order in the orders list |

More detail: [`COMBO_ORDER_FLOW.md`](COMBO_ORDER_FLOW.md), [`COMBO_CONCEPTUAL_ARCHITECTURE.md`](COMBO_CONCEPTUAL_ARCHITECTURE.md).

---

## 2. Payment integration

The payment screen is `lib/kifiya/kifiya_screen.dart` (`KifiyaScreen`).

It loads gateways from `POST /api/user/get_payment_gateway`. It then finds the **`ZOORYA-PAY`** gateway and shows **its methods** as tiles, instead of the old flat gateway list. CyberSource (card) and Cash are added as extra tiles when the backend marks them visible.

### Payment methods

| Method key | Screen / handler | How the user pays |
|---|---|---|
| `telebirr` | `components/telebirr_ussd.dart` (`isZooryaPay: true`) | USSD push to the phone, user enters PIN |
| `mpesa` | `zoorya_pay/zoorya_pay_mpesa_screen.dart` | M-PESA push to a `+251 7…` number |
| `dashen` | `zoorya_pay/zoorya_pay_ussd_screen.dart` | USSD push |
| `zemen` | `zoorya_pay/zoorya_pay_otp_screen.dart` | Account number + OTP (`/api/zooryapay/send_otp`) |
| `nib`, `ethswitch` | `_startDirectZooryaPayUssd()` in `kifiya_screen.dart` | Direct push, polled from the payment screen |
| `telebirr_qr`, `ethswitch_qr` | `zoorya_pay/zoorya_pay_qr_screen.dart` | Scan a QR code |
| `telebirr inapp` | `components/telebirr_inapp.dart` | Telebirr in-app SDK |
| `cybersource` | `cybersource/cybersource_service.dart` + `cybersource_webview.dart` | Card payment in a WebView |
| `cash` | `kifiya_screen.dart` | Pay on delivery |

### ZOORYA-PAY endpoints (`zoorya_pay/zoorya_pay_service.dart`)

| Endpoint | Use |
|---|---|
| `POST /api/zooryapay/send_otp` | Send an OTP for OTP-based banks (Zemen) |
| `POST /api/zooryapay/pay` | Start a USSD / QR / OTP payment |
| `POST /admin/check_paid_order` | Check whether the payment is paid |

CyberSource uses `POST /api/user/cybersource/pay` (returns `checkout_url` for the WebView) and `POST /api/user/cybersource/status`.

### Payment check rule (same for every method)

- Call `/admin/check_paid_order`, wait for the answer, wait **2 seconds**, then check again.
- Only **one request at a time**. Each request times out after 10 s.
- Stop after **2 minutes** (`ZooryaPayService.pollWindow`, about 60 checks).
- After 2 minutes the user sees **"We couldn't confirm your payment"** with:
  - **Resend prompt** (QR: **Get new QR code**): sends a new prompt and starts a new 2 minutes.
  - **I've paid, check again**: checks once.
- Leaving the screen, or tapping "Change" on M-PESA, stops checking immediately.
- "Is it paid" is decided in one place: `ZooryaPayService.isPaid(result)`.

### M-PESA phone field

- `+251` is fixed at the start of the field. The user types 9 digits starting with `7`.
- A typed or pasted `0`, `251` or `+251` prefix is removed automatically.
- The backend receives `07XXXXXXXX`. The waiting screen shows `+251 7XX XXX XXX`.
- The "I Have Approved" button was removed: the screen continues automatically once paid.

Full per-method before/after table: [`CHANGES.md`](CHANGES.md).

---

## 3. Create order: what changed

> ⚠️ **This is the most important change for reviewers.** Order creation **no longer follows one single path**. Before this branch, the app **always** called `/api/user/create_order` after payment succeeded. Now, for some payment methods, the **backend** creates the order and the app must **not** call `create_order`.

### Before (old flow, every method)

```
Payment succeeds
  └─▶ App: POST /admin/check_paid_order   (verify)
        └─▶ App: POST /api/user/create_order   (app creates the order)
              └─▶ ReportScreen
```

### Now (new flow): two paths

```
                     Payment succeeds
                            │
          ┌─────────────────┴──────────────────┐
          ▼                                    ▼
  PATH A: BACKEND creates order        PATH B: APP creates order (as before)
  (Telebirr USSD, M-PESA, CyberSource) (Cash, Dashen, Zemen, QR, NIB, EthSwitch, wallet)
          │                                    │
  /admin/check_paid_order (or               _boaVerify()
  /cybersource/status) returns PAID            │
  → the order already exists                POST /api/user/create_order
          │                                 (combo: combo_create_order;
  _finishBackendCreatedOrder()               courier: create order for courier;
  - clear cart, aliexpressCart,              AliExpress: aliexpress_creat_order first)
    combo_cart                                 │
  - NO call to /api/user/create_order          ▼
          │                                 ReportScreen
          ▼
     ReportScreen
```

### Who creates the order, per method

| Method | Who creates the order | Code path |
|---|---|---|
| ZOORYA-PAY **Telebirr USSD** | **Backend** (inside `/admin/check_paid_order`) | `_onZooryaTelebirrResult()` → `_finishBackendCreatedOrder()`. Controlled by `_zooryaTelebirrBackendCreatesOrder = true` |
| **M-PESA** | **Backend** (inside `/admin/check_paid_order`) | `.then` → `_finishBackendCreatedOrder()`, or `_boaVerify(skipCreateOrder: true)` if the screen was closed |
| **CyberSource** card | **Backend** (once status is `PAID`) | `_startCyberSource()` → `_finishBackendCreatedOrder()` |
| **Cash** | App | `payOrderPayment(isPaymentModeCash: true)` → `_createOrder()` / `_createCourierOrder()` / `_createAliexpressOrder()` |
| Dashen, Zemen, Telebirr QR, EthSwitch QR, NIB, EthSwitch | App | `_boaVerify()` → `create_order` |
| Wallet / other | App | `payOrderPayment()` → `create_order` |
| **Telebirr In-App** | ⚠️ **Nobody right now.** Create order is turned off for testing | Search `FOR TESTING TELEBIRR INAPP` in `kifiya_screen.dart` |

### Important details

- `_boaVerify({bool skipCreateOrder = false})` now has a `skipCreateOrder` flag. When `true` and the payment is paid, it only finishes the order the backend created. It does not call `create_order`.
- `_finishBackendCreatedOrder(response)` reads the order unique id from `order_unique_id`, `data.order_unique_id`, or `order.unique_id`. If none is there, it falls back to the order payment unique id.
- Telebirr In-App, when turned back on, uses `/api/user/create_order_for_telebirr_inapp`, not `/api/user/create_order`.
- To go back to the old app-side create for Telebirr USSD, set `_zooryaTelebirrBackendCreatesOrder = false`. M-PESA has the old code commented out next to the new code (`// TEST: M-PESA order is created by the backend …`).
- **Cash was restored.** A test change had skipped order creation for cash. Cash now creates the order exactly as before.

---

## 4. Odoo branch stock availability and order status

### Stock check before checkout

ZMall branches (Ayat, Mexico, …) keep their stock in Odoo POS. Before checkout, the cart asks Odoo whether the items are in stock at that branch. If they are not, checkout is blocked.

```
Cart → tap Checkout
  ├─ storeId → branch slug via kZmallBranchSlugs (e.g. "ayat", "mexico")
  ├─ POST http://196.191.117.85:9070/zmall_order/<branch_slug>
  │    header X-Odoo-Database: zmall_odoo
  │    body   {"products":[{"product_id":101,"quantity":3}]}
  └─ can_checkout == true  → continue (StockLeftNotification if stock is low)
     can_checkout == false → block, show StockAvailabilityDialog
```

Response shape:

```json
{
  "success": true,
  "branch": "ayat",
  "can_checkout": false,
  "products": [
    { "product_id": 101, "quantity": 3, "available": false, "forecasted_quantity": 1, "error": null }
  ]
}
```

Stores **not** listed in `kZmallBranchSlugs` skip the check.

### Order status for Odoo stores (no driver)

Odoo/POS stores have no driver. For **Odoo stores only**, the app always shows the real `order_status` (for example "Preparing order") and never the driver `delivery_status`. Other stores are unchanged. Every change is behind `isOdooStoreByName(...)`.

| Screen | File |
|---|---|
| Order history | `lib/orders/components/orders_history.dart` |
| Combo order entry | `lib/orders/models/combo_order_entry.dart` |
| Order detail (no driver timeline) | `lib/orders/components/order_detail.dart` |

### Key files

| File | Purpose |
|---|---|
| `lib/services/zmall_availability_service.dart` | Odoo HTTP call, timeout, parsing |
| `lib/utils/constants.dart` | `kZmallOdooBaseUrl`, `kZmallOdooDatabase`, `kZmallBranchSlugs`, `zmallBranchSlugForStore()`, `isOdooStoreByName()` |
| `lib/cart/components/body.dart` | Runs the check and blocks checkout |
| `lib/widgets/stock_availability_dialog.dart` | Out-of-stock dialog and low-stock banner |

More detail: [`ZMALL_ODOO_AVAILABILITY.md`](ZMALL_ODOO_AVAILABILITY.md), [`docs/zmall-odoo-integration-guide.md`](docs/zmall-odoo-integration-guide.md).

---

## 5. MCP / ChatGPT cart

A user builds a cart outside the app, in ChatGPT through the ZMall MCP server. ChatGPT gives the user a link, and the link opens the app with that cart ready to check out.

### Flow

```
ChatGPT (ZMall MCP tools) builds a cart → returns a link
  e.g. https://testapp.zmall.et/go/cart/{cartId}
       https://…/ai-cart/{cartId}
       zmall://cart/{cartId}
       or FCM push with type: ai_cart
        │
        ▼
main.dart (app_links) parses cartId → McpCartScreen (/mcp-cart)
        │
        ├─ Not logged in → save pending_ai_cart, go to Login.
        │                  After login, resume McpCartScreen with the saved cartId.
        │
        └─ Logged in → GET /api/ai/cart/{cartId}
              ├─ Another store already in the cart → replace / keep dialog
              ├─ Save to local `cart` → open CartScreen
              └─ Auto-checkout (when target asks for it):
                   POST /api/user/add_item_in_cart_new
                   POST /api/store/get_vehicle_list
                   Google Distance Matrix (Haversine fallback)
                   POST /api/user/get_order_cart_invoice
                   → KifiyaScreen (payment, see sections 2 and 3)
```

Deep-link hosts are registered in `android/app/src/main/AndroidManifest.xml` (including `testapp.zmall.et` and `testbackend.zmall.et`). After changing the manifest or `Info.plist`, reinstall the app; hot reload does not pick it up.

### Key files

- `lib/mcp/mcp_cart_screen.dart`: cart bridge and auto-checkout
- `lib/main.dart`: deep-link parsing (`/ai-cart/`, `/go/cart/`, `?next=…`) and FCM `ai_cart`
- `lib/login/login_screen.dart`: resumes `pending_ai_cart` after login

More detail: [`zmall_files/docs/MCP_CART_FLOW_SUMMARY.md`](zmall_files/docs/MCP_CART_FLOW_SUMMARY.md), [`zmall_files/cart_mcp/MCP_CART_FLOW.md`](zmall_files/cart_mcp/MCP_CART_FLOW.md).

---

## 6. AI support chatbot

An in-app AI assistant (`lib/help/support_chat/`). It can track orders, answer questions about payments, refunds and store hours, show nearby stores and menus, and add products to a basket and check out from inside the chat.

### Flow

```
SupportChatScreen (typed message or quick reply)
  └─▶ ChatService.sendMessage(message, session_id, order_id, user_location, system_prompt)
        POST {baseUrl}/chat_test        (3 retries on timeout)
        └─▶ normalizeChatResponse()  → text / store carousel / product cards
              └─▶ Add to basket (chat_basket.dart)
                    └─▶ chat_checkout_service.dart:
                          add_item_in_cart_new → get_vehicle_list → distance
                          → get_order_cart_invoice → KifiyaScreen
```

- **Endpoint change (uncommitted in this branch):** the chat URL moved from `/api/chatbot/chat_web` to **`/chat_test`** at the server root, because `/api/chatbot/chat_test` returns 404.
- Active order context comes from `POST /api/user/get_orders`, so "Where is my order?" works without asking for an order id.
- Item prices with options or specifications are calculated in `service/chat_spec_pricing.dart`.
- Chat history is saved per user (`support_chat_messages_<userId>`) and cleared after 24 hours.

### Key files

| File | Purpose |
|---|---|
| `support_chat_screen.dart` | Screen, persistence, quick replies |
| `service/chat_service.dart` | API call and retries |
| `service/chat_response_parser.dart` | Turns replies into stores / products |
| `service/chat_basket.dart`, `service/chat_checkout_service.dart` | Basket and checkout from chat |
| `components/` | Bubbles, store carousel, menu sheet, product sheet, address picker |

More detail: [`lib/help/support_chat/README.md`](lib/help/support_chat/README.md), [`lib/help/support_chat/CHATBOT_TO_PAYMENT_FLOW.md`](lib/help/support_chat/CHATBOT_TO_PAYMENT_FLOW.md).

---

## 7. Before release: open items

1. **Telebirr In-App creates no order.** Order creation is commented out for testing in `kifiya_screen.dart` (search `FOR TESTING TELEBIRR INAPP`). Turn it back on before release, or users will pay and get no order.
2. **Possible double order.** Telebirr USSD, M-PESA and CyberSource rely on the backend creating the order. For Dashen, Zemen, QR, NIB and EthSwitch the app creates it. If the backend also creates orders for those methods in `check_paid_order`, the order is created twice. Confirm with the backend team.
3. **Backend-created orders are marked `TEST`** in code comments (Telebirr USSD, M-PESA). Confirm this is the final design, then remove the `TEST` comments.
4. **Odoo stores are detected by store name / id.** A new Odoo branch must be added to `kZmallBranchSlugs` in `lib/utils/constants.dart`.
5. **Odoo base URL is plain HTTP on an IP** (`http://196.191.117.85:9070`). Check that release builds allow it (Android network security config / iOS ATS).
6. **Stray character in `chat_service.dart`:** one debug separator line has an `i` in it (`═══…i══`). This is harmless, but clean it up.
7. **Not tested on a device with real money** for the new payment checks (see `CHANGES.md`).

---

## 8. Push guide

### Suggested commit message

```text
feat: combo orders, ZOORYA-PAY payments, backend-created orders, Odoo stock, MCP cart, AI chat

- Combo: two-store one-driver orders via combo_* endpoints, create-order retry only on null response
- Payments: ZOORYA-PAY method tiles (Telebirr USSD, M-PESA, Dashen, Zemen OTP, NIB, EthSwitch, QR),
  CyberSource card, 2-minute payment check with Resend / I've paid
- Create order: backend creates the order for Telebirr USSD, M-PESA and CyberSource
  (_finishBackendCreatedOrder, no /api/user/create_order); app still creates it for cash and others
- Odoo: branch stock check before checkout; Odoo stores show order_status, no driver timeline
- MCP/ChatGPT: deep-link cart bridge with login resume and auto-checkout
- AI chatbot: switch endpoint to /chat_test, in-chat basket and checkout
```

### Commands

```bash
# 1. Review what changed
git status
git diff

# 2. Check the code
flutter analyze

# 3. Stage and commit
git add lib/ GIT_PUSH_README.md README.md CHANGES.md
git commit -m "feat: combo, ZOORYA-PAY payments, backend-created orders, Odoo stock, MCP cart, AI chat"

# 4. Push this branch
git push origin mpessa_Create_order

# 5. Open a pull request into main
gh pr create --base main --head mpessa_Create_order
```
