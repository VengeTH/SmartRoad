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
  
  LocationSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.type,
  });
  
  LatLng get latLng => LatLng(latitude, longitude);
}

/// * Location search service using Nominatim (OpenStreetMap)
class LocationSearchService {
  static final LocationSearchService _instance = LocationSearchService._internal();
  factory LocationSearchService() => _instance;
  LocationSearchService._internal();
  
  // * Nominatim API endpoint (free, no API key required)
  static const String _baseUrl = "https://nominatim.openstreetmap.org";
  static const String _contactEmail = "contact@smartroad.app";
  
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
      // * Build URL with optional country code restriction
      String urlString = "$_baseUrl/search?q=${Uri.encodeComponent(query)}"
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
        headers: kIsWeb
            ? null
            : const {
              "User-Agent": "SmartRoad App (contact@smartroad.app)", // * Required by Nominatim (native only)
            },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        return data.map((item) {
          return LocationSearchResult(
            displayName: item['display_name'] as String? ?? '',
            latitude: double.parse(item['lat'] as String),
            longitude: double.parse(item['lon'] as String),
            type: item['type'] as String?,
          );
        }).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint("❌ [LocationSearchService] Location search error: $e");
      return [];
    }
  }
  
  /// * Reverse geocoding - get address from coordinates
  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    try {
      final url = Uri.parse(
        "$_baseUrl/reverse?lat=$lat&lon=$lon"
        "&format=json"
        "&addressdetails=1"
        "&email=${Uri.encodeComponent(_contactEmail)}"
      );
      
      final response = await http.get(
        url,
        headers: kIsWeb
            ? null
            : const {
              "User-Agent": "SmartRoad App (contact@smartroad.app)",
            },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      }
      
      return null;
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
      return null;
    }
  }
  
  /// * Get country code from coordinates using reverse geocoding
  /// * Returns ISO 3166-1 alpha-2 country code (e.g., "ph", "jp", "us")
  /// * Returns null if country cannot be determined
  Future<String?> getCountryCodeFromCoordinates(double lat, double lon) async {
    try {
      final url = Uri.parse(
        "$_baseUrl/reverse?lat=$lat&lon=$lon"
        "&format=json"
        "&addressdetails=1"
        "&email=${Uri.encodeComponent(_contactEmail)}"
      );
      
      final response = await http.get(
        url,
        headers: kIsWeb
            ? null
            : const {
              "User-Agent": "SmartRoad App (contact@smartroad.app)",
            },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          // * Try different possible country code fields
          final countryCode = address['country_code'] as String? ?? 
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
    }
  }
}

