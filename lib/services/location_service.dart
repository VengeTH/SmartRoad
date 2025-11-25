import "package:geolocator/geolocator.dart";
import "package:permission_handler/permission_handler.dart";

/// * Location service for getting user's current position
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  
  /// * Check and request location permissions
  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }
  
  /// * Check if location permission is granted
  Future<bool> isPermissionGranted() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }
  
  /// * Get current position
  /// * Returns null if permission denied or location unavailable
  Future<Position?> getCurrentPosition() async {
    try {
      // * Check if permission is granted
      final hasPermission = await isPermissionGranted();
      if (!hasPermission) {
        print("📍 [LocationService] Permission not granted, requesting...");
        final granted = await requestPermission();
        if (!granted) {
          print("📍 [LocationService] Permission denied by user");
          return null;
        }
        print("📍 [LocationService] Permission granted");
      }
      
      // * Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("📍 [LocationService] Location services not enabled");
        return null;
      }
      
      print("📍 [LocationService] Getting current position...");
      // * Get current position with better error handling
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      print("📍 [LocationService] Position obtained: ${position.latitude}, ${position.longitude}");
      return position;
    } catch (e, stackTrace) {
      print("❌ [LocationService] Error getting position: $e");
      print("❌ [LocationService] Stack: $stackTrace");
      
      // * Try to get last known position as fallback
      try {
        print("📍 [LocationService] Trying last known position...");
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          print("📍 [LocationService] Using last known position: ${lastKnown.latitude}, ${lastKnown.longitude}");
          return lastKnown;
        }
      } catch (e2) {
        print("❌ [LocationService] Error getting last known position: $e2");
      }
      
      return null;
    }
  }
  
  /// * Get last known position (cached)
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }
  
  /// * Calculate distance between two coordinates (in km)
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }
}

