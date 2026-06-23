# MCP Cart Flow Summary

## What MCP Cart Does

The MCP cart feature is implemented in [lib/mcp/mcp_cart_screen.dart](../lib/mcp/mcp_cart_screen.dart). It acts as a bridge from an external cart ID into the app's normal cart flow.

When the screen opens, it:
- Checks whether a user is already logged in by reading `user` from local storage.
- If the user is not logged in, it saves the cart ID as `pending_ai_cart` and sends the user to the login screen.
- If the user is logged in, it calls the backend endpoint `/api/ai/cart/{cartId}` to fetch the cart.
- It converts the API response into the app's cart structure.
- If there is already an existing local cart from another store, it shows a replace/keep dialog.
- If everything is valid, it saves the cart locally and opens the normal cart screen.

## Login Flow

The login flow is handled mainly in [lib/login/login_screen.dart](../lib/login/login_screen.dart).

After a successful login:
- The app saves the returned user payload using `Service.save('user', ...)`.
- It marks the session with `Service.saveBool('logged', true)`.
- It checks whether there is a `pending_ai_cart`.
- If a pending cart exists and is still fresh, it redirects back into [lib/mcp/mcp_cart_screen.dart](../lib/mcp/mcp_cart_screen.dart) using the saved `cartId`.

So the MCP cart flow depends on login, but it does not implement login itself. It only pauses and resumes the cart flow around authentication.

## Local Storage

Local storage is centralized in [lib/services/service.dart](../lib/services/service.dart).

The app uses two storage layers:
- SharedPreferences for normal app state like `user`, `cart`, `logged`, and `pending_ai_cart`.
- FlutterSecureStorage for sensitive biometric credentials like saved phone and password.

In practice, the MCP cart flow uses SharedPreferences to store:
- `pending_ai_cart`
- `cart`
- `user`
- `logged`

The login flow also uses secure storage for biometric login credentials, but that is separate from cart storage.

## OTP Verification

The MCP cart screen itself does not send, verify, or manage OTP.

OTP exists in the app in other places:
- OTP-at-login is in [lib/login/login_screen.dart](../lib/login/login_screen.dart), where `generateOtpAtLogin` is used before navigating to the OTP screen.
- Forgot-password OTP is in [lib/forgot_password/forgot_password_screen.dart](../lib/forgot_password/forgot_password_screen.dart).
- There is also older/commented OTP verification code in [lib/register/components/complete_profile_form.dart](../lib/register/components/complete_profile_form.dart).

So the answer is:
- MCP cart: no direct OTP work.
- Login: yes, OTP logic exists there.
- Forgot password: yes, OTP logic exists there too.
- MCP cart only benefits indirectly because it waits for the user to authenticate before resuming.

## Short Conclusion

The MCP cart feature is a login-aware cart bridge. It checks authentication, stores a pending cart if needed, fetches the cart from the backend, reconciles it with any existing local cart, and then routes into the normal cart screen. The only OTP-related behavior is in the login flow, not in the MCP cart feature itself.