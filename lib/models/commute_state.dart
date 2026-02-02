import "package:latlong2/latlong.dart";

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
  
  const SafetySettings({
    this.enabled = false,
    this.emergencyContacts = const [],
    this.offRouteThresholdKm = 3.0,
    this.autoSmsEnabled = false,
    this.smsCooldownMinutes = 5,
  });
  
  SafetySettings copyWith({
    bool? enabled,
    List<EmergencyContact>? emergencyContacts,
    double? offRouteThresholdKm,
    bool? autoSmsEnabled,
    int? smsCooldownMinutes,
  }) {
    return SafetySettings(
      enabled: enabled ?? this.enabled,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      offRouteThresholdKm: offRouteThresholdKm ?? this.offRouteThresholdKm,
      autoSmsEnabled: autoSmsEnabled ?? this.autoSmsEnabled,
      smsCooldownMinutes: smsCooldownMinutes ?? this.smsCooldownMinutes,
    );
  }
  
  Map<String, dynamic> toJson() => {
    "enabled": enabled,
    "emergencyContacts": emergencyContacts.map((c) => c.toJson()).toList(),
    "offRouteThresholdKm": offRouteThresholdKm,
    "autoSmsEnabled": autoSmsEnabled,
    "smsCooldownMinutes": smsCooldownMinutes,
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
  
  const CommuteSettings({
    this.alarmDistanceMeters = 500,
    this.useTimeBackupAlarm = true,
    this.backupAlarmMinutes = 5,
    this.vibrateOnAlarm = true,
    this.playSoundOnAlarm = true,
    this.safetySettings = const SafetySettings(),
  });
  
  CommuteSettings copyWith({
    int? alarmDistanceMeters,
    bool? useTimeBackupAlarm,
    int? backupAlarmMinutes,
    bool? vibrateOnAlarm,
    bool? playSoundOnAlarm,
    SafetySettings? safetySettings,
  }) {
    return CommuteSettings(
      alarmDistanceMeters: alarmDistanceMeters ?? this.alarmDistanceMeters,
      useTimeBackupAlarm: useTimeBackupAlarm ?? this.useTimeBackupAlarm,
      backupAlarmMinutes: backupAlarmMinutes ?? this.backupAlarmMinutes,
      vibrateOnAlarm: vibrateOnAlarm ?? this.vibrateOnAlarm,
      playSoundOnAlarm: playSoundOnAlarm ?? this.playSoundOnAlarm,
      safetySettings: safetySettings ?? this.safetySettings,
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
    bool clearDestination = false,
    bool clearEta = false,
    bool clearDistance = false,
    bool clearStartedAt = false,
    bool clearMinDistance = false,
    bool clearCurrentPosition = false,
    bool clearOffRouteDistance = false,
    bool clearLastSafetySms = false,
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
    );
  }
  
  /// Reset to idle state
  CommuteState reset() {
    return CommuteState(
      settings: settings, // Keep settings
    );
  }
}

