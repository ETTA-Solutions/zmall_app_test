import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zmall/services/address_validation_service.dart';

/// Pickup order and trip totals for a combo delivery.
class ComboRoute {
  ComboRoute({
    required this.originStoreId,
    required this.waypointStoreId,
    required this.totalDistance,
    required this.totalTime,
    required this.fromFallback,
  });

  /// Picked up first; sent as `store_a`.
  final String originStoreId;

  /// Picked up second; sent as `store_b`.
  final String waypointStoreId;

  /// Meters, whole trip (origin -> waypoint -> customer).
  final double totalDistance;

  /// Seconds, whole trip.
  final double totalTime;

  final bool fromFallback;
}

/// The farther store from the customer is the origin. The store-to-store leg
/// is the same both ways, so ending at the nearer store gives the shorter trip.
Future<ComboRoute> computeComboRoute({
  required String storeIdX,
  required double xLat,
  required double xLng,
  required String storeIdY,
  required double yLat,
  required double yLng,
  required double custLat,
  required double custLng,
  required String apiKey,
}) async {
  final dx = AddressValidationService.calculateDistanceInMeters(
    xLat,
    xLng,
    custLat,
    custLng,
  );
  final dy = AddressValidationService.calculateDistanceInMeters(
    yLat,
    yLng,
    custLat,
    custLng,
  );
  final xIsOrigin = dx >= dy;

  final originId = xIsOrigin ? storeIdX : storeIdY;
  final waypointId = xIsOrigin ? storeIdY : storeIdX;
  final oLat = xIsOrigin ? xLat : yLat, oLng = xIsOrigin ? xLng : yLng;
  final wLat = xIsOrigin ? yLat : xLat, wLng = xIsOrigin ? yLng : xLng;

  try {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${oLat.toStringAsFixed(6)},${oLng.toStringAsFixed(6)}'
        '&destination=$custLat,$custLng'
        '&waypoints=${wLat.toStringAsFixed(6)},${wLng.toStringAsFixed(6)}'
        '&mode=driving&key=$apiKey';
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    final data = json.decode(response.body);
    if (data['status'] == 'OK') {
      final legs = data['routes'][0]['legs'] as List;
      double distance = 0, time = 0;
      for (final leg in legs) {
        distance += (leg['distance']['value'] as num).toDouble();
        time += (leg['duration']['value'] as num).toDouble();
      }
      return ComboRoute(
        originStoreId: originId,
        waypointStoreId: waypointId,
        totalDistance: distance,
        totalTime: time,
        fromFallback: false,
      );
    }
  } catch (_) {}

  // Fallback: two straight-line legs, ~2 min per km (same as checkout).
  final distance =
      AddressValidationService.calculateDistanceInMeters(
        oLat,
        oLng,
        wLat,
        wLng,
      ) +
      AddressValidationService.calculateDistanceInMeters(
        wLat,
        wLng,
        custLat,
        custLng,
      );
  return ComboRoute(
    originStoreId: originId,
    waypointStoreId: waypointId,
    totalDistance: distance,
    totalTime: distance / 1000 * 120,
    fromFallback: true,
  );
}
