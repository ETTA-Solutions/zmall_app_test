# ZMall — User App

ZMall E-commerce App: a multi-service Flutter application for shopping, food/lunch delivery,
courier/parcel delivery, wallet & payments, events & ticketing, magazines, and more — across
Ethiopia (`app.zmall.et`) and Juba (`juba.zmallapp.com`) regions.

- **Package:** `zmall`
- **Version:** see `version:` in [`pubspec.yaml`](pubspec.yaml) (currently `3.2.9+362`)
- **Dart SDK:** `>=3.10.4 <4.0.0` · **Flutter:** 3.44.x (stable)
- **State management:** `provider`

---

## Features

| Area | Folders |
|---|---|
| Auth & onboarding | `login`, `register`, `forgot_password`, `splash` |
| Home & discovery | `home`, `search`, `store`, `product`, `item`, `scanner` |
| Cart & checkout | `cart`, `checkout`, `delivery`, `courier`, `courier_checkout`, `dine_in`, `lunch_home` |
| Orders | `orders`, `notifications` |
| Wallet & payments | `borsa`, `topup`, `kifiya` (payment gateways: Telebirr, CBE, Amole, Chapa, SantimPay, Dashen, AddisPay, EttaCard, EthSwitch, …) |
| Marketplace | `aliexpress`, `favorites`, `comments` (reviews) |
| Engagement | `events` (ticketing), `world_cup` (predictions), `home/magazine`, `home/yearly_recap`, `loyalty_card` |
| AI / deep links | `mcp` (AI cart), `map_view`, `location` |
| Support & misc | `help` (FAQ + support chat), `report`, `profile` |
| Shared | `models`, `services`, `controllers`, `widgets`, `custom_widgets`, `utils`, `global` (abroad/global flows) |

---

## Tech stack / key packages

Dependencies are grouped by usage in [`pubspec.yaml`](pubspec.yaml). Highlights:

- **Networking:** `http` (current), `dio` (target — see migration plan below)
- **Firebase:** core, auth, analytics, messaging, in-app messaging · **Analytics:** `facebook_app_events`
- **Maps & location:** `google_maps_flutter`, `flutter_map`, `geolocator`, `fl_location`
- **Media:** `cached_network_image`, `image_picker`, `just_audio`, `photo_view`
- **Storage & security:** `shared_preferences`, `flutter_secure_storage`, `encrypt`, `local_auth` (biometrics), `sms_autofill` (OTP)
- **UI/icons:** `heroicons_flutter`, `iconsx_plus` (FontAwesome icons), `shimmer`, `flutter_spinkit`, `confetti`, `flutter_staggered_grid_view`
- **Docs/web:** `pdfx`, `page_flip` (magazine), `flutter_inappwebview`, `url_launcher`, `app_links` (deep links)

---

## Project structure

```
lib/
  main.dart            # app entry: Firebase init, deep links (app_links), FCM, providers
  models/              # data models (metadata/ZMetaData, language, …)
  services/            # CoreServices, Service, url_launcher_service, backend_logger, …
  utils/               # constants.dart (BASE_URL*, errorCodes, theme), routes, navigator_key
  global/              # "global"/abroad variants of core flows
  <feature>/           # one folder per feature (see Features table)
packages/
  heroicons_flutter/   # (only if vendored — see Notes)
android/ ios/ web/     # platform projects
zmall_files/docs/      # project documentation (see below)
```

### Networking & configuration

- **Base URL** is provided at runtime by the `ZMetaData` provider (`models/metadata.dart`),
  selecting between region hosts. Static fallbacks (`BASE_URL`, `BASE_URL_PROD`, `BASE_URL_JUBA`)
  live in `utils/constants.dart`.
- **Server error codes** (e.g. `999` "Invalid server token", `2000` "Token expired") are mapped to
  user messages via the `errorCodes` map in `utils/constants.dart`.
- A full map of every endpoint, URL, request body, and the host/method exceptions is in
  [`zmall_files/docs/api_endpoints_reference.md`](zmall_files/docs/api_endpoints_reference.md).

---

## Getting started

### Prerequisites
- Flutter **3.44.x** (stable) / Dart `>=3.10.4`
- Android Studio / Xcode toolchains
- Firebase config files: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
  (and `lib/utils/firebase_options.dart`)
- A Google Maps API key configured for Android/iOS

### Setup & run
```bash
flutter pub get
flutter run
```

### Build
```bash
flutter build apk --release        # Android
flutter build appbundle --release  # Play Store
flutter build ios --release        # iOS (then archive in Xcode)
```

> After any change to `AndroidManifest.xml` / `Info.plist`, do a full reinstall
> (`flutter run` / clean rebuild) — hot reload won't pick those up.

---

## Documentation

Project docs live in [`zmall_files/docs/`](zmall_files/docs):

- [`api_endpoints_reference.md`](zmall_files/docs/api_endpoints_reference.md) — full API/endpoint catalog
- [`api_dio_migration_plan.md`](zmall_files/docs/api_dio_migration_plan.md) — plan to migrate `http` → organized `dio`
- [`heroicons_flutter_compatibility_fix.md`](zmall_files/docs/heroicons_flutter_compatibility_fix.md) — icon package fix
- [`APP_UPDATE_SYSTEM.md`](zmall_files/docs/APP_UPDATE_SYSTEM.md) · [`MCP_CART_FLOW_SUMMARY.md`](zmall_files/docs/MCP_CART_FLOW_SUMMARY.md) · [`kifiya_screen_documentation.md`](zmall_files/docs/kifiya_screen_documentation.md) · [`LUNCH_MISAKA_IMPLEMENTATION.md`](zmall_files/docs/LUNCH_MISAKA_IMPLEMENTATION.md) · [`COURIER_IMAGE_UPLOAD_FIX.md`](zmall_files/docs/COURIER_IMAGE_UPLOAD_FIX.md) · [`android_mainfest.md`](zmall_files/docs/android_mainfest.md)

---

## Notes

- **Icons:** Heroicons come from `heroicons_flutter`; FontAwesome icons come from `iconsx_plus`
  (its `HeroIcons` set is solid-only, so it is **not** used for Heroicons). If a local vendored,
  patched copy exists under `packages/heroicons_flutter/`, see the compatibility-fix doc for why.
- **Deep links:** handled in `main.dart` via `app_links` (`zmall://cart/{id}`,
  `https://…/ai-cart/{id}`, `https://…/go/cart/{id}`) and FCM messages (`type: ai_cart`).
- **Private package:** `publish_to: "none"` — not intended for pub.dev.
