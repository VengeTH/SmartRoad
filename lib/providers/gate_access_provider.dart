/// * Gate Access Provider
/// * Riverpod providers for gate access logs and day passes
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gate_access_log.dart';
import '../models/hoa_day_pass.dart';
import '../services/sticker_service.dart';
import 'auth_provider.dart';
import 'sticker_provider.dart';

// ============================================================================
// * Access History Providers
// ============================================================================

/// * User access history provider
/// * Fetches all gate access log entries for the current user
final userAccessHistoryProvider = FutureProvider<List<GateAccessLog>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final stickerService = ref.watch(stickerServiceProvider);
  return stickerService.getUserAccessHistory(userId);
});

/// * HOA access history provider
/// * Fetches access logs for a specific HOA (guard/admin view)
final hoaAccessHistoryProvider =
    FutureProvider.family<List<GateAccessLog>, String>((ref, hoaId) async {
  final stickerService = ref.watch(stickerServiceProvider);
  return stickerService.getHoaAccessHistory(hoaId);
});

// ============================================================================
// * Day Pass Providers
// ============================================================================

/// * User day passes provider
/// * Fetches active day passes for the current user (valid today or future)
final userDayPassesProvider = FutureProvider<List<HoaDayPass>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final stickerService = ref.watch(stickerServiceProvider);
  return stickerService.getUserDayPasses(userId);
});

/// * Active today day pass provider
/// * Returns day passes that are valid today, keyed by HOA ID
final todayDayPassesProvider = Provider<AsyncValue<Map<String, HoaDayPass>>>((ref) {
  return ref.watch(userDayPassesProvider).whenData(
    (passes) {
      final map = <String, HoaDayPass>{};
      for (final pass in passes) {
        if (pass.isValidToday) {
          map[pass.hoaId] = pass;
        }
      }
      return map;
    },
  );
});

// ============================================================================
// * Gate Access Notifier (for adding logs + day passes during runtime)
// ============================================================================

/// * Gate access notifier for recording scans and notifying providers
class GateAccessNotifier extends StateNotifier<List<GateAccessLog>> {
  final StickerService _stickerService;
  final String? _userId;

  GateAccessNotifier(this._stickerService, this._userId) : super([]);

  /// * Record a gate access event and prepend to local state
  Future<GateAccessLog?> recordAccess({
    required String hoaId,
    required bool accessGranted,
    String? stickerId,
    String? scannedBy,
    GatePassMode passMode = GatePassMode.locationBound,
    String? notes,
  }) async {
    if (_userId == null) return null;

    final log = await _stickerService.logGateAccess(
      hoaId: hoaId,
      userId: _userId!,
      accessGranted: accessGranted,
      stickerId: stickerId,
      scannedBy: scannedBy,
      passMode: passMode,
      notes: notes,
    );

    if (log != null) {
      state = [log, ...state];
    }
    return log;
  }
}

/// * Gate access notifier provider
final gateAccessNotifierProvider =
    StateNotifierProvider<GateAccessNotifier, List<GateAccessLog>>((ref) {
  final stickerService = ref.watch(stickerServiceProvider);
  final userId = ref.watch(currentUserIdProvider);
  return GateAccessNotifier(stickerService, userId);
});
