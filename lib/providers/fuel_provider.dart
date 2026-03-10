import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/fuel_station.dart";
import "../models/fuel_price_report.dart";
import "../models/fuel_type.dart";
import "../models/fuel_station_submission.dart";
import "../services/fuel_service.dart";
import "../services/supabase_service.dart";
import "../services/app_preferences_service.dart";
import "../services/location_service.dart";

// ============================================================
// * SERVICE PROVIDERS
// ============================================================

final _supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final _appPreferencesServiceProvider = Provider<AppPreferencesService>((ref) {
  return AppPreferencesService();
});

final _locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final fuelServiceProvider = Provider<FuelService>((ref) {
  return FuelService(
    supabaseService: ref.watch(_supabaseServiceProvider),
    prefsService: ref.watch(_appPreferencesServiceProvider),
    locationService: ref.watch(_locationServiceProvider),
  );
});

// ============================================================
// * MAP FUEL STATIONS PROVIDER
// ============================================================

/// * Fuel stations visible on the map (within current bounds).
final mapFuelStationsProvider =
    StateNotifierProvider<MapFuelStationsNotifier, AsyncValue<List<FuelStation>>>(
  (ref) {
    return MapFuelStationsNotifier(
      fuelService: ref.watch(fuelServiceProvider),
    );
  },
);

class MapFuelStationsNotifier extends StateNotifier<AsyncValue<List<FuelStation>>> {
  final FuelService _fuelService;

  MapFuelStationsNotifier({
    required FuelService fuelService,
  })  : _fuelService = fuelService,
        super(const AsyncValue.data([]));

  /// * Load fuel stations within map bounds.
  Future<void> loadStationsInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    bool includeUnverified = false,
  }) async {
    try {
      state = const AsyncValue.loading();

      final stations = await _fuelService.getStationsInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        includeUnverified: includeUnverified,
      );

      state = AsyncValue.data(stations);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// * Add a newly submitted station to the map.
  void addStation(FuelStation station) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([station, ...current]);
  }

  /// * Update a station after price updates.
  void updateStation(FuelStation station) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((s) => s.id == station.id ? station : s).toList(),
    );
  }

  /// * Refresh stations in current bounds.
  Future<void> refresh({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    await loadStationsInBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
    );
  }
}

// ============================================================
// * SELECTED FUEL STATION PROVIDER
// ============================================================

/// * Currently selected fuel station on the map.
final selectedFuelStationProvider =
    StateNotifierProvider<SelectedFuelStationNotifier, FuelStation?>(
  (ref) {
    return SelectedFuelStationNotifier(
      fuelService: ref.watch(fuelServiceProvider),
    );
  },
);

class SelectedFuelStationNotifier extends StateNotifier<FuelStation?> {
  final FuelService _fuelService;

  SelectedFuelStationNotifier({
    required FuelService fuelService,
  })  : _fuelService = fuelService,
        super(null);

  /// * Select a fuel station by ID and load detailed data.
  Future<void> selectStation(String stationId) async {
    try {
      final station = await _fuelService.getStationById(stationId);
      state = station;
    } catch (e) {
      state = null;
    }
  }

  /// * Select a fuel station directly (already loaded).
  void selectStationDirect(FuelStation station) {
    state = station;
  }

  /// * Clear selection.
  void clearSelection() {
    state = null;
  }

  /// * Refresh current station data.
  Future<void> refresh() async {
    final current = state;
    if (current != null) {
      await selectStation(current.id);
    }
  }
}

// ============================================================
// * FUEL SUBMISSION STATE PROVIDER
// ============================================================

/// * Tracks pending fuel submission operations.
final fuelSubmissionProvider =
    StateNotifierProvider<FuelSubmissionNotifier, FuelSubmissionState>(
  (ref) {
    return FuelSubmissionNotifier(
      fuelService: ref.watch(fuelServiceProvider),
    );
  },
);

class FuelSubmissionNotifier extends StateNotifier<FuelSubmissionState> {
  final FuelService _fuelService;

  FuelSubmissionNotifier({
    required FuelService fuelService,
  })  : _fuelService = fuelService,
        super(FuelSubmissionState.idle());

  /// * Submit a price update.
  Future<void> submitPriceUpdate({
    required String stationId,
    required Map<FuelType, double> prices,
    String? photoUrl,
  }) async {
    state = FuelSubmissionState.loading();

    final result = await _fuelService.submitPriceUpdate(
      stationId: stationId,
      prices: prices,
      photoUrl: photoUrl,
    );

    if (result.success) {
      state = FuelSubmissionState.success();
    } else {
      state = FuelSubmissionState.error(
        result.error ?? "UNKNOWN",
        result.message ?? "Submission failed.",
      );
    }
  }

  /// * Submit a new station.
  Future<String?> submitNewStation({
    required String name,
    required double latitude,
    required double longitude,
    String? brand,
    required String province,
    required String city,
    String? region,
    String? photoUrl,
  }) async {
    state = FuelSubmissionState.loading();

    final deviceId = await AppPreferencesService().getFuelDeviceId();
    final userId = SupabaseService().currentUserId;

    final submission = FuelStationSubmission(
      name: name,
      latitude: latitude,
      longitude: longitude,
      brand: brand,
      province: province,
      city: city,
      region: region,
      photoUrl: photoUrl,
      deviceId: deviceId,
      userId: userId,
    );

    final result = await _fuelService.submitNewStation(submission);

    if (result.success) {
      state = FuelSubmissionState.success();
      return result.stationId;
    } else {
      state = FuelSubmissionState.error(
        result.error ?? "UNKNOWN",
        result.message ?? "Submission failed.",
      );
      return null;
    }
  }

  /// * Submit an incorrect price report.
  Future<void> reportIncorrectPrice({
    required String stationId,
    required FuelType fuelType,
    required double reportedIncorrectPrice,
    String? reason,
  }) async {
    state = FuelSubmissionState.loading();

    final result = await _fuelService.reportIncorrectPrice(
      stationId: stationId,
      fuelType: fuelType,
      reportedIncorrectPrice: reportedIncorrectPrice,
      reason: reason,
    );

    if (result.success) {
      state = FuelSubmissionState.success();
    } else {
      state = FuelSubmissionState.error(
        result.error ?? "UNKNOWN",
        result.message ?? "Report failed.",
      );
    }
  }

  /// * Reset submission state.
  void reset() {
    state = FuelSubmissionState.idle();
  }
}

/// * Submission state model.
class FuelSubmissionState {
  final FuelSubmissionStatus status;
  final String? errorCode;
  final String? errorMessage;

  const FuelSubmissionState({
    required this.status,
    this.errorCode,
    this.errorMessage,
  });

  factory FuelSubmissionState.idle() {
    return const FuelSubmissionState(status: FuelSubmissionStatus.idle);
  }

  factory FuelSubmissionState.loading() {
    return const FuelSubmissionState(status: FuelSubmissionStatus.loading);
  }

  factory FuelSubmissionState.success() {
    return const FuelSubmissionState(status: FuelSubmissionStatus.success);
  }

  factory FuelSubmissionState.error(String errorCode, String errorMessage) {
    return FuelSubmissionState(
      status: FuelSubmissionStatus.error,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  bool get isIdle => status == FuelSubmissionStatus.idle;
  bool get isLoading => status == FuelSubmissionStatus.loading;
  bool get isSuccess => status == FuelSubmissionStatus.success;
  bool get isError => status == FuelSubmissionStatus.error;
}

enum FuelSubmissionStatus {
  idle,
  loading,
  success,
  error,
}

// ============================================================
// * ADMIN PROVIDERS
// ============================================================

/// * Pending fuel stations for admin review.
final pendingFuelStationsProvider =
    FutureProvider.autoDispose<List<FuelStation>>((ref) async {
  final fuelService = ref.watch(fuelServiceProvider);
  return await fuelService.getPendingStations();
});

/// * Pending price reports for admin review.
final pendingFuelReportsProvider =
    FutureProvider.autoDispose<List<FuelPriceReport>>((ref) async {
  final fuelService = ref.watch(fuelServiceProvider);
  return await fuelService.getPendingReports();
});

// ============================================================
// * REGIONAL FUEL STATIONS PROVIDER (FOR HEATMAPS/ANALYTICS)
// ============================================================

/// * Get fuel stations by region/province.
final regionalFuelStationsProvider = FutureProvider.family
    .autoDispose<List<FuelStation>, RegionalFuelQuery>((ref, query) async {
  final fuelService = ref.watch(fuelServiceProvider);
  return await fuelService.getStationsByRegion(
    province: query.province,
    city: query.city,
  );
});

/// * Query parameters for regional fuel stations.
class RegionalFuelQuery {
  final String province;
  final String? city;

  const RegionalFuelQuery({
    required this.province,
    this.city,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RegionalFuelQuery &&
        other.province == province &&
        other.city == city;
  }

  @override
  int get hashCode => province.hashCode ^ city.hashCode;
}
