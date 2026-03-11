import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import '../models/map_poi.dart';

/// * Fetches ambient map landmarks from the OpenStreetMap Overpass API.
/// *
/// * Unlike Nominatim keyword search, Overpass queries by OSM *tag categories*
/// * (amenity, shop, tourism, etc.) within a bounding box — the same approach
/// * used by Google Maps for ambient POI display.
/// *
/// * API: https://overpass-api.de/api/interpreter (free, no key required)
/// * Rate limit: be conservative — caller must debounce and cache.
class OverpassPoiService {
  static final OverpassPoiService _instance = OverpassPoiService._internal();
  factory OverpassPoiService() => _instance;
  OverpassPoiService._internal();

  static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static const bool _enableWebOverpassPoi = bool.fromEnvironment(
    'ENABLE_OVERPASS_WEB_POI',
    defaultValue: false,
  );
  static const bool _enableWebOverpassFuel = bool.fromEnvironment(
    'ENABLE_OVERPASS_WEB_FUEL',
    defaultValue: true,
  );
  static const Duration _cacheTtl = Duration(seconds: 45);
  static const Duration _minNetworkGap = Duration(milliseconds: 1200);
  static const Duration _fallbackRateLimitCooldown = Duration(seconds: 45);
  static const int _maxCacheEntries = 36;
  final Map<String, _CachedPoiResponse> _responseCache = {};
  DateTime? _cooldownUntil;
  DateTime? _lastNetworkAttemptAt;

  // ---------------------------------------------------------------------------
  // * Zoom-tiered tag filters — mirrors Google Maps landmark density.
  // * BBOX is replaced at runtime with south,west,north,east coordinates.
  // ---------------------------------------------------------------------------

  /// * zoom 10–11: major landmarks only (hospitals, malls, bus terminals, airports)
  static const _tierMajor = r'''
nwr["amenity"~"^(hospital|bus_station|ferry_terminal)$"](BBOX);
nwr["shop"~"^(mall|department_store|supermarket)$"](BBOX);
nwr["tourism"~"^(attraction|museum|zoo|theme_park|aquarium)$"](BBOX);
nwr["aeroway"="aerodrome"](BBOX);
''';

  /// * zoom 12–13: + everyday services (schools, banks, fuel, hotels)
  static const _tierMid = r'''
nwr["amenity"~"^(hospital|bus_station|ferry_terminal|school|university|college|bank|fuel|police|fire_station|library|cinema|theatre|place_of_worship)$"](BBOX);
nwr["shop"~"^(mall|department_store|supermarket)$"](BBOX);
nwr["tourism"~"^(attraction|museum|zoo|theme_park|aquarium|hotel|hostel|guest_house)$"](BBOX);
nwr["aeroway"="aerodrome"](BBOX);
''';

  /// * zoom 14+: fine-grained POIs (restaurants, ATMs, pharmacies, parks, etc.)
  static const _tierFine = r'''
nwr["amenity"~"^(hospital|bus_station|ferry_terminal|school|university|college|bank|fuel|police|fire_station|library|cinema|theatre|place_of_worship|restaurant|fast_food|cafe|pharmacy|atm|parking|post_office|marketplace|community_centre|courthouse|embassy)$"](BBOX);
nwr["shop"~"^(mall|department_store|supermarket|convenience|bakery|electronics|hardware)$"](BBOX);
nwr["tourism"~"^(attraction|museum|zoo|theme_park|aquarium|hotel|hostel|guest_house|motel|viewpoint|information)$"](BBOX);
nwr["leisure"~"^(park|stadium|sports_centre|golf_course|swimming_pool|water_park)$"](BBOX);
nwr["aeroway"="aerodrome"](BBOX);
''';

  // ---------------------------------------------------------------------------
  // * Public API
  // ---------------------------------------------------------------------------

  /// * Fetches POIs within [bounds] appropriate for the given [zoom] level.
  /// * Returns an empty list on error (fail-silently for map display).
  Future<List<MapPoi>> fetchInBounds({
    required LatLngBounds bounds,
    required double zoom,
    int limit = 60,
  }) async {
    if (kIsWeb && !_enableWebOverpassPoi) {
      return [];
    }

    final cacheKey = _buildCacheKey(bounds: bounds, zoom: zoom, limit: limit);
    final cached = _responseCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <= _cacheTtl) {
      return cached.items;
    }

    final tier =
        zoom >= 14.0
            ? _tierFine
            : zoom >= 12.0
            ? _tierMid
            : _tierMajor;

    return _fetchByTagLines(
      bounds: bounds,
      tagLines: tier,
      cacheKey: _buildCacheKey(bounds: bounds, zoom: zoom, limit: limit),
      limit: limit,
      debugLabel: 'POIs at zoom $zoom',
      fuelBoostByCategory: true,
    );
  }

  /// * Fetches only fuel POIs within [bounds].
  /// * Used by the fuel list screen to avoid broad POI queries dropping stations.
  Future<List<MapPoi>> fetchFuelInBounds({
    required LatLngBounds bounds,
    int limit = 200,
  }) async {
    if (kIsWeb && !_enableWebOverpassFuel) {
      return [];
    }

    const fuelOnly = r'''
nwr["amenity"="fuel"](BBOX);
''';

    return _fetchByTagLines(
      bounds: bounds,
      tagLines: fuelOnly,
      cacheKey: '${_buildCacheKey(bounds: bounds, zoom: 99, limit: limit)}:fuel',
      limit: limit,
      debugLabel: 'fuel POIs',
      fuelBoostByCategory: false,
    );
  }

  Future<List<MapPoi>> _fetchByTagLines({
    required LatLngBounds bounds,
    required String tagLines,
    required String cacheKey,
    required int limit,
    required String debugLabel,
    required bool fuelBoostByCategory,
  }) async {
    final cached = _responseCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <= _cacheTtl) {
      return cached.items;
    }

    // * Overpass bounding box convention: south,west,north,east
    final bbox =
        '${bounds.south},${bounds.west},${bounds.north},${bounds.east}';
    final renderedTagLines = tagLines.replaceAll('BBOX', bbox);
    final query =
      '[out:json][timeout:10];\n(\n$renderedTagLines);\nout center $limit;';

    try {
      final response = await _firstSuccessfulResponse(query);

      if (response == null) {
        return [];
      }

      if (response.statusCode != 200) {
        if (kDebugMode) {
          final body = response.body.length > 400 ? "${response.body.substring(0, 400)}…" : response.body;
          debugPrint("[OverpassPoiService] Overpass error: status=$response.statusCode body=$body");
        }
        return [];
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map || decoded['elements'] is! List) return [];

      final elements = decoded['elements'] as List;
      final results = <MapPoi>[];

      for (final el in elements) {
        if (el is! Map) continue;

        // * Nodes have lat/lon directly; ways/relations have a 'center' object.
        final double? lat =
            (el['lat'] as num?)?.toDouble() ??
            ((el['center'] as Map?)?['lat'] as num?)?.toDouble();
        final double? lon =
            (el['lon'] as num?)?.toDouble() ??
            ((el['center'] as Map?)?['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        final tags = (el['tags'] as Map?) ?? {};
        String name = (tags['name'] ?? tags['name:en'] ?? '').toString().trim();
        final category = _categoryFromTags(tags);
        // * For fuel stations, prefer brand over name so "NTN" shows instead of building name "South Emerald"
        if (category == 'fuel') {
          final brand = (tags['brand'] ?? '').toString().trim();
          if (brand.isNotEmpty) name = brand;
        }
        if (name.isEmpty) continue;

        final id = 'overpass:${el['type']}:${el['id']}';
        final addressLine = _buildAddressLine(tags);

        // * Assign importance proxy based on zoom tier (major = higher priority).
        // * Fuel POIs get a boost so gas stations win over nearby malls/shops.
        const baseImportance = 0.6;
        final importance =
          fuelBoostByCategory && category == "fuel"
            ? (baseImportance + 0.25)
            : baseImportance;

        results.add(
          MapPoi(
            id: id,
            name: name,
            latitude: lat,
            longitude: lon,
            type: category,
            category: category,
            importance: importance,
            addressLine: addressLine,
          ),
        );
      }

      debugPrint(
        '✅ [OverpassPoiService] Fetched ${results.length} $debugLabel',
      );

      if (results.isNotEmpty) {
        _responseCache[cacheKey] = _CachedPoiResponse(
          items: results,
          fetchedAt: DateTime.now(),
        );
        if (_responseCache.length > _maxCacheEntries) {
          _responseCache.remove(_responseCache.keys.first);
        }
      }
      return results;
    } catch (e) {
      debugPrint('❌ [OverpassPoiService] fetchInBounds failed: $e');
      return [];
    }
  }

  Future<http.Response?> _firstSuccessfulResponse(String query) async {
    final now = DateTime.now();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      return null;
    }

    http.Response? firstNonNull;
    for (final endpoint in _endpoints) {
      if (_lastNetworkAttemptAt != null) {
        final elapsed = DateTime.now().difference(_lastNetworkAttemptAt!);
        if (elapsed < _minNetworkGap) {
          await Future<void>.delayed(_minNetworkGap - elapsed);
        }
      }

      final response = await _postToEndpoint(endpoint, query);
      _lastNetworkAttemptAt = DateTime.now();
      if (response != null) {
        if (response.statusCode == 429) {
          final retryAfterSeconds =
              int.tryParse(response.headers['retry-after'] ?? '');
          final cooldown =
              retryAfterSeconds != null && retryAfterSeconds > 0
                  ? Duration(seconds: retryAfterSeconds)
                  : _fallbackRateLimitCooldown;
          _cooldownUntil = DateTime.now().add(cooldown);
          continue;
        }
        firstNonNull ??= response;
        if (response.statusCode == 200) {
          _cooldownUntil = null;
          return response;
        }
      }
    }

    return firstNonNull;
  }

  Future<http.Response?> _postToEndpoint(String endpoint, String query) async {
    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers:
                kIsWeb
                    ? {'Content-Type': 'application/x-www-form-urlencoded'}
                    : {
                      'Content-Type': 'application/x-www-form-urlencoded',
                      'User-Agent': 'SmartRoad App (contact@smartroad.app)',
                    },
            body: 'data=${Uri.encodeComponent(query)}',
          )
          .timeout(const Duration(seconds: 7));
      return response;
    } catch (_) {
      return null;
    }
  }

  String _buildCacheKey({
    required LatLngBounds bounds,
    required double zoom,
    required int limit,
  }) {
    final z = zoom.floor();
    final s = (bounds.south * 1000).round();
    final w = (bounds.west * 1000).round();
    final n = (bounds.north * 1000).round();
    final e = (bounds.east * 1000).round();
    return '$z:$limit:$s:$w:$n:$e';
  }

  // ---------------------------------------------------------------------------
  // * Tag → category mapping
  // ---------------------------------------------------------------------------

  /// * Maps OSM tags to a simplified category string used for icon/color lookup.
  String _categoryFromTags(Map tags) {
    final amenity = tags['amenity']?.toString() ?? '';
    final shop = tags['shop']?.toString() ?? '';
    final tourism = tags['tourism']?.toString() ?? '';
    final leisure = tags['leisure']?.toString() ?? '';
    final aeroway = tags['aeroway']?.toString() ?? '';

    if (aeroway == 'aerodrome') return 'airport';
    if (amenity == 'hospital') return 'hospital';
    if (amenity == 'bus_station' || amenity == 'ferry_terminal') {
      return 'terminal';
    }
    if (amenity == 'school' ||
        amenity == 'university' ||
        amenity == 'college') {
      return 'school';
    }
    if (amenity == 'bank') return 'bank';
    if (amenity == 'atm') return 'atm';
    if (amenity == 'fuel') return 'fuel';
    if (amenity == 'pharmacy') return 'pharmacy';
    if (amenity == 'police') return 'police';
    if (amenity == 'fire_station') return 'fire_station';
    if (amenity == 'library') return 'library';
    if (amenity == 'cinema' || amenity == 'theatre') return 'entertainment';
    if (amenity == 'place_of_worship') return 'worship';
    if (amenity == 'restaurant' ||
        amenity == 'fast_food' ||
        amenity == 'cafe') {
      return 'restaurant';
    }
    if (amenity == 'parking') return 'parking';
    if (amenity == 'post_office') return 'post_office';
    if (amenity == 'marketplace') return 'market';
    if (shop == 'mall' || shop == 'department_store') return 'mall';
    if (shop == 'supermarket') return 'supermarket';
    if (shop.isNotEmpty) return 'shop';
    if (tourism == 'hotel' ||
        tourism == 'hostel' ||
        tourism == 'guest_house' ||
        tourism == 'motel') {
      return 'hotel';
    }
    if (tourism == 'museum') return 'museum';
    if (tourism == 'attraction' ||
        tourism == 'viewpoint' ||
        tourism == 'zoo' ||
        tourism == 'theme_park' ||
        tourism == 'aquarium') {
      return 'attraction';
    }
    if (leisure == 'park') return 'park';
    if (leisure == 'stadium' || leisure == 'sports_centre') return 'sports';
    return 'landmark';
  }

  String? _buildAddressLine(Map tags) {
    final houseNumber = tags['addr:housenumber']?.toString().trim() ?? '';
    final streetBase =
        tags['addr:street']?.toString().trim() ??
        tags['addr:road']?.toString().trim() ??
        tags['addr:place']?.toString().trim() ??
        tags['addr:hamlet']?.toString().trim() ??
        tags['addr:quarter']?.toString().trim() ??
        '';

    final street =
        houseNumber.isNotEmpty && streetBase.isNotEmpty
            ? '$houseNumber $streetBase'
            : streetBase;

    final locality =
        tags['addr:barangay']?.toString().trim() ??
        tags['addr:suburb']?.toString().trim() ??
        tags['addr:neighbourhood']?.toString().trim() ??
        tags['addr:village']?.toString().trim() ??
        tags['addr:city_district']?.toString().trim() ??
        tags['addr:city']?.toString().trim() ??
        tags['addr:town']?.toString().trim() ??
        tags['addr:municipality']?.toString().trim() ??
        '';

    final province =
        tags['addr:state']?.toString().trim() ??
        tags['addr:province']?.toString().trim() ??
        tags['addr:county']?.toString().trim() ??
        '';

    final parts = <String>[];
    if (street.isNotEmpty) {
      parts.add(street);
    }
    if (locality.isNotEmpty) {
      parts.add(locality);
    }
    if (province.isNotEmpty && province.toLowerCase() != locality.toLowerCase()) {
      parts.add(province);
    }

    final fallbackPlace =
        tags['addr:full']?.toString().trim() ??
        tags['addr:district']?.toString().trim() ??
        tags['addr:city']?.toString().trim() ??
        tags['addr:town']?.toString().trim() ??
        tags['addr:municipality']?.toString().trim() ??
        tags['is_in']?.toString().trim() ??
        '';

    if (parts.isEmpty) {
      return fallbackPlace.isNotEmpty ? fallbackPlace : null;
    }

    final line = parts.join(', ');
    if (_isImpreciseRoadOnly(line) && fallbackPlace.isNotEmpty) {
      final lineLower = line.toLowerCase();
      final fallbackLower = fallbackPlace.toLowerCase();
      if (!lineLower.contains(fallbackLower)) {
        return '$line, $fallbackPlace';
      }
    }
    return line;
  }

  bool _isImpreciseRoadOnly(String text) {
    final normalized = text.trim().toLowerCase();
    final hasComma = normalized.contains(',');
    if (hasComma) return false;
    return normalized.contains('highway') ||
        normalized.contains('road') ||
        normalized.contains('street') ||
        normalized.contains('ave') ||
        normalized.contains('avenue');
  }
}

class _CachedPoiResponse {
  final List<MapPoi> items;
  final DateTime fetchedAt;

  const _CachedPoiResponse({required this.items, required this.fetchedAt});
}
