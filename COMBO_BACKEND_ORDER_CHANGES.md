# Combo: backend-created orders — what changed and how to roll back

## 1. What changed (2 files)

Before: the app paid a combo, then the app called `combo_create_order` to create both orders.
After: the app tells the backend about the combo before payment (the "intent"). The backend creates both orders. The app never calls `combo_create_order` in the payment flow.

### File 1: `lib/combo/services/combo_service.dart`
`getInvoice` (`combo_get_order_cart_invoice`) now also sends:
`flow: "combo"`, `store_a_cart_id`, `store_b_cart_id`, `is_user_pick_up_order: false`, `order_from`.
(`combo_id` and the nested carts were already sent.)

`createOrder` (`combo_create_order`) is untouched and still exists. Nothing calls it in the payment flow any more.

### File 2: `lib/kifiya/kifiya_screen.dart`

| # | Where | Change |
|---|---|---|
| A | `_createOrder`, the `data['duplicate']` check (~line 604) | A duplicate reply that carries the combo orders now counts as success. |
| B | `_createOrder`, success branch (~line 636) | The inline "save combo_orders and build receipt id" code was replaced by calls to `_saveComboOrders(data)` and `_comboReceiptId(data)`. Same behaviour. |
| C | `_finishBackendCreatedOrder` (~line 1476) | For combo it hands over to `_finishBackendCreatedComboOrder`. |
| D | New block "Combo orders" (~line 1522) | New helpers: `_comboOrderId`, `_hasComboOrders`, `_comboReceiptId`, `_saveComboOrders`, `_finishBackendCreatedComboOrder`. |
| E | `_mustCreateOrderFromApp` (~line 1692) | `if (widget.isCombo) return true;` became `return false;`. So after an online payment, combo waits for the backend (`_waitForOrder`). |
| F | `_afterPayOrderPayment` (~line 1731) | For combo: show the receipt if the pay response has the orders, otherwise `_waitForOrder()`. It never calls `combo_create_order`. |

## 2. Roll back the whole thing

Do NOT run `git checkout lib/kifiya/kifiya_screen.dart`. That file has other uncommitted work (the settlement changes) that you would lose. Undo by hand, as below.

### Step 1: `combo_service.dart`
Delete these lines at the end of the `getInvoice` body (the comment and the five fields after the `store_b` block):

```dart
    // Order intent: ... (3 comment lines)
    "flow": "combo",
    "store_a_cart_id": combo.cartIdByStore[route.originStoreId],
    "store_b_cart_id": combo.cartIdByStore[route.waypointStoreId],
    "is_user_pick_up_order": false,
    "order_from": Platform.isIOS ? "ios" : "android",
```

### Step 2: `kifiya_screen.dart`

**E — `_mustCreateOrderFromApp`.** Change back to:
```dart
    if (widget.isCombo) return true;
```
and remove the 4-line comment above it.

**F — `_afterPayOrderPayment`.** Replace the `if (widget.isCombo) { ... return; }` block with nothing. With E reverted, combo goes to `_createOrderFromApp()` and calls `combo_create_order` again.

**C — `_finishBackendCreatedOrder`.** Remove:
```dart
    if (widget.isCombo) {
      await _finishBackendCreatedComboOrder(response);
      return;
    }
```

**A — duplicate check in `_createOrder`.** Change back to:
```dart
        if (data['duplicate'] != null && data['duplicate'] == true) {
```

**B — success branch in `_createOrder`.** Replace
```dart
            await ComboCart.clear();
            await _saveComboOrders(data);
          }
          if (!mounted) return;

          final uniqueId = widget.isCombo
              ? _comboReceiptId(data)
              : (widget.orderPaymentUniqueId ?? "");
```
with the original:
```dart
            await ComboCart.clear();
            try {
              final orderA = data['store_a']?['order_id']?.toString();
              final orderB = data['store_b']?['order_id']?.toString();
              final orderIds = [
                if (orderA != null && orderA.isNotEmpty) orderA,
                if (orderB != null && orderB.isNotEmpty) orderB,
              ];
              final uniqueIds = data['order_unique_ids'] is List
                  ? List.from(data['order_unique_ids'])
                  : [];
              final cId = data['combo_id']?.toString() ?? widget.comboId ?? "";
              if (cId.isNotEmpty && orderIds.isNotEmpty) {
                final existingRaw = await Service.read('combo_orders');
                List<dynamic> existingList = [];
                if (existingRaw is List) {
                  existingList = List.from(existingRaw);
                } else if (existingRaw is String) {
                  try {
                    existingList = List.from(jsonDecode(existingRaw));
                  } catch (_) {}
                }
                existingList.insert(0, {
                  'combo_id': cId,
                  'order_ids': orderIds,
                  'order_unique_ids': uniqueIds,
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (existingList.length > 50) {
                  existingList = existingList.sublist(0, 50);
                }
                await Service.save('combo_orders', existingList);
              }
            } catch (e) {
              debugPrint("Failed to persist combo_orders: $e");
            }
          }
          if (!mounted) return;

          final orderIdsList =
              widget.isCombo && data['order_unique_ids'] is List
              ? List.from(data['order_unique_ids'])
              : null;
          final uniqueId = (orderIdsList != null && orderIdsList.isNotEmpty)
              ? orderIdsList.join(',')
              : (widget.orderPaymentUniqueId ?? "");
```

**D — helpers.** Delete the whole "Combo orders" block (from the `// ──── Combo orders ────` comment through the end of `_finishBackendCreatedComboOrder`). Once B and C are reverted nothing uses it.

### Step 3: check
Run `dart analyze lib/kifiya/kifiya_screen.dart lib/combo`. Then pay one cash combo and confirm the log shows `Step 4: combo_create_order attempt 1/3`.

## 3. Partial rollback (keep the intent, bring back the safety net)

If the backend does not create cash/wallet combo orders yet, only revert **E and F**. The app then sends the intent but still calls `combo_create_order` after payment. This is safe because the backend's `create_order` is idempotent (confirm the same for `combo_create_order`).

## 4. Assumptions to confirm with the backend
- Online combo is paid once, with the combined total on store A's `unique_id`.
- `combo_get_order_cart_invoice` accepts the new fields.
- After a combo payment, the backend creates both orders, and `check_paid_order` / `/api/zooryapay/status` return them (ideally `order_unique_ids`).
