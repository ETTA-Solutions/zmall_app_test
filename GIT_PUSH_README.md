# ZMall Feature Release & Git Push Documentation

This document summarizes the core features, architectural implementations, use cases, and payload updates included in this branch (`ai_chatbot_branch`) for review and git push.

---

## Table of Contents
1. [Branch Overview](#1-branch-overview)
2. [Feature 1: Odoo Branch Stock Availability](#2-feature-1-odoo-branch-stock-availability)
   - [Use Case & Problem Statement](#use-case--problem-statement)
   - [How It Was Implemented](#how-it-was-implemented)
   - [Endpoint & Data Contract](#endpoint--data-contract)
   - [Cart & Checkout UI Flow](#cart--checkout-ui-flow)
3. [Feature 2: AI Support Chatbot Integration](#3-feature-2-ai-support-chatbot-integration)
   - [Use Case & Overview](#use-case--overview)
   - [Architecture & Endpoints](#architecture--endpoints)
   - [Context-Aware Capabilities & Cart Injection](#context-aware-capabilities--cart-injection)
   - [User Isolation & 24h Persistence](#user-isolation--24h-persistence)
4. [Feature 3: Telebirr USSD Payment Gateway Update](#4-feature-3-telebirr-ussd-payment-gateway-update)
   - [Use Case & Gateway Role](#use-case--gateway-role)
   - [Payload Update (`channel: "zmalltest"`)](#payload-update-channel-zmalltest)
   - [End-to-End Payment Lifecycle](#end-to-end-payment-lifecycle)
5. [Git Commit Summary & Push Guide](#5-git-commit-summary--push-guide)

---

## 1. Branch Overview

- **Branch:** `ai_chatbot_branch`
- **Key Modules Impacted:**
  - `lib/services/zmall_availability_service.dart` (Odoo inventory service)
  - `lib/cart/components/body.dart` (Cart inventory verification & checkout guard)
  - `lib/widgets/stock_availability_dialog.dart` (Stock alert modals & banners)
  - `lib/utils/constants.dart` (Branch slug configurations & base URLs)
  - `lib/help/support_chat/` (End-to-end AI support chatbot feature)
  - `lib/kifiya/components/telebirr_ussd.dart` (Telebirr USSD push payload configuration)

---

## 2. Feature 1: Odoo Branch Stock Availability

### Use Case & Problem Statement
* **The Problem:** ZMall operates multiple physical branches and grocery stores across Addis Ababa (e.g., Ayat, Mexico, Bole). Each branch manages its own dedicated warehouse and stock levels in Odoo POS. Previously, the mobile app only checked if the store was open, not whether items were physically in stock at that branch. As a result, customers could order items that were already sold out, leading to failed orders, customer dissatisfaction, and manual refund operations.
* **The Solution:** A pre-checkout stock verification system. Before navigating to the checkout or delivery screens, the app checks real-time forecasted inventory against the branch warehouse on the Odoo server. If items are out of stock or requested quantities exceed available inventory, checkout is blocked and the customer is warned immediately.

### How It Was Implemented

```
User opens Cart / Taps "Checkout"
       │
       ▼
CartScreen (`lib/cart/components/body.dart`)
       │
       ├─► 1. Store Mapping: Read `cart.storeId` -> resolve `branchSlug` via `kZmallBranchSlugs`
       │      (e.g., "6a6b0698..." -> "ayat", "6a69539f..." -> "mexico")
       │
       ├─► 2. Build Payload: Extract `item.odooProductId` and `item.quantity`
       │
       ├─► 3. Dispatch Request: `ZmallAvailabilityService.check()`
       │      POST http://196.191.117.85:9070/zmall_order/<branch_slug>
       │
       ├─► 4. Evaluate Response:
       │      ├── can_checkout == true ──► Allow Checkout / Navigate to DeliveryScreen
       │      │                            (Show `StockLeftNotification` banner if stock is low)
       │      │
       │      └── can_checkout == false ─► Block Checkout (`_checkoutBlocked = true`)
       │                                   Display `StockAvailabilityDialog` with out-of-stock items
```

### Endpoint & Data Contract

* **Endpoint:** `POST http://196.191.117.85:9070/zmall_order/<branch_slug>`
* **Headers:** `Content-Type: application/json`
* **Request Body:**
```json
{
  "products": [
    { "product_id": 101, "quantity": 3 },
    { "product_id": 205, "quantity": 1 }
  ]
}
```
* **Response:**
```json
{
  "success": true,
  "branch": "ayat",
  "can_checkout": false,
  "products": [
    {
      "product_id": 101,
      "quantity": 3,
      "available": false,
      "forecasted_quantity": 1,
      "error": null
    }
  ]
}
```

### Key Files
- `lib/services/zmall_availability_service.dart`: Streamlined HTTP client handling the Odoo endpoint call, timeout safety, and model parsing.
- `lib/utils/constants.dart`: Stores `kZmallOdooBaseUrl`, `kZmallBranchSlugs`, and branch slug helper functions.
- `lib/cart/components/body.dart`: Triggers `_checkAvailability()`, manages checkout lock state, and coordinates UI feedback.
- `lib/widgets/stock_availability_dialog.dart`: Renders out-of-stock item lists and low stock warning banners.

---

## 3. Feature 2: AI Support Chatbot Integration

### Use Case & Overview
The ZMall Support Chatbot provides users with a real-time, context-aware AI assistant accessible directly within the app (`lib/help/support_chat/`). It enables users to:
1. Track active deliveries with real order status data.
2. Inquire about payment methods, store operating hours, and refund policies.
3. Discover nearby stores and browse menus dynamically inside chat.
4. Add recommended products directly to their active shopping cart with one tap.

```
       ┌─────────────────────────────────────────────────────────┐
       │                ZMall Support Chat Screen                │
       └─────────────────────────────────────────────────────────┘
                                   │
                ┌──────────────────┴──────────────────┐
                ▼                                     ▼
        User Typed Query                     Quick Reply Taps
                │                                     │
                └──────────────────┬──────────────────┘
                                   │
                                   ▼
             `ChatService.sendMessage(..., session_id, context)`
                                   │
                                   ▼
                       POST /chat_test (Backend API)
                                   │
       ┌───────────────────────────┴───────────────────────────┐
       ▼                                                       ▼
  Text Response                                     Structured Response
  - Instant advice                                  - Store Carousels
  - Live order tracking                             - Product Cards (Add to Cart)
```

### Architecture & Endpoints

1. **Active Order Lookup (`getOrders`):**
   - **Endpoint:** `POST /api/user/get_orders`
   - Automatically retrieves the user's latest active order so the AI can answer "Where is my food?" or "Track my order" without asking for the order ID.

2. **Chat API (`sendMessage`):**
   - **Endpoint:** `POST /chat_test`
   - **Payload Includes:**
     - `message`: User input text
     - `session_id`: Unique conversation session UUID
     - `order_id`: Current active order ID for context
     - `user_location`: User's coordinates `[lat, lng]` for store proximity
     - `system_prompt`: Structured guidelines instructing the model to format stores and products for the Flutter parser.

3. **In-Chat Cart Integration:**
   - Products returned by the AI are rendered in rich action cards (`chat_bubble.dart`).
   - Tapping "Add to Cart" directly calls `addMockProductsToCart(...)` to sync items into the local cart state (`cart.dart`).

4. **Persistence & Account Isolation:**
   - Chat history is stored locally in `SharedPreferences` partitioned by `userId`: `support_chat_messages_<userId>`.
   - Automatically expires after 24 hours to ensure fresh session state and prevent stale order information.

---

## 4. Feature 3: Telebirr USSD Payment Gateway Update

### Use Case & Gateway Role
ZMall provides seamless in-app mobile payments via Ethio Telecom's **Telebirr USSD Push** service. When paying with Telebirr:
1. The app requests a Network-Initiated USSD Push via the Odoo payment middleware (`http://196.189.44.60:8069/telebirr/ussd/send_sms`).
2. Ethio Telecom flashes a USSD prompt directly onto the user's phone ("Pay ETB X to ZMall? Enter PIN").
3. The customer types their PIN on their phone dialer.
4. The app asynchronously polls `/admin/check_paid_order` to verify payment before creating the order.

### Payload Update (`channel: "zmalltest"`)
In `lib/kifiya/components/telebirr_ussd.dart`, the request payload dispatched to the Odoo gateway was updated to include the routing parameter `"channel": "zmalltest"`.

```dart
// lib/kifiya/components/telebirr_ussd.dart
Map data = {
  "traceNo": widget.traceNo,
  "amount": widget.hisab,
  "phone": "251${widget.phone}",
  "payerId": "22",
  "appId": "1234",
  "apiKey": "90e503b019a811ef9bc8005056a4ed36",
  "zmall": true,
  "channel": "zmalltest",  // <-- ADDED: Gateway channel identifier
};
```

### Why `channel: "zmalltest"` Was Added:
- **Multi-Tenant Gateway Routing:** The Odoo payment gateway handles transactions for multiple platforms and testing environments.
- **Merchant Channel Segregation:** Specifying `"channel": "zmalltest"` tells the gateway aggregator exactly which Ethio Telecom merchant account and notification webhook channel to route the request through.
- **Accurate Callback Reconciliation:** Ensures Ethio Telecom IPN payment notifications are mapped to the correct test environment database, preventing dropped or unverified orders.

---

## 5. Git Commit Summary & Push Guide

### Suggested Commit Message

```text
feat: integrate odoo branch availability, ai chatbot, and telebirr channel payload

- Odoo Availability:
  - Add real-time forecasted inventory check via POST /zmall_order/<branch_slug>
  - Map storeId to Odoo POS branch slugs (Ayat, Mexico, etc.)
  - Block checkout and warn users when branch stock is insufficient
  - Add StockAvailabilityDialog and StockLeftNotification widgets

- AI Support Chatbot:
  - Connect ChatService to POST /chat_test with user location and active order context
  - Support store carousel browsing and direct add-to-cart from chat
  - Enable 24-hour user-isolated local chat history persistence
  - Remove dead mock responses and obsolete prototype screens (-4000 lines)

- Telebirr USSD Payment:
  - Update payment payload in telebirr_ussd.dart with channel: "zmalltest"
  - Maintain idempotent trace numbers and async polling verification
```

### Git Commands to Push

```bash
# 1. Review status
git status

# 2. Stage changes
git add lib/ README.md GIT_PUSH_README.md

# 3. Commit
git commit -m "feat: integrate odoo branch availability, ai chatbot, and telebirr channel payload"

# 4. Push to remote branch
git push origin ai_chatbot_branch
```
