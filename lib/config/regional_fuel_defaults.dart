import "../models/fuel_price.dart";
import "../models/fuel_type.dart";

/// * Regional default fuel prices used when a station has no community-reported prices.
/// *
/// * Provides at least one display value per station (e.g. "Regional default ~₱XX")
/// * so the card "has a value" until someone submits real prices. Replace placeholder
/// * numbers with DOE or manual updates as needed.
class RegionalFuelDefaults {
  RegionalFuelDefaults._();

  /// * Default prices per fuel type by region/province key.
  /// * Keys: "NCR", "Quezon", "default" (fallback). Values in PHP per liter.
  static const Map<String, Map<FuelType, double>> _defaultsByRegion = {
    "NCR": {
      FuelType.unleaded91: 58.50,
      FuelType.unleaded95: 65.20,
      FuelType.unleaded97: 68.00,
      FuelType.diesel: 52.80,
    },
    "Quezon": {
      FuelType.unleaded91: 57.80,
      FuelType.unleaded95: 64.50,
      FuelType.unleaded97: 67.20,
      FuelType.diesel: 52.00,
    },
    "default": {
      FuelType.unleaded91: 58.00,
      FuelType.unleaded95: 64.80,
      FuelType.unleaded97: 67.50,
      FuelType.diesel: 52.50,
    },
  };

  /// * Normalize province/region to a key used in [_defaultsByRegion].
  static String _regionKey(String province, String? region) {
    final p = province.trim();
    final r = (region ?? "").trim();
    final combined = "$p $r".toLowerCase();
    if (combined.contains("metro manila") ||
        combined.contains("ncr") ||
        combined.contains("national capital")) {
      return "NCR";
    }
    if (combined.contains("quezon") && !combined.contains("city")) {
      return "Quezon";
    }
    return "default";
  }

  /// * Returns synthetic [FuelPrice] list for display when a station has no prices.
  /// *
  /// * Uses [province] and [region] to pick regional defaults; uses "default" when
  /// * neither matches. Prices use source "default", low confidence, and today's date.
  static List<FuelPrice> getDefaultPricesForStation(String province, String? region) {
    final key = _regionKey(province, region);
    final map = _defaultsByRegion[key] ?? _defaultsByRegion["default"]!;
    final now = DateTime.now();
    return map.entries.map((e) {
      return FuelPrice(
        fuelType: e.key,
        price: e.value,
        updatedAt: now,
        source: "default",
        confidenceScore: 0.3,
        isStale: false,
      );
    }).toList();
  }
}
