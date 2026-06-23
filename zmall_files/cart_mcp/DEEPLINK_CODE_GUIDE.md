# ZMall Deeplink — Complete Code Guide

This document explains every line of deeplink-related code in the app.
After reading this you will understand exactly how a link becomes a cart on screen.

---

## Table of Contents

1. [What is a Deeplink?](#1-what-is-a-deeplink)
2. [Supported Link Formats](#2-supported-link-formats)
3. [Android Manifest — Declaring the Links](#3-android-manifest--declaring-the-links)
4. [main.dart — Catching the Link](#4-maindart--catching-the-link)
5. [McpCartScreen — Fetching the Cart](#5-mcpcartscreen--fetching-the-cart)
6. [Login Flow — When User is Not Logged In](#6-login-flow--when-user-is-not-logged-in)
7. [FCM Push Notification Path](#7-fcm-push-notification-path)
8. [Service.consumePendingAiCart — Shared Utility](#8-serviceconsumependingaicart--shared-utility)
9. [Complete Flow in One Diagram](#9-complete-flow-in-one-diagram)
10. [How to Test](#10-how-to-test)

---

## 1. What is a Deeplink?

A deeplink is a URL that opens a specific screen inside your app instead of a website.

```
Normal link  →  opens browser
Deeplink     →  opens ZMall app at a specific screen
```

There are two types used in ZMall:

| Type | Example | When to use |
|---|---|---|
| Custom scheme | `zmall://cart/abc123` | Direct app-to-app, always works |
| HTTPS | `https://zmall-web.vercel.app/ai-cart/abc123` | Shareable web links |

---

## 2. Supported Link Formats

```
zmall://cart/{cartId}
       ──┬──  ──┬──  ────┬────
         │      │        │
      scheme  host    cartId (the ID of the cart on the backend)

https://zmall-web.vercel.app/ai-cart/{cartId}
─────┬──  ──────────┬──────  ───┬───  ────┬────
     │              │           │          │
  scheme          host       path      cartId

https://testapp.zmall.et/ai-cart/{cartId}
         (same structure, different host)
```

The **cartId** is the only piece of data the app needs. Everything else
(store name, items, prices) is fetched from the backend using that ID.

---

## 3. Android Manifest — Declaring the Links

**File:** `android/app/src/main/AndroidManifest.xml`

Android needs to know which URLs your app should intercept.
This is done with `<intent-filter>` blocks.

```xml
<!-- ① Custom scheme: zmall://cart/{cartId} -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="zmall" android:host="cart" />
</intent-filter>
```

**Line by line:**
- `action VIEW` — this filter handles URL-open events
- `category DEFAULT` — can handle intents without an explicit target
- `category BROWSABLE` — can be triggered from a browser or SMS
- `data scheme="zmall" host="cart"` — match URLs that look like `zmall://cart/...`

```xml
<!-- ② HTTPS from Vercel web app -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https"
          android:host="zmall-web.vercel.app"
          android:pathPrefix="/ai-cart" />
</intent-filter>
```

**What `android:autoVerify="true"` means:**
Android will try to verify that you own `zmall-web.vercel.app` by checking:
`https://zmall-web.vercel.app/.well-known/assetlinks.json`
If verified, Android opens your app directly with NO chooser dialog.
If NOT verified, Android shows a "Open with..." popup.

```xml
<!-- ③ HTTPS from test server -->
<intent-filter android:autoVerify="true">
    <data android:scheme="https"
          android:host="testapp.zmall.et"
          android:pathPrefix="/ai-cart" />
</intent-filter>
```

Also enable Flutter's built-in deeplink handling:
```xml
<meta-data android:name="flutter_deeplinking_enabled" android:value="true" />
```

---

## 4. main.dart — Catching the Link

**File:** `lib/main.dart`

This is where the app first receives and processes every deeplink.

### 4.1 The Navigator Key

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
```

**What it is:** A global reference to the app's Navigator (the thing that
controls which screen is shown). Without this, you cannot navigate from
outside a widget (e.g., from the deeplink handler which lives in `_MyAppState`).

**Where it's used:**
```dart
// In MaterialApp
MaterialApp(
  navigatorKey: navigatorKey,  // ← plugs the key in
  ...
)

// In deeplink handler
navigatorKey.currentState?.pushNamed('/mcp-cart', arguments: {...});
//           ─────────────  navigate from anywhere in the app
```

---

### 4.2 The AppLinks Instance

```dart
final AppLinks appLinks = AppLinks();
```

`app_links` is a Flutter package that listens for incoming URLs.
It works on both cold start (app was closed) and warm start (app was open).

---

### 4.3 Duplicate Prevention

```dart
String? _lastHandledDeepLink;
DateTime? _lastHandledDeepLinkAt;

bool _shouldIgnoreDeepLink(Uri uri) {
  final now = DateTime.now();
  final uriText = uri.toString();

  if (_lastHandledDeepLink == uriText &&
      _lastHandledDeepLinkAt != null &&
      now.difference(_lastHandledDeepLinkAt!) < const Duration(seconds: 2)) {
    return true;  // ← same link arrived within 2 seconds, ignore it
  }

  _lastHandledDeepLink = uriText;   // ← remember this link
  _lastHandledDeepLinkAt = now;     // ← remember when it arrived
  return false;
}
```

**Why this exists:** Android sometimes delivers the same deeplink twice
(once from `getInitialLink` and once from `uriLinkStream`). Without this
check, the app would navigate to `McpCartScreen` twice, stacking two copies.

---

### 4.4 The Main Handler

```dart
void _handleDeepLink(Uri uri) {
  if (_shouldIgnoreDeepLink(uri)) return;  // skip duplicates

  String? cartId;

  // Pattern 1: zmall://cart/{cartId}
  if (uri.scheme == 'zmall' && uri.host == 'cart') {
    if (uri.pathSegments.isNotEmpty) {
      cartId = uri.pathSegments.first;
      //                        ─────
      //  zmall://cart/abc123
      //                └── pathSegments = ['abc123']
      //                    .first = 'abc123'
    }
  }

  // Pattern 2: https://.../ai-cart/{cartId}
  else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.pathSegments.length >= 2 &&
      uri.pathSegments[0] == 'ai-cart') {
    cartId = uri.pathSegments[1];
    //  https://zmall-web.vercel.app/ai-cart/abc123
    //                               pathSegments[0]='ai-cart'
    //                                       pathSegments[1]='abc123'
  }

  if (cartId != null && cartId.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      //  ↑ Wait until the current frame finishes drawing before navigating.
      //    Navigating mid-frame causes errors.
      if (!mounted) return;
      navigatorKey.currentState?.pushNamed(
        McpCartScreen.routeName,       // '/mcp-cart'
        arguments: {'cartId': cartId}, // pass cartId to the screen
      );
    });
  }
}
```

---

### 4.5 Cold Start vs Warm Start

```dart
@override
void initState() {
  super.initState();

  // COLD START: app was closed when link was tapped
  // getInitialLink() returns the URL that launched the app
  appLinks.getInitialLink().then((uri) {
    if (uri != null) {
      _handleDeepLink(uri);
    }
  });

  // WARM START: app was already open when link was tapped
  // uriLinkStream fires every time a new link arrives
  _deepLinkSub = appLinks.uriLinkStream.listen(_handleDeepLink);
}
```

**Visual difference:**

```
Cold start:
  User taps link → Android launches app → getInitialLink() returns link → handle it

Warm start:
  User taps link → Android brings app to foreground → uriLinkStream fires → handle it
```

---

## 5. McpCartScreen — Fetching the Cart

**File:** `lib/mcp/mcp_cart_screen.dart`

This screen receives the `cartId` and does all the work of fetching
and populating the cart.

### 5.1 Screen Setup

```dart
class McpCartScreen extends StatefulWidget {
  static const String routeName = '/mcp-cart';  // the route name used in navigation
  final String cartId;                           // received from deeplink handler

  const McpCartScreen({super.key, required this.cartId});
}
```

```dart
class _McpCartScreenState extends State<McpCartScreen> {
  String statusText = 'Preparing your order...'; // shown on loading screen
  String? error;        // if not null, shows error screen instead of loading
  bool _didNavigate = false; // prevents navigating away twice
```

---

### 5.2 bridgeCart() — The Main Function

Called automatically when the screen opens (`initState → bridgeCart()`).

```dart
Future<void> bridgeCart() async {
  // ── Step 1: Check if user is logged in ──────────────────────────────
  final userRaw = await Service.read('user');
  //              reads the saved user data from local storage

  if (userRaw == null) {
    // Not logged in — save the cart ID for after login
    await Service.save('pending_ai_cart', {
      'cart_id': widget.cartId,
      'saved_at': DateTime.now().millisecondsSinceEpoch,
      //          ↑ timestamp so we can expire it later (2 hour limit)
    });
    _replaceRoute(LoginScreen.routeName); // go to login
    return;
  }

  // ── Step 2: Fetch cart from backend ─────────────────────────────────
  final uri = Uri.parse('$BASE_URL/api/ai/cart/${widget.cartId}');
  final response = await http.get(uri, headers: {
    'server_token': user['user']['server_token'],  // auth: who is asking
    'user_id': user['user']['_id'],               // auth: which user
  }).timeout(const Duration(seconds: 15));
  //          ↑ give up after 15 seconds

  final data = jsonDecode(response.body);

  // ── Step 3: Handle failure ───────────────────────────────────────────
  if (response.statusCode == 404 || data['success'] != true) {
    setState(() {
      error = data['error'] ?? 'Cart not found or expired.';
      //      ↑ show backend's error message e.g. "Cart link has expired"
    });
    return;
  }

  // ── Step 4: Extract data from response ──────────────────────────────
  final storeId = data['store_id'];
  final storeName = data['store_name'];
  final storeLocation = data['store_location']; // [lat, lng] array

  final items = (data['items'] as List).map((i) => {
    '_id': i['item_id'],
    'item_name': i['name'],
    'price': (i['price'] as num).toDouble(),
    'quantity': i['quantity'],
    'specification': [],
    'note_for_item': '',
    'image_url': i['image_url'] ?? '',
  }).toList();

  // ── Step 5: Check for existing cart conflict ──────────────────────────
  final existingCartRaw = await Service.read('cart');
  if (existingCartRaw != null) {
    // User already has items from a different store
    if (existingStoreId != storeId && existingItems.isNotEmpty) {
      final replace = await showConflictDialog(...);
      if (!replace) {
        _replaceRoute(CartScreen.routeName); // keep old cart, go to it
        return;
      }
      // if replace == true → fall through and overwrite
    }
  }

  // ── Step 6: Save cart to local storage ───────────────────────────────
  await commitCart(user, storeId, storeName, items, storeLocation);
}
```

---

### 5.3 commitCart() — Writing to Local Storage

```dart
Future<void> commitCart({...}) async {

  // Convert [lat, lng] array → {lat: x, long: y} map
  // because the cart model expects a map, not a list
  Map<String, dynamic> storeLocationMap;
  if (storeLocation is List && storeLocation.length >= 2) {
    storeLocationMap = {
      'lat': storeLocation[0],   // index 0 = latitude
      'long': storeLocation[1],  // index 1 = longitude
    };
  }

  // Build the cart object in the exact format CartScreen expects
  final cartData = {
    'user_id': user['user']['_id'],
    'server_token': user['user']['server_token'],
    'store_id': storeId,
    'store_name': storeName,
    'items': items,
    'destination_address': {'name': '', 'lat': 0.0, 'long': 0.0, 'note': ''},
    'store_location': storeLocationMap,
    'is_schedule': false,
    // ... other required fields with defaults
  };

  await Service.save('cart', cartData);  // write to shared preferences

  // Verify the save actually worked before navigating
  final savedCart = await Service.read('cart');
  final hasStoreId = savedCart['store_id']?.isNotEmpty ?? false;
  final hasItems = savedCart['items'] is List;

  if (!hasStoreId || !hasItems) {
    setState(() { error = 'Cart verification failed. Please try again.'; });
    return;
  }

  _replaceRoute(CartScreen.routeName);  // ✅ success — open cart screen
}
```

---

### 5.4 _replaceRoute() — Safe Navigation

```dart
void _replaceRoute(String routeName) {
  if (_didNavigate || !mounted) return;
  //   ↑ prevent double navigation (important — bridgeCart is async,
  //     so it could theoretically be called twice)
  _didNavigate = true;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Wait for current frame to finish, then navigate
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, routeName);
    //        ↑ "replace" means pressing Back won't return to this loading screen
  });
}
```

---

### 5.5 The Two UI States

```dart
@override
Widget build(BuildContext context) {

  // ── ERROR STATE ──────────────────────────────────────────────────────
  if (error != null) {
    return Scaffold(
      body: Column(children: [
        Icon(Icons.close, color: Colors.red),
        Text('Cart Unavailable'),
        Text(error!),                        // e.g. "Cart link has expired"
        ElevatedButton(
          onPressed: () {
            setState(() => error = null);    // clear error
            bridgeCart();                    // try again
          },
          child: Text('Try Again'),
        ),
        TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
          child: Text('Browse Stores'),
        ),
      ]),
    );
  }

  // ── LOADING STATE ─────────────────────────────────────────────────────
  return Scaffold(
    body: Column(children: [
      CircularProgressIndicator(),
      Text(statusText),   // "Preparing your order..." → "Fetching your cart..."
                          //  → "Setting up your cart..."
      Text('AI Cart Bridge'),
    ]),
  );
}
```

---

## 6. Login Flow — When User is Not Logged In

When `bridgeCart()` finds no logged-in user, it saves the cart ID and
redirects to Login. After login, the cart is resumed automatically.

### 6.1 Saving the Pending Cart

```dart
// In McpCartScreen.bridgeCart()
await Service.save('pending_ai_cart', {
  'cart_id': widget.cartId,
  'saved_at': DateTime.now().millisecondsSinceEpoch,
  //          Unix timestamp in milliseconds
  //          Used later to expire the pending cart after 2 hours
});
```

### 6.2 Resuming After Login

The same logic runs in `login_screen.dart`, `otp_screen.dart`, and
the **Guest** button — all calling the shared Service method:

```dart
// In Service (lib/services/service.dart)
static Future<String?> consumePendingAiCart() async {
  final pendingRaw = await Service.read('pending_ai_cart');
  if (pendingRaw == null) return null;   // nothing saved

  final pending = pendingRaw is Map ? pendingRaw : jsonDecode(pendingRaw.toString());

  final savedAt = pending['saved_at'] as int;
  final ageMs = DateTime.now().millisecondsSinceEpoch - savedAt;
  //            how many milliseconds ago was this cart saved?

  await Service.remove('pending_ai_cart');  // always clear it (consume once)

  if (ageMs < 2 * 60 * 60 * 1000) {
    //         2 hours in milliseconds = 7,200,000
    return pending['cart_id'];  // still fresh — resume it
  }

  return null;  // too old — discard
}
```

### 6.3 Where `consumePendingAiCart` is Called

```dart
// In login_screen.dart — after successful login
Future<bool> _resumePendingAiCartIfAny() async {
  final cartId = await Service.consumePendingAiCart();
  if (cartId != null && mounted) {
    Navigator.pushReplacementNamed(
      context,
      McpCartScreen.routeName,
      arguments: {'cartId': cartId},
    );
    return true;  // tell the caller we redirected
  }
  return false;
}

// Called after biometric login:
final redirected = await _resumePendingAiCartIfAny();
if (redirected) return;   // don't go to home, go to McpCartScreen instead

// Called after OTP login — same pattern

// Called when tapping "Continue as Guest":
onTap: () async {
  final redirected = await _resumePendingAiCartIfAny();
  if (!redirected && mounted) {
    Navigator.pushReplacement(context, ...TabScreen...);
  }
}
```

---

## 7. FCM Push Notification Path

The backend can also deliver a cart via push notification
instead of a URL. The app handles this in `main.dart`.

```dart
// In _MyAppState.initState()
FirebaseMessaging.instance.getInitialMessage().then(_handleFcmMessage);
//                          ↑ app was killed, notification tapped to open it

FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmMessage);
//                ↑ app was in background, notification tapped

void _handleFcmMessage(RemoteMessage? message) {
  if (message == null) return;

  final type   = message.data['type'];      // must be 'ai_cart'
  final cartId = message.data['cart_id'];   // the cart ID

  if (type == 'ai_cart' && cartId != null && cartId.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamed(
        McpCartScreen.routeName,
        arguments: {'cartId': cartId},
      );
    });
  }
}
```

**Backend notification payload must look like this:**

```json
{
  "to": "<device_fcm_token>",
  "data": {
    "type": "ai_cart",
    "cart_id": "6a0d644087184a5f84e3f915"
  },
  "notification": {
    "title": "Your cart is ready!",
    "body": "Tap to open your AI-built cart in ZMall"
  }
}
```

---

## 8. Service.consumePendingAiCart — Shared Utility

**File:** `lib/services/service.dart`

This method is the single source of truth for resuming a pending cart.
Before this existed, the same code was copy-pasted in `login_screen.dart`
and `otp_screen.dart` — a bug in one place wouldn't be fixed in the other.

```
Before:                          After:
┌─────────────────┐             ┌─────────────────┐
│ login_screen    │             │ login_screen    │──┐
│  _resumePending │             │  calls Service  │  │   ┌──────────────┐
│  (copy 1)       │             └─────────────────┘  ├──▶│ Service      │
└─────────────────┘             ┌─────────────────┐  │   │ .consumePend │
┌─────────────────┐             │ otp_screen      │──┘   │ ingAiCart()  │
│ otp_screen      │             │  calls Service  │       └──────────────┘
│  _resumePending │             └─────────────────┘
│  (copy 2)       │             ┌─────────────────┐
└─────────────────┘             │ Guest button    │──┘
                                │  calls Service  │
                                └─────────────────┘
```

---

## 9. Complete Flow in One Diagram

```
User taps link
     │
     ├─ zmall://cart/{id}  ──────────────────────────┐
     │                                               │
     └─ https://.../ai-cart/{id}  ──────────────────▶│
                                                     │
                              AndroidManifest routes it to app
                                                     │
                                              main.dart
                                         _handleDeepLink(uri)
                                                     │
                                         extract cartId from URL
                                                     │
                                    navigatorKey → pushNamed('/mcp-cart')
                                                     │
                                           McpCartScreen opens
                                                     │
                              ┌──────────────────────┤
                              │                      │
                         Not logged in          Logged in
                              │                      │
                   save pending_ai_cart    GET /api/ai/cart/{id}
                   → go to LoginScreen    + server_token header
                              │                      │
                   User logs in / guest        success?
                              │                   │      │
                   consumePendingAiCart()       NO      YES
                              │                   │      │
                   cartId returned            show   commitCart()
                              │               error  + save to storage
                   → McpCartScreen again    screen       │
                                                    CartScreen opens ✅
```

---

## 10. How to Test

### Test custom scheme (always works on Android)
```bash
adb shell am start -a android.intent.action.VIEW \
  -d "zmall://cart/{cartId}" com.zmall.user
```

### Test HTTPS Vercel link
```bash
adb shell am start -a android.intent.action.VIEW \
  -d "https://zmall-web.vercel.app/ai-cart/{cartId}" com.zmall.user
```

### Watch live logs
```bash
adb logcat | grep -E "DEEP LINK|McpCart|cartId"
```

### Test push notification (FCM)
Send this from your backend or Firebase Console → Cloud Messaging:
```json
{
  "data": {
    "type": "ai_cart",
    "cart_id": "your-cart-id-here"
  }
}
```

### Test pending cart (not logged in flow)
1. Log out of the app
2. Run the deeplink adb command
3. App should go to Login screen
4. Log in → app should go directly to `McpCartScreen`
