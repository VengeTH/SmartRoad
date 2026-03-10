/// * Fuel type enumeration for supported fuel types in the Philippines.
enum FuelType {
  unleaded91,
  unleaded95,
  unleaded97,
  diesel;

  /// * Display name for UI.
  String get displayName {
    switch (this) {
      case FuelType.unleaded91:
        return "Unleaded 91";
      case FuelType.unleaded95:
        return "Unleaded 95";
      case FuelType.unleaded97:
        return "Unleaded 97";
      case FuelType.diesel:
        return "Diesel";
    }
  }

  /// * Short label for compact UI.
  String get shortLabel {
    switch (this) {
      case FuelType.unleaded91:
        return "91";
      case FuelType.unleaded95:
        return "95";
      case FuelType.unleaded97:
        return "97";
      case FuelType.diesel:
        return "Diesel";
    }
  }

  /// * Database column name or key.
  String get dbKey {
    switch (this) {
      case FuelType.unleaded91:
        return "unleaded_91";
      case FuelType.unleaded95:
        return "unleaded_95";
      case FuelType.unleaded97:
        return "unleaded_97";
      case FuelType.diesel:
        return "diesel";
    }
  }

  /// * Parse from database key.
  static FuelType? fromDbKey(String key) {
    switch (key) {
      case "unleaded_91":
        return FuelType.unleaded91;
      case "unleaded_95":
        return FuelType.unleaded95;
      case "unleaded_97":
        return FuelType.unleaded97;
      case "diesel":
        return FuelType.diesel;
      default:
        return null;
    }
  }
}
