/// * Application-wide constants
class AppConstants {
  // * Map Configuration
  static const double defaultLatitude = 14.5995; // Manila default
  static const double defaultLongitude = 120.9842;
  static const double defaultZoom = 13.0;
  static const double minZoom = 6.8; // * Restrict zoom to Philippines area - more zoomed in at max zoom out
  static const double maxZoom = 18.0;
  
  // * Philippines geographic bounds
  // * Southwest corner (southernmost point)
  static const double philippinesSouth = 4.215806;
  static const double philippinesWest = 116.147499;
  // * Northeast corner (northernmost point)
  static const double philippinesNorth = 21.321780;
  static const double philippinesEast = 127.647621;
  
  // * Hazard Notification
  static const double notificationRadiusKm = 2.0; // * Notify if hazard within 2km
  
  // * Pagination
  static const int feedPageSize = 20;
  static const int maxMapMarkers = 500; // * Limit markers for performance
  
  // * Image Upload
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // * 5MB
  static const List<String> allowedImageTypes = ['image/jpeg', 'image/png', 'image/webp'];
  
  // * Storage
  static const String storageBucketName = 'hazard-images';
  
  // * Demo Account
  static const String demoEmail = 'demo@smartroad.app';
  static const String demoPassword = 'DemoPass123!';
}

