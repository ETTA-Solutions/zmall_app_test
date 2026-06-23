# App Update & Force Update System

> **Last updated:** February 2026
> **Files:** `app_update_service.dart`, `app_update_dialog.dart`, `core_services.dart`

---

## Overview

The app update system checks whether the user is running an outdated version of the app. If an update is available, it shows a dialog prompting the user to update. The dialog has two modes:

| Mode | User can dismiss? | Back button works? | "Remind Later" shown? |
|------|:-:|:-:|:-:|
| **Normal update** | Yes | Yes | Yes |
| **Force update** | No | No | No |

---

## Architecture

```
┌──────────────────────────┐
│   Admin Dashboard        │  Sets version, flags
│   (Backend)              │
└──────────┬───────────────┘
           │ POST /api/admin/get_app_keys
           ▼
┌──────────────────────────┐
│   CoreServices.appKeys() │  Raw API call (core_services.dart)
│   Returns server response│
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│   AppUpdateService       │  Central logic (app_update_service.dart)
│   - Saves keys locally   │
│   - Compares versions    │
│   - Shows dialog         │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│   AppUpdateDialog        │  UI widget (app_update_dialog.dart)
│   - Force / Normal mode  │
│   - "Update Now" button  │
│   - "Remind Later" button│
└──────────────────────────┘
```

---

## Files

### 1. `lib/services/app_update_service.dart`

This is the **single entry point** for the entire update logic. Every screen that needs to check for updates calls this one method.

#### Public API

```dart
// Check for updates and show dialog if needed
AppUpdateService.fetchAndCheck(context);

// Only to save keys, don't show any dialog (used in background screens)
AppUpdateService.fetchAndCheck(context, showDialogIfNeeded: false);

// With a closure/maintenance notice callback
AppUpdateService.fetchAndCheck(
  context,
  onMessageFlag: (message) {
    // Show banner, notification, etc.
  },
);
```

#### What `fetchAndCheck()` does, step by step:

1. Calls `CoreServices.appKeys(context)` — hits the backend API
2. If the API fails or returns `success: false`, exits silently
3. **Saves all keys** to local storage (SharedPreferences) via `_saveAppKeys()`
4. If `message_flag` is `true`, calls the `onMessageFlag` callback (if provided)
5. If `showDialogIfNeeded` is `true` (default):
   - Reads the remote version from `ios_user_app_version_code`
   - Checks if `is_ios_user_app_open_update_dialog` is `true`
   - Compares versions using **semantic versioning** (not string comparison)
   - If update is needed AND dialog isn't already shown → shows `AppUpdateDialog`

#### Version Comparison

```
Current app version:  3.2.6    (from constants.dart → appVersion)
Remote version:       3.3.0    (from server → ios_user_app_version_code)

Comparison: 3 == 3, 2 < 3 → update needed ✅
```

The comparison splits each version on `.` and compares segments as integers:
- `3.2.6` vs `3.2.6` → equal, no update
- `3.2.6` vs `3.3.0` → update needed
- `3.2.6` vs `3.2.5` → current is newer, no update
- `3.2.6` vs `4.0.0` → update needed

#### Duplicate Dialog Prevention

A static `_isUpdateDialogShown` flag prevents the dialog from appearing multiple times (e.g. when multiple screens call `fetchAndCheck` on load). The flag resets when the dialog is dismissed.

---

### 2. `lib/widgets/app_update_dialog.dart`

A **stateless** dialog widget. It does NOT contain any business logic — it only handles UI.

#### Two Modes

**Normal update** (`isForceUpdate: false`):
- User can tap outside to dismiss
- Back button closes the dialog
- Shows both "Remind Later" and "Update Now" buttons

**Force update** (`isForceUpdate: true`):
- `barrierDismissible: false` — tapping outside does nothing
- `PopScope(canPop: false)` — back button is blocked
- Only shows "Update Now" button — user **must** update

#### "Update Now" Action

Opens the app store link: `http://onelink.to/vnchst` via `Service.launchInWebViewOrVC()`.

---

### 3. `lib/services/core_services.dart` — `appKeys()` method

The raw API call. **Do not call this directly** — use `AppUpdateService.fetchAndCheck()` instead.

**Endpoint:** `POST {baseUrl}/api/admin/get_app_keys`

**Response fields:**

| Field | Type | Description |
|-------|------|-------------|
| `success` | `bool` | Whether the API call succeeded |
| `ios_user_app_version_code` | `String` | Latest app version (e.g. `"3.3.0"`) |
| `is_ios_user_app_open_update_dialog` | `bool` | Whether to show the update dialog |
| `is_ios_user_app_force_update` | `bool` | Whether update is mandatory |
| `message_flag` | `bool` | Whether there's a service notice |
| `message` | `String` | The service notice text |
| `app_open_time` | `String` | Store opening time |
| `app_close_time` | `String` | Store closing time |

---

## Dashboard Configuration

To trigger an update dialog for users, set these keys on the admin dashboard:

| Dashboard Key | Value | Purpose |
|---------------|-------|---------|
| `ios_user_app_version_code` | `"3.3.0"` | The new version number |
| `is_ios_user_app_open_update_dialog` | `true` | Enable the update dialog |
| `is_ios_user_app_force_update` | `false` | `false` = dismissible, `true` = mandatory |

### To release a normal (optional) update:
1. Set `ios_user_app_version_code` to the new version (e.g. `"3.3.0"`)
2. Set `is_ios_user_app_open_update_dialog` to `true`
3. Set `is_ios_user_app_force_update` to `false`

### To force-update all users:
1. Set `ios_user_app_version_code` to the new version
2. Set `is_ios_user_app_open_update_dialog` to `true`
3. Set `is_ios_user_app_force_update` to **`true`**

### To disable the update dialog:
- Set `is_ios_user_app_open_update_dialog` to `false`

---

## Local Storage Keys

These are saved to SharedPreferences by `AppUpdateService._saveAppKeys()`:

| Key | Type | Description |
|-----|------|-------------|
| `ios_app_version` | `String` | Cached remote version |
| `ios_update_dialog` | `bool` | Cached dialog-enabled flag |
| `ios_force_update` | `bool` | Cached force-update flag |
| `is_closed` | `bool` | Service closure flag |
| `closed_message` | `String` | Service closure message |
| `app_open` | `String` | Store opening time |
| `app_close` | `String` | Store closing time |
| `version` | `String` | Current installed app version (set in splash_screen.dart) |

---

## App Version (Client Side)

The current app version is defined in two places — **both must be updated** when releasing:

| File | Line | Value |
|------|------|-------|
| `lib/utils/constants.dart` | `const String appVersion = "3.2.6"` | Used by `AppUpdateService` for comparison |
| `pubspec.yaml` | `version: 3.2.6+357` | Used by the build system |

---

## Which Screens Call `fetchAndCheck()`

| Screen | File | Mode | Notes |
|--------|------|------|-------|
| Home | `lib/home/components/home_body.dart` | `showDialogIfNeeded: true` | Also handles `onMessageFlag` for notice banner |
| Splash Ad | `lib/splash/component/splash_container.dart` | `showDialogIfNeeded: true` | — |
| Global Home | `lib/global/home_page/components/global_home_screen.dart` | `showDialogIfNeeded: true` | Also handles `onMessageFlag` with `Service.showMessage` |
| Store | `lib/store/components/body.dart` | `showDialogIfNeeded: false` | Only saves keys + reads `app_open`/`app_close` |
| Nearby Stores | `lib/home/components/featured_nearby_stores.dart.dart` | `showDialogIfNeeded: false` | Only saves keys + reads `app_open`/`app_close` |
| Notification Store | `lib/notifications/notification_store.dart` | `showDialogIfNeeded: false` | Only saves keys |
| Splash | `lib/splash/splash_screen.dart` | `showDialogIfNeeded: false` | Only saves keys |

---

## Common Tasks

### Adding the update check to a new screen

```dart
import 'package:zmall/services/app_update_service.dart';

// In initState or any init method:
AppUpdateService.fetchAndCheck(context);
```

### Adding with a service notice handler

```dart
AppUpdateService.fetchAndCheck(
  context,
  onMessageFlag: (message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  },
);
```

### Only saving keys (no dialog)

```dart
AppUpdateService.fetchAndCheck(context, showDialogIfNeeded: false);
```

### Changing the update link

Edit `lib/widgets/app_update_dialog.dart`, line with:
```dart
Service.launchInWebViewOrVC("http://onelink.to/vnchst");
```

### Changing the dialog text or styling

Edit `lib/widgets/app_update_dialog.dart` — the `build()` method contains all UI.

### Changing the version comparison logic

Edit `lib/services/app_update_service.dart` — the `_isVersionUpToDate()` method.
