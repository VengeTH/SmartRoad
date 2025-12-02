/// * Application-wide constants
class AppConstants {
  // * Map Configuration
  static const double defaultLatitude = 14.4244; // STI College Las Piñas
  static const double defaultLongitude = 120.9883;
  static const double defaultZoom = 13.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 18.0;
  
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
  
  // * Routing API
  static const String routingApiUrl = 'http://localhost:3000';
}

