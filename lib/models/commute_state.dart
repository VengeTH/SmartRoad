import "package:flutter/material.dart";
import "package:latlong2/latlong.dart";
import "weather_state.dart";

/// * Commute mode status enum
enum CommuteStatus {
  /// Not tracking - idle state
  idle,
  
  /// Commute in progress - actively tracking
  active,
  
  /// Within alarm distance - getting close
  approaching,
  
  /// Reached destination
  arrived,
  
  /// Passed destination - lagpas-baba!
  passed,
  
  /// Safety alert - off-route detected
  danger,
}

/// * Multi-stage alarm levels for progressive escalation
enum AlarmStage {
  /// No alarm active
  none,
  
  /// First stage: soft vibration only (~60+ seconds before)
  stage1Soft,
  
  /// Second stage: medium vibration + soft sound (~30-60 seconds)
  stage2Medium,
  
  /// Final stage: loud continuous alarm (<30 seconds)
  stage3Loud,
}

/// * Vehicle type for realistic ETA calculation
enum VehicleType {
  /// Jeepney / FX / UV Express (typical PH public transport)
  jeepney,
  
  /// Bus / P2P / Shuttle
  bus,
  
  /// Private car
  car,
  
  /// Motorcycle / Habal-habal
  motorcycle,
  
  /// Tricycle / E-bike
  tricycle,
  
  /// Walking / on foot
  walking,
}

/// * Extension for VehicleType display and speed properties
extension VehicleTypeExtension on VehicleType {
  /// Display label
  String get label {
    switch (this) {
      case VehicleType.jeepney:   return "Jeepney";
      case VehicleType.bus:       return "Bus";
      case VehicleType.car:       return "Car";
      case VehicleType.motorcycle: return "Motorcycle";
      case VehicleType.tricycle:  return "Tricycle";
      case VehicleType.walking:   return "Walking";
    }
  }
  
  /// Icon data
  IconData get iconData {
    switch (this) {
      case VehicleType.jeepney:   return Icons.directions_bus_filled_outlined; // Closest to Jeepney
      case VehicleType.bus:       return Icons.directions_bus;
      case VehicleType.car:       return Icons.directions_car;
      case VehicleType.motorcycle: return Icons.two_wheeler;
      case VehicleType.tricycle:  return Icons.electric_rickshaw; // Closest to Tricycle
      case VehicleType.walking:   return Icons.directions_walk;
    }
  }
  
  /// Typical base speed in km/h (used when no live GPS speed is available)
  double get baseSpeedKmh {
    switch (this) {
      case VehicleType.jeepney:   return 20.0;
      case VehicleType.bus:       return 25.0;
      case VehicleType.car:       return 40.0;
      case VehicleType.motorcycle: return 45.0;
      case VehicleType.tricycle:  return 15.0;
      case VehicleType.walking:   return 5.0;
    }
  }
  
  /// Maximum realistic speed in km/h (clamp for live GPS speed)
  double get maxSpeedKmh {
    switch (this) {
      case VehicleType.jeepney:   return 50.0;
      case VehicleType.bus:       return 60.0;
      case VehicleType.car:       return 100.0;
      case VehicleType.motorcycle: return 110.0;
      case VehicleType.tricycle:  return 35.0;
      case VehicleType.walking:   return 8.0;
    }
  }
  
  /// JSON key
  String get jsonKey => name;
  
  /// From JSON key
  static VehicleType fromJson(String? key) {
    return VehicleType.values.firstWhere(
      (v) => v.name == key,
      orElse: () => VehicleType.jeepney,
    );
  }
}

/// * Saved stop categories for quick access
enum StopCategory {
  work,
  school,
  home,
  terminal,
  custom,
}

/// * Emergency contact for safety alerts
class EmergencyContact {
  final String name;
  final String phoneNumber;
  
  const EmergencyContact({
    required this.name,
    required this.phoneNumber,
  });
  
  Map<String, dynamic> toJson() => {
    "name": name,
    "phoneNumber": phoneNumber,
  };
  
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json["name"] as String? ?? "Unknown",
      phoneNumber: json["phoneNumber"] as String? ?? "",
    );
  }
}

/// * Safety settings for off-route detection
class SafetySettings {
  /// Whether safety alerts are enabled
  final bool enabled;
  
  /// Emergency contacts to notify
  final List<EmergencyContact> emergencyContacts;
  
  /// Distance threshold in km to trigger off-route alert (default: 3km)
  final double offRouteThresholdKm;
  
  /// Whether to automatically send SMS when danger detected
  final bool autoSmsEnabled;
  
  /// Cooldown between auto-SMS in minutes
  final int smsCooldownMinutes;
  
  /// Grace period in seconds before auto-sending alert (default: 30)
  final int gracePeriodSeconds;
  
  /// Minimum sustained off-route time in seconds before triggering (default: 120 = 2 min)
  final int sustainedOffRouteSeconds;
  
  /// Deviation angle threshold in degrees (default: 45)
  final double deviationAngleThreshold;
  
  /// Whether to use time-of-day sensitivity
  final bool useTimeOfDaySensitivity;
  
  /// Night mode start hour (24h format, default: 21 = 9PM)
  final int nightModeStartHour;
  
  /// Night mode end hour (24h format, default: 5 = 5AM)
  final int nightModeEndHour;
  
  /// Multiplier for off-route threshold during night (default: 0.7 = stricter)
  final double nightModeThresholdMultiplier;
  
  /// Cooldown period after alert in minutes (default: 15)
  final int alertCooldownMinutes;
  
  const SafetySettings({
    this.enabled = false,
    this.emergencyContacts = const [],
    this.offRouteThresholdKm = 3.0,
    this.autoSmsEnabled = false,
    this.smsCooldownMinutes = 5,
    this.gracePeriodSeconds = 30,
    this.sustainedOffRouteSeconds = 120,
    this.deviationAngleThreshold = 45.0,
    this.useTimeOfDaySensitivity = true,
    this.nightModeStartHour = 21,
    this.nightModeEndHour = 5,
    this.nightModeThresholdMultiplier = 0.7,
    this.alertCooldownMinutes = 15,
  });
  
  SafetySettings copyWith({
    bool? enabled,
    List<EmergencyContact>? emergencyContacts,
    double? offRouteThresholdKm,
    bool? autoSmsEnabled,
    int? smsCooldownMinutes,
    int? gracePeriodSeconds,
    int? sustainedOffRouteSeconds,
    double? deviationAngleThreshold,
    bool? useTimeOfDaySensitivity,
    int? nightModeStartHour,
    int? nightModeEndHour,
    double? nightModeThresholdMultiplier,
    int? alertCooldownMinutes,
  }) {
    return SafetySettings(
      enabled: enabled ?? this.enabled,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      offRouteThresholdKm: offRouteThresholdKm ?? this.offRouteThresholdKm,
      autoSmsEnabled: autoSmsEnabled ?? this.autoSmsEnabled,
      smsCooldownMinutes: smsCooldownMinutes ?? this.smsCooldownMinutes,
      gracePeriodSeconds: gracePeriodSeconds ?? this.gracePeriodSeconds,
      sustainedOffRouteSeconds: sustainedOffRouteSeconds ?? this.sustainedOffRouteSeconds,
      deviationAngleThreshold: deviationAngleThreshold ?? this.deviationAngleThreshold,
      useTimeOfDaySensitivity: useTimeOfDaySensitivity ?? this.useTimeOfDaySensitivity,
      nightModeStartHour: nightModeStartHour ?? this.nightModeStartHour,
      nightModeEndHour: nightModeEndHour ?? this.nightModeEndHour,
      nightModeThresholdMultiplier: nightModeThresholdMultiplier ?? this.nightModeThresholdMultiplier,
      alertCooldownMinutes: alertCooldownMinutes ?? this.alertCooldownMinutes,
    );
  }
  
  Map<String, dynamic> toJson() => {
    "enabled": enabled,
    "emergencyContacts": emergencyContacts.map((c) => c.toJson()).toList(),
    "offRouteThresholdKm": offRouteThresholdKm,
    "autoSmsEnabled": autoSmsEnabled,
    "smsCooldownMinutes": smsCooldownMinutes,
    "gracePeriodSeconds": gracePeriodSeconds,
    "sustainedOffRouteSeconds": sustainedOffRouteSeconds,
    "deviationAngleThreshold": deviationAngleThreshold,
    "useTimeOfDaySensitivity": useTimeOfDaySensitivity,
    "nightModeStartHour": nightModeStartHour,
    "nightModeEndHour": nightModeEndHour,
    "nightModeThresholdMultiplier": nightModeThresholdMultiplier,
    "alertCooldownMinutes": alertCooldownMinutes,
  };
  
  factory SafetySettings.fromJson(Map<String, dynamic> json) {
    return SafetySettings(
      enabled: json["enabled"] as bool? ?? false,
      emergencyContacts: (json["emergencyContacts"] as List<dynamic>?)
          ?.map((c) => EmergencyContact.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],
      offRouteThresholdKm: (json["offRouteThresholdKm"] as num?)?.toDouble() ?? 3.0,
      autoSmsEnabled: json["autoSmsEnabled"] as bool? ?? false,
      smsCooldownMinutes: json["smsCooldownMinutes"] as int? ?? 5,
      gracePeriodSeconds: json["gracePeriodSeconds"] as int? ?? 30,
      sustainedOffRouteSeconds: json["sustainedOffRouteSeconds"] as int? ?? 120,
      deviationAngleThreshold: (json["deviationAngleThreshold"] as num?)?.toDouble() ?? 45.0,
      useTimeOfDaySensitivity: json["useTimeOfDaySensitivity"] as bool? ?? true,
      nightModeStartHour: json["nightModeStartHour"] as int? ?? 21,
      nightModeEndHour: json["nightModeEndHour"] as int? ?? 5,
      nightModeThresholdMultiplier: (json["nightModeThresholdMultiplier"] as num?)?.toDouble() ?? 0.7,
      alertCooldownMinutes: json["alertCooldownMinutes"] as int? ?? 15,
    );
  }
}

/// * Commute mode settings
class CommuteSettings {
  /// Distance in meters before destination to trigger alarm (default: 500m)
  final int alarmDistanceMeters;
  
  /// Whether to use time-based backup alarm
  final bool useTimeBackupAlarm;
  
  /// Backup alarm time in minutes (default: 5 minutes before ETA)
  final int backupAlarmMinutes;
  
  /// Whether to vibrate on alarm
  final bool vibrateOnAlarm;
  
  /// Whether to play sound on alarm
  final bool playSoundOnAlarm;
  
  /// Safety settings for off-route detection
  final SafetySettings safetySettings;
  
  // * NEW: Smart Alarm Buffer settings
  
  /// Whether to use smart alarm buffer based on speed
  final bool useSmartAlarmBuffer;
  
  /// Minimum seconds before destination to trigger alarm (default: 30)
  final int minSecondsBeforeAlarm;
  
  /// Maximum seconds before destination to trigger alarm (default: 90)
  final int maxSecondsBeforeAlarm;
  
  // * NEW: Multi-Stage Alarm settings
  
  /// Whether to use multi-stage alarm (progressive escalation)
  final bool useMultiStageAlarm;
  
  // * NEW: Ultra-Low Power Mode settings
  
  /// Whether ultra-low power mode is enabled
  final bool ultraLowPowerMode;
  
  /// GPS sampling interval in seconds for low power mode (default: 30)
  final int lowPowerGpsIntervalSeconds;
  
  /// Whether to minimize alerts when phone is actively being used
  final bool minimizeAlertsWhenActive;
  
  // * NEW: Vehicle Type for realistic ETA
  
  /// The type of vehicle being used for this commute
  final VehicleType vehicleType;
  
  const CommuteSettings({
    this.alarmDistanceMeters = 500,
    this.useTimeBackupAlarm = true,
    this.backupAlarmMinutes = 5,
    this.vibrateOnAlarm = true,
    this.playSoundOnAlarm = true,
    this.safetySettings = const SafetySettings(),
    this.useSmartAlarmBuffer = true,
    this.minSecondsBeforeAlarm = 30,
    this.maxSecondsBeforeAlarm = 90,
    this.useMultiStageAlarm = true,
    this.ultraLowPowerMode = false,
    this.lowPowerGpsIntervalSeconds = 30,
    this.minimizeAlertsWhenActive = true,
    this.vehicleType = VehicleType.jeepney,
  });
  
  CommuteSettings copyWith({
    int? alarmDistanceMeters,
    bool? useTimeBackupAlarm,
    int? backupAlarmMinutes,
    bool? vibrateOnAlarm,
    bool? playSoundOnAlarm,
    SafetySettings? safetySettings,
    bool? useSmartAlarmBuffer,
    int? minSecondsBeforeAlarm,
    int? maxSecondsBeforeAlarm,
    bool? useMultiStageAlarm,
    bool? ultraLowPowerMode,
    int? lowPowerGpsIntervalSeconds,
    bool? minimizeAlertsWhenActive,
    VehicleType? vehicleType,
  }) {
    return CommuteSettings(
      alarmDistanceMeters: alarmDistanceMeters ?? this.alarmDistanceMeters,
      useTimeBackupAlarm: useTimeBackupAlarm ?? this.useTimeBackupAlarm,
      backupAlarmMinutes: backupAlarmMinutes ?? this.backupAlarmMinutes,
      vibrateOnAlarm: vibrateOnAlarm ?? this.vibrateOnAlarm,
      playSoundOnAlarm: playSoundOnAlarm ?? this.playSoundOnAlarm,
      safetySettings: safetySettings ?? this.safetySettings,
      useSmartAlarmBuffer: useSmartAlarmBuffer ?? this.useSmartAlarmBuffer,
      minSecondsBeforeAlarm: minSecondsBeforeAlarm ?? this.minSecondsBeforeAlarm,
      maxSecondsBeforeAlarm: maxSecondsBeforeAlarm ?? this.maxSecondsBeforeAlarm,
      useMultiStageAlarm: useMultiStageAlarm ?? this.useMultiStageAlarm,
      ultraLowPowerMode: ultraLowPowerMode ?? this.ultraLowPowerMode,
      lowPowerGpsIntervalSeconds: lowPowerGpsIntervalSeconds ?? this.lowPowerGpsIntervalSeconds,
      minimizeAlertsWhenActive: minimizeAlertsWhenActive ?? this.minimizeAlertsWhenActive,
      vehicleType: vehicleType ?? this.vehicleType,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      "alarmDistanceMeters": alarmDistanceMeters,
      "useTimeBackupAlarm": useTimeBackupAlarm,
      "backupAlarmMinutes": backupAlarmMinutes,
      "vibrateOnAlarm": vibrateOnAlarm,
      "playSoundOnAlarm": playSoundOnAlarm,
      "safetySettings": safetySettings.toJson(),
      "useSmartAlarmBuffer": useSmartAlarmBuffer,
      "minSecondsBeforeAlarm": minSecondsBeforeAlarm,
      "maxSecondsBeforeAlarm": maxSecondsBeforeAlarm,
      "useMultiStageAlarm": useMultiStageAlarm,
      "ultraLowPowerMode": ultraLowPowerMode,
      "lowPowerGpsIntervalSeconds": lowPowerGpsIntervalSeconds,
      "minimizeAlertsWhenActive": minimizeAlertsWhenActive,
      "vehicleType": vehicleType.jsonKey,
    };
  }
  
  factory CommuteSettings.fromJson(Map<String, dynamic> json) {
    return CommuteSettings(
      alarmDistanceMeters: json["alarmDistanceMeters"] as int? ?? 500,
      useTimeBackupAlarm: json["useTimeBackupAlarm"] as bool? ?? true,
      backupAlarmMinutes: json["backupAlarmMinutes"] as int? ?? 5,
      vibrateOnAlarm: json["vibrateOnAlarm"] as bool? ?? true,
      playSoundOnAlarm: json["playSoundOnAlarm"] as bool? ?? true,
      safetySettings: json["safetySettings"] != null
          ? SafetySettings.fromJson(json["safetySettings"] as Map<String, dynamic>)
          : const SafetySettings(),
      useSmartAlarmBuffer: json["useSmartAlarmBuffer"] as bool? ?? true,
      minSecondsBeforeAlarm: json["minSecondsBeforeAlarm"] as int? ?? 30,
      maxSecondsBeforeAlarm: json["maxSecondsBeforeAlarm"] as int? ?? 90,
      useMultiStageAlarm: json["useMultiStageAlarm"] as bool? ?? true,
      ultraLowPowerMode: json["ultraLowPowerMode"] as bool? ?? false,
      lowPowerGpsIntervalSeconds: json["lowPowerGpsIntervalSeconds"] as int? ?? 30,
      minimizeAlertsWhenActive: json["minimizeAlertsWhenActive"] as bool? ?? true,
      vehicleType: VehicleTypeExtension.fromJson(json["vehicleType"] as String?),
    );
  }
}

/// * Commute mode state
class CommuteState {
  /// Destination coordinates
  final LatLng? destination;
  
  /// Destination display name
  final String? destinationName;
  
  /// Current commute settings
  final CommuteSettings settings;
  
  /// Current commute status
  final CommuteStatus status;
  
  /// Current distance to destination in meters
  final double? distanceToDestinationMeters;
  
  /// Initial distance when commute started (for progress calculation)
  final double? initialDistanceMeters;
  
  /// Estimated time of arrival
  final Duration? etaToDestination;
  
  /// When commute tracking started
  final DateTime? startedAt;
  
  /// Starting position when commute began
  final LatLng? startPosition;
  
  /// Whether the user has passed the destination (lagpas-baba)
  final bool hasPassedDestination;
  
  /// Minimum distance reached (to detect passing destination)
  final double? minDistanceReached;
  
  /// Whether alarm has been triggered
  final bool alarmTriggered;
  
  /// Whether alarm has been dismissed by user
  final bool alarmDismissed;
  
  /// Current user position
  final LatLng? currentPosition;
  
  /// Whether safety alert has been triggered
  final bool safetyAlertTriggered;
  
  /// Distance off route in km (for safety feature)
  final double? offRouteDistanceKm;
  
  /// Last time safety SMS was sent
  final DateTime? lastSafetySmsAt;
  
  // * NEW: Smart Alarm Buffer fields
  
  /// Current speed in meters per second
  final double? currentSpeedMs;
  
  // * NEW: Multi-Stage Alarm fields
  
  /// Current alarm stage
  final AlarmStage alarmStage;
  
  /// Whether alarm sound is currently playing
  final bool alarmSoundPlaying;
  
  // * NEW: Overshoot Recovery fields
  
  /// Recovery hint for overshoot (lagpas-baba)
  final String? overshootRecoveryHint;
  
  /// Distance overshot past destination in meters
  final double? overshootDistanceMeters;
  
  // * NEW: Ultra-Low Power Mode fields
  
  /// Whether currently in low power mode
  final bool isLowPowerActive;
  
  // * NEW: Safety Alert Improvement fields
  
  /// When off-route was first detected (for sustained detection)
  final DateTime? offRouteStartedAt;
  
  /// Direction deviation from expected route (degrees)
  final double? deviationAngleDegrees;
  
  /// When the last safety alert was triggered (for cooldown)
  final DateTime? lastAlertTriggeredAt;
  
  /// Previous position (for direction calculation)
  final LatLng? previousPosition;
  
  // * NEW: Weather-aware ETA fields
  
  /// Current weather data (fetched from WeatherService on commute start)
  final WeatherData? currentWeather;
  
  // * NEW: Traffic light ETA fields
  
  /// Estimated number of traffic lights along the route (from OSM Overpass)
  final int? trafficLightCount;

  /// * Top transit itinerary from GTFS planner (PlannerItinerary, stored as Object to avoid service import).
  final Object? transitItinerary;

  const CommuteState({
    this.destination,
    this.destinationName,
    this.settings = const CommuteSettings(),
    this.status = CommuteStatus.idle,
    this.distanceToDestinationMeters,
    this.initialDistanceMeters,
    this.etaToDestination,
    this.startedAt,
    this.startPosition,
    this.hasPassedDestination = false,
    this.minDistanceReached,
    this.alarmTriggered = false,
    this.alarmDismissed = false,
    this.currentPosition,
    this.safetyAlertTriggered = false,
    this.offRouteDistanceKm,
    this.lastSafetySmsAt,
    this.currentSpeedMs,
    this.alarmStage = AlarmStage.none,
    this.alarmSoundPlaying = false,
    this.overshootRecoveryHint,
    this.overshootDistanceMeters,
    this.isLowPowerActive = false,
    this.offRouteStartedAt,
    this.deviationAngleDegrees,
    this.lastAlertTriggeredAt,
    this.previousPosition,
    this.currentWeather,
    this.trafficLightCount,
    this.transitItinerary,
  });
  
  /// Check if commute is currently active
  bool get isActive => status == CommuteStatus.active || 
                        status == CommuteStatus.approaching ||
                        status == CommuteStatus.danger;
  
  /// Check if alarm should be triggered based on distance
  bool get shouldTriggerDistanceAlarm {
    if (distanceToDestinationMeters == null) return false;
    return distanceToDestinationMeters! <= settings.alarmDistanceMeters;
  }
  
  /// Check if alarm should be triggered based on time
  bool get shouldTriggerTimeAlarm {
    if (!settings.useTimeBackupAlarm) return false;
    if (etaToDestination == null) return false;
    return etaToDestination!.inMinutes <= settings.backupAlarmMinutes;
  }
  
  /// Get progress percentage (0.0 to 1.0)
  double get progressPercentage {
    if (initialDistanceMeters == null || distanceToDestinationMeters == null) {
      return 0.0;
    }
    if (initialDistanceMeters! <= 0) return 1.0;
    
    final traveled = initialDistanceMeters! - distanceToDestinationMeters!;
    return (traveled / initialDistanceMeters!).clamp(0.0, 1.0);
  }
  
  /// Get formatted distance string with proper units
  String get formattedDistance {
    if (distanceToDestinationMeters == null) return "-- m";
    
    final meters = distanceToDestinationMeters!;
    if (meters < 1000) {
      return "${meters.round()} m";
    } else {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
  }
  
  /// Get formatted ETA string
  String get formattedEta {
    if (etaToDestination == null) return "-- min";
    
    final totalSeconds = etaToDestination!.inSeconds;
    if (totalSeconds < 60) {
      return "< 1 min";
    }
    
    final minutes = etaToDestination!.inMinutes;
    if (minutes < 60) {
      return "$minutes min";
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return "$hours hr";
      }
      return "$hours hr $remainingMinutes min";
    }
  }
  
  /// Get short formatted ETA (for compact display)
  String get formattedEtaShort {
    if (etaToDestination == null) return "--";
    
    final minutes = etaToDestination!.inMinutes;
    if (minutes < 60) {
      return "${minutes}m";
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return "${hours}h${remainingMinutes}m";
    }
  }
  
  /// Get status display text
  String get statusText {
    switch (status) {
      case CommuteStatus.idle:
        return "Set your destination";
      case CommuteStatus.active:
        return "Tracking your commute";
      case CommuteStatus.approaching:
        return "Get ready to alight!";
      case CommuteStatus.arrived:
        return "You've arrived safely!";
      case CommuteStatus.passed:
        return "LAGPAS KA NA!";
      case CommuteStatus.danger:
        return "Safety Alert!";
    }
  }
  
  // * NEW: Smart Alarm Buffer computed properties
  
  /// Get smart alarm distance based on current speed
  double get smartAlarmDistanceMeters {
    if (!settings.useSmartAlarmBuffer || currentSpeedMs == null || currentSpeedMs! <= 0) {
      return settings.alarmDistanceMeters.toDouble();
    }
    // Calculate distance = speed × time (target average of min/max seconds)
    final targetSeconds = (settings.minSecondsBeforeAlarm + settings.maxSecondsBeforeAlarm) / 2;
    final distance = currentSpeedMs! * targetSeconds;
    // Clamp between 100m and 2km
    return distance.clamp(100.0, 2000.0);
  }
  
  /// Get formatted ETA in seconds (for alarm preview)
  String get formattedEtaSeconds {
    if (currentSpeedMs == null || currentSpeedMs! <= 0) {
      return "~${settings.minSecondsBeforeAlarm}-${settings.maxSecondsBeforeAlarm} sec";
    }
    final seconds = (smartAlarmDistanceMeters / currentSpeedMs!).round();
    return "~$seconds sec";
  }
  
  /// Get current speed in km/h for display
  String get formattedSpeedKmh {
    if (currentSpeedMs == null || currentSpeedMs! <= 0) return "0 km/h";
    final kmh = currentSpeedMs! * 3.6;
    return "${kmh.toStringAsFixed(0)} km/h";
  }
  
  // * NEW: Safety Alert computed properties
  
  /// Whether currently in night mode (stricter safety)
  bool get isNightMode {
    final hour = DateTime.now().hour;
    final start = settings.safetySettings.nightModeStartHour;
    final end = settings.safetySettings.nightModeEndHour;
    if (start > end) {
      // Spans midnight (e.g., 21:00 to 05:00)
      return hour >= start || hour < end;
    }
    return hour >= start && hour < end;
  }
  
  /// Effective off-route threshold (adjusted for time of day)
  double get effectiveOffRouteThresholdKm {
    final base = settings.safetySettings.offRouteThresholdKm;
    if (!settings.safetySettings.useTimeOfDaySensitivity) return base;
    if (isNightMode) {
      return base * settings.safetySettings.nightModeThresholdMultiplier;
    }
    return base;
  }
  
  /// Whether deviation is sustained (meets time threshold)
  bool get isSustainedOffRoute {
    if (offRouteStartedAt == null) return false;
    final duration = DateTime.now().difference(offRouteStartedAt!);
    return duration.inSeconds >= settings.safetySettings.sustainedOffRouteSeconds;
  }
  
  /// Whether in alert cooldown period
  bool get isInAlertCooldown {
    if (lastAlertTriggeredAt == null) return false;
    final cooldownDuration = Duration(minutes: settings.safetySettings.alertCooldownMinutes);
    return DateTime.now().difference(lastAlertTriggeredAt!) < cooldownDuration;
  }
  
  /// Get formatted overshoot distance
  String get formattedOvershootDistance {
    if (overshootDistanceMeters == null) return "-- m";
    final meters = overshootDistanceMeters!;
    if (meters < 1000) {
      return "${meters.round()} m";
    }
    return "${(meters / 1000).toStringAsFixed(1)} km";
  }

  
  CommuteState copyWith({
    LatLng? destination,
    String? destinationName,
    CommuteSettings? settings,
    CommuteStatus? status,
    double? distanceToDestinationMeters,
    double? initialDistanceMeters,
    Duration? etaToDestination,
    DateTime? startedAt,
    LatLng? startPosition,
    bool? hasPassedDestination,
    double? minDistanceReached,
    bool? alarmTriggered,
    bool? alarmDismissed,
    LatLng? currentPosition,
    bool? safetyAlertTriggered,
    double? offRouteDistanceKm,
    DateTime? lastSafetySmsAt,
    double? currentSpeedMs,
    AlarmStage? alarmStage,
    bool? alarmSoundPlaying,
    String? overshootRecoveryHint,
    double? overshootDistanceMeters,
    bool? isLowPowerActive,
    DateTime? offRouteStartedAt,
    double? deviationAngleDegrees,
    DateTime? lastAlertTriggeredAt,
    LatLng? previousPosition,
    WeatherData? currentWeather,
    int? trafficLightCount,
    Object? transitItinerary,
    bool clearDestination = false,
    bool clearEta = false,
    bool clearDistance = false,
    bool clearStartedAt = false,
    bool clearMinDistance = false,
    bool clearCurrentPosition = false,
    bool clearOffRouteDistance = false,
    bool clearLastSafetySms = false,
    bool clearOvershootHint = false,
    bool clearOvershootDistance = false,
    bool clearOffRouteStartedAt = false,
    bool clearDeviationAngle = false,
    bool clearLastAlertTriggered = false,
    bool clearPreviousPosition = false,
    bool clearWeather = false,
    bool clearTrafficLights = false,
    bool clearTransitItinerary = false,
  }) {
    return CommuteState(
      destination: clearDestination ? null : (destination ?? this.destination),
      destinationName: clearDestination ? null : (destinationName ?? this.destinationName),
      settings: settings ?? this.settings,
      status: status ?? this.status,
      distanceToDestinationMeters: clearDistance ? null : (distanceToDestinationMeters ?? this.distanceToDestinationMeters),
      initialDistanceMeters: initialDistanceMeters ?? this.initialDistanceMeters,
      etaToDestination: clearEta ? null : (etaToDestination ?? this.etaToDestination),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      startPosition: startPosition ?? this.startPosition,
      hasPassedDestination: hasPassedDestination ?? this.hasPassedDestination,
      minDistanceReached: clearMinDistance ? null : (minDistanceReached ?? this.minDistanceReached),
      alarmTriggered: alarmTriggered ?? this.alarmTriggered,
      alarmDismissed: alarmDismissed ?? this.alarmDismissed,
      currentPosition: clearCurrentPosition ? null : (currentPosition ?? this.currentPosition),
      safetyAlertTriggered: safetyAlertTriggered ?? this.safetyAlertTriggered,
      offRouteDistanceKm: clearOffRouteDistance ? null : (offRouteDistanceKm ?? this.offRouteDistanceKm),
      lastSafetySmsAt: clearLastSafetySms ? null : (lastSafetySmsAt ?? this.lastSafetySmsAt),
      currentSpeedMs: currentSpeedMs ?? this.currentSpeedMs,
      alarmStage: alarmStage ?? this.alarmStage,
      alarmSoundPlaying: alarmSoundPlaying ?? this.alarmSoundPlaying,
      overshootRecoveryHint: clearOvershootHint ? null : (overshootRecoveryHint ?? this.overshootRecoveryHint),
      overshootDistanceMeters: clearOvershootDistance ? null : (overshootDistanceMeters ?? this.overshootDistanceMeters),
      isLowPowerActive: isLowPowerActive ?? this.isLowPowerActive,
      offRouteStartedAt: clearOffRouteStartedAt ? null : (offRouteStartedAt ?? this.offRouteStartedAt),
      deviationAngleDegrees: clearDeviationAngle ? null : (deviationAngleDegrees ?? this.deviationAngleDegrees),
      lastAlertTriggeredAt: clearLastAlertTriggered ? null : (lastAlertTriggeredAt ?? this.lastAlertTriggeredAt),
      previousPosition: clearPreviousPosition ? null : (previousPosition ?? this.previousPosition),
      currentWeather: clearWeather ? null : (currentWeather ?? this.currentWeather),
      trafficLightCount: clearTrafficLights ? null : (trafficLightCount ?? this.trafficLightCount),
      transitItinerary: clearTransitItinerary ? null : (transitItinerary ?? this.transitItinerary),
    );
  }
  
  /// Reset to idle state
  CommuteState reset() {
    return CommuteState(
      settings: settings, // Keep settings
    );
  }
}

