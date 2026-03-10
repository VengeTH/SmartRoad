/// * Payload for submitting a new fuel station.
/// *
/// * Used when community adds a station not yet in the system.
class FuelStationSubmission {
  final String name;
  final double latitude;
  final double longitude;
  final String? brand;
  final String province;
  final String city;
  final String? region;
  final String? photoUrl;
  final String deviceId;
  final String? userId;

  const FuelStationSubmission({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.brand,
    required this.province,
    required this.city,
    this.region,
    this.photoUrl,
    required this.deviceId,
    this.userId,
  });

  /// * Convert to JSON for API submission.
  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "latitude": latitude,
      "longitude": longitude,
      if (brand != null) "brand": brand,
      "province": province,
      "city": city,
      if (region != null) "region": region,
      if (photoUrl != null) "photo_url": photoUrl,
      "device_id": deviceId,
      if (userId != null) "user_id": userId,
    };
  }
}
