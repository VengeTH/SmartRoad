import "fuel_type.dart";

/// * Payload for submitting fuel price updates.
/// *
/// * Used when a user updates one or more fuel prices at a station.
/// * The client sends a map of fuel types to prices; the server expands each
/// * into a row in fuel_price_updates with the following shape:
/// *
/// * - station_id, fuel_type, price, reporter_latitude, reporter_longitude,
/// *   photo_url (optional), device_id, user_id (optional)
/// * - Server sets: timestamp (created_at), source (e.g. 'community'),
/// *   confidence_score (e.g. 1.0)
class FuelPriceUpdate {
  final String stationId;
  final Map<FuelType, double> prices; // fuelType -> price
  final double reporterLatitude;
  final double reporterLongitude;
  final String? photoUrl; // optional proof photo (required if distance > 50m)
  final String deviceId; // anonymous device identifier
  final String? userId; // authenticated user ID (optional)

  const FuelPriceUpdate({
    required this.stationId,
    required this.prices,
    required this.reporterLatitude,
    required this.reporterLongitude,
    this.photoUrl,
    required this.deviceId,
    this.userId,
  });

  /// * Convert to JSON for API submission.
  Map<String, dynamic> toJson() {
    return {
      "station_id": stationId,
      "prices": prices.map((k, v) => MapEntry(k.dbKey, v)),
      "reporter_latitude": reporterLatitude,
      "reporter_longitude": reporterLongitude,
      if (photoUrl != null) "photo_url": photoUrl,
      "device_id": deviceId,
      if (userId != null) "user_id": userId,
    };
  }
}
