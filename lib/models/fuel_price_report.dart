import "fuel_type.dart";

/// * Report for incorrect fuel pricing.
/// *
/// * Used when community members flag inaccurate prices.
class FuelPriceReport {
  final String id;
  final String stationId;
  final FuelType fuelType;
  final double reportedIncorrectPrice;
  final String? reason;
  final String deviceId;
  final String? userId;
  final DateTime createdAt;
  final String status; // "pending", "reviewed", "dismissed"

  const FuelPriceReport({
    required this.id,
    required this.stationId,
    required this.fuelType,
    required this.reportedIncorrectPrice,
    this.reason,
    required this.deviceId,
    this.userId,
    required this.createdAt,
    required this.status,
  });

  /// * Build from Supabase JSON.
  factory FuelPriceReport.fromJson(Map<String, dynamic> json) {
    final id = (json["id"] ?? "").toString();
    final stationId = (json["station_id"] ?? "").toString();

    final fuelTypeKey = json["fuel_type"] as String? ?? "";
    final fuelType = FuelType.fromDbKey(fuelTypeKey) ?? FuelType.unleaded91;

    final priceRaw = json["reported_incorrect_price"];
    final reportedIncorrectPrice =
        (priceRaw is num) ? priceRaw.toDouble() : 0.0;

    final reason = json["reason"] as String?;
    final deviceId = json["device_id"] as String? ?? "";
    final userId = json["user_id"] as String?;

    final createdAtRaw = json["created_at"] as String?;
    final createdAt =
        (createdAtRaw != null)
            ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
            : DateTime.now();

    final status = json["status"] as String? ?? "pending";

    return FuelPriceReport(
      id: id,
      stationId: stationId,
      fuelType: fuelType,
      reportedIncorrectPrice: reportedIncorrectPrice,
      reason: reason,
      deviceId: deviceId,
      userId: userId,
      createdAt: createdAt,
      status: status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "station_id": stationId,
      "fuel_type": fuelType.dbKey,
      "reported_incorrect_price": reportedIncorrectPrice,
      if (reason != null) "reason": reason,
      "device_id": deviceId,
      if (userId != null) "user_id": userId,
      "created_at": createdAt.toIso8601String(),
      "status": status,
    };
  }
}
