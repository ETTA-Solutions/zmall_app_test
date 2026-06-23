# API Migration Plan — `http` → organized `dio`

**Goal:** Replace the scattered, boilerplate-heavy `http` calls (~88 files) with a single,
organized, `dio`-based networking layer: one configured client, interceptors for
base URL / headers / logging / errors, and thin per-feature service classes.

**Status:** Proposed (not yet started)

---

## 1. `dio` vs `http` — comparison

| Capability | `http` (current) | `dio` (target) |
|---|---|---|
| Level | Low-level HTTP | Full HTTP client / framework |
| Base URL | Manual string concat every call | `BaseOptions.baseUrl` set once |
| Default headers | Re-declared in every call | `BaseOptions.headers` set once |
| Timeouts | Manual `.timeout(...)` + `onTimeout` each call | `connectTimeout` / `receiveTimeout` once |
| Interceptors | ❌ none (no hook point) | ✅ request/response/error interceptors (auth, logging, retry, refresh) |
| JSON handling | Manual `json.encode` / `json.decode` everywhere | Auto encode/decode (`response.data` is already parsed) |
| Error model | Throws on socket only; status codes are manual | `DioException` with typed `type` (timeout, badResponse, cancel, connectionError…) |
| Query params | Manual URL building | `queryParameters:` map |
| File upload | Verbose `MultipartRequest` | `FormData` + `MultipartFile` |
| Download / progress | Manual | `dio.download()` + `onReceiveProgress` |
| Cancellation | ❌ not built-in | ✅ `CancelToken` |
| Global logging | Manual prints | One interceptor (e.g. `LogInterceptor` / `pretty_dio_logger`) |
| Retry / token refresh | Hand-rolled per call | Interceptor (centralized) |
| Bundle size / deps | Tiny, in most projects already | Slightly heavier (already a dependency here) |
| Testability | Inject `http.Client` | Inject `Dio` or swap `HttpClientAdapter` |

### When each wins
- **`http`** is fine for a handful of simple, stateless calls. Its strength is minimalism.
- **`dio`** wins as soon as you have cross-cutting concerns repeated across many endpoints —
  exactly this codebase: base URL, headers, timeouts, logging, and consistent error mapping
  are currently copy-pasted into ~88 files. `dio` lets all of that live in **one place**.

**Verdict for ZMall:** migrate to `dio`. The repeated boilerplate and inconsistent error
handling are the core problem, and interceptors solve both directly. `dio` is already in
`pubspec.yaml` (`^5.9.2`).

---

## 2. Current state (what exists today)

- **Config:** `lib/utils/constants.dart` holds `BASE_URL*` constants; runtime base URL comes
  from the `ZMetaData` provider (`Provider.of<ZMetaData>(context).baseUrl`).
- **Good pattern:** `lib/borsa/refund/refund_service.dart` — a `_post` helper with timeout and
  **structured error maps** (`{success, error_type, message}`) and an `errorCodes` lookup. This
  is the model the whole app should follow.
- **Bad pattern:** `lib/checkout/checkout_screen.dart` (and many screens) — inline
  `http.post(Uri.parse(url), headers: {...}).timeout(...)`, `json.decode`, `try/catch` mixed with
  `setState`/`showMessage`. Networking is tangled with UI.
- **Endpoints:** mix of constants (`kRefundGenerateOtpEndpoint`) and inline string URLs.
- **Uploads:** 2 files use `http.MultipartRequest`.
- **Auth:** headers are mostly `Content-Type`/`Accept`; identity is passed in the body
  (`user_id`, `phone`) rather than a bearer token. (Confirm before building an auth interceptor.)

---

## 3. Target architecture

```
lib/
  core/
    network/
      api_client.dart        # Dio instance + BaseOptions + interceptor wiring
      api_endpoints.dart     # all endpoint path constants (move kRefund*, inline URLs)
      api_result.dart        # ApiResult<T> / structured success+error type
      api_exception.dart     # maps DioException -> app error (timeout/network/server/...)
      interceptors/
        auth_interceptor.dart      # inject identity/headers (if/when tokens exist)
        logging_interceptor.dart   # debug-only request/response logging
        error_interceptor.dart     # normalize errors into ApiException
  features/
    refund/data/refund_api.dart    # thin service: calls api_client, returns models/ApiResult
    checkout/data/checkout_api.dart
    ...
```

### 3.1 The client (single source of truth)

```dart
// lib/core/network/api_client.dart
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({required String baseUrl})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          // dio parses JSON automatically; response.data is a Map/List.
        )) {
    dio.interceptors.addAll([
      // AuthInterceptor(),        // add when token auth exists
      ErrorInterceptor(),          // DioException -> ApiException
      if (kDebugMode) LoggingInterceptor(),
    ]);
  }

  final Dio dio;
}
```

> **Base URL note:** today the base URL is read from the `ZMetaData` provider at call time.
> Since `dio` sets `baseUrl` once at construction, build/provide the `ApiClient` where
> `ZMetaData` is available (e.g. create it after metadata loads, or expose it via a provider
> that depends on `ZMetaData`). If the base URL can change at runtime, update
> `dio.options.baseUrl` when `ZMetaData` changes.

### 3.2 Structured result (keep the refund pattern, make it typed)

```dart
// lib/core/network/api_result.dart
sealed class ApiResult<T> {
  const ApiResult();
}
class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}
class ApiFailure<T> extends ApiResult<T> {
  final String message;          // user-facing
  final String errorType;        // timeout | network | server | unknown
  final int? statusCode;
  const ApiFailure(this.message, {required this.errorType, this.statusCode});
}
```

### 3.3 Error normalization (one place, replaces per-call try/catch)

```dart
// lib/core/network/error_interceptor.dart  (or a helper)
ApiFailure<T> mapDioError<T>(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return ApiFailure('Connection timed out. Check your internet and try again.',
          errorType: 'timeout');
    case DioExceptionType.connectionError:
      return ApiFailure('No internet connection. Check your network and try again.',
          errorType: 'network');
    case DioExceptionType.badResponse:
      final data = e.response?.data;
      final msg = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'Something went wrong. Please try again later.';
      return ApiFailure(msg, errorType: 'server', statusCode: e.response?.statusCode);
    default:
      return ApiFailure('Something went wrong. Please try again.', errorType: 'unknown');
  }
}
```

### 3.4 A feature service (thin — no UI)

```dart
// lib/features/refund/data/refund_api.dart
class RefundApi {
  RefundApi(this._client);
  final ApiClient _client;

  Future<ApiResult<Map<String, dynamic>>> generateOtp({
    required String userId, required String phone,
  }) async {
    try {
      final res = await _client.dio.post(
        ApiEndpoints.refundGenerateOtp,
        data: {'user_id': userId, 'phone': phone},
      );
      return ApiSuccess(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}
```

UI then handles `ApiSuccess` / `ApiFailure` instead of decoding JSON and catching sockets.

### 3.5 Handling varying base URLs (e.g. payments use a different host)

`dio` sets `baseUrl` once per instance, so use one of these:

- **Option A — Named clients (recommended for a few stable hosts).** One `Dio` per host, all
  sharing the same interceptors:

  ```dart
  class ApiClients {
    ApiClients({required String mainBaseUrl, required String paymentBaseUrl})
        : main = _build(mainBaseUrl),
          payment = _build(paymentBaseUrl);

    final Dio main;
    final Dio payment;

    static Dio _build(String baseUrl) {
      final dio = Dio(BaseOptions(baseUrl: baseUrl /* timeouts, headers */));
      dio.interceptors.addAll([
        BusinessErrorInterceptor(),
        ErrorInterceptor(),
        if (kDebugMode) LoggingInterceptor(),
      ]);
      return dio;
    }
  }
  ```

- **Option B — Per-request absolute URL.** If you pass a **full URL** (with `https://`) as the
  path, `dio` ignores `baseUrl`. Good for payment endpoints whose host is dynamic/known only at
  call time:

  ```dart
  await _client.dio.post('https://pay.someprovider.com/charge', data: {...});
  ```

- **Option C — Per-request override** via `Options` / a copied `BaseOptions`.

> **Recommendation:** Option A for the handful of fixed hosts (main API, payment gateway),
> Option B for the per-provider `kifiya/*` payment endpoints whose host varies. They combine fine.

### 3.6 Handling business error codes (`999`, `2000`, …) returned with HTTP 200

Codes like `999` ("Invalid server token") and `2000` ("Token expired") in
`errorCodes` (`lib/utils/constants.dart`) are **application errors returned in the JSON body,
almost always with HTTP `200 OK`** — *not* HTTP status codes. Because the request succeeds at the
HTTP level, `dio`'s `badResponse` path does **not** fire. Catch them with a **response
interceptor** that reuses the existing `errorCodes` map:

```dart
// lib/core/network/business_error_interceptor.dart
class BusinessErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is Map && (data['success'] == false || data['error_code'] != null)) {
      final code = '${data['error_code']}';
      final message = errorCodes[code]            // map in constants.dart
          ?? (data['message'] as String?)
          ?? 'Something went wrong.';

      // Session codes get special, centralized handling:
      if (code == '999' || code == '2000') {      // invalid / expired token
        AuthEvents.instance.forceLogout(reason: message);
      }

      // Reject so callers hit the same error path as real HTTP errors:
      handler.reject(DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: ApiFailure(message, errorType: 'business', statusCode: int.tryParse(code)),
      ));
      return;
    }
    handler.next(response); // genuine success
  }
}
```

`mapDioError` then just unwraps the already-mapped failure:

```dart
ApiFailure<T> mapDioError<T>(DioException e) {
  if (e.error is ApiFailure) return e.error as ApiFailure<T>; // business error, already mapped
  // ... timeout / network / badResponse / unknown as in §3.3
}
```

**Why this is better than today:**
- The `errorCodes` → message mapping happens **once**, centrally (today only `refund_service`
  does it; most screens, e.g. `checkout`, don't).
- Session codes `999`/`2000` trigger **one** logout path instead of being silently ignored across
  dozens of screens.
- Callers uniformly receive `ApiFailure` whether the failure was HTTP-level (timeout/500) or
  business-level (`error_code: 545`).

> **Confirm with the backend:** do these codes ever arrive with a non-200 status, or always 200?
> If some endpoints return them as real 4xx, relax `validateStatus` (e.g. `(s) => true`) so the
> body still reaches `BusinessErrorInterceptor` instead of throwing as `badResponse` first.

---

## 4. Migration plan (phased, incremental — app stays shippable)

**Phase 0 — Foundation (no behavior change)**
1. Create `lib/core/network/` (client/named clients, result, error mapping, interceptors —
   including `BusinessErrorInterceptor` from §3.6).
2. Move endpoint strings into `api_endpoints.dart` (start with the `kRefund*` constants and
   the most common inline URLs).
3. Wire clients to the `ZMetaData` base URL(s) — main + payment host(s) per §3.5; add debug
   logging interceptor.
4. Unit-test `mapDioError`, `BusinessErrorInterceptor` (incl. `999`/`2000` → logout), and the
   client against a mocked adapter.

**Phase 1 — Pilot (prove the pattern)**
5. Migrate **one** well-contained feature first: `refund_service.dart` → `RefundApi`
   (it already has the right shape, lowest risk). Verify OTP/refund flows end-to-end.

**Phase 2 — High-traffic services**
6. Migrate the service-style files next: `chat_service`, `magazine_service`, `recap_service`,
   then the `kifiya/*` payment calls (group by payment provider).

**Phase 3 — Screen-embedded calls**
7. Extract inline calls out of screens (`checkout_screen`, `home_body`, `global/*`, etc.) into
   feature `*_api.dart` services, one feature at a time. This is the bulk of the ~88 files.

**Phase 4 — Special cases**
8. Convert the 2 `MultipartRequest` uploads to `FormData` + `MultipartFile`.
9. Add `CancelToken` where screens dispose mid-request (search lists, etc.).

**Phase 5 — Cleanup**
10. Remove `http` from `pubspec.yaml` once no imports remain (`grep -r "package:http/http.dart" lib`).
11. Delete dead error-handling boilerplate and inline header maps.

> Run incrementally: `http` and `dio` can coexist during the migration, so each PR migrates a
> slice and ships independently.

---

## 5. Risks & how to manage them

- **Base-URL timing:** `dio.baseUrl` is set once; ensure `ApiClient` is created/updated after
  `ZMetaData` resolves. Mitigation: provider-scoped client or update `dio.options.baseUrl`.
- **Response shape differences:** with `http` you call `json.decode(response.body)`; with `dio`,
  `response.data` is **already decoded**. Don't double-decode. Audit each migrated call.
- **Status-code behavior:** `http` does not throw on 4xx/5xx; `dio` throws `badResponse` by
  default. Decide per endpoint whether non-2xx is an error or a payload to read
  (`validateStatus` can be relaxed if some endpoints return business errors with 4xx).
- **Large surface area (88 files):** mitigate with the phased approach and the pilot; keep PRs
  small and feature-scoped.
- **Behavior parity:** preserve the existing structured error contract
  (`success`/`error_type`/`message` + `errorCodes` map) so UI code doesn't have to change all at
  once.

---

## 6. Effort estimate (rough)

| Phase | Scope | Effort |
|---|---|---|
| 0 Foundation | core/network + tests | ~0.5–1 day |
| 1 Pilot | refund | ~0.5 day |
| 2 Services | chat, magazine, recap, kifiya | ~2–3 days |
| 3 Screens | ~88 call sites across features | ~4–6 days |
| 4 Special | uploads, cancellation | ~0.5–1 day |
| 5 Cleanup | remove http, dead code | ~0.5 day |

---

## 7. Definition of done

- [ ] No `package:http/http.dart` imports remain in `lib/` (or only intentionally documented ones).
- [ ] All endpoints live in `api_endpoints.dart`.
- [ ] All requests go through the configured client(s); base URL/headers/timeouts/logging are set once (multiple hosts handled per §3.5).
- [ ] Errors are normalized via the interceptors/`mapDioError`; business codes from `errorCodes` (incl. `999`/`2000` session handling) map centrally; UI consumes `ApiResult`.
- [ ] Uploads use `FormData`; long-lived screens use `CancelToken`.
- [ ] `http` removed from `pubspec.yaml`.
