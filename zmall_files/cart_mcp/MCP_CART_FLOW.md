# ZMall MCP / AI Cart — How It Works & Known Issues

## Overview

The MCP (Model Context Protocol) cart feature lets an AI assistant (ChatGPT or similar) build a shopping cart on behalf of the user. The backend creates a cart, stores it server-side, and sends the user a deeplink. The Flutter app intercepts that link and populates the local cart automatically.

---

## Flow Diagram

```
ChatGPT / AI
     │
     │  1. AI builds cart items, calls backend
     ▼
Backend (testapp.zmall.et)
     │  POST /api/ai/cart  →  returns { cart_id: "abc123" }
     │
     │  2. Backend sends URL to user (SMS / chat / web)
     │     https://zmall-web.vercel.app/ai-cart/abc123
     │     or  zmall://cart/abc123
     ▼
User taps the link
     │
     │  3. Android intercepts via intent-filter
     │     → opens ZMall app → main.dart _handleDeepLink()
     ▼
McpCartScreen (lib/mcp/mcp_cart_screen.dart)
     │
     ├─ Not logged in?
     │     │  Save { cart_id, saved_at } to local storage as "pending_ai_cart"
     │     │  Redirect → LoginScreen → OtpScreen
     │     │  After successful login → _resumePendingAiCartIfAny()
     │     │  If pending cart age < 2 hours → navigate to McpCartScreen
     │     └─ Else discard pending cart
     │
     └─ Logged in?
           │  GET /api/ai/cart/{cartId}  (15s timeout, no auth header)
           │
           ├─ 404 / success:false  → Show "Cart Unavailable" error screen
           │
           └─ success:true
                 │  Conflict? (existing cart from different store)
                 │     → showConflictDialog → user picks Keep / Replace
                 │
                 └─ Write cart to local storage ("cart" key)
                       → Navigate to CartScreen
```

---

## Supported Deeplink Formats

| Format | Example | Handled |
|---|---|---|
| Custom scheme | `zmall://cart/{cartId}` | ✅ |
| HTTPS (test server) | `https://testapp.zmall.et/ai-cart/{cartId}` | ✅ |
| HTTPS (Vercel web) | `https://zmall-web.vercel.app/ai-cart/{cartId}` | ✅ (added May 2026) |

---

## Key Files

| File | Role |
|---|---|
| `lib/main.dart` | Listens for incoming deeplinks via `app_links`, calls `_handleDeepLink()` |
| `lib/mcp/mcp_cart_screen.dart` | Fetches cart from backend, writes to local storage, navigates |
| `lib/login/login_screen.dart` | Saves pending cart before redirecting unauthenticated users |
| `lib/login/otp_screen.dart` | Resumes pending cart after OTP login completes |
| `android/app/src/main/AndroidManifest.xml` | Declares intent-filters for all supported deeplink hosts |

---

## Backend API

```
GET https://testapp.zmall.et/api/ai/cart/{cartId}

Response (success):
{
  "success": true,
  "store_id": "...",
  "store_name": "...",
  "store_location": [lat, lng],
  "items": [
    { "item_id": "...", "name": "...", "price": 99.0, "quantity": 1, "image_url": "..." }
  ]
}

Response (error):
{
  "success": false,
  "error": "Cart link has expired"
}
```

---

## Known Issues

### 1. Cart Expiration — No Expiry Time Shown to User
**Problem:** The backend expires cart links (confirmed: `{"success": false, "error": "Cart link has expired"}`). The app shows a generic "Cart Unavailable" screen with no indication of when it expired or how to get a new link.  
**Impact:** User is stuck — the only option is "Browse Stores" which loses the AI-built cart entirely.  
**Fix:** Show when the link was generated and add a "Request New Cart" button, or display the backend error message clearly.

---

### 2. No Retry on McpCartScreen Error
**Problem:** `McpCartScreen` error state only has a "Browse Stores" button. If the failure was a network timeout, the user cannot retry without going back and tapping the link again.  
**Fix:** Add a "Try Again" button that calls `bridgeCart()` again.

---

### 3. `autoVerify` Not Set Up for `zmall-web.vercel.app`
**Problem:** The intent-filter for `zmall-web.vercel.app` has `android:autoVerify="true"`, but `https://zmall-web.vercel.app/.well-known/assetlinks.json` does not exist. Without it, Android cannot verify domain ownership and will show a browser/app chooser instead of opening ZMall directly.  
**Fix:** Host an `assetlinks.json` at `https://zmall-web.vercel.app/.well-known/assetlinks.json`:
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.zmall.user",
    "sha256_cert_fingerprints": ["<your-release-cert-sha256>"]
  }
}]
```

---

### 4. Pending Cart 2-Hour Timeout May Be Too Short
**Problem:** In `login_screen.dart:729` and `otp_screen.dart:665`, a saved pending cart is discarded if it's older than 2 hours. If the backend cart TTL is longer than 2 hours, the app discards a still-valid cart.  
**Fix:** Align the pending cart timeout with the backend's actual cart TTL, or remove the local timeout entirely and let the backend decide.

---

### 5. `_resumePendingAiCartIfAny` Duplicated
**Problem:** The same function is copy-pasted in both `login_screen.dart:716` and `otp_screen.dart:653`. Any bug fix must be applied in two places.  
**Fix:** Extract to a shared utility or a service method in `Service`.

---

### 6. Cart API Has No Authentication Header
**Problem:** `McpCartScreen` calls `GET /api/ai/cart/{cartId}` with no auth headers. Anyone who knows the cart ID can fetch the cart contents.  
**Fix:** Pass the user's `server_token` in the request header so the backend can validate ownership.

---

### 7. Deeplink Dedup Window (2 seconds) Can Drop Rapid Re-triggers
**Problem:** `_shouldIgnoreDeepLink` in `main.dart:48` ignores the same URI if triggered within 2 seconds. If the user taps the same link twice quickly (or the OS delivers it twice), the second delivery is silently dropped.  
**Impact:** Minor — but could confuse users who tap a link and nothing happens.  
**Fix:** Only dedup identical URIs that arrive within the same app lifecycle event, not a fixed time window.

---

### 8. OTP Screen Login Bug — Uses Wrong Variable
**Problem:** In `otp_screen.dart:684`, `_login()` checks `if (this.responseData != null)` but `responseData` is a `setState` side-effect of `login()`. If the widget rebuilds before the `setState` completes, the check can evaluate against stale data even though `loginResponseData` is the correct fresh value.  
**Fix:** Use `loginResponseData` directly instead of `this.responseData` for the null check.

---

## Testing the Flow

```bash
# Trigger with custom scheme (always works, no domain verification needed)
adb shell am start -a android.intent.action.VIEW \
  -d "zmall://cart/{cartId}" com.zmall.user

# Trigger with Vercel HTTPS link
adb shell am start -a android.intent.action.VIEW \
  -d "https://zmall-web.vercel.app/ai-cart/{cartId}" com.zmall.user

# Watch deeplink logs
adb logcat | grep -E "DEEP LINK|McpCart"
```

---

## Release Info

- APK: `build/app/outputs/flutter-apk/app-release.apk` (79 MB, signed)
- Keystore: `android/app/zmall-release.jks`
- Key alias: `zmall`
- Backend: `https://testapp.zmall.et`
