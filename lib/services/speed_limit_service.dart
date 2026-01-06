import "dart:convert";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:latlong2/latlong.dart";

import "../models/navigation_settings.dart";

/// * Where a speed limit value came from.
enum SpeedLimitSource {
  userOverride,
  osmMaxspeed,
  highwayDefault,
  unknown,
}

class SpeedLimitResult {
  final int? speedLimitKph;
  final SpeedLimitSource source;
  final String? highwayType;
  final int? wayId;
  final String? rawMaxspeed;

  const SpeedLimitResult({
    required this.speedLimitKph,
    required this.source,
    required this.highwayType,
    required this.wayId,
    required this.rawMaxspeed,
  });
}

class _OsmRoadInfo {
  final int? wayId;
  final String? highwayType;
  final int? maxspeedKph;
  final String? rawMaxspeed;
  final LatLng? center;

  const _OsmRoadInfo({
    required this.wayId,
    required this.highwayType,
    required this.maxspeedKph,
    required this.rawMaxspeed,
    required this.center,
  });
}

class _CacheEntry {
  final _OsmRoadInfo info;
  final DateTime fetchedAt;

  const _CacheEntry({
    required this.info,
    required this.fetchedAt,
  });
}

/// * Speed limit service (best-effort).
/// *
/// * Uses OpenStreetMap via Overpass to find the nearest highway and read `maxspeed`.
/// * Falls back to defaults by `highway` type when `maxspeed` is missing.
/// *
/// * NOTE:
/// * - OSM data coverage varies. Always treat returned values as best-effort.
/// * - The app supports user overrides to correct missing/incorrect limits.
class SpeedLimitService {
  static final SpeedLimitService _instance = SpeedLimitService._internal();
  factory SpeedLimitService() => _instance;
  SpeedLimitService._internal();

  static const String _defaultOverpassUrl = "https://overpass-api.de/api/interpreter";

  // * Override with: --dart-define=OVERPASS_URL=https://...
  static const String _overpassUrl = String.fromEnvironment(
    "OVERPASS_URL",
    defaultValue: _defaultOverpassUrl,
  );

  // * Cache and throttling
  static const Duration _cacheTtl = Duration(seconds: 45);
  static const Duration _failureBackoff = Duration(seconds: 25);
  DateTime? _disabledUntil;

  final Map<String, _CacheEntry> _cache = {};

  String _cacheKey(LatLng location) {
    // * ~100m-ish bucket
    final latKey = (location.latitude * 1000).round();
    final lonKey = (location.longitude * 1000).round();
    return "$latKey:$lonKey";
  }

  int? _parseMaxspeedToKph(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    final match = RegExp(r"(\d+(\.\d+)?)").firstMatch(lower);
    if (match == null) return null;

    final numeric = double.tryParse(match.group(1) ?? "");
    if (numeric == null) return null;

    final isMph = lower.contains("mph");
    final kph = isMph ? (numeric * 1.60934) : numeric;
    final rounded = kph.round();

    if (rounded <= 0 || rounded > 200) return null;
    return rounded;
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLon = _toRadians(b.longitude - a.longitude);

    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);

    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);

    final h = sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadiusM * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);

  Future<_OsmRoadInfo?> _fetchNearestRoad(LatLng location) async {
    final disabledUntil = _disabledUntil;
    if (disabledUntil != null && DateTime.now().isBefore(disabledUntil)) {
      return null;
    }

    final query = """
[out:json][timeout:10];
way(around:45,${location.latitude},${location.longitude})["highway"];
out tags center 25;
""";

    final url = Uri.parse(_overpassUrl).replace(queryParameters: {
      "data": query,
    });

    try {
      final response = await http.get(
        url,
        // ! Browsers do not allow setting User-Agent; avoid custom headers for CORS.
        headers: kIsWeb
            ? null
            : const {
                "User-Agent": "SmartRoad App (contact@smartroad.app)",
              },
      );

      if (response.statusCode != 200) {
        throw Exception("Overpass error: ${response.statusCode}");
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final elements = decoded["elements"];
      if (elements is! List) {
        return null;
      }

      _OsmRoadInfo? best;
      var bestDistance = double.infinity;

      for (final el in elements) {
        if (el is! Map) continue;

        final type = el["type"];
        if (type != "way") continue;

        final idValue = el["id"];
        final wayId = idValue is int ? idValue : (idValue is num ? idValue.toInt() : null);

        final tags = el["tags"];
        if (tags is! Map) continue;

        final highway = tags["highway"]?.toString().trim().toLowerCase();
        if (highway == null || highway.isEmpty) continue;

        final center = el["center"];
        LatLng? centerLatLng;
        if (center is Map) {
          final lat = center["lat"];
          final lon = center["lon"];
          if (lat is num && lon is num) {
            centerLatLng = LatLng(lat.toDouble(), lon.toDouble());
          }
        }

        // * If center is missing, skip to avoid nonsense distance comparisons.
        if (centerLatLng == null) continue;

        final rawMax = tags["maxspeed"]?.toString();
        final maxKph = _parseMaxspeedToKph(rawMax);

        final distance = _haversineMeters(location, centerLatLng);
        if (distance < bestDistance) {
          bestDistance = distance;
          best = _OsmRoadInfo(
            wayId: wayId,
            highwayType: highway,
            maxspeedKph: maxKph,
            rawMaxspeed: rawMax,
            center: centerLatLng,
          );
        }
      }

      return best;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [SpeedLimitService] Overpass failed: $e");
      }
      _disabledUntil = DateTime.now().add(_failureBackoff);
      return null;
    }
  }

  SpeedLimitResult _resolveWithSettings({
    required _OsmRoadInfo? info,
    required NavigationSettings settings,
  }) {
    if (info == null) {
      return const SpeedLimitResult(
        speedLimitKph: null,
        source: SpeedLimitSource.unknown,
        highwayType: null,
        wayId: null,
        rawMaxspeed: null,
      );
    }

    final wayId = info.wayId;
    if (wayId != null) {
      final override = settings.speedLimitOverridesByWayId[wayId];
      if (override != null && override > 0) {
        return SpeedLimitResult(
          speedLimitKph: override,
          source: SpeedLimitSource.userOverride,
          highwayType: info.highwayType,
          wayId: wayId,
          rawMaxspeed: info.rawMaxspeed,
        );
      }
    }

    if (settings.useOsmSpeedLimits && info.maxspeedKph != null) {
      return SpeedLimitResult(
        speedLimitKph: info.maxspeedKph,
        source: SpeedLimitSource.osmMaxspeed,
        highwayType: info.highwayType,
        wayId: info.wayId,
        rawMaxspeed: info.rawMaxspeed,
      );
    }

    final fallback = settings.defaultSpeedLimitsByHighway[info.highwayType ?? ""];
    if (fallback != null && fallback > 0) {
      return SpeedLimitResult(
        speedLimitKph: fallback,
        source: SpeedLimitSource.highwayDefault,
        highwayType: info.highwayType,
        wayId: info.wayId,
        rawMaxspeed: info.rawMaxspeed,
      );
    }

    return SpeedLimitResult(
      speedLimitKph: null,
      source: SpeedLimitSource.unknown,
      highwayType: info.highwayType,
      wayId: info.wayId,
      rawMaxspeed: info.rawMaxspeed,
    );
  }

  Future<SpeedLimitResult> getSpeedLimit({
    required LatLng location,
    required NavigationSettings settings,
  }) async {
    final key = _cacheKey(location);
    final now = DateTime.now();

    final cached = _cache[key];
    if (cached != null && now.difference(cached.fetchedAt) <= _cacheTtl) {
      return _resolveWithSettings(info: cached.info, settings: settings);
    }

    final info = await _fetchNearestRoad(location);
    if (info != null) {
      _cache[key] = _CacheEntry(info: info, fetchedAt: now);
    }

    return _resolveWithSettings(info: info, settings: settings);
  }
}

