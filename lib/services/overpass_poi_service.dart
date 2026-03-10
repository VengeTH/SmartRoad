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
  static const Duration _cacheTtl = Duration(seconds: 45);
  static const int _maxCacheEntries = 36;
  final Map<String, _CachedPoiResponse> _responseCache = {};

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
    final cacheKey = _buildCacheKey(bounds: bounds, zoom: zoom, limit: limit);
    final cached = _responseCache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) <= _cacheTtl) {
      return cached.items;
    }

    final tier =
        zoom >= 14.0
            ? _tierFine
            : zoom >= 12.0
            ? _tierMid
            : _tierMajor;

    // * Overpass bounding box convention: south,west,north,east
    final bbox =
        '${bounds.south},${bounds.west},${bounds.north},${bounds.east}';
    final tagLines = tier.replaceAll('BBOX', bbox);
    final query = '[out:json][timeout:10];\n(\n${tagLines});\nout center $limit;';

    try {
      final response = await _firstSuccessfulResponse(query);

      if (response == null) {
        return [];
      }

      if (response.statusCode != 200) {
        debugPrint(
          '⚠️ [OverpassPoiService] HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}',
        );
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

        // * Assign importance proxy based on zoom tier (major = higher priority).
        // * Fuel POIs get a boost so gas stations win over nearby malls/shops.
        final baseImportance = zoom >= 14.0 ? 0.4 : zoom >= 12.0 ? 0.6 : 0.8;
        final importance = category == "fuel" ? (baseImportance + 0.25) : baseImportance;

        results.add(
          MapPoi(
            id: id,
            name: name,
            latitude: lat,
            longitude: lon,
            type: category,
            category: category,
            importance: importance,
          ),
        );
      }

      debugPrint(
        '✅ [OverpassPoiService] Fetched ${results.length} POIs at zoom $zoom',
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
    final completer = Completer<http.Response?>();
    var completed = 0;

    for (final endpoint in _endpoints) {
      _postToEndpoint(endpoint, query).then((response) {
        if (!completer.isCompleted && response != null && response.statusCode == 200) {
          completer.complete(response);
          return;
        }

        completed += 1;
        if (completed == _endpoints.length && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
  }

  Future<http.Response?> _postToEndpoint(String endpoint, String query) async {
    try {
      return await http
          .post(
            Uri.parse(endpoint),
            headers: kIsWeb
                ? {'Content-Type': 'application/x-www-form-urlencoded'}
                : {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'User-Agent': 'SmartRoad App (contact@smartroad.app)',
                },
            body: 'data=${Uri.encodeComponent(query)}',
          )
          .timeout(const Duration(seconds: 7));
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
}

class _CachedPoiResponse {
  final List<MapPoi> items;
  final DateTime fetchedAt;

  const _CachedPoiResponse({required this.items, required this.fetchedAt});
}
