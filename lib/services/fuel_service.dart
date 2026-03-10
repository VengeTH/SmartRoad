import "package:flutter/foundation.dart";

import "../models/fuel_station.dart";
import "../models/fuel_price.dart";
import "../models/fuel_price_report.dart";
import "../models/fuel_station_submission.dart";
import "../models/fuel_type.dart";
import "supabase_service.dart";
import "app_preferences_service.dart";
import "location_service.dart";

/// * Fuel service for community fuel pricing features.
/// *
/// * Handles:
/// * - Fetching fuel stations and prices
/// * - Submitting price updates with validation
/// * - Adding new stations
/// * - Reporting incorrect prices
/// * - Admin moderation queues
/// * - Rate limiting (device-based)
class FuelService {
  final SupabaseService _supabaseService;
  final AppPreferencesService _prefsService;
  final LocationService _locationService;

  FuelService({
    required SupabaseService supabaseService,
    required AppPreferencesService prefsService,
    required LocationService locationService,
  })  : _supabaseService = supabaseService,
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
          stations.add(FuelStation.fromJson(stationData));
        }
      }

      return stations;
    } catch (e) {
      debugPrint("❌ [FuelService] Failed to fetch stations: $e");
      return [];
    }
  }

  /// * Get a single fuel station by ID with latest prices.
  Future<FuelStation?> getStationById(String stationId) async {
    if (_supabaseService.isDemoMode) {
      return _getDemoStations().firstWhere(
        (s) => s.id == stationId,
        orElse: () => _getDemoStations().first,
      );
    }

    final client = _supabaseService.client;
    if (client == null) return null;

    try {
      final response = await client
          .from("fuel_stations")
          .select()
          .eq("id", stationId)
          .single();

      final prices = await _getLatestPrices(stationId);
      final stationData = Map<String, dynamic>.from(response);
      stationData["prices"] = prices.map((p) => p.toJson()).toList();

      return FuelStation.fromJson(stationData);
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
        message: "Unable to get your location. Please enable location services.",
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
        final response = await client.rpc("submit_fuel_price_update", params: {
          "p_station_id": stationId,
          "p_fuel_type": entry.key.dbKey,
          "p_price": entry.value,
          "p_reporter_latitude": position.latitude,
          "p_reporter_longitude": position.longitude,
          "p_photo_url": photoUrl,
          "p_device_id": deviceId,
          "p_user_id": userId,
        });

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

      final response = await client.rpc("submit_fuel_station", params: {
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
      });

      if (response is Map<String, dynamic>) {
        final success = response["success"] as bool? ?? false;
        if (success) {
          final stationId = response["station_id"] as String?;
          return FuelSubmissionResult(
            success: true,
            stationId: stationId,
          );
        } else {
          final error = response["error"] as String? ?? "UNKNOWN";
          final message = response["message"] as String? ?? "Submission failed.";
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
            stationData["prices"] = []; // * Pending stations may not have prices yet
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

      final response = await client.rpc("approve_fuel_station", params: {
        "p_station_id": stationId,
      });

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

      final response = await client.rpc("reject_fuel_station", params: {
        "p_station_id": stationId,
      });

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

  List<FuelStation> _getDemoStations() {
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
            price: 58.50,
            updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
            source: "community",
            confidenceScore: 0.9,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.unleaded95,
            price: 65.20,
            updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
            source: "community",
            confidenceScore: 0.9,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.diesel,
            price: 52.80,
            updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
            source: "community",
            confidenceScore: 0.9,
            isStale: false,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
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
            price: 59.00,
            updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
            source: "community",
            confidenceScore: 0.85,
            isStale: false,
          ),
          FuelPrice(
            fuelType: FuelType.diesel,
            price: 53.50,
            updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
            source: "community",
            confidenceScore: 0.85,
            isStale: false,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];
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
