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
        final granted = await requestPermission();
        if (!granted) {
          return null;
        }
      }
      
      // * Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
      
      // * Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
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

