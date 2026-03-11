import "dart:convert";

import "package:flutter/services.dart";

import "../models/commute_state.dart";

/// * Result of fare estimation.
class FareEstimateResult {
  final double amountPhp;
  final Map<String, dynamic>? breakdown;
  final String currency;

  const FareEstimateResult({
    required this.amountPhp,
    this.breakdown,
    this.currency = "PHP",
  });
}

/// * Loads fare table from asset and estimates fare by type and distance (and optional route).
class FareEstimator {
  FareEstimator._();

  static final FareEstimator _instance = FareEstimator._();
  static FareEstimator get instance => _instance;

  Map<String, dynamic> _defaults = {};
  Map<String, dynamic> _routeOverrides = {};
  bool _loaded = false;

  /// * Load default fare table from JSON asset (lib/config/fare_table.json).
  Future<void> loadDefaults() async {
    if (_loaded) return;
    try {
      final json = await rootBundle.loadString("lib/config/fare_table.json");
      final map = jsonDecode(json) as Map<String, dynamic>?;
      if (map == null) return;
      _defaults = (map["defaults"] as Map<String, dynamic>?) ?? {};
      _routeOverrides = (map["route_overrides"] as Map<String, dynamic>?) ?? {};
      _loaded = true;
    } catch (_) {
      _defaults = {};
      _routeOverrides = {};
    }
  }

  /// * Ensure defaults are loaded (no-op if already loaded).
  Future<void> ensureLoaded() async {
    if (!_loaded) await loadDefaults();
  }

  /// * Estimate fare for [type] and [distanceMeters]. Optional [routeId] for route-specific overrides (e.g. rail).
  /// * Returns amountPhp, breakdown, currency.
  Future<FareEstimateResult> estimateFare(
    VehicleType type, {
    required double distanceMeters,
    String? routeId,
  }) async {
    await ensureLoaded();
    final distanceKm = distanceMeters / 1000.0;
    final typeKey = _vehicleTypeToKey(type);

    if (routeId != null && routeId.isNotEmpty) {
      final override = _routeOverrides[routeId] as Map<String, dynamic>?;
      if (override != null) {
        final result = _applyOverride(override, distanceKm, routeId);
        if (result != null) return result;
      }
    }

    final defaults = _defaults[typeKey] as Map<String, dynamic>?;
    if (defaults == null) {
      return FareEstimateResult(amountPhp: 0, breakdown: {"reason": "no_defaults"}, currency: "PHP");
    }
    return _applyDefaults(defaults, distanceKm, typeKey);
  }

  /// * Estimate by string type key (e.g. "jeepney", "bus", "lrt", "mrt", "pnr", "tricycle", "taxi", "angkas"). Used by planner for GTFS route_type mapping.
  FareEstimateResult estimateFareByKey(
    String typeKey, {
    required double distanceMeters,
    String? routeId,
  }) {
    final distanceKm = distanceMeters / 1000.0;
    if (routeId != null && routeId.isNotEmpty) {
      final override = _routeOverrides[routeId] as Map<String, dynamic>?;
      if (override != null) {
        final result = _applyOverride(override, distanceKm, routeId);
        if (result != null) return result;
      }
    }
    final defaults = _defaults[typeKey] as Map<String, dynamic>?;
    if (defaults == null) {
      return FareEstimateResult(amountPhp: 0, breakdown: {"reason": "no_defaults"}, currency: "PHP");
    }
    return _applyDefaults(defaults, distanceKm, typeKey);
  }

  /// * Synchronous estimate using already-loaded defaults. Call ensureLoaded() first.
  FareEstimateResult estimateFareSync(
    VehicleType type, {
    required double distanceMeters,
    String? routeId,
  }) {
    final distanceKm = distanceMeters / 1000.0;
    final typeKey = _vehicleTypeToKey(type);

    if (routeId != null && routeId.isNotEmpty) {
      final override = _routeOverrides[routeId] as Map<String, dynamic>?;
      if (override != null) {
        final result = _applyOverride(override, distanceKm, routeId);
        if (result != null) return result;
      }
    }

    final defaults = _defaults[typeKey] as Map<String, dynamic>?;
    if (defaults == null) {
      return FareEstimateResult(amountPhp: 0, breakdown: {"reason": "no_defaults"}, currency: "PHP");
    }
    return _applyDefaults(defaults, distanceKm, typeKey);
  }

  String _vehicleTypeToKey(VehicleType type) {
    switch (type) {
      case VehicleType.jeepney:
        return "jeepney";
      case VehicleType.bus:
        return "bus";
      case VehicleType.tricycle:
        return "tricycle";
      case VehicleType.car:
        return "taxi";
      case VehicleType.motorcycle:
        return "angkas";
      case VehicleType.walking:
        return "jeepney";
    }
  }

  FareEstimateResult _applyDefaults(Map<String, dynamic> d, double distanceKm, String typeKey) {
    final flat = d["flat_fare_php"];
    if (flat != null) {
      final php = (flat is int) ? flat.toDouble() : (flat as num).toDouble();
      return FareEstimateResult(
        amountPhp: php,
        breakdown: {"flat_fare_php": php},
        currency: "PHP",
      );
    }
    final base = d["base_fare_php"];
    final perKm = d["per_km_php"];
    if (base != null && perKm != null) {
      final b = (base is int) ? base.toDouble() : (base as num).toDouble();
      final p = (perKm is int) ? perKm.toDouble() : (perKm as num).toDouble();
      final amount = b + distanceKm * p;
      return FareEstimateResult(
        amountPhp: amount.ceilToDouble(),
        breakdown: {"base_fare_php": b, "per_km_php": p, "distance_km": distanceKm},
        currency: "PHP",
      );
    }
    final firstKm = d["first_km"];
    final firstFare = d["first_fare_php"];
    final perKmAfter = d["per_km_after_php"];
    if (firstKm != null && firstFare != null && perKmAfter != null) {
      final fk = (firstKm is int) ? firstKm.toDouble() : (firstKm as num).toDouble();
      final ff = (firstFare is int) ? firstFare.toDouble() : (firstFare as num).toDouble();
      final pa = (perKmAfter is int) ? perKmAfter.toDouble() : (perKmAfter as num).toDouble();
      double amount = ff;
      if (distanceKm > fk) {
        amount += (distanceKm - fk) * pa;
      }
      return FareEstimateResult(
        amountPhp: amount.ceilToDouble(),
        breakdown: {"first_km": fk, "first_fare_php": ff, "per_km_after_php": pa, "distance_km": distanceKm},
        currency: "PHP",
      );
    }
    final flagdown = d["flagdown_php"];
    final perKmTaxi = d["per_km_php"];
    if (flagdown != null && perKmTaxi != null) {
      final fd = (flagdown is int) ? flagdown.toDouble() : (flagdown as num).toDouble();
      final pk = (perKmTaxi is int) ? perKmTaxi.toDouble() : (perKmTaxi as num).toDouble();
      final amount = fd + distanceKm * pk;
      return FareEstimateResult(
        amountPhp: amount.ceilToDouble(),
        breakdown: {"flagdown_php": fd, "per_km_php": pk, "distance_km": distanceKm},
        currency: "PHP",
      );
    }
    return FareEstimateResult(amountPhp: 0, breakdown: {"reason": "unknown_schema"}, currency: "PHP");
  }

  FareEstimateResult? _applyOverride(Map<String, dynamic> d, double distanceKm, String routeId) {
    final flat = d["flat_fare_php"];
    if (flat != null) {
      final php = (flat is int) ? flat.toDouble() : (flat as num).toDouble();
      return FareEstimateResult(
        amountPhp: php,
        breakdown: {"route_id": routeId, "flat_fare_php": php},
        currency: "PHP",
      );
    }
    return _applyDefaults(d, distanceKm, "route_override");
  }
}
