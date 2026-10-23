import "dart:convert";

import "package:flutter/foundation.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:uuid/uuid.dart";

import "../models/route_activity_log.dart";

/// * Service for storing and managing route search and trip start activity logs.
class RouteActivityLogService {
  static final RouteActivityLogService _instance =
      RouteActivityLogService._internal();
  factory RouteActivityLogService() => _instance;
  RouteActivityLogService._internal();

  static const String _boxName = "route_activity_logs";
  static const String _keyLogs = "logs_list";
  static const int _maxLogsLimit = 50;

  static Box? _box;
  final List<RouteActivityLog> _memoryFallback = [];

  Future<Box?> _ensureBox() async {
    if (_box != null) return _box!;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
      return _box;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("ℹ️ [RouteActivityLogService] Hive init fallback: $e");
      }
      return null;
    }
  }

  /// * Loads all route activity logs sorted by most recent first.
  Future<List<RouteActivityLog>> getLogs() async {
    final box = await _ensureBox();
    if (box == null) {
      _memoryFallback.sort((a, b) {
        final aTime = a.initiatedAt ?? a.searchedAt;
        final bTime = b.initiatedAt ?? b.searchedAt;
        return bTime.compareTo(aTime);
      });
      return List.unmodifiable(_memoryFallback);
    }

    try {
      final raw = box.get(_keyLogs);
      if (raw == null) return [];

      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return [];

      final list = decoded
          .whereType<Map>()
          .map((e) => RouteActivityLog.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      list.sort((a, b) {
        final aTime = a.initiatedAt ?? a.searchedAt;
        final bTime = b.initiatedAt ?? b.searchedAt;
        return bTime.compareTo(aTime);
      });

      return list;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [RouteActivityLogService] Failed to load logs: $e");
      }
      return [];
    }
  }

  /// * Saves a search time log with type `searched`.
  Future<RouteActivityLog> logRouteSearch({
    required String originLabel,
    required String destinationLabel,
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
    required double distanceKm,
    required int estimatedDurationMinutes,
    required String mode,
    DateTime? targetArrivalTime,
    double? requiredSpeedKph,
    int? legalSpeedLimitKph,
    bool isExceedingLimit = false,
  }) async {
    final now = DateTime.now();
    final log = RouteActivityLog(
      id: const Uuid().v4(),
      type: RouteActivityType.searched,
      searchedAt: now,
      initiatedAt: null,
      originLabel: originLabel.trim().isEmpty ? "Current Location" : originLabel.trim(),
      destinationLabel:
          destinationLabel.trim().isEmpty ? "Destination" : destinationLabel.trim(),
      originLat: originLat,
      originLon: originLon,
      destinationLat: destinationLat,
      destinationLon: destinationLon,
      distanceKm: distanceKm,
      estimatedDurationMinutes: estimatedDurationMinutes,
      mode: mode,
      targetArrivalTime: targetArrivalTime,
      requiredSpeedKph: requiredSpeedKph,
      legalSpeedLimitKph: legalSpeedLimitKph,
      isExceedingLimit: isExceedingLimit,
    );

    final currentLogs = await getLogs();
    final updated = [log, ...currentLogs].take(_maxLogsLimit).toList();
    await _persistLogs(updated);

    debugPrint("📝 [RouteActivityLog] Recorded search log: ${log.destinationLabel} at $now");
    return log;
  }

  /// * Records navigation start / ride initiated time.
  /// * Updates existing search log if [searchLogId] is provided, or creates new initiated log.
  Future<RouteActivityLog> logTripInitiated({
    String? searchLogId,
    required String originLabel,
    required String destinationLabel,
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
    required double distanceKm,
    required int estimatedDurationMinutes,
    required String mode,
    DateTime? targetArrivalTime,
    double? requiredSpeedKph,
    int? legalSpeedLimitKph,
    bool isExceedingLimit = false,
  }) async {
    final now = DateTime.now();
    final currentLogs = await getLogs();

    RouteActivityLog? existing;
    int existingIndex = -1;

    if (searchLogId != null) {
      existingIndex = currentLogs.indexWhere((l) => l.id == searchLogId);
      if (existingIndex >= 0) {
        existing = currentLogs[existingIndex];
      }
    }

    final RouteActivityLog resultLog;
    if (existing != null) {
      resultLog = existing.copyWith(
        type: RouteActivityType.initiated,
        initiatedAt: now,
        targetArrivalTime: targetArrivalTime ?? existing.targetArrivalTime,
        requiredSpeedKph: requiredSpeedKph ?? existing.requiredSpeedKph,
        legalSpeedLimitKph: legalSpeedLimitKph ?? existing.legalSpeedLimitKph,
        isExceedingLimit: isExceedingLimit,
      );
      currentLogs[existingIndex] = resultLog;
    } else {
      resultLog = RouteActivityLog(
        id: const Uuid().v4(),
        type: RouteActivityType.initiated,
        searchedAt: now,
        initiatedAt: now,
        originLabel: originLabel.trim().isEmpty ? "Current Location" : originLabel.trim(),
        destinationLabel:
            destinationLabel.trim().isEmpty ? "Destination" : destinationLabel.trim(),
        originLat: originLat,
        originLon: originLon,
        destinationLat: destinationLat,
        destinationLon: destinationLon,
        distanceKm: distanceKm,
        estimatedDurationMinutes: estimatedDurationMinutes,
        mode: mode,
        targetArrivalTime: targetArrivalTime,
        requiredSpeedKph: requiredSpeedKph,
        legalSpeedLimitKph: legalSpeedLimitKph,
        isExceedingLimit: isExceedingLimit,
      );
      currentLogs.insert(0, resultLog);
    }

    await _persistLogs(currentLogs.take(_maxLogsLimit).toList());
    debugPrint("🚀 [RouteActivityLog] Recorded initiated trip log: ${resultLog.destinationLabel} at $now");
    return resultLog;
  }

  Future<void> _persistLogs(List<RouteActivityLog> logs) async {
    final box = await _ensureBox();
    if (box == null) {
      _memoryFallback.clear();
      _memoryFallback.addAll(logs);
      return;
    }

    try {
      final encoded = jsonEncode(logs.map((e) => e.toJson()).toList());
      await box.put(_keyLogs, encoded);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [RouteActivityLogService] Failed to persist logs: $e");
      }
    }
  }

  Future<void> clearLogs() async {
    final box = await _ensureBox();
    _memoryFallback.clear();
    if (box != null) {
      await box.delete(_keyLogs);
    }
  }

  Future<void> deleteLog(String id) async {
    final current = await getLogs();
    final filtered = current.where((l) => l.id != id).toList();
    await _persistLogs(filtered);
  }
}
