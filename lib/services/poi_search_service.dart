import "dart:convert";

import "package:flutter/foundation.dart";
import "package:flutter_map/flutter_map.dart";
import "package:http/http.dart" as http;

import "../models/map_poi.dart";
import "location_search_service.dart";

/// * Searches map landmarks/POIs using OpenStreetMap Nominatim (web-CORS friendly).
/// *
/// * IMPORTANT:
/// * - Nominatim has strict usage policies. This implementation is debounced and
/// *   rate-limited at the caller (MapScreen).
/// * - For production scale, host your own Nominatim instance or use a paid provider.
class PoiSearchService {
  static final PoiSearchService _instance = PoiSearchService._internal();
  factory PoiSearchService() => _instance;
  PoiSearchService._internal();

  static const String _baseUrl = "https://nominatim.openstreetmap.org";
  static const String _contactEmail = "contact@smartroad.app";

  /// * Searches within a bounding box using Nominatim's `viewbox` + `bounded=1`.
  Future<List<MapPoi>> searchInBounds({
    required LatLngBounds bounds,
    required String query,
    int limit = 12,
    String countryCode = "ph",
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [];
    }

    try {
      await LocationSearchService.enforceRateLimit();

      final west = bounds.west;
      final east = bounds.east;
      final north = bounds.north;
      final south = bounds.south;

      final url = Uri.parse(
        "$_baseUrl/search"
        "?format=jsonv2"
        "&q=${Uri.encodeComponent(trimmed)}"
        "&limit=$limit"
        "&bounded=1"
        "&viewbox=$west,$north,$east,$south"
        "&countrycodes=${countryCode.toLowerCase()}"
        "&email=${Uri.encodeComponent(_contactEmail)}",
      );

      final response = await http.get(
        url,
        // ! Browsers do not allow setting User-Agent; it triggers CORS/preflight failures.
        // * Use the `email` query parameter for web, and keep User-Agent for native platforms.
        headers: kIsWeb
            ? null
            : const {
              // * Required by Nominatim usage policy (native only).
              "User-Agent": "SmartRoad App (contact@smartroad.app)",
            },
      );

      if (response.statusCode != 200) {
        return [];
      }

      final decoded = json.decode(response.body);
      if (decoded is! List) {
        return [];
      }

      final results = <MapPoi>[];
      for (final item in decoded) {
        if (item is! Map) continue;

        final nameRaw = item["name"];
        final displayNameRaw = item["display_name"];
        final name = (nameRaw?.toString().trim().isNotEmpty ?? false)
            ? nameRaw.toString().trim()
            : (displayNameRaw?.toString().split(",").first.trim() ?? "").trim();

        final lat = double.tryParse(item["lat"]?.toString() ?? "");
        final lon = double.tryParse(item["lon"]?.toString() ?? "");
        if (name.isEmpty || lat == null || lon == null) continue;

        final placeIdRaw = item["place_id"];
        final placeId = placeIdRaw?.toString().trim();
        final id = (placeId != null && placeId.isNotEmpty)
            ? "nominatim:$placeId"
            : "nominatim:$trimmed:$lat:$lon";

        final importanceRaw = item["importance"];
        final importance = (importanceRaw is num)
            ? importanceRaw.toDouble()
            : double.tryParse(importanceRaw?.toString() ?? "");

        results.add(
          MapPoi(
            id: id,
            name: name,
            latitude: lat,
            longitude: lon,
            type: item["type"]?.toString(),
            category: item["category"]?.toString(),
            importance: importance,
          ),
        );
      }

      return results;
    } catch (e) {
      debugPrint("❌ [PoiSearchService] searchInBounds failed: $e");
      return [];
    } finally {
      LocationSearchService.releaseRateLimit();
    }
  }
}

