/// * Location Search Service
/// * Uses OpenStreetMap Nominatim API for free geocoding
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "dart:convert";
import "package:latlong2/latlong.dart";

/// * Location search result model
class LocationSearchResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final String? type; // * e.g., "city", "road", "place"
  final String? countryCode;

  LocationSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.type,
    this.countryCode,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

/// * Location search service using Nominatim (OpenStreetMap)
class LocationSearchService {
  static final LocationSearchService _instance =
      LocationSearchService._internal();
  factory LocationSearchService() => _instance;
  LocationSearchService._internal();

  // * Nominatim API endpoint (free, no API key required)
  static const String _baseUrl = "https://nominatim.openstreetmap.org";
  static const String _contactEmail = "contact@smartroad.app";
  DateTime? _reverseCooldownUntil;

  // * Global rate limiting state for Nominatim (max 1 request per second)
  static DateTime? _lastRequestTime;
  static bool _isRequestInProgress = false;

  /// Guarantee at least 1.1s between Nominatim requests to strictly respect their usage policy.
  static Future<void> enforceRateLimit() async {
    while (_isRequestInProgress) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    _isRequestInProgress = true;

    final last = _lastRequestTime;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      const limit = Duration(milliseconds: 1100);
      if (elapsed < limit) {
        await Future<void>.delayed(limit - elapsed);
      }
    }
  }

  static void releaseRateLimit() {
    _lastRequestTime = DateTime.now();
    _isRequestInProgress = false;
  }

  static final RegExp _queryWithCountryHint = RegExp(
    r"(,\s*[a-zA-Z ]{3,})|(\bphilippines\b|\bph\b|\bperu\b|\bjapan\b|\bus\b|\busa\b|\bunited states\b)",
    caseSensitive: false,
  );

  bool _hasExplicitCountryHint(String query) {
    return _queryWithCountryHint.hasMatch(query.trim());
  }

  /// * Search with country-first behavior.
  /// * If [preferredCountryCode] is present and query has no explicit country hint,
  /// * search is restricted to that country.
  Future<List<LocationSearchResult>> searchLocationRespectCountry(
    String query, {
    String? preferredCountryCode,
    bool allowOutsideWhenNoLocal = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final hasCountryHint = _hasExplicitCountryHint(trimmed);

    if (preferredCountryCode == null ||
        preferredCountryCode.isEmpty ||
        hasCountryHint) {
      return searchLocation(trimmed);
    }

    final local = await searchLocation(
      trimmed,
      countryCode: preferredCountryCode,
    );
    if (local.isNotEmpty || !allowOutsideWhenNoLocal) {
      return local;
    }

    final global = await searchLocation(trimmed);
    return _prioritizeCountryResults(global, preferredCountryCode);
  }

  List<LocationSearchResult> _prioritizeCountryResults(
    List<LocationSearchResult> results,
    String preferredCountryCode,
  ) {
    final code = preferredCountryCode.toLowerCase();
    final local = <LocationSearchResult>[];
    final outside = <LocationSearchResult>[];
    for (final result in results) {
      if ((result.countryCode ?? "").toLowerCase() == code) {
        local.add(result);
      } else {
        outside.add(result);
      }
    }
    return <LocationSearchResult>[...local, ...outside];
  }

  /// * Search for locations by query string
  /// *
  /// * [countryCode] - Optional ISO 3166-1 alpha-2 country code (e.g., "ph", "jp", "us")
  /// * If provided, search will be restricted to that country only
  /// * If null, search will be global (no country restriction)
  /// *
  /// * Returns list of location results
  Future<List<LocationSearchResult>> searchLocation(
    String query, {
    String? countryCode,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      await enforceRateLimit();
      
      // * Build URL with optional country code restriction
      String urlString =
          "$_baseUrl/search?q=${Uri.encodeComponent(query)}"
          "&format=json"
          "&limit=10"
          "&addressdetails=1"
          "&extratags=1"
          "&email=${Uri.encodeComponent(_contactEmail)}";

      // * Add country code restriction if provided
      if (countryCode != null && countryCode.isNotEmpty) {
        urlString += "&countrycodes=${countryCode.toLowerCase()}";
      }

      final url = Uri.parse(urlString);

      final response = await http.get(
        url,
        // ! Browsers do not allow setting User-Agent; it triggers CORS/preflight failures.
        // * Use the `email` query parameter for web, and keep User-Agent for native platforms.
        headers:
            kIsWeb
                ? null
                : const {
                  "User-Agent":
                      "SmartRoad App (contact@smartroad.app)", // * Required by Nominatim (native only)
                },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        return data.map((item) {
          final address = item["address"];
          String? countryCode;
          if (address is Map) {
            final cc = address["country_code"] ?? address["countryCode"];
            if (cc is String && cc.trim().isNotEmpty) {
              countryCode = cc.toLowerCase();
            }
          }
          return LocationSearchResult(
            displayName: item['display_name'] as String? ?? '',
            latitude: double.parse(item['lat'] as String),
            longitude: double.parse(item['lon'] as String),
            type: item['type'] as String?,
            countryCode: countryCode,
          );
        }).toList();
      }

      return [];
    } catch (e) {
      debugPrint("❌ [LocationSearchService] Location search error: $e");
      return [];
    } finally {
      releaseRateLimit();
    }
  }

  /// * Structured reverse geocoding – returns "Street, Barangay, City" from
  /// * Nominatim addressdetails fields. Works on all platforms including web.
  Future<String?> getStructuredAddressFromCoordinates(
    double lat,
    double lon,
  ) async {
    final cooldown = _reverseCooldownUntil;
    if (cooldown != null && DateTime.now().isBefore(cooldown)) {
      return null;
    }

    try {
      await enforceRateLimit();

      final url = Uri.parse(
        "$_baseUrl/reverse?lat=$lat&lon=$lon"
        "&format=json"
        "&addressdetails=1"
        "&email=${Uri.encodeComponent(_contactEmail)}",
      );

      final response = await http.get(
        url,
        headers:
            kIsWeb
                ? null
                : const {"User-Agent": "SmartRoad App (contact@smartroad.app)"},
      );

      if (response.statusCode == 429) {
        _reverseCooldownUntil = DateTime.now().add(const Duration(minutes: 2));
        return null;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _reverseCooldownUntil = null;

        final address = data['address'];
        if (address is Map<String, dynamic>) {
          return _formatStructuredAddress(address);
        }

        // Fallback to display_name if address block is missing
        return data['display_name'] as String?;
      }

      return null;
    } catch (e) {
      debugPrint("Structured reverse geocoding error: $e");
      return null;
    } finally {
      releaseRateLimit();
    }
  }

  /// * Build "Street, Barangay, City" from Nominatim address fields.
  String? _formatStructuredAddress(Map<String, dynamic> address) {
    final parts = <String>[];

    // Street / road
    final road =
        (address['road'] ?? address['street'] ?? address['pedestrian'])
            as String?;
    if (road != null && road.trim().isNotEmpty) {
      parts.add(road.trim());
    }

    // Barangay / suburb / neighbourhood
    final suburb =
        (address['suburb'] ??
                address['neighbourhood'] ??
                address['quarter'] ??
                address['village'])
            as String?;
    if (suburb != null &&
        suburb.trim().isNotEmpty &&
        suburb.trim() != (road?.trim() ?? '')) {
      parts.add(suburb.trim());
    }

    // City / town / municipality
    final city =
        (address['city'] ??
                address['town'] ??
                address['municipality'] ??
                address['city_district'])
            as String?;
    if (city != null &&
        city.trim().isNotEmpty &&
        !parts.contains(city.trim())) {
      parts.add(city.trim());
    }

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  /// * Reverse geocoding - get address from coordinates
  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    // * Nominatim reverse-geocoding from browser often fails due to CORS/rate limits.
    // * Fuel list already has city/province fallback, so skip this on web.
    if (kIsWeb) {
      return null;
    }

    final cooldown = _reverseCooldownUntil;
    if (cooldown != null && DateTime.now().isBefore(cooldown)) {
      return null;
    }

    try {
      await enforceRateLimit();

      final url = Uri.parse(
        "$_baseUrl/reverse?lat=$lat&lon=$lon"
        "&format=json"
        "&addressdetails=1"
        "&email=${Uri.encodeComponent(_contactEmail)}",
      );

      final response = await http.get(
        url,
        headers:
            kIsWeb
                ? null
                : const {"User-Agent": "SmartRoad App (contact@smartroad.app)"},
      );

      if (response.statusCode == 429) {
        _reverseCooldownUntil = DateTime.now().add(const Duration(minutes: 2));
        return null;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _reverseCooldownUntil = null;
        return data['display_name'] as String?;
      }

      return null;
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
      return null;
    } finally {
      releaseRateLimit();
    }
  }

  /// * Get country code from coordinates using reverse geocoding
  /// * Returns ISO 3166-1 alpha-2 country code (e.g., "ph", "jp", "us")
  /// * Returns null if country cannot be determined
  Future<String?> getCountryCodeFromCoordinates(double lat, double lon) async {
    try {
      await enforceRateLimit();

      final url = Uri.parse(
        "$_baseUrl/reverse?lat=$lat&lon=$lon"
        "&format=json"
        "&addressdetails=1"
        "&email=${Uri.encodeComponent(_contactEmail)}",
      );

      final response = await http.get(
        url,
        headers:
            kIsWeb
                ? null
                : const {"User-Agent": "SmartRoad App (contact@smartroad.app)"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          // * Try different possible country code fields
          final countryCode =
              address['country_code'] as String? ??
              address['countryCode'] as String?;
          if (countryCode != null) {
            return countryCode.toLowerCase();
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint("❌ [LocationSearchService] Error getting country code: $e");
      return null;
    } finally {
      releaseRateLimit();
    }
  }
}
