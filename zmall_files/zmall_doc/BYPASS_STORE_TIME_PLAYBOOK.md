# Bypass Store Closed-Time Check — APPLIED CHANGES

Stores now behave as **always open** so ordering and checkout work regardless of
operating hours. This file documents **exactly what was changed** and why.

> The open/closed decision is spread across **four independent gates** plus a
> backend flag. All blocking gates are now bypassed. Status as of 2026-07-24.

---

## Summary of gates

| # | File | Role | Status |
|---|------|------|--------|
| 1 | `lib/services/service.dart` — `isStoreOpen` (singular) | Source of truth for many single-store `isOpen` checks (home body, splash, global home, notification store). | ✅ Bypassed (`return true`) |
| 1b | `lib/services/service.dart` — `storeOpen` (list) | **Real** per-store algorithm feeding store-list badges, list filtering (hides closed stores), and `ProductScreen.isOpen`. | ✅ Bypassed (returns all-`true`) |
| 2 | `lib/cart/components/body.dart` — checkout button | Cart's own inline time check that blocks the checkout button. | ✅ Bypassed (`if (true)`) |
| 3 | `lib/models/cart.dart` — `AbroadCart.isOpen` | Backend `is_open` flag; when false, global checkout forces next-day-only booking. | ✅ Bypassed (`isOpen: true`) |
| 4 | `lib/product/product_screen.dart` — `widget.isOpen!` | Add-to-cart / product gates. | ✅ Covered by #1b automatically |
| 5 | `lib/favorites/favorites_screen.dart` — inline `storeOpen()` | Drifted private copy of the algorithm (favorites list badges). | ✅ Bypassed (fills all-`true`) |
| 6 | `lib/global/stores/components/body.dart` — inline `storeOpen()` | Drifted private copy of the algorithm (global stores list badges). | ✅ Bypassed (fills all-`true`) |

> Why so many: there is no single switch. The app computes open/closed in
> **four different places** (central service + two drifted inline copies + a cart
> inline check) and also honors a **backend `is_open`** flag at checkout. All are
> now forced open.

---

## 1. `lib/services/service.dart` — main check (already bypassed)

`Service.isStoreOpen()` wraps the real `storeOpen()` algorithm and feeds the
`isOpen` flag used by the store list, home screen, and product screen.

**Change (~line 576):**

```dart
static Future<bool> isStoreOpen(var store) async {
  List<bool> result = await storeOpen([store]);
  return true;                                  // ← bypass: always open
  // return result.isNotEmpty ? result[0] : false;   // original
}
```

### 1b. `storeOpen()` list version — the real algorithm (changed)

The **list** version is what store-list screens actually use
(`store/components/body.dart`, `search_screen.dart`,
`featured_nearby_stores.dart.dart`, `misaka_store_list_screen.dart`). It was
still returning real values, so closed stores got a "Closed" badge **and were
hidden from the list** (`store/components/body.dart:484-494`), and the `isOpen`
flag it feeds into `ProductScreen` could still block add-to-cart.

**Change (~line 601):**

```dart
static Future<List<bool>> storeOpen(List stores) async {
  // BYPASS store closed-time check: treat every store as open.
  return List<bool>.filled(stores.length, true);
  // ignore: dead_code
  List<bool> isOpen = [];
  ...original algorithm (lines 601–737) left intact but unreachable...
}
```

---

## 2. `lib/cart/components/body.dart` — checkout button (changed)

The cart screen has its **own** inline time check (was ~line 541) that is **not**
driven by gate #1. Without this edit, tapping checkout while "closed" showed
*"Sorry, we are currently closed. Please comeback soon."*

**Change (~line 541):**

```dart
// BYPASS store closed-time check: always allow checkout regardless of
// open/close time. Original gate kept below for reference.
// if (now.isAfter(zmallOpen) &&
//     now.isBefore(zmallClose)) {
if (true) {
  Navigator.pushNamed(context, DeliveryScreen.routeName);
} else {
  // (now dead code) "Sorry, we are currently closed..."
}
```

> Note: there is a **separate unused** `storeOpen()` helper at lines 321–351 in
> the same file — it is defined but never called (dead code), so it gates
> nothing and needs no change.

---

## 3. `lib/models/cart.dart` — `AbroadCart.isOpen` (changed)

`global_checkout.dart` reads `cart!.isOpen` (an `AbroadCart`). This comes from
the **backend** field `is_open`, not from gate #1. When false it forced
scheduled / next-day-only booking (`global_checkout.dart` lines 108, 250,
326–345).

**Change (~line 121):**

```dart
isOpen: true, // BYPASS store closed flag — was: json['is_open']
```

Default was already `true` at line 86 (`this.isOpen = true`); this makes the
parsed value ignore the backend and stay `true`, so global checkout never falls
into next-day-only mode.

---

## 4. `lib/product/product_screen.dart` — no change needed

Add-to-cart / product-tap gates use `widget.isOpen!` (lines ~399, 497, 509, 854,
962) which shows *"Sorry the store is closed at this time!"*. This value is fed
by gate #1, so bypassing #1 covers this **automatically**.

---

## 5 & 6. Drifted inline copies (changed)

Two screens re-implement the open/closed algorithm privately instead of calling
the service, so they had to be bypassed separately.

**`lib/favorites/favorites_screen.dart` — `storeOpen()` (~line 99):**

```dart
void storeOpen(List stores) {
  isOpen.clear();
  // BYPASS store closed-time check: mark every favorite store as open.
  isOpen.addAll(List<bool>.filled(stores.length, true));
  if (isOpen.isNotEmpty) return;
  ...original loop below (unreachable when there are stores)...
}
```

**`lib/global/stores/components/body.dart` — `storeOpen()` (~line 100):**

```dart
void storeOpen(List stores) async {
  isOpen.clear();
  // BYPASS store closed-time check: mark every store as open.
  isOpen.addAll(List<bool>.filled(stores.length, true));
  if (isOpen.isNotEmpty) return;
  ...original loop below (unreachable when there are stores)...
}
```

Neither method calls `setState` at its end, so the early return is safe.

> Not touched: `favorites` hardcoded a 21:00 close and ignored `app_open`;
> that quirk no longer matters since the method now returns all-open.

---

## Display-only (intentionally left alone)

These only show an Open/Closed badge and do **not** block anything:

- `lib/widgets/open_close_status_card.dart`
- `lib/store/components/store_info.dart`
- `lib/home/components/offer_card.dart`, `proximity_offer_card.dart`
- `lib/models/language.dart` — the "Closed" / "Open" label strings

Leaving these untouched means a store may still *display* a "Closed" badge while
ordering works — remove or hardcode these if you also want the badge to always
read "Open".

---

## Verification

`flutter analyze` on all changed files reports **0 errors** — only expected
`dead_code` / `unused_variable` warnings, all a direct result of the early
returns and `if (true)` bypasses (the original code is kept but unreachable).

## How to revert

1. `service.dart` `isStoreOpen` (~578): restore `return result.isNotEmpty ? result[0] : false;`
2. `service.dart` `storeOpen` (~601): remove the `return List<bool>.filled(...)` early return
3. `body.dart` (~541): restore `if (now.isAfter(zmallOpen) && now.isBefore(zmallClose))`
4. `cart.dart` (~121): restore `isOpen: json['is_open'],`
5. `favorites_screen.dart` (~99): remove the `isOpen.addAll(...)` + early return
6. `global/stores/components/body.dart` (~100): remove the `isOpen.addAll(...)` + early return