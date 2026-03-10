import "dart:math" as math;

import "package:latlong2/latlong.dart";

/// * Utility functions for fuel feature.
class FuelUtils {
  FuelUtils._();

  /// * Format relative time (e.g., "2h ago", "5m ago", "just now").
  /// *
  /// * Used for displaying "Updated X ago" on fuel prices.
  static String formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return "just now";
    } else if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return "${minutes}m ago";
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      return "${hours}h ago";
    } else if (diff.inDays < 7) {
      final days = diff.inDays;
      return days == 1 ? "1 day ago" : "$days days ago";
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? "1 week ago" : "$weeks weeks ago";
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return months == 1 ? "1 month ago" : "$months months ago";
    } else {
      final years = (diff.inDays / 365).floor();
      return years == 1 ? "1 year ago" : "$years years ago";
    }
  }

  /// * Check if a price is stale (older than 24 hours).
  static bool isPriceStale(DateTime timestamp) {
    final now = DateTime.now();
    return now.difference(timestamp).inHours >= 24;
  }

  /// * Calculate distance in meters between two coordinates.
  /// *
  /// * Uses Haversine formula for accuracy.
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// * Calculate distance from LatLng objects.
  static double calculateDistanceLatLng(LatLng point1, LatLng point2) {
    return calculateDistance(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// * Validate distance rules for fuel price updates.
  /// *
  /// * Returns validation result with:
  /// * - `allowed`: true if update is allowed
  /// * - `requiresPhoto`: true if photo proof is required
  /// * - `message`: user-facing error message if not allowed
  static FuelDistanceValidation validateDistance(double distanceMeters) {
    if (distanceMeters <= 50) {
      return FuelDistanceValidation(allowed: true, requiresPhoto: false);
    } else if (distanceMeters <= 200) {
      return FuelDistanceValidation(allowed: true, requiresPhoto: true);
    } else {
      return FuelDistanceValidation(
        allowed: false,
        requiresPhoto: false,
        message: "You must be within 200m of the station to update prices.",
      );
    }
  }

  /// * Format price with currency (e.g., "₱65.50").
  static String formatPrice(double price) {
    return "₱${price.toStringAsFixed(2)}";
  }

  /// * Format confidence score as percentage (e.g., "85%").
  static String formatConfidence(double confidence) {
    final percentage = (confidence * 100).round();
    return "$percentage%";
  }

  /// * Get display label for price source (e.g. "Community Report", "SmartRoad").
  static String getSourceDisplayLabel(String source) {
    switch (source.toLowerCase()) {
      case "community":
        return "Community Report";
      case "smartroad":
        return "SmartRoad";
      case "verified":
        return "Verified";
      case "official":
        return "Official";
      case "osm":
        return "OSM";
      case "default":
        return "Regional default";
      default:
        return "Community Report";
    }
  }

  /// * Get confidence label for UI display.
  static String getConfidenceLabel(double confidence) {
    if (confidence >= 0.9) {
      return "High confidence";
    } else if (confidence >= 0.7) {
      return "Moderate confidence";
    } else if (confidence >= 0.5) {
      return "Low confidence";
    } else {
      return "Uncertain";
    }
  }

  /// * Get confidence color indicator (for badges/labels).
  static ConfidenceColor getConfidenceColor(double confidence) {
    if (confidence >= 0.9) {
      return ConfidenceColor.high;
    } else if (confidence >= 0.7) {
      return ConfidenceColor.moderate;
    } else if (confidence >= 0.5) {
      return ConfidenceColor.low;
    } else {
      return ConfidenceColor.uncertain;
    }
  }
}

/// * Distance validation result.
class FuelDistanceValidation {
  final bool allowed;
  final bool requiresPhoto;
  final String? message;

  const FuelDistanceValidation({
    required this.allowed,
    required this.requiresPhoto,
    this.message,
  });
}

/// * Confidence color indicator.
enum ConfidenceColor { high, moderate, low, uncertain }
