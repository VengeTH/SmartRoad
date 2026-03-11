import "../models/commute_state.dart";

/// * In-app fare reference for commute cost estimate (LTFRB-style).
/// * Segment-based estimates; update when LTFRB publishes new matrices.
/// * Used when vehicle type is jeepney, bus, or tricycle. Not for car/motorcycle/walking.
class CommuteFareReference {
  CommuteFareReference._();

  /// * Jeepney: ~15 PHP first 4 km, then ~2.50 PHP per km (LTFRB-style segment).
  static const double _jeepneyFirstKm = 4.0;
  static const int _jeepneyFirstFare = 15;
  static const double _jeepneyPerKmAfter = 2.5;

  /// * Bus: higher base and per-km (approximate).
  static const double _busFirstKm = 5.0;
  static const int _busFirstFare = 25;
  static const double _busPerKmAfter = 3.0;

  /// * Tricycle: short trips, base + per km.
  static const int _tricycleBase = 10;
  static const double _tricyclePerKm = 2.0;

  /// * Returns estimated fare in PHP for the given distance and vehicle type.
  /// * Only jeepney, bus, tricycle are supported; returns 0 for car/motorcycle/walking.
  static int estimateFare(double distanceKm, VehicleType vehicleType) {
    if (distanceKm <= 0) return 0;
    switch (vehicleType) {
      case VehicleType.jeepney:
        if (distanceKm <= _jeepneyFirstKm) return _jeepneyFirstFare;
        final after = distanceKm - _jeepneyFirstKm;
        return _jeepneyFirstFare + (after * _jeepneyPerKmAfter).ceil();
      case VehicleType.bus:
        if (distanceKm <= _busFirstKm) return _busFirstFare;
        final after = distanceKm - _busFirstKm;
        return _busFirstFare + (after * _busPerKmAfter).ceil();
      case VehicleType.tricycle:
        return _tricycleBase + (distanceKm * _tricyclePerKm).ceil();
      case VehicleType.car:
      case VehicleType.motorcycle:
      case VehicleType.walking:
        return 0;
    }
  }

  /// * True if the vehicle type has a fare estimate (jeepney, bus, tricycle).
  static bool hasFareEstimate(VehicleType vehicleType) {
    switch (vehicleType) {
      case VehicleType.jeepney:
      case VehicleType.bus:
      case VehicleType.tricycle:
        return true;
      case VehicleType.car:
      case VehicleType.motorcycle:
      case VehicleType.walking:
        return false;
    }
  }

  /// * Returns (minPhp, maxPhp) for the given distance and vehicle (LTFRB-style with margin).
  /// * Lower bound ~0.85x point estimate; upper bound ~1.2x for variability.
  static ({int minPhp, int maxPhp}) estimateFareRange(double distanceKm, VehicleType vehicleType) {
    final point = estimateFare(distanceKm, vehicleType);
    if (point <= 0) return (minPhp: 0, maxPhp: 0);
    final minPhp = (point * 0.85).floor().clamp(1, point);
    final maxPhp = (point * 1.2).ceil().clamp(point, 9999);
    return (minPhp: minPhp, maxPhp: maxPhp);
  }
}
