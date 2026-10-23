import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/route_activity_log.dart";
import "../services/route_activity_log_service.dart";

/// * Provider for the singleton RouteActivityLogService
final routeActivityLogServiceProvider =
    Provider<RouteActivityLogService>((ref) {
  return RouteActivityLogService();
});

/// * State notifier for managing route activity logs (searched vs initiated)
final routeActivityLogsProvider =
    StateNotifierProvider<RouteActivityLogsNotifier, AsyncValue<List<RouteActivityLog>>>(
  (ref) {
    final service = ref.watch(routeActivityLogServiceProvider);
    return RouteActivityLogsNotifier(service);
  },
);

class RouteActivityLogsNotifier
    extends StateNotifier<AsyncValue<List<RouteActivityLog>>> {
  final RouteActivityLogService _service;

  RouteActivityLogsNotifier(this._service) : super(const AsyncValue.loading()) {
    loadLogs();
  }

  Future<void> loadLogs() async {
    try {
      final logs = await _service.getLogs();
      state = AsyncValue.data(logs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clearAll() async {
    await _service.clearLogs();
    state = const AsyncValue.data([]);
  }

  Future<void> deleteLog(String id) async {
    await _service.deleteLog(id);
    await loadLogs();
  }
}
