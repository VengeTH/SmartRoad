import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";

import "../models/commute_guide_data.dart";
import "../models/commute_state.dart";
import "../services/commute_guide_service.dart";
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

/// * Quick access to alarm stage
final alarmStageProvider = Provider<AlarmStage>((ref) {
  return ref.watch(commuteProvider).alarmStage;
});

/// * Quick access to night mode status
final isNightModeProvider = Provider<bool>((ref) {
  return ref.watch(commuteProvider).isNightMode;
});

/// * Quick access to low power mode status
final isLowPowerActiveProvider = Provider<bool>((ref) {
  return ref.watch(commuteProvider).isLowPowerActive;
});

/// * Stable key for commute guide so the guide is not rebuilt on every state tick (e.g. ETA/location updates).
class CommuteGuideKey {
  final double? destLat;
  final double? destLon;
  final String vehicleTypeName;
  final String? destinationName;
  final bool hasTransitItinerary;

  const CommuteGuideKey({
    this.destLat,
    this.destLon,
    required this.vehicleTypeName,
    this.destinationName,
    required this.hasTransitItinerary,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommuteGuideKey &&
          destLat == other.destLat &&
          destLon == other.destLon &&
          vehicleTypeName == other.vehicleTypeName &&
          destinationName == other.destinationName &&
          hasTransitItinerary == other.hasTransitItinerary;

  @override
  int get hashCode =>
      Object.hash(destLat, destLon, vehicleTypeName, destinationName, hasTransitItinerary);
}

/// * Derives a stable key from commute state so the guide future only reruns when destination/vehicle/itinerary change.
final commuteGuideKeyProvider = Provider<CommuteGuideKey?>((ref) {
  final state = ref.watch(commuteProvider);
  final dest = state.destination;
  if (dest == null) return null;
  return CommuteGuideKey(
    destLat: dest.latitude,
    destLon: dest.longitude,
    vehicleTypeName: state.settings.vehicleType.name,
    destinationName: state.destinationName,
    hasTransitItinerary: state.transitItinerary != null,
  );
});

/// * Memoized commute guide; only refetches when [commuteGuideKeyProvider] changes (destination, vehicle, or itinerary).
final commuteGuideProvider = FutureProvider<CommuteGuideData?>((ref) async {
  final key = ref.watch(commuteGuideKeyProvider);
  if (key == null) return null;
  final state = ref.read(commuteProvider);
  return CommuteGuideService.instance.buildGuide(state);
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
    
    _service.onStateChanged = (newState) {
      state = newState;
    };
    _service.onTransitPlanReady = (itinerary) {
      state = state.copyWith(transitItinerary: itinerary);
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
  
  /// * Trigger manual SOS (immediate send)
  Future<void> triggerManualSOS() async {
    await _service.triggerManualSOS();
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
  
  // * NEW: Smart Alarm Buffer settings
  
  /// * Toggle smart alarm buffer
  void setUseSmartAlarmBuffer(bool enabled) {
    final newSettings = state.settings.copyWith(useSmartAlarmBuffer: enabled);
    updateSettings(newSettings);
  }
  
  /// * Set minimum seconds before alarm
  void setMinSecondsBeforeAlarm(int seconds) {
    final newSettings = state.settings.copyWith(minSecondsBeforeAlarm: seconds);
    updateSettings(newSettings);
  }
  
  /// * Set maximum seconds before alarm
  void setMaxSecondsBeforeAlarm(int seconds) {
    final newSettings = state.settings.copyWith(maxSecondsBeforeAlarm: seconds);
    updateSettings(newSettings);
  }
  
  // * NEW: Multi-Stage Alarm settings
  
  /// * Toggle multi-stage alarm
  void setUseMultiStageAlarm(bool enabled) {
    final newSettings = state.settings.copyWith(useMultiStageAlarm: enabled);
    updateSettings(newSettings);
  }
  
  // * NEW: Ultra-Low Power Mode settings
  
  /// * Toggle ultra-low power mode
  void setUltraLowPowerMode(bool enabled) {
    final newSettings = state.settings.copyWith(ultraLowPowerMode: enabled);
    updateSettings(newSettings);
  }
  
  /// * Set GPS interval for low power mode
  void setLowPowerGpsIntervalSeconds(int seconds) {
    final newSettings = state.settings.copyWith(lowPowerGpsIntervalSeconds: seconds);
    updateSettings(newSettings);
  }
  
  /// * Toggle minimize alerts when phone is active
  void setMinimizeAlertsWhenActive(bool enabled) {
    final newSettings = state.settings.copyWith(minimizeAlertsWhenActive: enabled);
    updateSettings(newSettings);
  }
  
  // * NEW: Safety settings helpers
  
  /// * Set grace period seconds
  void setGracePeriodSeconds(int seconds) {
    final newSafetySettings = state.settings.safetySettings.copyWith(
      gracePeriodSeconds: seconds,
    );
    updateSafetySettings(newSafetySettings);
  }
  
  /// * Set sustained off-route seconds
  void setSustainedOffRouteSeconds(int seconds) {
    final newSafetySettings = state.settings.safetySettings.copyWith(
      sustainedOffRouteSeconds: seconds,
    );
    updateSafetySettings(newSafetySettings);
  }
  
  /// * Toggle time-of-day sensitivity
  void setUseTimeOfDaySensitivity(bool enabled) {
    final newSafetySettings = state.settings.safetySettings.copyWith(
      useTimeOfDaySensitivity: enabled,
    );
    updateSafetySettings(newSafetySettings);
  }
  
  /// * Set night mode hours
  void setNightModeHours(int startHour, int endHour) {
    final newSafetySettings = state.settings.safetySettings.copyWith(
      nightModeStartHour: startHour,
      nightModeEndHour: endHour,
    );
    updateSafetySettings(newSafetySettings);
  }
  
  /// * Set night mode threshold multiplier
  void setNightModeThresholdMultiplier(double multiplier) {
    final newSafetySettings = state.settings.safetySettings.copyWith(
      nightModeThresholdMultiplier: multiplier,
    );
    updateSafetySettings(newSafetySettings);
  }
  
  /// * Set alert cooldown minutes
  void setAlertCooldownMinutes(int minutes) {
    final newSafetySettings = state.settings.safetySettings.copyWith(
      alertCooldownMinutes: minutes,
    );
    updateSafetySettings(newSafetySettings);
  }
  
  /// * Set off-route threshold
  void setOffRouteThresholdKm(double km) {
    final newSafetySettings = state.settings.safetySettings.copyWith(
      offRouteThresholdKm: km,
    );
    updateSafetySettings(newSafetySettings);
  }
  
  // * NEW: Vehicle Type
  
  /// * Set vehicle type for ETA calculation
  void setVehicleType(VehicleType type) {
    final newSettings = state.settings.copyWith(vehicleType: type);
    updateSettings(newSettings);
  }
}

