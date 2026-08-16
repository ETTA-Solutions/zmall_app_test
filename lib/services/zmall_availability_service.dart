import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zmall/utils/backend_logger.dart';
import 'package:zmall/utils/constants.dart';

/// Result of one product's availability check from Odoo.
class ZmallProductAvailability {
  const ZmallProductAvailability({
    required this.productId,
    required this.quantity,
    required this.available,
    this.forecastedQuantity,
    this.error,
  });

  factory ZmallProductAvailability.fromJson(Map<String, dynamic> json) {
    var forecasted = json["forecasted_quantity"];
    return ZmallProductAvailability(
      productId: json["product_id"],
      quantity: json["quantity"],
      available: json["available"] ?? false,
      forecastedQuantity: forecasted is num
          ? forecasted.toDouble()
          : forecasted == null
              ? null
              : double.tryParse(forecasted.toString()),
      error: json["error"],
    );
  }

  final int productId;
  final int quantity;
  final bool available;
  final double? forecastedQuantity;
  final String? error;
}

/// Result of the whole /zmall_order/<branch_slug> request.
class ZmallAvailabilityResult {
  const ZmallAvailabilityResult({
    required this.success,
    required this.canCheckout,
    this.branch,
    this.products = const [],
    this.error,
  });

  factory ZmallAvailabilityResult.fromJson(Map<String, dynamic> json) {
    return ZmallAvailabilityResult(
      success: json["success"] ?? false,
      branch: json["branch"],
      canCheckout: json["can_checkout"] ?? false,
      products: json["products"] == null
          ? const []
          : (json["products"] as List)
              .map((e) => ZmallProductAvailability.fromJson(e))
              .toList(),
      error: json["error"],
    );
  }

  final bool success;
  final String? branch;
  final bool canCheckout;
  final List<ZmallProductAvailability> products;
  final String? error;

  List<ZmallProductAvailability> get unavailableProducts =>
      products.where((p) => !p.available).toList();
}

/// Branch-scoped forecasted inventory check against the Odoo server.
/// See docs/superpowers/specs/2026-08-11-zmall-branch-availability-design.md
class ZmallAvailabilityService {
  static Future<ZmallAvailabilityResult?> check({
    required String branchSlug,
    required List<Map<String, dynamic>> products,
    int timeoutSeconds = 15,
  }) async {
    var url = "$kZmallOdooBaseUrl/zmall_order/$branchSlug";
    var body = json.encode({"products": products});

    try {
      BackendLogger.request(
        method: 'POST',
        url: url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );

      BackendLogger.response(
        method: 'POST',
        url: url,
        statusCode: response.statusCode,
        body: response.body,
      );

      if (response.statusCode != 200) {
        Map<String, dynamic>? json;
        try {
          json = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        return ZmallAvailabilityResult(
          success: false,
          canCheckout: false,
          error: json?["error"] ??
              "Availability check failed (HTTP ${response.statusCode})",
        );
      }

      return ZmallAvailabilityResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      BackendLogger.error(method: 'POST', url: url, error: e);
      return null;
    }
  }
}