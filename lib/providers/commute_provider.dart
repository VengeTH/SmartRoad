import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";

import "../models/commute_state.dart";
import "../services/commute_service.dart";

/// * Commute mode state provider
final commuteProvider = StateNotifierProvider<CommuteNotifier, CommuteState>((ref) {
  return CommuteNotifier();
});

/// * Quick access to commute status
final isCommuteActiveProvider = Provider<bool>((ref) {
  return ref.watch(commuteProvider).isActive;
});

/// * Quick access to commute status enum
final commuteStatusProvider = Provider<CommuteStatus>((ref) {
  return ref.watch(commuteProvider).status;
});

/// * Commute state notifier
class CommuteNotifier extends StateNotifier<CommuteState> {
  CommuteNotifier() : super(const CommuteState()) {
    _initialize();
  }
  
  final CommuteService _service = CommuteService();
  
  /// * Initialize the service and wire up state updates
  Future<void> _initialize() async {
    await _service.initialize();
    
    // * Wire up state change callbacks
    _service.onStateChanged = (newState) {
      state = newState;
    };
  }
  
  /// * Start commute tracking
  Future<bool> startCommute({
    required LatLng destination,
    required String destinationName,
    CommuteSettings? settings,
  }) async {
    final success = await _service.startCommute(
      destination: destination,
      destinationName: destinationName,
      settings: settings ?? state.settings,
    );
    
    return success;
  }
  
  /// * Stop commute tracking
  Future<void> stopCommute() async {
    await _service.stopCommute();
  }
  
  /// * Dismiss the current alarm
  void dismissAlarm() {
    _service.dismissAlarm();
  }
  
  /// * Dismiss safety alert
  void dismissSafetyAlert() {
    _service.dismissSafetyAlert();
  }
  
  /// * Send safety alert to emergency contacts
  Future<void> sendSafetyAlert() async {
    await _service.sendSafetyAlert();
  }
  
  /// * Update commute settings
  void updateSettings(CommuteSettings settings) {
    _service.updateSettings(settings);
    state = state.copyWith(settings: settings);
  }
  
  /// * Update safety settings
  void updateSafetySettings(SafetySettings safetySettings) {
    final newSettings = state.settings.copyWith(safetySettings: safetySettings);
    updateSettings(newSettings);
  }
  
  /// * Update alarm distance setting
  void setAlarmDistance(int meters) {
    final newSettings = state.settings.copyWith(alarmDistanceMeters: meters);
    updateSettings(newSettings);
  }
  
  /// * Toggle time-based backup alarm
  void setUseTimeBackupAlarm(bool enabled) {
    final newSettings = state.settings.copyWith(useTimeBackupAlarm: enabled);
    updateSettings(newSettings);
  }
  
  /// * Set backup alarm time
  void setBackupAlarmMinutes(int minutes) {
    final newSettings = state.settings.copyWith(backupAlarmMinutes: minutes);
    updateSettings(newSettings);
  }
  
  /// * Toggle vibration on alarm
  void setVibrateOnAlarm(bool enabled) {
    final newSettings = state.settings.copyWith(vibrateOnAlarm: enabled);
    updateSettings(newSettings);
  }
  
  /// * Toggle sound on alarm
  void setPlaySoundOnAlarm(bool enabled) {
    final newSettings = state.settings.copyWith(playSoundOnAlarm: enabled);
    updateSettings(newSettings);
  }
}

