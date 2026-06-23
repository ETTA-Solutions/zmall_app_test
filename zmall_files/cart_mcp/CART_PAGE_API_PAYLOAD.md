# Cart Page API & Payload Contract

This document describes the backend API contract and JSON payload structure used by the cart checkout flow in `lib/cart/components/body.dart`.

## Relevant App Flow

1. User adds items to cart.
2. The cart is stored locally using `Service.save('cart', cart)`.
3. On checkout, the app navigates from the cart page to `DeliveryScreen`.
4. `DeliveryScreen` calls the backend to add the cart items:
   - `/api/user/add_item_in_cart_new`
   - `/api/user/add_item_in_cart_new_for_aliexpress` (for AliExpress orders)

## Relevant Files

- `lib/cart/components/body.dart`
- `lib/models/cart.dart`
- `lib/delivery/delivery_screen.dart`
- `lib/checkout/checkout_screen.dart`

## Store Detail Endpoint

### POST `/api/user/user_get_store_product_item_list`

**Request Headers**

```http
Content-Type: application/json
Accept: application/json
```

**Request body**

```json
{
  "store_id": "string"
}
```

- `store_id` is taken from `cart!.storeId!` in `lib/cart/components/body.dart`.

## Primary Backend Endpoint

### POST `/api/user/add_item_in_cart_new`

### POST `/api/user/add_item_in_cart_new_for_aliexpress`

**Request Headers**

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer {user_token}  # if used by backend
```

**Request body**
The request body is the serialized `Cart` object sent from the app.

### `Cart` JSON structure

```json
{
  "user_id": "string",
  "items": [
    {
      "_id": "string",
      "quantity": 1,
      "specification": [
        {
          "unique_id": 123,
          "list": [{ "unique_id": 456, "price": 12.34 }]
        }
      ],
      "note_for_item": "string",
      "price": 12.34,
      "item_name": "string",
      "image_url": "string"
    }
  ],
  "server_token": "string",
  "destination_address": {
    "name": "string",
    "long": 38.761886,
    "lat": 9.010498,
    "note": "string"
  },
  "store_id": "string",
  "store_location": {
    "lat": 9.010498,
    "long": 38.761886
  },
  "is_schedule": false,
  "schedule_start": null,
  "delivery_for_other": false,
  "username": "string",
  "phone": "string",
  "is_laundry_service": false
}
```

### Field Descriptions

- `user_id`: ID of the current user.
- `items`: List of cart items.
- `server_token`: User session/server token.
- `destination_address`: Delivery destination chosen by user.
- `store_id`: Store identifier.
- `store_location`: Store GPS coordinates.
- `is_schedule`: If the order is scheduled.
- `schedule_start`: Scheduled pickup/delivery time.
- `delivery_for_other`: True when ordering for another person.
- `username`: Receiver or orderer name.
- `phone`: Receiver or orderer phone number.
- `is_laundry_service`: True if the order is laundry service.

## Secondary Checkout Invoice Endpoint

After cart creation and delivery selection, checkout uses an invoice API.

### POST `/api/user/get_order_cart_invoice`

**Request body**
In `lib/checkout/checkout_screen.dart`, the app sends:

```json
{
  "user_id": "string",
  "store_id": "string",
  "total_time": 0,
  "total_distance": 0,
  "order_type": 7,
  "is_user_pick_up_order": false,
  "total_item_count": 2,
  "is_user_drop_order": true,
  "express_option": 0,
  "server_token": "string",
  "vehicle_id": "string",
  "tip": 0
}
```

### Field Notes

- `total_time`: delivery/travel time in minutes.
- `total_distance`: delivery distance.
- `order_type`: fixed value `7` in current code.
- `is_user_pick_up_order`: true when user picks up.
- `is_user_drop_order`: false for laundry service.
- `express_option`: selected express/delivery option.
- `vehicle_id`: selected vehicle ID for courier delivery.
- `tip`: tip amount.

## Cart Item Format

Each item inside `Cart.items` follows this format:

```json
{
  "_id": "string",
  "quantity": 1,
  "specification": [
    {
      "unique_id": 123,
      "list": [{ "unique_id": 456, "price": 12.34 }]
    }
  ],
  "note_for_item": "string",
  "price": 12.34,
  "item_name": "string",
  "image_url": "string"
}
```

## Destination Address Format

```json
{
  "name": "Delivery address label or description",
  "long": 38.761886,
  "lat": 9.010498,
  "note": "Optional delivery note"
}
```

## Store Location Format

```json
{
  "lat": 9.010498,
  "long": 38.761886
}
```

## AliExpress-specific endpoint

If the cart is for AliExpress, the app calls:

- `/api/user/add_item_in_cart_new_for_aliexpress`

The request payload is still the same serialized `Cart` object.

## Recommended Backend Contract

1. Accept cart creation payload at `/api/user/add_item_in_cart_new`.
2. Accept AliExpress cart payload at `/api/user/add_item_in_cart_new_for_aliexpress`.
3. Validate `user_id`, `server_token`, `store_id`, `destination_address`, and `items`.
4. Calculate total price and return a `cart_id`/session.
5. After delivery choice, accept invoice request at `/api/user/get_order_cart_invoice`.
6. Use `order_type`, `express_option`, and `tip` to calculate the checkout amount.

## Example Full Checkout Payload

```json
{
  "user_id": "63f1c2a7edabc12345",
  "items": [
    {
      "_id": "6041e2b8f0d0d9a1c9",
      "quantity": 2,
      "specification": [
        {
          "unique_id": 11,
          "list": [{ "unique_id": 101, "price": 10.0 }]
        }
      ],
      "note_for_item": "No onions",
      "price": 20.0,
      "item_name": "Burger",
      "image_url": "https://..."
    }
  ],
  "server_token": "abc123xyz",
  "destination_address": {
    "name": "Home",
    "long": 38.761886,
    "lat": 9.010498,
    "note": "Leave at the gate"
  },
  "store_id": "store_987",
  "store_location": {
    "lat": 9.010498,
    "long": 38.761886
  },
  "is_schedule": false,
  "schedule_start": null,
  "delivery_for_other": false,
  "username": "John Doe",
  "phone": "+251912345678",
  "is_laundry_service": false
}
```

## Notes for Backend Developer

- The UI sends the cart payload as the exact `Cart.toJson()` object.
- `DestinationAddress` and `StoreLocation` are required inside the cart payload.
- The first backend call is to add the cart.
- The second backend call is to request an invoice before final checkout.

---

**File generated from:** `lib/cart/components/body.dart` and `lib/models/cart.dart`.
