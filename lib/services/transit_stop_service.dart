import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:latlong2/latlong.dart";

import "../utils/fuel_utils.dart";

/// * Info for a single transit stop (bus stop, jeepney stand, etc.).
class TransitStopInfo {
  final String name;
  final LatLng position;
  final double distanceMeters;

  const TransitStopInfo({
    required this.name,
    required this.position,
    required this.distanceMeters,
  });
}

/// * Fetches nearest public transport stop from OpenStreetMap Overpass API.
/// * Used for "where to hop in" in commute guide (jeepney, bus, tricycle).
class TransitStopService {
  TransitStopService._();
  static final TransitStopService instance = TransitStopService._();

  static const String _overpassUrl = "https://overpass-api.de/api/interpreter";
  static const Duration _timeout = Duration(seconds: 4);

  /// * Cache by rounded position to avoid repeated Overpass calls.
  final Map<String, _CachedResult> _cache = {};
  static const int _cacheMaxEntries = 20;
  static const Duration _cacheTtl = Duration(minutes: 5);

  String _cacheKey(LatLng position, double radiusMeters) {
    final r = (position.latitude * 1000).round() / 1000;
    final s = (position.longitude * 1000).round() / 1000;
    return "${r}_${s}_${radiusMeters.round()}";
  }

  /// * Returns the nearest transit stop to [position] within [radiusMeters].
  /// * Queries Overpass for highway=bus_stop, amenity=bus_station, public_transport=stop_position.
  Future<TransitStopInfo?> getNearestTransitStop(
    LatLng position, {
    double radiusMeters = 500,
  }) async {
    final clampedRadius = radiusMeters.clamp(100.0, 3000.0);
    final key = _cacheKey(position, clampedRadius);
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.stop;
    }

    try {
      final deg = clampedRadius / 111320.0;
      final minLat = position.latitude - deg;
      final maxLat = position.latitude + deg;
      final minLon = position.longitude - deg;
      final maxLon = position.longitude + deg;

      final bbox = "$minLat,$minLon,$maxLat,$maxLon";
      final q = '''
[out:json][timeout:10];
(
  node["highway"="bus_stop"]($bbox);
  node["amenity"="bus_stop"]($bbox);
  node["amenity"="bus_station"]($bbox);
  node["public_transport"="stop_position"]($bbox);
  node["public_transport"="stop_area"]($bbox);
  node["public_transport"="platform"]($bbox);
);
out body;
''';
      if (q.isEmpty || q.length > 2000) {
        return _cacheAndReturn(key, null);
      }

      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: "data=${Uri.encodeComponent(q)}",
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          final body = response.body.length > 400 ? "${response.body.substring(0, 400)}…" : response.body;
          debugPrint("[TransitStopService] Overpass error: status=${response.statusCode} body=$body");
        }
        return _cacheAndReturn(key, null);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = data["elements"] as List<dynamic>?;
      if (elements == null || elements.isEmpty) return _cacheAndReturn(key, null);

      TransitStopInfo? nearest;
      double minDist = double.infinity;

      for (final el in elements) {
        final map = el as Map<String, dynamic>;
        final lat = (map["lat"] as num?)?.toDouble();
        final lon = (map["lon"] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        final tags = map["tags"] as Map<String, dynamic>?;
        final name = _getName(tags);
        final stopLatLng = LatLng(lat, lon);
        final dist = FuelUtils.calculateDistance(
          position.latitude,
          position.longitude,
          lat,
          lon,
        );
        if (dist < minDist) {
          minDist = dist;
          nearest = TransitStopInfo(
            name: name,
            position: stopLatLng,
            distanceMeters: dist,
          );
        }
      }

      return _cacheAndReturn(key, nearest);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("[TransitStopService] getNearestTransitStop error: $e");
      }
      return _cacheAndReturn(key, null);
    }
  }

  TransitStopInfo? _cacheAndReturn(String key, TransitStopInfo? stop) {
    _cache[key] = _CachedResult(stop: stop, fetchedAt: DateTime.now());
    if (_cache.length > _cacheMaxEntries) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
    }
    return stop;
  }

  String _getName(Map<String, dynamic>? tags) {
    if (tags == null) return "Transit stop";
    final name = tags["name"]?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    if (tags["amenity"] == "bus_station") return "Bus station";
    if (tags["highway"] == "bus_stop") return "Bus stop";
    return "Transit stop";
  }
}

class _CachedResult {
  final TransitStopInfo? stop;
  final DateTime fetchedAt;

  _CachedResult({this.stop, required this.fetchedAt});
}
