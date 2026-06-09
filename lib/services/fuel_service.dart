import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";

import "../config/regional_fuel_defaults.dart";
import "../models/fuel_station.dart";
import "../models/fuel_price.dart";
import "../models/fuel_price_report.dart";
import "../models/fuel_station_submission.dart";
import "../models/fuel_type.dart";
import "supabase_service.dart";
import "app_preferences_service.dart";
import "location_service.dart";
import "overpass_poi_service.dart";
import "../utils/fuel_utils.dart";

/// * Fuel service for community fuel pricing features.
/// *
/// * Handles:
/// * - Fetching fuel stations and prices
/// * - Submitting price updates with validation
/// * - Adding new stations
/// * - Reporting incorrect prices
/// * - Admin moderation queues
/// * - Rate limiting (device-based)
/// *
/// * Future extensions (structure ready):
/// * - Fuel price heatmap: use [getStationsByRegion] or [getStationsInBounds]
/// *   plus price aggregation by region/grid.
/// * - Cheapest fuel along route: route geometry + [getStationsInBounds] along
/// *   segments or [getStationsByRegion] for waypoints; min price per fuel type.
/// * - Province expansion: [getStationsByRegion], [getStationsInBounds], and
/// *   [groupStationsByProvince] / [groupStationsByRegion] for nationwide coverage.
/// * - Community contributor leaderboard: new table/view (e.g. contributions per
/// *   device_id/user_id); new provider and screen.
class FuelService {
  final SupabaseService _supabaseService;
  final AppPreferencesService _prefsService;
  final LocationService _locationService;
  static const bool _enableWebOverpassFuel = bool.fromEnvironment(
    'ENABLE_OVERPASS_WEB_FUEL',
    defaultValue: true,
  );
  static const Duration _demoFuelCacheTtl = Duration(minutes: 3);
  List<FuelStation> _demoFuelStationsCache = const [];
  DateTime? _demoFuelCacheAt;
  double? _demoFuelCacheCenterLat;
  double? _demoFuelCacheCenterLon;
  double _demoFuelCacheRadiusKm = 0.0;

  FuelService({
    required SupabaseService supabaseService,
    required AppPreferencesService prefsService,
    required LocationService locationService,
  }) : _supabaseService = supabaseService,
       _prefsService = prefsService,
       _locationService = locationService;

  // ============================================================
  // * QUERY METHODS
  // ============================================================

  /// * Get fuel stations within a bounding box.
  Future<List<FuelStation>> getStationsInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    bool includeUnverified = false,
  }) async {
    if (_supabaseService.isDemoMode) {
      // * Return demo stations for testing
      return _getDemoStations();
    }

    final client = _supabaseService.client;
    if (client == null) return [];

    try {
      var query = client
          .from("fuel_stations")
          .select()
          .gte("latitude", minLat)
          .lte("latitude", maxLat)
          .gte("longitude", minLon)
          .lte("longitude", maxLon);

      if (!includeUnverified) {
        query = query.eq("verified", true);
      }

      final response = await query;
      final List<FuelStation> stations = [];

      for (final item in response) {
        // * Fetch latest prices for each station
        final stationId = item["id"] as String?;
        if (stationId != null) {
          final prices = await _getLatestPrices(stationId);
          final stationData = Map<String, dynamic>.from(item);
          stationData["prices"] = prices.map((p) => p.toJson()).toList();
          FuelStation station = FuelStation.fromJson(stationData);
          if (station.prices.isEmpty) {
            station = station.copyWith(
              prices: RegionalFuelDefaults.getDefaultPricesForStation(
                station.province,
                station.region,
              ),
            );
          }
          stations.add(station);
        }
      }

      return stations;
    } catch (e) {
      debugPrint("❌ [FuelService] Failed to fetch stations: $e");
      return [];
    }
  }

  /// * Get fuel stations within [radiusKm] of (lat, lon).
  /// *
  /// * Computes a bounding box that contains the circle, fetches via
  /// * [getStationsInBounds], then filters by Haversine distance.
  Future<List<FuelStation>> getStationsNearLocation({
    required double lat,
    required double lon,
    required double radiusKm,
    bool includeUnverified = false,
  }) async {
    if (_supabaseService.isDemoMode) {
      return await _getDemoNearbyStations(
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
      );
    }

    // * ~111 km per degree latitude; longitude scaled by cos(lat)
    const kmPerDegLat = 111.0;
    final kmPerDegLon = 111.0 * _cosDeg(lat);
    final margin = 1.1; // * Slightly larger box so circle is fully contained
    final deltaLat = (radiusKm / kmPerDegLat) * margin;
    final deltaLon = (radiusKm / kmPerDegLon) * margin;

    final stations = await getStationsInBounds(
      minLat: lat - deltaLat,
      maxLat: lat + deltaLat,
      minLon: lon - deltaLon,
      maxLon: lon + deltaLon,
      includeUnverified: includeUnverified,
    );

    final radiusMeters = radiusKm * 1000.0;
    final filtered =
        stations.where((s) {
          final distM = FuelUtils.calculateDistance(
            lat,
            lon,
            s.latitude,
            s.longitude,
          );
          return distM <= radiusMeters;
        }).toList();

    return filtered;
  }

  static double _cosDeg(double deg) {
    return math.cos(deg * math.pi / 180.0).clamp(-1.0, 1.0);
  }

  /// * Get a single fuel station by ID with latest prices.
  Future<FuelStation?> getStationById(String stationId) async {
    if (_supabaseService.isDemoMode) {
      for (final station in _getDemoStations()) {
        if (station.id == stationId) {
          return station;
        }
      }
      return null;
    }

    final client = _supabaseService.client;
    if (client == null) return null;

    try {
      final response =
          await client
              .from("fuel_stations")
              .select()
              .eq("id", stationId)
              .single();

      final prices = await _getLatestPrices(stationId);
      final stationData = Map<String, dynamic>.from(response);
      stationData["prices"] = prices.map((p) => p.toJson()).toList();

      FuelStation station = FuelStation.fromJson(stationData);
      if (station.prices.isEmpty) {
        station = station.copyWith(
          prices: RegionalFuelDefaults.getDefaultPricesForStation(
            station.province,
            station.region,
          ),
        );
      }
      return station;
    } catch (e) {
      debugPrint("❌ [FuelService] Failed to fetch station: $e");
      return null;
    }
  }

  /// * Get latest fuel prices for a station.
  Future<List<FuelPrice>> _getLatestPrices(String stationId) async {
    final client = _supabaseService.client;
    if (client == null) return [];

    try {
      final response = await client.rpc(
        "get_latest_fuel_prices",
        params: {"p_station_id": stationId},
      );

      final List<FuelPrice> prices = [];
      if (response is List) {
        for (final item in response) {
          if (item is Map<String, dynamic>) {
            prices.add(FuelPrice.fromJson(item));
          }
        }
      }

      return prices;
    } catch (e) {
      debugPrint("❌ [FuelService] Failed to fetch prices: $e");
      return [];
    }
  }

  /// * Get fuel stations by region/province for heatmaps or regional views.
  Future<List<FuelStation>> getStationsByRegion({
    required String province,
    String? city,
  }) async {
    if (_supabaseService.isDemoMode) {
      return _getDemoStations()
          .where((s) => s.province.toLowerCase() == province.toLowerCase())
          .toList();
    }

    final client = _supabaseService.client;
    if (client == null) return [];

    try {
      var query = client
          .from("fuel_stations")
          .select()
          .eq("province", province)
          .eq("verified", true);

      if (city != null) {
        query = query.eq("city", city);
      }

      final response = await query;
      final List<FuelStation> stations = [];

      for (final item in response) {
        final stationId = item["id"] as String?;
        if (stationId != null) {
          final prices = await _getLatestPrices(stationId);
          final stationData = Map<String, dynamic>.from(item);
          stationData["prices"] = prices.map((p) => p.toJson()).toList();
          stations.add(FuelStation.fromJson(stationData));
        }
      }

      return stations;
    } catch (e) {
      debugPrint("❌ [FuelService] Failed to fetch regional stations: $e");
      return [];
    }
  }

  /// * Group stations by province for UI or province expansion.
  /// *
  /// * Returns a map of province name -> list of stations in that province.
  static Map<String, List<FuelStation>> groupStationsByProvince(
    List<FuelStation> stations,
  ) {
    final map = <String, List<FuelStation>>{};
    for (final s in stations) {
      final key = s.province.trim().isEmpty ? "Unknown" : s.province;
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  /// * Group stations by region for UI or nationwide expansion.
  /// *
  /// * Returns a map of region (or province if region is null) -> list of stations.
  static Map<String, List<FuelStation>> groupStationsByRegion(
    List<FuelStation> stations,
  ) {
    final map = <String, List<FuelStation>>{};
    for (final s in stations) {
      final key =
          (s.region ?? s.province).trim().isEmpty
              ? "Unknown"
              : (s.region ?? s.province);
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  // ============================================================
  // * SUBMISSION METHODS
  // ============================================================

  /// * Submit fuel price update with validation.
  /// *
  /// * Validates:
  /// * - Device rate limits (5 per 10 minutes per fuel type)
  /// * - Station cooldown (15 minutes per station/fuel)
  /// * - Distance from station (max 200m, photo required > 50m)
  /// *
  /// * Returns result with success flag and error message if failed.
  Future<FuelSubmissionResult> submitPriceUpdate({
    required String stationId,
    required Map<FuelType, double> prices,
    String? photoUrl,
  }) async {
    // * Get device ID
    final deviceId = await _prefsService.getFuelDeviceId();

    // * Get current location
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      return FuelSubmissionResult(
        success: false,
        error: "LOCATION_UNAVAILABLE",
        message:
            "Unable to get your location. Please enable location services.",
      );
    }

    // * Get station location
    final station = await getStationById(stationId);
    if (station == null) {
      return FuelSubmissionResult(
        success: false,
        error: "STATION_NOT_FOUND",
        message: "Station not found.",
      );
    }

    // * Calculate distance
    final distance = _locationService.calculateDistance(
      position.latitude,
      position.longitude,
      station.latitude,
      station.longitude,
    );

    // * Validate distance
    if (distance > 200) {
      return FuelSubmissionResult(
        success: false,
        error: "TOO_FAR",
        message: "You must be within 200m of the station.",
      );
    }

    if (distance > 50 && photoUrl == null) {
      return FuelSubmissionResult(
        success: false,
        error: "PHOTO_REQUIRED",
        message: "Photo proof required when more than 50m away.",
      );
    }

    // * Check local rate limits for each fuel type
    for (final fuelType in prices.keys) {
      final canSubmit = await _prefsService.checkFuelRateLimit(
        stationId: stationId,
        fuelType: fuelType.dbKey,
      );

      if (!canSubmit) {
        return FuelSubmissionResult(
          success: false,
          error: "RATE_LIMIT_EXCEEDED",
          message:
              "Too many submissions for ${fuelType.displayName}. Please wait.",
        );
      }

      final cooldownOk = await _prefsService.checkFuelCooldown(
        stationId: stationId,
        fuelType: fuelType.dbKey,
      );

      if (!cooldownOk) {
        return FuelSubmissionResult(
          success: false,
          error: "COOLDOWN_ACTIVE",
          message:
              "Please wait 15 minutes before updating ${fuelType.displayName} again.",
        );
      }
    }

    // * Demo mode: simulate success
    if (_supabaseService.isDemoMode) {
      // * Record submissions locally
      for (final fuelType in prices.keys) {
        await _prefsService.recordFuelSubmission(
          stationId: stationId,
          fuelType: fuelType.dbKey,
        );
      }

      debugPrint("✅ [DEMO] Price update simulated");
      return FuelSubmissionResult(success: true);
    }

    // * Submit to database via RPC
    try {
      final client = _supabaseService.client;
      if (client == null) {
        return FuelSubmissionResult(
          success: false,
          error: "CLIENT_UNAVAILABLE",
          message: "Database connection unavailable.",
        );
      }

      final userId = _supabaseService.currentUserId;

      // * Submit each price update
      for (final entry in prices.entries) {
        final response = await client.rpc(
          "submit_fuel_price_update",
          params: {
            "p_station_id": stationId,
            "p_fuel_type": entry.key.dbKey,
            "p_price": entry.value,
            "p_reporter_latitude": position.latitude,
            "p_reporter_longitude": position.longitude,
            "p_photo_url": photoUrl,
            "p_device_id": deviceId,
            "p_user_id": userId,
          },
        );

        if (response is Map<String, dynamic>) {
          final success = response["success"] as bool? ?? false;
          if (!success) {
            final error = response["error"] as String? ?? "UNKNOWN";
            final message = response["message"] as String? ?? "Update failed.";
            return FuelSubmissionResult(
              success: false,
              error: error,
              message: message,
            );
          }
        }

        // * Record submission locally
        await _prefsService.recordFuelSubmission(
          stationId: stationId,
          fuelType: entry.key.dbKey,
        );
      }

      return FuelSubmissionResult(success: true);
    } catch (e) {
      debugPrint("❌ [FuelService] Price update failed: $e");
      return FuelSubmissionResult(
        success: false,
        error: "EXCEPTION",
        message: "An error occurred: ${e.toString()}",
      );
    }
  }

  /// * Submit a new fuel station.
  Future<FuelSubmissionResult> submitNewStation(
    FuelStationSubmission submission,
  ) async {
    final deviceId = await _prefsService.getFuelDeviceId();

    // * Demo mode: simulate success
    if (_supabaseService.isDemoMode) {
      debugPrint("✅ [DEMO] Station submission simulated");
      return FuelSubmissionResult(success: true);
    }

    try {
      final client = _supabaseService.client;
      if (client == null) {
        return FuelSubmissionResult(
          success: false,
          error: "CLIENT_UNAVAILABLE",
          message: "Database connection unavailable.",
        );
      }

      final userId = _supabaseService.currentUserId;

      final response = await client.rpc(
        "submit_fuel_station",
        params: {
          "p_name": submission.name,
          "p_latitude": submission.latitude,
          "p_longitude": submission.longitude,
          "p_brand": submission.brand,
          "p_province": submission.province,
          "p_city": submission.city,
          "p_region": submission.region,
          "p_photo_url": submission.photoUrl,
          "p_device_id": deviceId,
          "p_user_id": userId,
        },
      );

      if (response is Map<String, dynamic>) {
        final success = response["success"] as bool? ?? false;
        if (success) {
          final stationId = response["station_id"] as String?;
          return FuelSubmissionResult(success: true, stationId: stationId);
        } else {
          final error = response["error"] as String? ?? "UNKNOWN";
          final message =
              response["message"] as String? ?? "Submission failed.";
          return FuelSubmissionResult(
            success: false,
            error: error,
            message: message,
          );
        }
      }

      return FuelSubmissionResult(
        success: false,
        error: "INVALID_RESPONSE",
        message: "Invalid server response.",
      );
    } catch (e) {
      debugPrint("❌ [FuelService] Station submission failed: $e");
      return FuelSubmissionResult(
        success: false,
        error: "EXCEPTION",
        message: "An error occurred: ${e.toString()}",
      );
    }
  }

  /// * Report incorrect price.
  Future<FuelSubmissionResult> reportIncorrectPrice({
    required String stationId,
    required FuelType fuelType,
    required double reportedIncorrectPrice,
    String? reason,
  }) async {
    final deviceId = await _prefsService.getFuelDeviceId();

    // * Demo mode: simulate success
    if (_supabaseService.isDemoMode) {
      debugPrint("✅ [DEMO] Price report simulated");
      return FuelSubmissionResult(success: true);
    }

    try {
      final client = _supabaseService.client;
      if (client == null) {
        return FuelSubmissionResult(
          success: false,
          error: "CLIENT_UNAVAILABLE",
          message: "Database connection unavailable.",
        );
      }

      final userId = _supabaseService.currentUserId;

      await client.from("fuel_price_reports").insert({
        "station_id": stationId,
        "fuel_type": fuelType.dbKey,
        "reported_incorrect_price": reportedIncorrectPrice,
        "reason": reason,
        "device_id": deviceId,
        "user_id": userId,
      });

      return FuelSubmissionResult(success: true);
    } catch (e) {
      debugPrint("❌ [FuelService] Price report failed: $e");
      return FuelSubmissionResult(
        success: false,
        error: "EXCEPTION",
        message: "An error occurred: ${e.toString()}",
      );
    }
  }

  // ============================================================
  // * ADMIN METHODS
  // ============================================================

  /// * Get pending fuel stations for admin review.
  Future<List<FuelStation>> getPendingStations() async {
    if (_supabaseService.isDemoMode) {
      return [];
    }

    final client = _supabaseService.client;
    if (client == null) return [];

    try {
      final response = await client.rpc("get_pending_fuel_stations");

      final List<FuelStation> stations = [];
      if (response is List) {
        for (final item in response) {
          if (item is Map<String, dynamic>) {
            final stationData = Map<String, dynamic>.from(item);
            stationData["prices"] =
                []; // * Pending stations may not have prices yet
            stations.add(FuelStation.fromJson(stationData));
          }
        }
      }

      return stations;
    } catch (e) {
      debugPrint("❌ [FuelService] Failed to fetch pending stations: $e");
      return [];
    }
  }

  /// * Approve a fuel station (Admin only).
  Future<FuelSubmissionResult> approveStation(String stationId) async {
    if (_supabaseService.isDemoMode) {
      return FuelSubmissionResult(success: true);
    }

    try {
      final client = _supabaseService.client;
      if (client == null) {
        return FuelSubmissionResult(
          success: false,
          error: "CLIENT_UNAVAILABLE",
          message: "Database connection unavailable.",
        );
      }

      final response = await client.rpc(
        "approve_fuel_station",
        params: {"p_station_id": stationId},
      );

      if (response is Map<String, dynamic>) {
        final success = response["success"] as bool? ?? false;
        if (success) {
          return FuelSubmissionResult(success: true);
        } else {
          final error = response["error"] as String? ?? "UNKNOWN";
          final message = response["message"] as String? ?? "Approval failed.";
          return FuelSubmissionResult(
            success: false,
            error: error,
            message: message,
          );
        }
      }

      return FuelSubmissionResult(
        success: false,
        error: "INVALID_RESPONSE",
        message: "Invalid server response.",
      );
    } catch (e) {
      debugPrint("❌ [FuelService] Station approval failed: $e");
      return FuelSubmissionResult(
        success: false,
        error: "EXCEPTION",
        message: "An error occurred: ${e.toString()}",
      );
    }
  }

  /// * Reject a fuel station (Admin only).
  Future<FuelSubmissionResult> rejectStation(String stationId) async {
    if (_supabaseService.isDemoMode) {
      return FuelSubmissionResult(success: true);
    }

    try {
      final client = _supabaseService.client;
      if (client == null) {
        return FuelSubmissionResult(
          success: false,
          error: "CLIENT_UNAVAILABLE",
          message: "Database connection unavailable.",
        );
      }

      final response = await client.rpc(
        "reject_fuel_station",
        params: {"p_station_id": stationId},
      );

      if (response is Map<String, dynamic>) {
        final success = response["success"] as bool? ?? false;
        if (success) {
          return FuelSubmissionResult(success: true);
        } else {
          final error = response["error"] as String? ?? "UNKNOWN";
          final message = response["message"] as String? ?? "Rejection failed.";
          return FuelSubmissionResult(
            success: false,
            error: error,
            message: message,
          );
        }
      }

      return FuelSubmissionResult(
        success: false,
        error: "INVALID_RESPONSE",
        message: "Invalid server response.",
      );
    } catch (e) {
      debugPrint("❌ [FuelService] Station rejection failed: $e");
      return FuelSubmissionResult(
        success: false,
        error: "EXCEPTION",
        message: "An error occurred: ${e.toString()}",
      );
    }
  }

  /// * Get pending price reports for admin review.
  Future<List<FuelPriceReport>> getPendingReports() async {
    if (_supabaseService.isDemoMode) {
      return [];
    }

    final client = _supabaseService.client;
    if (client == null) return [];

    try {
      final response = await client
          .from("fuel_price_reports")
          .select()
          .eq("status", "pending")
          .order("created_at", ascending: false);

      final List<FuelPriceReport> reports = [];
      for (final item in response) {
        reports.add(FuelPriceReport.fromJson(item));
      }

      return reports;
    } catch (e) {
      debugPrint("❌ [FuelService] Failed to fetch pending reports: $e");
      return [];
    }
  }

  /// * Mark a price report as reviewed (Admin only).
  Future<FuelSubmissionResult> markPriceReportReviewed(String reportId) async {
    if (_supabaseService.isDemoMode) {
      return const FuelSubmissionResult(success: true);
    }

    final client = _supabaseService.client;
    if (client == null) {
      return const FuelSubmissionResult(
        success: false,
        error: "CLIENT_UNAVAILABLE",
        message: "Database connection unavailable.",
      );
    }

    try {
      await client
          .from("fuel_price_reports")
          .update({
            "status": "reviewed",
            "reviewed_by": _supabaseService.currentUserId,
            "reviewed_at": DateTime.now().toIso8601String(),
          })
          .eq("id", reportId);
      return const FuelSubmissionResult(success: true);
    } catch (e) {
      debugPrint("❌ [FuelService] Failed to mark report reviewed: $e");
      return FuelSubmissionResult(
        success: false,
        error: "EXCEPTION",
        message: "An error occurred: ${e.toString()}",
      );
    }
  }

  /// * Dismiss a price report (Admin only).
  Future<FuelSubmissionResult> dismissPriceReport(String reportId) async {
    if (_supabaseService.isDemoMode) {
      return const FuelSubmissionResult(success: true);
    }

    final client = _supabaseService.client;
    if (client == null) {
      return const FuelSubmissionResult(
        success: false,
        error: "CLIENT_UNAVAILABLE",
        message: "Database connection unavailable.",
      );
    }

    try {
      await client
          .from("fuel_price_reports")
          .update({
            "status": "dismissed",
            "reviewed_by": _supabaseService.currentUserId,
            "reviewed_at": DateTime.now().toIso8601String(),
          })
          .eq("id", reportId);
      return const FuelSubmissionResult(success: true);
    } catch (e) {
      debugPrint("❌ [FuelService] Failed to dismiss report: $e");
      return FuelSubmissionResult(
        success: false,
        error: "EXCEPTION",
        message: "An error occurred: ${e.toString()}",
      );
    }
  }

  // ============================================================
  // * DEMO DATA
  // ============================================================

  /// * Demo stations with March 2026–style Philippines reference prices (NCR).
  /// * Prices as of 2026-03-11; used when no backend data or in demo mode.
  List<FuelStation> _getDemoStations() {
    final asOf = DateTime(2026, 3, 11, 12, 0, 0);

    return [
      FuelStation(
        id: "demo-1",
        name: "Shell EDSA Ortigas",
        latitude: 14.5836,
        longitude: 121.0577,
        brand: "Shell",
        province: "Metro Manila",
        city: "Pasig",
        region: "NCR",
        verified: true,
        source: "osm",
        prices: [
          FuelPrice(
            fuelType: FuelType.unleaded91,
            price: 62.40,
            updatedAt: asOf,
            source: "community",
            confidenceScore: 0.9,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.unleaded95,
            price: 67.20,
            updatedAt: asOf,
            source: "community",
            confidenceScore: 0.9,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.unleaded97,
            price: 71.50,
            updatedAt: asOf,
            source: "community",
            confidenceScore: 0.9,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.diesel,
            price: 60.80,
            updatedAt: asOf,
            source: "community",
            confidenceScore: 0.9,
            isStale: false,
          ),
        ],
        createdAt: asOf.subtract(const Duration(days: 30)),
        updatedAt: asOf,
      ),
      FuelStation(
        id: "demo-2",
        name: "Petron Makati Ave",
        latitude: 14.5547,
        longitude: 121.0244,
        brand: "Petron",
        province: "Metro Manila",
        city: "Makati",
        region: "NCR",
        verified: true,
        source: "community",
        prices: [
          FuelPrice(
            fuelType: FuelType.unleaded91,
            price: 63.00,
            updatedAt: asOf.subtract(const Duration(hours: 2)),
            source: "community",
            confidenceScore: 0.85,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.unleaded95,
            price: 67.90,
            updatedAt: asOf.subtract(const Duration(hours: 2)),
            source: "community",
            confidenceScore: 0.85,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.diesel,
            price: 61.50,
            updatedAt: asOf.subtract(const Duration(hours: 2)),
            source: "community",
            confidenceScore: 0.85,
            isStale: false,
          ),
        ],
        createdAt: asOf.subtract(const Duration(days: 60)),
        updatedAt: asOf.subtract(const Duration(hours: 2)),
      ),
      FuelStation(
        id: "demo-3",
        name: "Caltex Quezon Ave",
        latitude: 14.6325,
        longitude: 121.0382,
        brand: "Caltex",
        province: "Metro Manila",
        city: "Quezon City",
        region: "NCR",
        verified: true,
        source: "community",
        prices: [
          FuelPrice(
            fuelType: FuelType.unleaded91,
            price: 61.90,
            updatedAt: asOf,
            source: "community",
            confidenceScore: 0.88,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.unleaded95,
            price: 66.50,
            updatedAt: asOf,
            source: "community",
            confidenceScore: 0.88,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.diesel,
            price: 59.90,
            updatedAt: asOf,
            source: "community",
            confidenceScore: 0.88,
            isStale: false,
          ),
        ],
        createdAt: asOf.subtract(const Duration(days: 45)),
        updatedAt: asOf,
      ),
      FuelStation(
        id: "demo-4",
        name: "Unioil BGC",
        latitude: 14.5504,
        longitude: 121.0495,
        brand: "Unioil",
        province: "Metro Manila",
        city: "Taguig",
        region: "NCR",
        verified: true,
        source: "community",
        prices: [
          FuelPrice(
            fuelType: FuelType.unleaded91,
            price: 62.10,
            updatedAt: asOf.subtract(const Duration(hours: 5)),
            source: "community",
            confidenceScore: 0.82,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.unleaded95,
            price: 66.80,
            updatedAt: asOf.subtract(const Duration(hours: 5)),
            source: "community",
            confidenceScore: 0.82,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.unleaded97,
            price: 70.90,
            updatedAt: asOf.subtract(const Duration(hours: 5)),
            source: "community",
            confidenceScore: 0.82,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.diesel,
            price: 60.20,
            updatedAt: asOf.subtract(const Duration(hours: 5)),
            source: "community",
            confidenceScore: 0.82,
            isStale: false,
          ),
        ],
        createdAt: asOf.subtract(const Duration(days: 20)),
        updatedAt: asOf.subtract(const Duration(hours: 5)),
      ),
      FuelStation(
        id: "demo-5",
        name: "Total Mandaluyong",
        latitude: 14.5832,
        longitude: 121.0409,
        brand: "Total",
        province: "Metro Manila",
        city: "Mandaluyong",
        region: "NCR",
        verified: true,
        source: "osm",
        prices: [
          FuelPrice(
            fuelType: FuelType.unleaded91,
            price: 62.70,
            updatedAt: asOf,
            source: "community",
            confidenceScore: 0.9,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.unleaded95,
            price: 67.40,
            updatedAt: asOf,
            source: "community",
            confidenceScore: 0.9,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.diesel,
            price: 61.00,
            updatedAt: asOf,
            source: "community",
            confidenceScore: 0.9,
            isStale: false,
          ),
        ],
        createdAt: asOf.subtract(const Duration(days: 90)),
        updatedAt: asOf,
      ),
      FuelStation(
        id: "demo-6",
        name: "Seaoil Manila",
        latitude: 14.5995,
        longitude: 120.9842,
        brand: "Seaoil",
        province: "Metro Manila",
        city: "Manila",
        region: "NCR",
        verified: true,
        source: "community",
        prices: [
          FuelPrice(
            fuelType: FuelType.unleaded91,
            price: 61.50,
            updatedAt: asOf.subtract(const Duration(days: 1)),
            source: "community",
            confidenceScore: 0.85,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.unleaded95,
            price: 66.20,
            updatedAt: asOf.subtract(const Duration(days: 1)),
            source: "community",
            confidenceScore: 0.85,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.diesel,
            price: 59.50,
            updatedAt: asOf.subtract(const Duration(days: 1)),
            source: "community",
            confidenceScore: 0.85,
            isStale: false,
          ),
        ],
        createdAt: asOf.subtract(const Duration(days: 120)),
        updatedAt: asOf.subtract(const Duration(days: 1)),
      ),
    ];
  }

  Future<List<FuelStation>> _getDemoNearbyStations({
    required double lat,
    required double lon,
    required double radiusKm,
  }) async {
    if (kIsWeb && !_enableWebOverpassFuel) {
      return _buildWebFallbackNearbyStations(
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
      );
    }

    if (_canReuseDemoFuelCache(lat: lat, lon: lon, radiusKm: radiusKm)) {
      return _filterStationsByRadius(
        stations: _demoFuelStationsCache,
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
      );
    }

    final queryRadiusKm = math.max(radiusKm, 30.0);

    final bounds = _boundsForRadius(
      lat: lat,
      lon: lon,
      radiusKm: queryRadiusKm,
    );
    final pois = await OverpassPoiService().fetchFuelInBounds(
      bounds: bounds,
      limit: queryRadiusKm <= 10 ? 90 : 160,
    );

    if (pois.isEmpty && _demoFuelStationsCache.isNotEmpty) {
      return _filterStationsByRadius(
        stations: _demoFuelStationsCache,
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
      );
    }

    final seen = <String>{};
    final results = <FuelStation>[];

    for (final poi in pois) {
      final category = (poi.category ?? poi.type ?? '').trim().toLowerCase();
      if (category != 'fuel') continue;

      final distM = FuelUtils.calculateDistance(
        lat,
        lon,
        poi.latitude,
        poi.longitude,
      );
      if (distM > queryRadiusKm * 1000.0) continue;

      final dedupeKey =
          '${poi.name.trim().toLowerCase()}:${poi.latitude.toStringAsFixed(5)}:${poi.longitude.toStringAsFixed(5)}';
      if (!seen.add(dedupeKey)) continue;

      results.add(
        FuelStation(
          id: poi.id,
          name: poi.name,
          latitude: poi.latitude,
          longitude: poi.longitude,
          brand: poi.name,
          province: '',
          city: '',
          region: null,
          verified: false,
          source: 'osm',
          prices: RegionalFuelDefaults.getDefaultPricesForStation('', null),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          addressLine: poi.addressLine,
        ),
      );
    }

    results.sort((a, b) {
      final da = FuelUtils.calculateDistance(lat, lon, a.latitude, a.longitude);
      final db = FuelUtils.calculateDistance(lat, lon, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    if (results.isNotEmpty) {
      _demoFuelStationsCache = results;
      _demoFuelCacheAt = DateTime.now();
      _demoFuelCacheCenterLat = lat;
      _demoFuelCacheCenterLon = lon;
      _demoFuelCacheRadiusKm = queryRadiusKm;
    }

    return _filterStationsByRadius(
      stations: results,
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
    );
  }

  bool _canReuseDemoFuelCache({
    required double lat,
    required double lon,
    required double radiusKm,
  }) {
    final cacheAt = _demoFuelCacheAt;
    final centerLat = _demoFuelCacheCenterLat;
    final centerLon = _demoFuelCacheCenterLon;
    if (cacheAt == null || centerLat == null || centerLon == null) {
      return false;
    }
    if (_demoFuelStationsCache.isEmpty) return false;
    if (DateTime.now().difference(cacheAt) > _demoFuelCacheTtl) return false;
    if (_demoFuelCacheRadiusKm + 0.001 < radiusKm) return false;

    final centerDriftMeters = FuelUtils.calculateDistance(
      centerLat,
      centerLon,
      lat,
      lon,
    );
    return centerDriftMeters <= 2500.0;
  }

  List<FuelStation> _filterStationsByRadius({
    required List<FuelStation> stations,
    required double lat,
    required double lon,
    required double radiusKm,
  }) {
    final radiusMeters = radiusKm * 1000.0;
    final filtered =
        stations.where((station) {
          final distM = FuelUtils.calculateDistance(
            lat,
            lon,
            station.latitude,
            station.longitude,
          );
          return distM <= radiusMeters;
        }).toList();

    filtered.sort((a, b) {
      final da = FuelUtils.calculateDistance(lat, lon, a.latitude, a.longitude);
      final db = FuelUtils.calculateDistance(lat, lon, b.latitude, b.longitude);
      return da.compareTo(db);
    });
    return filtered;
  }

  List<FuelStation> _buildWebFallbackNearbyStations({
    required double lat,
    required double lon,
    required double radiusKm,
  }) {
    final asOf = DateTime.now();
    final defaults = RegionalFuelDefaults.getDefaultPricesForStation('', null);

    final templates = <
      ({
        String name,
        String brand,
        String address,
        double latOffset,
        double lonOffset,
      })
    >[
      (
        name: 'Shell Nearby',
        brand: 'Shell',
        address: 'Maharlika Highway',
        latOffset: 0.008,
        lonOffset: 0.004,
      ),
      (
        name: 'Petron Junction',
        brand: 'Petron',
        address: 'Rizal Avenue',
        latOffset: -0.007,
        lonOffset: 0.005,
      ),
      (
        name: 'Caltex Town Center',
        brand: 'Caltex',
        address: 'Quezon Avenue',
        latOffset: 0.006,
        lonOffset: -0.006,
      ),
      (
        name: 'Seaoil Highway Stop',
        brand: 'Seaoil',
        address: 'Diversion Road',
        latOffset: -0.005,
        lonOffset: -0.004,
      ),
    ];

    final kmPerDegLat = 111.0;
    final kmPerDegLon = math.max(111.0 * _cosDeg(lat), 0.0001);

    final stations = <FuelStation>[];
    for (int i = 0; i < templates.length; i++) {
      final t = templates[i];
      final stationLat = lat + t.latOffset;
      final stationLon = lon + t.lonOffset;
      final distanceMeters = FuelUtils.calculateDistance(
        lat,
        lon,
        stationLat,
        stationLon,
      );
      if (distanceMeters > radiusKm * 1000.0) {
        continue;
      }

      final approxCity = _deriveApproxCity(lat, lon);
      final approxProvince = _deriveApproxProvince(lat, lon);

      stations.add(
        FuelStation(
          id: 'web-fallback-${i + 1}',
          name: t.name,
          latitude: stationLat,
          longitude: stationLon,
          brand: t.brand,
          province: approxProvince,
          city: approxCity,
          region: null,
          verified: false,
          source: 'community',
          prices:
              defaults
                  .map(
                    (p) => FuelPrice(
                      fuelType: p.fuelType,
                      price: p.price,
                      updatedAt: asOf.subtract(Duration(hours: i + 2)),
                      source: p.source,
                      confidenceScore: p.confidenceScore,
                      isStale: false,
                    ),
                  )
                  .toList(),
          createdAt: asOf.subtract(const Duration(days: 10)),
          updatedAt: asOf.subtract(Duration(hours: i + 2)),
          addressLine: '${t.address}, $approxCity',
        ),
      );
    }

    stations.sort((a, b) {
      final da = FuelUtils.calculateDistance(lat, lon, a.latitude, a.longitude);
      final db = FuelUtils.calculateDistance(lat, lon, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    if (stations.isNotEmpty) {
      return stations;
    }

    final fallbackLat = lat + (radiusKm / kmPerDegLat) * 0.20;
    final fallbackLon = lon + (radiusKm / kmPerDegLon) * 0.15;
    final approxCity = _deriveApproxCity(lat, lon);
    final approxProvince = _deriveApproxProvince(lat, lon);

    return [
      FuelStation(
        id: 'web-fallback-single',
        name: 'Fuel Station Nearby',
        latitude: fallbackLat,
        longitude: fallbackLon,
        brand: 'Fuel',
        province: approxProvince,
        city: approxCity,
        region: null,
        verified: false,
        source: 'community',
        prices:
            defaults
                .map(
                  (p) => FuelPrice(
                    fuelType: p.fuelType,
                    price: p.price,
                    updatedAt: asOf.subtract(const Duration(hours: 3)),
                    source: p.source,
                    confidenceScore: p.confidenceScore,
                    isStale: false,
                  ),
                )
                .toList(),
        createdAt: asOf.subtract(const Duration(days: 5)),
        updatedAt: asOf.subtract(const Duration(hours: 3)),
        addressLine: 'National Highway, $approxCity',
      ),
    ];
  }

  String _deriveApproxCity(double lat, double lon) {
    if (lat >= 14.40 && lat <= 14.85 && lon >= 120.90 && lon <= 121.20) {
      return 'Metro Manila';
    }
    if (lat >= 13.80 && lat <= 14.30 && lon >= 120.90 && lon <= 121.40) {
      return 'Laguna';
    }
    if (lat >= 13.60 && lat <= 14.20 && lon >= 121.20 && lon <= 122.00) {
      return 'Quezon';
    }
    return 'Nearby Area';
  }

  String _deriveApproxProvince(double lat, double lon) {
    if (lat >= 14.40 && lat <= 14.85 && lon >= 120.90 && lon <= 121.20) {
      return 'NCR';
    }
    if (lat >= 13.80 && lat <= 14.30 && lon >= 120.90 && lon <= 121.40) {
      return 'Laguna';
    }
    if (lat >= 13.60 && lat <= 14.20 && lon >= 121.20 && lon <= 122.00) {
      return 'Quezon';
    }
    return 'Philippines';
  }

  LatLngBounds _boundsForRadius({
    required double lat,
    required double lon,
    required double radiusKm,
  }) {
    const kmPerDegLat = 111.0;
    final kmPerDegLon = math.max(111.0 * _cosDeg(lat), 0.0001);
    final margin = 1.15;
    final deltaLat = (radiusKm / kmPerDegLat) * margin;
    final deltaLon = (radiusKm / kmPerDegLon) * margin;

    return LatLngBounds.fromPoints([
      LatLng(lat - deltaLat, lon - deltaLon),
      LatLng(lat + deltaLat, lon + deltaLon),
    ]);
  }
}

/// * Result of a fuel submission operation.
class FuelSubmissionResult {
  final bool success;
  final String? error;
  final String? message;
  final String? stationId;

  const FuelSubmissionResult({
    required this.success,
    this.error,
    this.message,
    this.stationId,
  });
}



