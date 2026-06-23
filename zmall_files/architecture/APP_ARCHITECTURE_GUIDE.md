# ZMall App — Full Architecture Guide

> A complete explanation of how the app works: startup, login, state, storage, API calls, and payment.

---

## Table of Contents

1. [App Startup — `main.dart`](#1-app-startup--maindart)
2. [Splash Screen](#2-splash-screen)
3. [State Management — Provider](#3-state-management--provider)
4. [Local Storage — `Service` class](#4-local-storage--service-class)
5. [API Fetching — `CoreServices`](#5-api-fetching--coreservices)
6. [Login Flow](#6-login-flow)
7. [Navigation & Routes](#7-navigation--routes)
8. [Tab Screen (Home Shell)](#8-tab-screen-home-shell)
9. [Kifiya Payment Screen](#9-kifiya-payment-screen)
10. [Data Flow Diagram](#10-data-flow-diagram)

---

## 1. App Startup — `main.dart`

**File:** `lib/main.dart`

```
App opens → main() runs → Firebase initializes → MyApp widget starts
```

### What happens in `main()`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Required before any async work
  await Firebase.initializeApp(...);          // Connect to Firebase project
  runApp(MyApp());                            // Start the Flutter app
}
```

### `MyApp` is a StatefulWidget because it needs to:
- Listen to **deeplinks** (links that open the app from outside)
- Listen to **Firebase push notifications**

### Deeplink Handling

```
User taps link →  AppLinks package catches it → _handleDeepLink() runs
                                                        ↓
                               Parse the URL → find cartId
                                                        ↓
                               Navigate to McpCartScreen with cartId
```

Two URL formats are supported:
| Format | Example |
|--------|---------|
| Custom scheme | `zmall://cart/abc123` |
| HTTPS (App Link) | `https://testapp.zmall.et/ai-cart/abc123` |

### Push Notification Handling

When a notification with `type: "ai_cart"` arrives, the app reads `cart_id` from the notification data and navigates to `McpCartScreen`.

### `navigatorKey`

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
```

This is a global key that lets the app navigate **without needing a BuildContext** (used by deeplinks and push notifications which fire outside the widget tree).

---

## 2. Splash Screen

**File:** `lib/splash/splash_screen.dart`

The splash screen is the **first screen the user sees**. It runs in parallel to check several things.

### What it does in `initState()`

```dart
getLang();          // Load saved language preference
getMetaData();      // Load saved country (Ethiopia or South Sudan)
initPlatformState();// Get app version number
isLogged();         // Check if user was previously logged in
getAd();            // Fetch banner advertisement from backend
_doLocationTask();  // Request/check GPS permission
MyApp.analytics.logAppOpen(); // Firebase Analytics event
loader(8);          // Start 8-second timer before navigating away
```

### Timing Logic

```
Timer starts (8 seconds)
        ↓
If ad loads successfully → timer resets to 3 seconds (show ad faster)
If ad fails             → timer resets to 5 seconds (navigate quickly)
        ↓
onDoneLoading() runs → decide where to go
```

### Where does the user go after splash?

```dart
onDoneLoading() {
  if (isGlobal == true) {
    // User chose Global mode
    abroadData != null → GlobalHome()   // Already set up abroad profile
                       → GlobalScreen() // Setup global profile
  } else {
    // Normal mode
    logged == true → TabScreen()    // Go to main app (home/orders/profile)
    logged == false → LoginScreen() // Go to login
  }
}
```

### Ad Banner from Backend

The splash calls `/admin/get_all_advertises` via HTTP POST. It filters for `is_ads_visible: true`, picks the last visible ad, and shows it full-screen. The ad has a `urlLink` that tells the app where to navigate when tapped:
- `store/{storeId}` → open a store
- `item/{itemId}` → open a product item
- External URL → open browser

---

## 3. State Management — Provider

**Files:** `lib/models/metadata.dart`, `lib/models/language.dart`

The app uses **Provider** (not Bloc, not Riverpod). Two providers wrap the entire app in `main.dart`:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider<ZMetaData>(create: (_) => ZMetaData()),
    ChangeNotifierProvider<ZLanguage>(create: (_) => ZLanguage()),
  ],
  child: ...
)
```

### `ZMetaData` — Country/Region Settings

This is the **most important provider**. It switches between Ethiopia and South Sudan and updates:

| Property | Ethiopia | South Sudan |
|----------|----------|-------------|
| `baseUrl` | `BASE_URL` (Addis Ababa server) | `BASE_URL_JUBA` (Juba server) |
| `areaCode` | `+251` | `+211` |
| `currency` | `ብር` | `SSP` |
| `latitude/longitude` | 9.004188, 38.768154 | 4.861544, 31.583369 |
| `countryId` | Ethiopia ID | South Sudan ID |

**How to read it anywhere:**
```dart
Provider.of<ZMetaData>(context, listen: false).baseUrl
Provider.of<ZMetaData>(context, listen: false).currency
```

**How to update it:**
```dart
Provider.of<ZMetaData>(context, listen: false).changeCountrySettings("Ethiopia");
```

Changing country settings automatically changes the API base URL, so ALL API calls use the correct server.

### `ZLanguage` — Language/Text Strings

All text in the app (buttons, labels, messages) comes from `ZLanguage`. This allows easy localization. Any widget that shows text reads from this provider:

```dart
Provider.of<ZLanguage>(context).login     // "Login" text
Provider.of<ZLanguage>(context).register  // "Register" text
Provider.of<ZLanguage>(context).home      // "Home" tab label
```

---

## 4. Local Storage — `Service` class

**File:** `lib/services/service.dart`

`Service` is a static utility class — you never create an instance of it. Every method is called as `Service.methodName(...)`.

### Two Storage Backends

| Backend | Used For | Package |
|---------|----------|---------|
| `SharedPreferences` | Normal data (user, cart, settings) | `shared_preferences` |
| `FlutterSecureStorage` | Sensitive biometric credentials (phone, password) | `flutter_secure_storage` |

### Core Storage Methods

```dart
// Save any value (auto-JSON encodes)
await Service.save('user', responseData);
await Service.save('cart', cartData);

// Read any value (auto-JSON decodes)
var userData = await Service.read('user');

// Save/read booleans
await Service.saveBool('logged', true);
var isLogged = await Service.readBool('logged');

// Delete a key
await Service.remove('cart');
```

### Important Keys Stored in SharedPreferences

| Key | What it stores |
|-----|---------------|
| `user` | Full user object from login API (includes `server_token`, `_id`, wallet balance) |
| `logged` | `bool` — whether user is logged in |
| `cart` | Current shopping cart items |
| `courier` | Courier delivery cart |
| `country` | `"Ethiopia"` or `"South Sudan"` |
| `lang` | Language code e.g. `"en_US"` |
| `categories` | Cached nearby store categories |
| `is_global` | `bool` — whether in Global mode |
| `version` | App version string |
| `app_open` / `app_close` | App operating hours from backend |
| `pending_ai_cart` | Cart ID saved for unauthenticated deeplink users |
| `service_logs` | Last 200 API call logs (for debugging) |
| `images` | File paths of courier images |

### Secure Storage Keys (Biometric)

| Key | What it stores |
|-----|---------------|
| `saved_phone` | Phone number for biometric login |
| `saved_password` | Password for biometric login |
| `biometric_enabled` | `bool` — biometric enabled flag |

### Other Utility Methods in `Service`

```dart
// Check internet
await Service.isConnected(context)  // Shows snackbar if offline

// Show snackbar message
Service.showMessage(context: context, title: "Done!", error: false);
Service.showMessage(context: context, title: "Failed!", error: true);

// Check if user is logged
await Service.isLogged()

// Get user object
await Service.getUser()  // Returns the full saved user JSON

// Distance between two GPS points (km)
Service.calculateDistance(lat1, lon1, lat2, lon2)

// Cart item merge logic
Service.addOrMergeCartItem(cart, newItem)
Service.isSameItem(item1, item2)

// AI cart deeplink pending cart
await Service.consumePendingAiCart()  // Returns cartId or null
```

---

## 5. API Fetching — `CoreServices`

**File:** `lib/services/core_services.dart`

`CoreServices` handles all HTTP requests to the backend. Every method:
1. Builds the URL using `Provider.of<ZMetaData>(context).baseUrl`
2. Sends a POST request with JSON body
3. Logs request/response via `BackendLogger`
4. Returns decoded JSON or `null` on failure
5. Has a 15-second timeout

### Pattern for every API call

```dart
static Future<dynamic> someApiCall(params, BuildContext context) async {
  var url = "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/...";
  Map data = { "key": "value" };
  var body = json.encode(data);

  http.Response response = await http.post(
    Uri.parse(url),
    headers: {"Content-Type": "application/json"},
    body: body,
  ).timeout(Duration(seconds: 15));

  return json.decode(response.body);
}
```

### Available API Methods in CoreServices

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `getCategoryList()` | `/api/user/get_delivery_list_for_nearest_city` | Get stores near user location |
| `getServicesList()` | Same endpoint with `delivery_type: 2` | Get courier services |
| `getPromotionalItems()` | `/api/user/get_promotion_item` | Get featured/promoted products |
| `getPromotionalStores()` | `/api/user/get_promotion_store` | Get featured stores |
| `updateDeviceToken()` | `/api/user/update_device_token` | Register FCM push token |
| `appKeys()` | `/api/admin/get_app_keys` | Get app config (open/close times, version) |
| `saveAdClick()` | `/admin/get_all_advertises/{adId}` | Track ad click analytics |
| `getUserDetail()` | `/api/user/get_detail` | Refresh user profile data |
| `clearCache()` | Local | Clear all saved user data (logout) |
| `getProximityOrders()` | `/api/user/get_recent_orders` | Get nearby delivery orders |
| `registerNotification()` | Firebase SDK | Subscribe to push notifications |

### Authentication Headers

Most API calls need `user_id` and `server_token`. These come from the saved user object:

```dart
var userData = await Service.read('user');
String userId = userData['user']['_id'];
String serverToken = userData['user']['server_token'];
```

---

## 6. Login Flow

**Files:** `lib/login/login_screen.dart`, `lib/login/otp_screen.dart`

### Normal Login (Phone + Password + OTP)

```
User enters phone (9 digits) + password
        ↓
loginButtonPressed() → validate form
        ↓
generateOtpAtLogin() → POST /api/user/generate_otp_at_login
        ↓
Backend sends OTP to user's phone via SMS
        ↓
OtpScreen opens → user enters 6-digit OTP
        ↓
Backend verifies OTP → returns user object with server_token
        ↓
Service.save('user', responseData)
Service.saveBool('logged', true)
        ↓
Check if there's a pending AI cart → go to McpCartScreen
OR → navigate to TabScreen (main app)
```

### Biometric Login (Fingerprint/Face)

```
On login screen load → check if biometric is available + enabled
        ↓
Auto-trigger biometric prompt after 500ms
        ↓
User authenticates with fingerprint/face
        ↓
Service.biometricLogin() → POST /api/user/login (no OTP needed)
        ↓
Same as normal login from here
```

### Multi-Account "Switch Account"

The app supports multiple saved accounts. Users can tap "Switch Account" to see a list of saved accounts and pick one. Each account stores phone + password in secure storage with a `BiometricCredential` object.

### Guest Mode

```
User taps "Continue as a Guest"
        ↓
Check for pending AI cart (Service.consumePendingAiCart())
If found → go to McpCartScreen
If not → go to TabScreen (browse without account)
```

### Biometric Credential Storage

Credentials are stored in `FlutterSecureStorage` (encrypted storage, not SharedPreferences). They survive app reinstall only if the device keystore is preserved.

### Error Codes

Login errors from the backend return an `error_code` integer. The app maps these to human-readable messages via the `errorCodes` map in `constants.dart`.

```dart
errorCodes['999']  // Session expired → force logout
errorCodes['813']  // Location not in service area
```

---

## 7. Navigation & Routes

**File:** `lib/utils/routes.dart`

The app uses Flutter's **named routes** system. All screens are registered in one map:

```dart
final Map<String, WidgetBuilder> routes = {
  '/splash'    : (context) => SplashScreen(),
  '/login'     : (context) => LoginScreen(),
  '/start'     : (context) => TabScreen(),
  '/home'      : (context) => HomeScreen(),
  '/store'     : (context) => StoreScreen(),
  '/product'   : (context) => ProductScreen(),
  '/item'      : (context) => ItemScreen(),
  '/cart'      : (context) => CartScreen(),
  '/kifiya'    : (context) => KifiyaScreen(),
  '/mcp-cart'  : (context) => McpCartScreen(...),
  // + 20 more screens
};
```

### Navigation Patterns Used

```dart
// Go to a named route
Navigator.pushNamed(context, '/login');

// Go back and replace current screen
Navigator.pushReplacementNamed(context, TabScreen.routeName);

// Clear entire stack (no going back) — used after login
Navigator.pushNamedAndRemoveUntil(
  context,
  TabScreen.routeName,
  (Route<dynamic> route) => false,
);

// Go back
Navigator.pop(context);

// Navigate from outside widget tree (deeplinks)
navigatorKey.currentState?.pushNamed('/mcp-cart', arguments: {'cartId': id});
```

### Screen Hierarchy

```
SplashScreen
    ↓
LoginScreen ──────────────────────────────────────────┐
    ↓                                                  │
TabScreen (bottom nav shell)                           │
  ├── HomeScreen                                       │
  │     ├── StoreScreen                                │
  │     │     └── ProductScreen                        │
  │     │           └── ItemScreen                     │
  │     │                 └── CartScreen               │
  │     │                       └── CheckoutScreen     │
  │     │                             └── KifiyaScreen │
  │     │                                   └── ReportScreen
  ├── OrdersScreen                                     │
  ├── SupportChatScreen (if chatbot enabled)           │
  └── ProfileScreen                                    │
                                                       │
McpCartScreen ◄────────────────────────────────────────┘
(accessible from anywhere via deeplink or notification)
```

---

## 8. Tab Screen (Home Shell)

**File:** `lib/utils/tab_screen.dart`

`TabScreen` is the main shell after login. It shows a bottom navigation bar with 3 or 4 tabs depending on whether the chatbot feature is enabled.

### Tabs

| Tab | Screen | Condition |
|-----|--------|-----------|
| Home | `HomeScreen` | Always |
| Orders | `OrdersScreen` | Always |
| Chat | `SupportChatScreen` | Only if `is_chatbot_active == true` in user data |
| Profile | `ProfileScreen` | Always |

### Chatbot Check

On `initState()`, the tab screen reads the user data and checks `userData['is_chatbot_active']`. If `true`, it adds a 4th chat tab. This is a **server-controlled feature flag** — the backend decides per-user if they see the chat tab.

---

## 9. Kifiya Payment Screen

**File:** `lib/kifiya/kifiya_screen.dart`

`KifiyaScreen` is the payment gateway screen. It is called "Kifiya" (ክፍያ = payment in Amharic).

### When is it shown?

After the user reviews their order in `CheckoutScreen` or `CourierCheckout`, they tap "Pay" and are pushed to `KifiyaScreen`.

### Parameters received

```dart
KifiyaScreen(
  price: 250.00,              // Order total
  orderPaymentId: "abc123",   // Backend payment record ID
  orderPaymentUniqueId: "456",// Unique transaction reference
  isCourier: false,           // true = courier delivery order
  onlyCashless: false,        // true = cash not allowed
  vehicleId: null,            // For courier orders
)
```

### Initialization Sequence

```
initState()
    ↓
getUser() → read user from SharedPreferences
    ↓
getCart() → read cart from SharedPreferences
    ↓
_getPaymentGateway() → POST /api/... to backend
    ↓
Backend returns list of available payment methods
    ↓
useBorsa() → check wallet balance
    ↓
Screen shows payment method grid
```

### Available Payment Methods

The backend returns a list called `payment_gateway`. The app maps each payment name to a logo image and a handler:

| Payment Method | Type | Flow |
|----------------|------|------|
| **Wallet** | ZMall wallet | Instant debit |
| **Cash** | Cash on delivery | Allowed unless `onlyCashless: true` |
| **Telebirr InApp** | Mobile money | Opens Telebirr app SDK |
| **Tele Birr (USSD)** | Mobile money | USSD code screen |
| **Telebirr Reference** | Mobile money | Manual reference entry |
| **CBE Birr** | CBE bank mobile | USSD WebView |
| **BOA** | Bank of Abyssinia | CyberSource web payment |
| **EthSwitch** | Bank card (ATM) | EthSwitch WebView |
| **SantimPay** | Fintech | WebView payment |
| **Chapa** | Fintech | WebView payment |
| **Dashen Mastercard** | Bank card | WebView payment |
| **Addis Pay** | Mobile money | WebView payment |
| **Amole** | Dashen bank mobile | OTP screen |
| **StarPay** | Fintech | WebView payment |
| **YagoutPay** | Fintech | WebView payment |
| **Etta Card** | Loyalty card | Card PIN entry |

### Payment Flow (General Pattern)

```
User taps a payment method
        ↓
useBorsa() → tells backend which method user selected
        ↓
Method-specific screen opens (WebView / OTP / SDK)
        ↓
User completes payment outside app (or in WebView)
        ↓
Control returns to KifiyaScreen
        ↓
_boaVerify() → POST to backend to confirm payment status
        ↓
If verified:
  isCourier → _createCourierOrder()
  AliExpress → _createAliexpressOrder()
  Normal     → _createOrder()
        ↓
On success: clear cart, navigate to ReportScreen (order confirmation)
```

### Telebirr InApp Special Flow

Telebirr InApp has a dual verification system:

```
Open TelebirrInApp widget
        ↓
User pays in Telebirr app
        ↓
Return to KifiyaScreen
        ↓
Try _boaVerify() first (fast)
        ↓
If _boaVerify() fails → wait 3 seconds → pollTelebirrStatus()
  Polls https://pgw.shekla.app/teleInapp/query every 3 seconds
  Checks for status "PAID" or "SUCCESS"
        ↓
If payment confirmed → create order
If timeout/failed → show error, let user retry
```

### Image Validation for Courier Orders

Before any courier payment is processed, `_validateCourierImagesBeforePayment()` checks:
- Do attached images exist on device?
- Are they valid image formats?
- Are they within the size limit?

If images fail validation, payment is **blocked before money is charged**. This prevents a user paying but the order failing because images are missing.

### Order Creation

After payment, `createOrder()` calls the backend to create the order. On success:
- `Service.remove('cart')` — clears the local cart
- Navigates to `ReportScreen` with the order confirmation

If error code `999` is returned at any point, the session is expired:
```dart
await Service.saveBool('logged', false);
await Service.remove('user');
Navigator.pushReplacementNamed(context, LoginScreen.routeName);
```

---

## 10. Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ZMALL APP                                   │
│                                                                     │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │  main()  │───▶│  SplashScreen│───▶│  LoginScreen             │  │
│  │          │    │              │    │  OtpScreen               │  │
│  │ Firebase │    │ - fetch ads  │    │  BiometricAuth           │  │
│  │ Deeplink │    │ - check login│    │                          │  │
│  │ FCM      │    │ - get loc    │    └──────────┬───────────────┘  │
│  └──────────┘    └──────────────┘               │                  │
│                                                  ▼                  │
│                                       ┌──────────────────────────┐ │
│                                       │     TabScreen            │ │
│                                       │  ┌──────┬──────┬──────┐  │ │
│                                       │  │Home  │Orders│Profil│  │ │
│                                       │  └──┬───┘      └──────┘  │ │
│                                       └─────┼────────────────────┘ │
│                                             │                       │
│                        ┌────────────────────┤                       │
│                        ▼                    ▼                       │
│               ┌──────────────┐    ┌──────────────────┐             │
│               │  StoreScreen │    │  CartScreen       │             │
│               │  ProductScr  │    │  CheckoutScreen   │             │
│               │  ItemScreen  │    │  KifiyaScreen ◄───┼────────┐   │
│               └──────────────┘    │  ReportScreen     │        │   │
│                                   └──────────────────┘         │   │
│                                                                 │   │
│  ┌──────────────────────────────────────────────────┐          │   │
│  │  SERVICE LAYER                                   │          │   │
│  │  Service (local storage + utilities)             │          │   │
│  │  CoreServices (HTTP API calls)                   │──────────┘   │
│  └──────────────────────────────────────────────────┘              │
│                                                                     │
│  ┌──────────────────────────────────────────────────┐              │
│  │  STATE (Provider)                                │              │
│  │  ZMetaData → baseUrl, country, currency, location│              │
│  │  ZLanguage → all UI text strings                 │              │
│  └──────────────────────────────────────────────────┘              │
│                                                                     │
│  ┌──────────────────────────────────────────────────┐              │
│  │  LOCAL STORAGE (SharedPreferences)               │              │
│  │  user, cart, logged, country, lang, categories   │              │
│  │  ─────────────────────────────────────────────   │              │
│  │  SECURE STORAGE (FlutterSecureStorage)           │              │
│  │  biometric phone, biometric password             │              │
│  └──────────────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key Technical Decisions

| Decision | Why |
|----------|-----|
| `SharedPreferences` for data | Simple, fast, no SQL setup needed |
| `FlutterSecureStorage` for credentials | Encrypted on device, safer than SharedPreferences |
| Provider (not Bloc) | Simpler for this app size, less boilerplate |
| Static methods on `Service` | Avoid passing service instances, easier to call anywhere |
| Named routes | Central route definition, easy to add new screens |
| `GlobalKey<NavigatorState>` | Navigate from deeplink/push handlers outside widget tree |
| `_hasNavigatedAway` flag in Splash | Prevents double-navigation when timer fires after ad loads |
| Image validation before payment | Prevents user being charged when order will fail |
| `consumePendingAiCart()` | Handles AI cart deeplinks when user is not logged in |
