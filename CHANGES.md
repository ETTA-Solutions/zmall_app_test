# Changes: ZooryaPay payment checks, M-PESA, cash and Odoo order status

None of this is committed yet. Every file passes `flutter analyze` with no errors. Nothing has been tested on a device or with a real payment.

---

## 1. Payment check (`/admin/check_paid_order`): 2-minute limit

### Rule (the same for every method)
- Check `/admin/check_paid_order`, wait for the answer, wait **2 seconds**, check again.
- Only **one request at a time**. The next check starts only after the previous answer comes back. Each request times out after 10 seconds.
- Stop after **2 minutes** (about 60 checks at most).
- After 2 minutes the user sees **"We couldn't confirm your payment"** with two buttons:
  - **Resend prompt** (QR: **Get new QR code**): sends a new prompt and starts a new 2 minutes.
  - **I've paid, check again**: checks **once**. If paid, it continues as normal. If not: "Payment not received yet."
- Leaving the screen (back), or tapping "Change" on M-PESA, stops the checking immediately.
- A resend never leaves an old check loop running.

### Shared settings: `lib/kifiya/zoorya_pay/zoorya_pay_service.dart`
| Added | Value / purpose |
|---|---|
| `ZooryaPayService.pollWindow` | `Duration(minutes: 2)`: how long to keep checking |
| `ZooryaPayService.pollInterval` | `Duration(seconds: 2)`: wait between checks |
| `ZooryaPayService.isPaid(result)` | One "is it paid" test: `success` / `is_paid` / `paid` = true, or `data.is_paid` / `data.paid` = true, or `data.status` = `PAID` / `COMPLETED` |

### Per method
| Method | File | Before | Now |
|---|---|---|---|
| Telebirr USSD (ZooryaPay and old) | `lib/kifiya/components/telebirr_ussd.dart` | Every 2s. ZooryaPay stopped after 60 checks; old flow never stopped | Every 2s, stops at 2 min, then Resend / I've paid buttons. The screen now scrolls so the buttons fit on small phones |
| M-PESA | `lib/kifiya/zoorya_pay/zoorya_pay_mpesa_screen.dart` | A new check every 3s whether or not the previous one had answered, 40 checks; "I Have Approved" button | Every 2s, stops at 2 min, then Resend / I've paid. **"I Have Approved" button removed**: the screen continues automatically once paid |
| Dashen USSD screen | `lib/kifiya/zoorya_pay/zoorya_pay_ussd_screen.dart` | Every 2s, never stopped | Every 2s, stops at 2 min, then Resend / I've paid (light and dark designs) |
| QR (Telebirr QR, EthSwitch QR) | `lib/kifiya/zoorya_pay/zoorya_pay_qr_screen.dart` | Every 2s, never stopped | Every 2s, stops at 2 min, then Get new QR code / I've paid |
| NIB / EthSwitch direct | `lib/kifiya/kifiya_screen.dart` (`_pollDirectZooryaPayment`) | Every 2s, stopped after 60 checks with a "Payment timeout" message | Every 2s, stops at 2 min, then a **popup** with Resend prompt / I've paid |

---

## 2. M-PESA phone number field
File: `lib/kifiya/zoorya_pay/zoorya_pay_mpesa_screen.dart`

- **`+251` is fixed at the start of the field**: always visible, can't be deleted.
- Placeholder after it: `7XX XXX XXX`.
- The user types **9 digits** starting with 7.
- A typed or pasted `0`, `251` or `+251` in front is removed automatically:

| User types / pastes | Field shows | Sent to the backend |
|---|---|---|
| `718081364` | `718081364` | `0718081364` |
| `0718081364` | `718081364` | `0718081364` |
| `+251718081364` / `251718081364` | `718081364` | `0718081364` |

- Error only when the first digit isn't 7: "M-PESA numbers start with 7 after +251".
- Waiting screen shows the number as `+251 718 081 364`.
- If the user's saved phone is an M-PESA number, the field fills in automatically.
- Fixed bug: the old field cut a typed `07…` number to 8 digits and added `07` again, so the **wrong number** was sent.

---

## 3. Cash payment: order creation restored
File: `lib/kifiya/kifiya_screen.dart`

- The test code that skipped order creation for cash was removed. Cash now creates the order **exactly as before**:
  - combo: `_createOrder()`
  - courier: `_createCourierOrder()`
  - AliExpress cart: `_createAliexpressOrder()`
  - anything else: `_createOrder()`
- ⚠️ **Not changed: Telebirr in-app** still has order creation **turned off for testing**, in 2 places in `kifiya_screen.dart` (search for `FOR TESTING TELEBIRR INAPP`). Turn it back on before release.

---

## 4. Order status: Odoo/POS stores only (no driver)
Odoo/POS stores have no driver, so for **Odoo stores only** the status never uses `delivery_status` (driver status). They always show the real `order_status` (for example "Preparing order").
**Other stores are not changed.** Every change is behind `isOdooStoreByName(...)`.

| Screen | File | Odoo stores now | Other stores |
|---|---|---|---|
| Active orders list | `lib/orders/components/body.dart` | Always `order_status` (this was already in the code; not changed) | not changed |
| Order history | `lib/orders/components/orders_history.dart` | Always `order_status` (before: `order_status` 7 showed the driver label, or "null") | not changed |
| Combo order (single store) | `lib/orders/models/combo_order_entry.dart` | Always `order_status` | not changed |
| Order detail | `lib/orders/components/order_detail.dart` | **No driver timeline** (no "Delivery man started delivery" / "Delivery man completed delivery" steps) and no driver-status box. Shows the simple `order_status` box | not changed |

Odoo store detection: `isOdooStoreByName(storeName)` in `lib/utils/constants.dart`. It matches the store name against the branch slugs in `kZmallBranchSlugs`. Order history uses `store_detail.name`; the other screens use `store_name`.

---

## Still open: please check
1. **Order created twice?** Only **ZooryaPay Telebirr USSD** relies on the backend creating the order inside `check_paid_order`. For M-PESA, Dashen, QR and NIB/EthSwitch the **app** creates the order after payment. If the backend also creates it for those methods, the order is created **twice**. Confirm with the backend team.
2. **Telebirr in-app** order creation is still turned off for testing (see section 3).
3. **Odoo detection is by store name.** A new Odoo branch must be added to `kZmallBranchSlugs` in `lib/utils/constants.dart`, or its orders will be treated like a normal store.
