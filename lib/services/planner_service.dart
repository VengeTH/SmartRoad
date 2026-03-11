import "planner_local.dart";

/// * Cache entry with TTL.
class _CacheEntry {
  final PlannerLocalResult result;
  final DateTime cachedAt;

  _CacheEntry({required this.result, required this.cachedAt});
}

/// * Result from PlannerService.plan. Either [itineraries] or [fallback] / [error]/[code].
class PlannerServiceResult {
  final List<PlannerItinerary>? itineraries;
  final String? fallback;
  final String? error;
  final String? code;

  const PlannerServiceResult({
    this.itineraries,
    this.fallback,
    this.error,
    this.code,
  });

  bool get hasItineraries => itineraries != null && itineraries!.isNotEmpty;
  bool get isNoTransitFallback => fallback == "no-transit";
}

/// * Wrapper around PlannerLocal with in-memory cache by rounded origin/dest and 10-minute time window; TTL 10 min.
class PlannerService {
  PlannerService._();

  static final PlannerService _instance = PlannerService._();
  static PlannerService get instance => _instance;

  final PlannerLocal _local = PlannerLocal.instance;
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const int _timeWindowMinutes = 10;

  final Map<String, _CacheEntry> _cache = {};

  /// * Plan transit from (fromLat, fromLon) to (toLat, toLon) at [datetime]. [mode] reserved for future (e.g. transit-only).
  /// * Returns itineraries, or fallback "no-transit" when no itineraries and mode is not transit-only, or error/code.
  Future<PlannerServiceResult> plan({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    required DateTime datetime,
    String? mode,
  }) async {
    final key = _cacheKey(fromLat, fromLon, toLat, toLon, datetime);
    final now = DateTime.now();
    final entry = _cache[key];
    if (entry != null && now.difference(entry.cachedAt) < _cacheTtl) {
      return _toServiceResult(entry.result, mode);
    }

    final result = await _local.planLocalTransit(fromLat, fromLon, toLat, toLon, datetime);
    _cache[key] = _CacheEntry(result: result, cachedAt: now);
    return _toServiceResult(result, mode);
  }

  String _cacheKey(double fromLat, double fromLon, double toLat, double toLon, DateTime dt) {
    final round = (double v) => (v * 100).round() / 100;
    final t = dt.millisecondsSinceEpoch ~/ (_timeWindowMinutes * 60 * 1000);
    return "${round(fromLat)},${round(fromLon)},${round(toLat)},${round(toLon)},$t";
  }

  PlannerServiceResult _toServiceResult(PlannerLocalResult result, String? mode) {
    if (result.itineraries != null && result.itineraries!.isNotEmpty) {
      return PlannerServiceResult(itineraries: result.itineraries);
    }
    if (result.error != null && result.code != null) {
      return PlannerServiceResult(error: result.error, code: result.code);
    }
    if (mode != "transit") {
      return const PlannerServiceResult(fallback: "no-transit");
    }
    return PlannerServiceResult(error: result.error, code: result.code);
  }
}
