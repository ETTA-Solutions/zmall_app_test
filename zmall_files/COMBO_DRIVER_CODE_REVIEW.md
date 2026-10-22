# Combo Order: Driver App Code Review

| | |
|---|---|
| **Date** | 2026-10-19 |
| **Single-store app (baseline)** | `D:\zmall\zmall_driver` @ `701f44b` |
| **Combo app (reviewed)** | `D:\zmall\zmall-driver-test` @ `f8ffc5e`. It branches from the baseline at `701f44b`, so the review covers `git diff 701f44b f8ffc5e -- lib`: 13 files, +1,578 / −526 lines. |
| **Reviewed against** | The backend guide `zmall_user_updated_combo/zmall_files/combo/COMBO_ORDER_IMPLEMENTATION.md` §8, and this repo's `COMBO_AND_STATUS_LIFECYCLE_GUIDE.md` |
| **Method** | Code reading only. **`flutter analyze` could not run** because packages aren't resolved in this repo (no `.dart_tool`). The app was not run on a device or against the backend. |

---

## 1. Verdict

**The design is sound.** The new `DeliveryStop` list replaces the old hard-coded `pickup_addresses[0]`:

- A single-store trip is `[store, customer]`.
- A combo trip is `[store A, store B, customer]`.

For the second store, the app runs the pickup steps (13 → 15 → 17) again and sends the store's `order_id` with status 17. Single-store trips go through the same code with the same result as before.

**It is not ready to release.** There are **4 high-severity issues**:

- 2 are test settings that were left on: the geofence is off and `BASE_URL` points at the test server.
- 1 can **hide a real order** from the driver.
- 1 can send "picked up" without saying which store.

| Severity | Count |
|---|---|
| High | 4 |
| Medium | 6 |
| Low | 9 |

---

## 2. What changed compared with the single-store app

| File | Change |
|---|---|
| `lib/models/delivery_stop.dart` **(new)** | `DeliveryStop` and `buildStops()`: an ordered list of pickups plus one drop-off. It sorts by `combo_pickup_sequence` when present, parses coordinates whether they arrive as numbers or strings, and skips a bad stop instead of crashing. Also adds `isComboRequest`, `isActiveCombo` (combo with `combo != null`) and `orderIdsLabel`. |
| `lib/utils/stop_map.dart` **(new)** | Map markers for every stop and for the driver, map bounds that fit all stops, and a small offset when two stores share the same coordinates. |
| `lib/models/requests.dart` | `processOrders` now: (1) checks distance against the first pickup, (2) **removes duplicate accepted requests**, matching on store names plus customer location, (3) attaches each store's `order_id` to `pickup_addresses[seq-1]`, (4) collects `combo_unique_ids` so the card shows "470605 + 470606". |
| `lib/screens/accepted_orders/accepted_orders.dart` | The status machine knows which store is active (`activePickupIndex`). It saves progress per request under `combo_pickup_progress`, sends `order_id` with status 17, handles `ORDER_NOT_READY`, and names the store on the button ("ARRIVED GUADA"). The button title and color are now explicit `switch` statements that default to "UPDATE APP". An unknown status no longer rewinds the trip to 13. |
| `lib/services/api_services.dart` | `setRequestStatus` takes an optional `orderId`. Also adds `developer.log` of the order history responses. |
| `lib/screens/home_screen/home_screen.dart`, `lib/services/services.dart` | The new-order popup and the push popup draw every stop and show a COMBO badge. |
| `lib/screens/available_orders/available_orders.dart` | Store names are joined with " + ", and a COMBO badge is shown. |
| `lib/screens/order_history/order_detail.dart` | Lists every pickup address. |
| `lib/widgets/custom_widgets.dart` | Adds the `ComboBadge` widget. |
| `lib/utils/constants.dart` | Adds the `ORDER_NOT_READY` error text. **`BASE_URL` changed to the test backend** (see H2). |

---

## 3. What is implemented correctly

| Area | Why it is right | Where |
|---|---|---|
| Single-store trips keep working | One pickup gives `[store, customer]`. `activePickupIndex` returns 0 when there are fewer than 2 pickups, and `order_id` is only sent for combos. | `delivery_stop.dart:123`, `accepted_orders.dart:187-188, 463` |
| Pickup order | Sorted by `combo_pickup_sequence`, which the backend sets (1 = origin, 2 = waypoint). Raw array order is used only when the field is missing. | `delivery_stop.dart:141-151` |
| Safe parsing | Coordinates as numbers or strings, and missing names or phones, don't crash the app. A bad stop is skipped. | `delivery_stop.dart:83-198` |
| Which store is active | Uses the strongest of three signals: local progress, per-address `delivery_status ≥ 17`, and `combo_next_stop`. It never moves backwards. | `accepted_orders.dart:187-204` |
| Restart in the middle of a trip | Progress is saved to storage and loaded before the list is built, so the driver isn't sent back to store A. | `accepted_orders.dart:155-180, 711-712` |
| Status 17 per store | Sends `order_id` of the active store. The response of 13 or `combo_next_stop` moves the driver to store B. Store B's 17 clears the saved progress. | `accepted_orders.dart:463-541` |
| `ORDER_NOT_READY` | Nothing changes, the button stays on PICKED UP, and the message names the store. | `accepted_orders.dart:569-587` |
| Unknown status | The old nested ternary defaulted to the red **FINISH DELIVERING** button and to status 13. Now it shows "UPDATE APP" and makes no status call. This is a real safety improvement. | `accepted_orders.dart:105-143, 425-440` |
| Ecommerce sync | `updateDeliveryStatusEcommerce` isn't called between the two pickups. | `accepted_orders.dart:553-565` |
| Map | All stops get markers, the camera fits all of them, and two stores with the same coordinates are spread apart on screen only. The geofence still uses the real coordinates. | `stop_map.dart` |
| Double taps | `ModalProgressHUD(inAsyncCall: _isLoading)` blocks the button during the status call, but see **M3**. | `accepted_orders.dart:764` |

---

## 4. High-severity findings

### H1. The 100 m geofence is switched off for every build

**File:** `lib/screens/accepted_orders/accepted_orders.dart:377-378`

```dart
// // for debug purpose — uncomment to skip geofence during testing:
nearToStore = true;
nearDestination = true;
```

**Problem:** in the single-store app these two lines are **commented out** (`zmall_driver/.../accepted_orders.dart:143-144`). In the combo app they are active, with no `kDebugMode` check. `COMBO_AND_STATUS_LIFECYCLE_GUIDE.md` Q5 says production enforces the geofence, but it doesn't.

**Impact:** a driver can mark "Arrived at store" and "Arrived at destination" from anywhere. This is also the only check that the driver is at **store B** rather than still at store A.

**Fix:** comment the two lines out again, or wrap them in `if (kDebugMode)`. Add a release checklist item for this.

### H2. `BASE_URL` points at the test backend

**File:** `lib/utils/constants.dart:28-29`

```dart
// const BASE_URL = "https://app.zmall.et";
const BASE_URL = "https://testbackend.zmall.et";
```

**Problem:** a release build would talk to the test server.

**Fix:** switch back to `https://app.zmall.et` before release. Better still, choose the URL with `--dart-define` so the source code doesn't change between test and release builds.

### H3. Duplicate removal can hide a real order from the driver

**File:** `lib/models/requests.dart:156-241`

**Problem:** every request assigned to the driver is compared with the others using **sorted store names + customer latitude/longitude**. The second request with the same key is dropped from `acceptedRequests`. This runs for **all** requests, not only combos.

**Impact:**

- **Two separate orders can be merged.** Say a customer orders twice from the same store to the same address, and both orders go to the same driver. They get the same key, so the second order disappears from the driver's list. The driver can't move it forward or complete it, and the customer waits.
- **Two different combos can be merged** in the same way, if they use the same two stores and the same customer.
- **The counter is wrong.** `acceptedDeliveries` is lower than the real number of requests.

**Fix:**

1. Only remove duplicates when `isComboRequest(req)` is true, **and**
2. Match on an id instead of names and coordinates:
   - the request `_id`, if both copies are the same Request (the backend guide §8 says a combo is **one** Request with 2 `pickup_addresses`), or
   - `combo_id` / `order_detail.combo_id`.

**Ask the backend:** do the two copies have the same request `_id`?

- **If yes:** removing duplicates by `_id` is safe and simple.
- **If no:** there are two Requests, and the driver only ever updates the one that was kept. The other stays at status 11. The backend has to fix this; the client can't.

### H4. Status 17 can be sent without `order_id`

**File:** `lib/screens/accepted_orders/accepted_orders.dart:474-488`

**Problem:** when `activePickup.orderId == null`, the code only writes a debug message and sends status 17 anyway, without `order_id`. The id is missing when either of these is absent from the payload, so the attaching step in H3 does nothing:

- `order_detail.combo_pickup_sequence`
- `orders.order_id` / `order_detail._id`

**Impact:** the backend can't tell which store was picked up. It may mark the wrong store, or the whole trip.

**Fix:** for a combo pickup with no `orderId`, don't send the call. Refresh the list with `getOrdersForDelivery()` and show "Order data is incomplete. Pull to refresh or contact support." Also ask the backend to put `order_id` on each `pickup_addresses[i]`. The app reads it there already (`delivery_stop.dart:108`), and the client-side attaching would then no longer be needed.

---

## 5. Medium-severity findings

### M1. The available list shows a combo twice

**File:** `lib/models/requests.dart:131-142`

**Problem:** duplicates are removed only for **accepted** requests. Both copies of a combo go into `availableRequests`, and `availableDeliveries` counts 2.

**Fix:** apply the same id-based duplicate removal as in H3.

### M2. Delivery eligibility checks only the first store

**File:** `lib/models/requests.dart:131`

**Problem:** the 3 km offer radius is checked against the first pickup only. Store B can be far outside it. The code comment already flags this as a dispatch decision.

**Fix:** product needs to decide between "origin only", "every pickup within range" or "the whole route". Record the decision in the backend guide.

### M3. A quick second tap after store A can skip arriving at store B

**File:** `lib/screens/accepted_orders/accepted_orders.dart:494-541, 627`

**Problem:** after store A's 17 succeeds, the order of events is:

1. `_isLoading = false` (line 496)
2. progress is saved, which makes store B the active store
3. `getOrdersForDelivery()` runs (line 627) and the list waits for the reply

Until that reply arrives, the card still has `delivery_status == 15`. A tap in that window becomes **another 17, now for store B**, without 13 → 15 at store B. The backend should reject it, but that isn't confirmed.

**Fix:** keep `_isLoading` true until the refresh finishes. Or set `order['delivery_status'] = returned` locally straight after the response.

### M4. When the combo ends mid-trip, the app falls back to pickup index 0

**Files:** `accepted_orders.dart:339-340`, `delivery_stop.dart:243`

**Problem:** when `combo` becomes `null`, `isActiveCombo` is false and the active pickup is always index 0. That's wrong in two cases:

- **Store A (index 0) is the one that cancelled**, and the backend leaves it in `pickup_addresses`. The labels and the geofence then point to the cancelled store.
- **Store B cancels after store A's 17**, and the trip status is still 13. The driver is asked to "ARRIVE PICKUP" at store A again.

**Fix:** confirm with the backend that (a) the cancelled store is removed from `pickup_addresses`, and (b) the status becomes 17 when the remaining store has already been picked up. Until then, choose the first pickup whose `deliveryStatus < 17` instead of always index 0.

### M5. Customer names, phones and addresses go into release logs

**Files:** `delivery_stop.dart:180-184`, `stop_map.dart`, `accepted_orders.dart` (47 `debugPrint`s), `requests.dart`

**Problem:** the driver app has no `debugPrint` override in `main.dart`. The user app has one (`zmall_user_updated_combo/lib/main.dart:28`). `debugPrint` writes to logcat in release builds, so every list refresh logs every customer's name, phone and address. `buildStops` logs this each time it runs, and it runs many times per build.

**Fix:** add the same release-mode override, or remove the debug lines before release.

### M6. The status contract differs from the backend guide

**Problem:** the two documents describe different status flows:

| Document | What it says |
|---|---|
| Backend guide checklist (`COMBO_ORDER_IMPLEMENTATION.md` §11) | Asks the backend for **new** statuses: `DELIVERY_MAN_ARRIVED_STORE_2` / `DELIVERY_MAN_PICKED_ORDER_STORE_2` |
| This app | Reuses **13/15/17** with `combo_next_stop`, a per-store `order_id` on 17, and `ORDER_NOT_READY` |

**Fix:** agree on one contract with the backend and update both documents. The user app's status labels (`combo_order_entry.dart`) depend on this too.

---

## 6. Low-severity findings

| # | File:line | Issue | Fix |
|---|---|---|---|
| L1 | `available_orders.dart:187` | `pickupStops(order).first` throws if the list is empty. Today it's safe only because `processOrders` skips requests with no pickups. | Use `firstOrNull`. |
| L2 | `available_orders.dart:165`, `order_history/order_detail.dart:175, 208` | Still read `destination_addresses[0]` directly. There is only one drop-off, so the logic is fine, but an empty list crashes. | Use `dropoffStop(...)`. |
| L3 | `stop_map.dart:181-209` | Store 1 and store 2 use the same icon. Orange is only used when the icon fails to load, so the two stores differ only by their info-window title. | Use a numbered or differently colored icon for store 2 always. |
| L4 | `accepted_orders.dart:172-180` | `combo_pickup_progress` entries are removed only after store B's 17. Cancelled or collapsed trips leave entries behind forever. | Remove entries whose request is no longer in `acceptedRequests` during `processOrders`. |
| L5 | `requests.dart:156-185`, `home_screen.dart` | `buildStops` / `pickupStops` run again and again for the same request (inside the duplicate loop, and several times per `build`). | Build the stops once per request in `processOrders` and keep them. |
| L6 | `api_services.dart:250, 508` | `developer.log(response.body)` logs whole order history responses. | Remove it. |
| L7 | `main.dart:96-98` and others | Leftover comments (`//driver addrss` …) and large commented-out blocks, for example the old ternary at `accepted_orders.dart:448-460`. | Delete them. |
| L8 | `COMBO_AND_STATUS_LIFECYCLE_GUIDE.md` | Some statements don't match the code: Q5 says the geofence is enforced in production (see H1), and Q2 / Q4 state backend reasons as facts without a source. Its links point to `/Users/apple/Desktop/...`. | Rewrite it as a factual description of the code and use repo-relative links. |
| L9 | `test/` | No tests for `buildStops` (sorting, bad stops), `activePickupIndex`, `_nextStopIndex` or duplicate removal. These are pure functions and easy to test. | Add tests. |

---

## 7. Questions for the backend

| # | Question | Needed for |
|---|---|---|
| 1 | For a combo, does `get_orders_for_delivery` return **one Request twice** (same `_id`) or **two Requests**? | H3, M1 |
| 2 | Can each `pickup_addresses[i]` carry its own `order_id` and `combo_pickup_sequence`? | H4 |
| 3 | Is the contract 13/15/17 run twice with `combo_next_stop`, or the new `*_STORE_2` statuses? What exactly is `combo_next_stop`: a 1-based number, an order id, or an object? | M6, `_nextStopIndex` |
| 4 | Is status 17 for store B rejected while the trip is at 15 for store A? | M3 |
| 5 | When one store cancels mid-trip, is it removed from `pickup_addresses`, and what status does the trip move to? | M4 |
| 6 | Should the driver push notification be sent once per combo or once per order? | Duplicate popups |
| 7 | Dispatch radius for combos: origin only, or every pickup? | M2 |

---

## 8. Recommended order of work

1. **H1, H2:** turn the geofence back on and restore the production `BASE_URL`. These are two one-line changes and they block release.
2. **H3, M1:** remove duplicates by request `_id` or `combo_id`, only for combo requests (answer question 1 first).
3. **H4:** don't send status 17 without `order_id`.
4. **M3:** keep the button disabled until the list has refreshed.
5. **M5:** add the `debugPrint` release override.
6. **M4, M6:** align with the backend (questions 3 and 5).
7. Run `flutter pub get && flutter analyze` in this repo, then do the low-severity items and add unit tests.

**Re-test after the fixes:**

| Test | Expected result |
|---|---|
| Single-store order end to end | Same buttons, geofence and completion as the old app |
| Same customer, two separate orders from the same store, same driver | **Both** cards appear |
| Combo: accept → A 13/15/17 → B 13/15/17 → 19/21 → complete | Each 17 carries the right `order_id`, and the button names the right store |
| Combo: try "Arrived" at store B while standing at store A | Blocked by the geofence |
| Combo: kill the app between A and B, then reopen | The app resumes at store B |
| Combo: store not ready | `ORDER_NOT_READY` message, and a retry works |
| Combo: store B cancels before or after A's pickup | The trip continues correctly to the customer |
| Combo in the available list | Shown once, and counted once |
| Release build | No customer data in logcat, and requests go to `app.zmall.et` |
