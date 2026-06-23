# Kifiya Payment Screen Documentation

This document describes the implementation details of `lib/kifiya/kifiya_screen.dart`, which handles the payment selection and payment flow for the Zmall app.

## Overview

`KifiyaScreen` is a `StatefulWidget` that displays available payment options and manages the checkout flow for normal orders, courier orders, and AliExpress orders.

### Main Responsibilities

- Load user data and cart data
- Fetch available payment gateways
- Display payment methods in a selectable grid
- Validate payment preconditions before charging the user
- Launch provider-specific payment flows
- Verify external payment success
- Create a final order after confirmation

## Widget Inputs

`KifiyaScreen` accepts the following constructor parameters:

- `price`: `double?` — order amount
- `isCourier`: `bool?` — courier order mode
- `vehicleId`: `String?` — courier vehicle id
- `onlyCashless`: `bool?` — restrict to cashless options only
- `orderPaymentId`: `String?`
- `orderPaymentUniqueId`: `String?`
- `userpickupWithSchedule`: `bool?`

## State and Data

The state class `_KifiyaScreenState` holds:

- `paymentResponse`: payment gateway response data
- `orderResponse`: order creation response data
- `cart` / `aliexpressCart`: local cart data
- `courierCart`: courier-specific cart data
- `userData`: authenticated user data
- `kifiyaMethod`: currently selected payment method index
- `_loading` / `_placeOrder`: UI loading state flags
- `currentBalance`: wallet balance
- `uuid`: order / payment trace id
- `imagePath`: attached courier images

## Initialization

`initState()` performs:

- `getUser()` to retrieve locally stored user information and AliExpress token
- initialize `uuid` from `orderPaymentUniqueId`
- sets `kifiyaMethod = -1` if `onlyCashless` is true

## Data Loading

### getUser()

- Reads the saved user object from local storage
- Reads an `ali_access_token` if present
- Calls `getCart()` after user data loads

### getCart()

- For courier orders, reads courier cart data and calls additional courier setup methods
- For regular orders, reads normal cart and optional AliExpress cart data
- Always calls `_getPaymentGateway()` after loading cart data

### Courier helper methods

- `getServices()`
- `getImages()`
- `getCourierKefay()`
- `getCourierSchedule()`
- `getCourierScheduleDate()`

These support courier-order metadata and image handling.

## Payment Gateway Setup

### \_getPaymentGateway()

- Sets loading state
- Calls `getPaymentGateway()` to request available payment methods
- If the response is successful, it calls `useBorsa()` to prepare the payment session
- If the response indicates an auth error (`error_code == 999`), user is logged out and redirected to login

## Payment Prevalidation

### \_validateCourierImagesBeforePayment()

- Ensures courier order images exist and are valid before payment
- Uses `ImageUploadService.validateBatch(imagePath)`
- If validation fails, clears saved images and shows an error message

This is a security-focused validation step preventing payment attempts when courier images are invalid.

## Payment Processing

### \_payOrderPayment({otp, paymentId})

- Validates courier images before payment
- Determines the payment method identifier
- Calls `payOrderPayment(otp, paymentGatewayId)`
- On success, proceeds to create the appropriate order type:
  - courier order
  - AliExpress order
  - normal order
- On failure, displays the backend error text and logs out on auth expiration

## Payment Verification

### \_boaVerify()

- Runs BOA verification after returning from external payment flows
- If successful, validates courier images again before order creation
- Creates the appropriate order type on success
- If verification fails, resets the selected payment method and forces user to complete payment again

### \_ethSwitchVerify(String traceNo)

- Verifies EthSwitch payments using a trace number
- If successful, calls `_boaVerify()` to continue the final order flow
- Otherwise shows a failure message and resets the UI state

## Telebirr In-App / Polling Flow

The code specifically supports the Telebirr in-app payment flow with a fallback verification path:

- Return from `TelebirrInApp` component
- First call `_boaVerify()` for backend confirmation
- If `_boaVerify()` does not confirm payment, wait 3 seconds
- Call `pollTelebirrStatus(merchOrderId: traceNo)`
- If polling succeeds, create the order
- If polling fails, show a timeout/error message and reset `kifiyaMethod`

### pollTelebirrStatus({merchOrderId, intervalSeconds})

- Repeatedly sends POST requests to `https://pgw.shekla.app/teleInapp/query`
- Parses the response for success/failure status
- Returns `true` when the payment is confirmed
- Continues polling on transient errors until mounted

## Order Creation

### \_createCourierOrder()

- Creates a courier order by calling `createCourierOrder()`
- Manages loading state around the network call

### \_createAliexpressOrder()

- Calls `createAliexpressOrder()`
- Validates the AliExpress response structure
- If successful, passes returned order IDs to `_createOrder()`

### \_createOrder({orderIds})

- Creates the final order from the current cart
- Clears local cart state on success
- Redirects to `ReportScreen` with `price` and `orderPaymentUniqueId`
- Handles backend errors gracefully and shows user-friendly messages

## Supported Payment Flows

The screen handles many payment method flows through an index-based selection and method-specific dialogs. The supported flow examples include:

- `cash`
- `wallet`
- `telebirr reference`
- `telebirr in-app`
- `boa`
- `amole`
- `ethswitch`
- `etta card`
- `santimpay`
- `chapa`
- `cbe birr`
- `tele birr` (USSD)
- `dashen mastercard`
- `starpay`
- `addis pay`
- `yagoutpay`
- `zemen`
- `dashen`

Each flow generally follows this pattern:

1. Call `useBorsa()` to initialize the payment session
2. Show a confirmation dialog to the user
3. Launch the provider-specific widget/screen
4. On return, verify payment and create the order

## UI Structure

The screen uses a `ModalProgressHUD` wrapper to show a loading overlay while network calls are in progress.

The main UI is built around a `GridView.builder` of `KifiyaMethodContainer` items, with `press` handlers that:

- enforce `onlyCashless` restrictions
- handle insufficient wallet balance
- launch provider-specific flows
- show confirmation dialogs

## Notes and Improvements

- The code includes explicit fallback logic for Telebirr in-app payments, reducing false negatives when immediate verification fails.
- The courier payment flow includes image validation before payment to prevent invalid submissions.
- Authentication failures are handled by redirecting the user to login when `error_code == 999`.

## File Dependencies

`kifiya_screen.dart` imports several components used in provider-specific flows:

- `components/starpay_screen.dart`
- `components/addis_pay.dart`
- `components/amole_screen.dart`
- `components/cbe_ussd.dart`
- `components/chapa_screen.dart`
- `components/cyber_source.dart`
- `components/dashen_master_card.dart`
- `components/ethswitch_screen.dart`
- `components/etta_card_screen.dart`
- `components/santimpay_screen.dart`
- `components/telebirr_inapp.dart`
- `components/telebirr_ussd.dart`
- `components/yagoutpay.dart`
- `components/telebirr_screen.dart`
- `components/kifiya_method_container.dart`

Shared app imports include Provider models, `Service`, and `ReportScreen`.
