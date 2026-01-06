import "dart:convert";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "../models/place.dart";

/// * Loads and caches built-in known locations (landmarks) from assets.
/// *
/// * The list is intentionally small by default and can be extended by editing:
/// * - assets/known_places.json
class KnownPlacesService {
  static final KnownPlacesService _instance = KnownPlacesService._internal();
  factory KnownPlacesService() => _instance;
  KnownPlacesService._internal();

  List<Place>? _cached;

  /// * Clears the in-memory cache.
  void clearCache() {
    _cached = null;
  }

  Future<List<Place>> getKnownPlaces({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) {
      return List<Place>.from(_cached!);
    }

    try {
      final raw = await rootBundle.loadString("assets/known_places.json");
      final decoded = json.decode(raw);

      if (decoded is! List) {
        debugPrint("⚠️ [KnownPlacesService] known_places.json is not a JSON array");
        _cached = <Place>[];
        return [];
      }

      final places = <Place>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final place = Place.fromJson(item);
          // * Validate required fields to avoid broken markers.
          if (place.id.isEmpty ||
              place.name.isEmpty ||
              !place.latitude.isFinite ||
              !place.longitude.isFinite) {
            continue;
          }
          places.add(place);
        }
      }

      _cached = places;
      return List<Place>.from(places);
    } catch (e) {
      debugPrint("❌ [KnownPlacesService] Failed to load known places: $e");
      _cached = <Place>[];
      return [];
    }
  }
}

