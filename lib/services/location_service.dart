import "dart:async";

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
      debugPrint("[LocationService] ERROR: Error requesting permission: $e");
      return false;
    }
  }

  /// * Check if location permission is granted
  Future<bool> isPermissionGranted() async {
    try {
      final status = await Permission.location.status;
      return status.isGranted;
    } catch (e) {
      debugPrint("[LocationService] ERROR: Error checking permission: $e");
      return false;
    }
  }

  /// * Get current position
  /// * Returns null if permission denied or location unavailable
  Future<Position?> getCurrentPosition({
    LocationAccuracy? desiredAccuracy,
    Duration? timeLimit,
    bool preferCached = true,
  }) async {
    try {
      // * Removed verbose logging to prevent console overflow

      // * Check if permission is granted
      final hasPermission = await isPermissionGranted();
      if (!hasPermission) {
        debugPrint("[LocationService] Permission not granted, requesting...");
        final granted = await requestPermission();
        if (!granted) {
          debugPrint("[LocationService] ERROR: Permission denied by user");
          return null;
        }
      }

      // * On web, skip location service check (not always available)
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint("[LocationService] ERROR: Location services disabled");
          return null;
        }
      }

      Position? cachedPosition;
      if (preferCached && !kIsWeb) {
        try {
          cachedPosition = await Geolocator.getLastKnownPosition();
          if (cachedPosition != null) {
            debugPrint(
              "[LocationService] Using cached position for fast response",
            );
            return cachedPosition;
          }
        } catch (_) {
          // * Ignore cached lookup errors and continue to fresh fetch.
        }
      }

      // * Use appropriate accuracy and timeout for platform
      // * Fast-first defaults to reduce location wait time.
      final accuracy =
          desiredAccuracy ??
          (kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high);
      final timeout =
          timeLimit ??
          (kIsWeb ? const Duration(seconds: 8) : const Duration(seconds: 6));

      // * Removed verbose logging to prevent console overflow

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );

      debugPrint(
        "[LocationService] OK: Got position: ${position.latitude}, ${position.longitude}",
      );
      return position;
    } on TimeoutException catch (_) {
      debugPrint("[LocationService] WARNING: Location request timed out");
      if (!kIsWeb) {
        try {
          final fallback = await Geolocator.getLastKnownPosition();
          if (fallback != null) return fallback;
        } catch (_) {
          // * Ignore and fall through to null.
        }
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint("[LocationService] ERROR: Error getting position: $e");
      debugPrint("[LocationService] ERROR: Stack: $stackTrace");
      return null;
    }
  }

  /// * Get last known position (cached)
  Future<Position?> getLastKnownPosition() async {
    // ! Geolocator does not support getLastKnownPosition on web.
    if (kIsWeb) {
      return null;
    }
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        debugPrint(
          "[LocationService] Got last known position: ${position.latitude}, ${position.longitude}",
        );
      } else {
        debugPrint("[LocationService] No last known position available");
      }
      return position;
    } catch (e) {
      debugPrint(
        "[LocationService] ERROR: Error getting last known position: $e",
      );
      return null;
    }
  }

  /// * Calculate distance between two coordinates (in km)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }
}
