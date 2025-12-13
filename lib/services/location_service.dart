import "package:flutter/foundation.dart";
import "package:geolocator/geolocator.dart";
import "package:permission_handler/permission_handler.dart";

/// * Location service for getting user's current position
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  
  /// * Check and request location permissions
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.location.request();
      return status.isGranted;
    } catch (e) {
      debugPrint("❌ [LocationService] Error requesting permission: $e");
      return false;
    }
  }
  
  /// * Check if location permission is granted
  Future<bool> isPermissionGranted() async {
    try {
      final status = await Permission.location.status;
      return status.isGranted;
    } catch (e) {
      debugPrint("❌ [LocationService] Error checking permission: $e");
      return false;
    }
  }
  
  /// * Get current position
  /// * Returns null if permission denied or location unavailable
  Future<Position?> getCurrentPosition() async {
    try {
      debugPrint("📍 [LocationService] Getting current position...");
      
      // * Check if permission is granted
      final hasPermission = await isPermissionGranted();
      if (!hasPermission) {
        debugPrint("📍 [LocationService] Permission not granted, requesting...");
        final granted = await requestPermission();
        if (!granted) {
          debugPrint("❌ [LocationService] Permission denied by user");
          return null;
        }
      }
      
      // * On web, skip location service check (not always available)
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint("❌ [LocationService] Location services disabled");
          return null;
        }
      }
      
      // * Use appropriate accuracy and timeout for platform
      // * Web needs more time and lower accuracy
      final accuracy = kIsWeb ? LocationAccuracy.high : LocationAccuracy.bestForNavigation;
      final timeout = kIsWeb ? const Duration(seconds: 15) : const Duration(seconds: 10);
      
      debugPrint("📍 [LocationService] Requesting position (accuracy: $accuracy, timeout: ${timeout.inSeconds}s)...");
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );
      
      debugPrint("✅ [LocationService] Got position: ${position.latitude}, ${position.longitude}");
      return position;
    } catch (e, stackTrace) {
      debugPrint("❌ [LocationService] Error getting position: $e");
      debugPrint("❌ [LocationService] Stack: $stackTrace");
      return null;
    }
  }
  
  /// * Get last known position (cached)
  Future<Position?> getLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        debugPrint("📍 [LocationService] Got last known position: ${position.latitude}, ${position.longitude}");
      } else {
        debugPrint("📍 [LocationService] No last known position available");
      }
      return position;
    } catch (e) {
      debugPrint("❌ [LocationService] Error getting last known position: $e");
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

