/// * App-wide constants and configuration values
class AppConstants {
  AppConstants._();

  // * Hazard Types
  static const List<String> hazardTypes = [
    "pothole",
    "flood",
    "accident",
    "closure",
    "roadblock",
    "landslide",
  ];

  // * Severity Levels
  static const List<String> severityLevels = [
    "Low",
    "Medium",
    "High",
  ];

  // * Map Configuration
  static const double defaultZoom = 13.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 18.0;

  // * Storage Buckets
  static const String hazardImagesBucket = "hazard-images";
  static const String profileImagesBucket = "profile-images";

  // * Realtime Channel
  static const String hazardsChannel = "hazards";
}

