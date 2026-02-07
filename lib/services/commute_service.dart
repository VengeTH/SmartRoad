import "dart:async";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";

import "../models/commute_state.dart";
import "location_service.dart";
import "notification_service.dart";
import "emergency_sms_service.dart";

/// * Commute Mode Service
/// * Handles background location tracking, distance calculations,
/// * alarm triggering, lagpas-baba detection, and safety alerts for commuters.
/// * V2: Adds smart alarm buffer, multi-stage alarms, and improved safety detection.
class CommuteService {
  static final CommuteService _instance = CommuteService._internal();
  factory CommuteService() => _instance;
  CommuteService._internal();
  
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final EmergencySmsService _emergencySmsService = EmergencySmsService();
  
  // * Location stream subscription
  StreamSubscription<Position>? _positionSubscription;
  
  // * State change callback
  void Function(CommuteState)? onStateChanged;
  
  // * Current state
  CommuteState _state = const CommuteState();
  CommuteState get state => _state;
  
  // * Alarm repeat timer
  Timer? _alarmRepeatTimer;
  
  // * Multi-stage alarm timers
  Timer? _stage1Timer;
  Timer? _stage2Timer;
  Timer? _stage3Timer;
  
  // * Average speed tracking for ETA calculation
  final List<double> _recentSpeeds = [];
  static const int _maxSpeedSamples = 10;
  static const double _defaultSpeedKmh = 20.0; // * Typical jeepney/bus speed
  
  /// * Initialize the commute service
  Future<void> initialize() async {
    await _notificationService.initialize();
    debugPrint("[CommuteService] OK: Initialized (v2 with enhanced features)");
  }
  
  /// * Start commute tracking
  Future<bool> startCommute({
    required LatLng destination,
    required String destinationName,
    CommuteSettings? settings,
  }) async {
    try {
      debugPrint("[CommuteService] Starting commute to: $destinationName");
      
      // * Check location permission
      final hasPermission = await _locationService.requestPermission();
      if (!hasPermission) {
        debugPrint("[CommuteService] ERROR: Location permission denied");
        return false;
      }
      
      // * Get initial position
      final initialPosition = await _locationService.getCurrentPosition();
      if (initialPosition == null) {
        debugPrint("[CommuteService] ERROR: Could not get initial position");
        return false;
      }
      
      final currentLocation = LatLng(
        initialPosition.latitude,
        initialPosition.longitude,
      );
      
      // * Calculate initial distance
      final initialDistance = _calculateDistanceMeters(
        currentLocation,
        destination,
      );
      
      // * Calculate initial ETA
      final initialEta = _estimateEta(initialDistance);
      
      final commuteSettings = settings ?? const CommuteSettings();
      
      // * Update state
      _state = CommuteState(
        destination: destination,
        destinationName: destinationName,
        settings: commuteSettings,
        status: CommuteStatus.active,
        distanceToDestinationMeters: initialDistance,
        initialDistanceMeters: initialDistance, // * Track starting distance
        etaToDestination: initialEta,
        startedAt: DateTime.now(),
        startPosition: currentLocation, // * Track starting position
        minDistanceReached: initialDistance,
        currentPosition: currentLocation,
        currentSpeedMs: initialPosition.speed > 0 ? initialPosition.speed : null,
        isLowPowerActive: commuteSettings.ultraLowPowerMode,
      );
      
      _notifyStateChanged();
      
      // * Show foreground notification for background tracking
      await _notificationService.showCommuteTrackingNotification(
        destinationName: destinationName,
        distanceText: _state.formattedDistance,
        etaText: _state.formattedEta,
      );
      
      // * Start location stream
      _startLocationStream();
      
      debugPrint("[CommuteService] OK: Commute started: ${initialDistance.round()}m to destination");
      debugPrint("[CommuteService] Smart alarm: ${_state.smartAlarmDistanceMeters.round()}m, Multi-stage: ${commuteSettings.useMultiStageAlarm}");
      return true;
    } catch (e) {
      debugPrint("[CommuteService] ERROR: Error starting commute: $e");
      return false;
    }
  }
  
  /// * Stop commute tracking
  Future<void> stopCommute() async {
    debugPrint("[CommuteService] Stopping commute");
    
    // * Cancel location subscription
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    
    // * Cancel all alarm timers
    _cancelAllAlarmTimers();
    
    // * Clear speed samples
    _recentSpeeds.clear();
    
    // * Cancel notifications
    await _notificationService.cancelCommuteNotifications();
    
    // * Reset state
    _state = _state.reset();
    _notifyStateChanged();
    
    debugPrint("[CommuteService] OK: Commute stopped");
  }
  
  /// * Cancel all alarm timers
  void _cancelAllAlarmTimers() {
    _alarmRepeatTimer?.cancel();
    _alarmRepeatTimer = null;
    _stage1Timer?.cancel();
    _stage1Timer = null;
    _stage2Timer?.cancel();
    _stage2Timer = null;
    _stage3Timer?.cancel();
    _stage3Timer = null;
  }
  
  /// * Dismiss the alarm
  void dismissAlarm() {
    debugPrint("[CommuteService] Alarm dismissed by user");
    
    _cancelAllAlarmTimers();
    
    _state = _state.copyWith(
      alarmDismissed: true,
      alarmStage: AlarmStage.none,
      alarmSoundPlaying: false,
    );
    _notifyStateChanged();
    
    _notificationService.cancelCommuteAlarm();
    _notificationService.cancelLagpasAlert();
  }
  
  /// * Dismiss safety alert (user confirmed safe)
  void dismissSafetyAlert() {
    debugPrint("[CommuteService] OK: Safety alert dismissed - user is safe");
    
    _state = _state.copyWith(
      safetyAlertTriggered: false,
      status: CommuteStatus.active,
      clearOffRouteDistance: true,
      clearOffRouteStartedAt: true,
      clearDeviationAngle: true,
    );
    _notifyStateChanged();
  }
  
  /// * Send safety alert to emergency contacts
  Future<void> sendSafetyAlert() async {
    final safetySettings = _state.settings.safetySettings;
    if (safetySettings.emergencyContacts.isEmpty) {
      debugPrint("[CommuteService] WARNING: No emergency contacts configured");
      return;
    }
    
    if (_state.currentPosition == null) {
      debugPrint("[CommuteService] WARNING: No current position available");
      return;
    }
    
    debugPrint("[CommuteService] Sending safety alert SMS...");
    
    await _emergencySmsService.sendEmergencyAlert(
      contacts: safetySettings.emergencyContacts,
      latitude: _state.currentPosition!.latitude,
      longitude: _state.currentPosition!.longitude,
      destinationName: _state.destinationName ?? "Unknown",
    );
    
    _state = _state.copyWith(
      lastSafetySmsAt: DateTime.now(),
      lastAlertTriggeredAt: DateTime.now(),
    );
    _notifyStateChanged();
  }
  
  /// * Manually trigger SOS (immediate send)
  Future<void> triggerManualSOS() async {
    debugPrint("[CommuteService] ALERT: MANUAL SOS TRIGGERED!");
    
    HapticFeedback.heavyImpact();
    
    // * Send immediately without grace period
    await sendSafetyAlert();
  }
  
  /// * Update commute settings
  void updateSettings(CommuteSettings settings) {
    _state = _state.copyWith(
      settings: settings,
      isLowPowerActive: settings.ultraLowPowerMode,
    );
    
    // * Restart location stream with new settings if active
    if (_state.isActive) {
      _startLocationStream();
    }
    
    _notifyStateChanged();
  }
  
  /// * Start listening to location updates
  void _startLocationStream() {
    _positionSubscription?.cancel();
    
    final locationSettings = _getLocationSettings();
    
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        debugPrint("[CommuteService] ERROR: Location stream error: $e");
      },
    );
    
    debugPrint("[CommuteService] Location stream started (low power: ${_state.isLowPowerActive})");
  }
  
  /// * Get location settings based on power mode
  LocationSettings _getLocationSettings() {
    if (_state.settings.ultraLowPowerMode) {
      return LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 50, // * Update every 50 meters
        timeLimit: Duration(seconds: _state.settings.lowPowerGpsIntervalSeconds),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // * Update every 10 meters
    );
  }
  
  /// * Handle position updates
  void _onPositionUpdate(Position position) {
    if (_state.status == CommuteStatus.idle) return;
    if (_state.destination == null) return;
    
    final currentLocation = LatLng(position.latitude, position.longitude);
    final destination = _state.destination!;
    
    // * Calculate distance to destination
    final distance = _calculateDistanceMeters(currentLocation, destination);
    
    // * Track speed for ETA calculation and smart alarm
    double? currentSpeed;
    if (position.speed > 0) {
      currentSpeed = position.speed;
      final speedKmh = position.speed * 3.6; // * m/s to km/h
      _recentSpeeds.add(speedKmh);
      if (_recentSpeeds.length > _maxSpeedSamples) {
        _recentSpeeds.removeAt(0);
      }
    }
    
    // * Calculate ETA
    final eta = _estimateEta(distance);
    
    // * Track minimum distance for lagpas-baba detection
    final minDistance = _state.minDistanceReached ?? distance;
    final newMinDistance = distance < minDistance ? distance : minDistance;
    
    // * Check off-route distance for safety feature
    double? offRouteDistance;
    double? deviationAngle;
    if (_state.settings.safetySettings.enabled && _state.startPosition != null) {
      offRouteDistance = _calculateOffRouteDistance(
        currentLocation,
        _state.startPosition!,
        destination,
      );
      
      // * Calculate deviation angle if we have previous position
      if (_state.previousPosition != null) {
        deviationAngle = _calculateDeviationAngle(
          currentLocation,
          _state.previousPosition!,
          destination,
        );
      }
    }
    
    // * Update state
    _state = _state.copyWith(
      distanceToDestinationMeters: distance,
      etaToDestination: eta,
      currentPosition: currentLocation,
      previousPosition: _state.currentPosition, // * Store previous for direction calc
      minDistanceReached: newMinDistance,
      offRouteDistanceKm: offRouteDistance,
      currentSpeedMs: currentSpeed,
      deviationAngleDegrees: deviationAngle,
    );
    
    // * Check for status changes
    _checkAndUpdateStatus(distance, newMinDistance);
    
    // * Check for off-route safety alert
    _checkSafetyAlert(offRouteDistance);
    
    // * Update foreground notification
    if (_state.isActive && _state.status != CommuteStatus.danger) {
      _notificationService.updateCommuteTrackingNotification(
        destinationName: _state.destinationName ?? "Destination",
        distanceText: _state.formattedDistance,
        etaText: _state.formattedEta,
      );
    }
    
    _notifyStateChanged();
  }
  
  /// * Calculate perpendicular distance from the route line (start -> destination)
  double _calculateOffRouteDistance(
    LatLng currentPosition,
    LatLng startPosition,
    LatLng destination,
  ) {
    // * Calculate distance from point to line (start -> destination)
    // * Using cross product method
    
    final startToEnd = _calculateDistanceMeters(startPosition, destination);
    if (startToEnd < 100) {
      // * Start and destination are very close, use direct distance
      return _calculateDistanceMeters(currentPosition, destination) / 1000.0;
    }
    
    // * Project current position onto line from start to destination
    // * Simplified: calculate min distance to either endpoint or perpendicular distance
    
    final distToStart = _calculateDistanceMeters(currentPosition, startPosition);
    final distToEnd = _calculateDistanceMeters(currentPosition, destination);
    
    // * Use cross-product approximation for perpendicular distance
    // * This is a simplified version - for more accuracy, use proper geodesic math
    
    // * Calculate vectors
    final v1Lat = destination.latitude - startPosition.latitude;
    final v1Lon = destination.longitude - startPosition.longitude;
    final v2Lat = currentPosition.latitude - startPosition.latitude;
    final v2Lon = currentPosition.longitude - startPosition.longitude;
    
    // * Cross product magnitude
    final crossProduct = (v1Lat * v2Lon - v1Lon * v2Lat).abs();
    
    // * Line length in degrees
    final lineLength = math.sqrt(v1Lat * v1Lat + v1Lon * v1Lon);
    
    if (lineLength < 0.00001) {
      return distToStart / 1000.0;
    }
    
    // * Perpendicular distance in degrees, convert to km approximately
    final perpDistDeg = crossProduct / lineLength;
    final perpDistKm = perpDistDeg * 111.0; // * ~111 km per degree
    
    // * Check if we're past the endpoints
    final dotProduct = v1Lat * v2Lat + v1Lon * v2Lon;
    if (dotProduct < 0) {
      // * Before start point
      return distToStart / 1000.0;
    }
    
    final lineLengthSq = v1Lat * v1Lat + v1Lon * v1Lon;
    if (dotProduct > lineLengthSq) {
      // * Past end point
      return distToEnd / 1000.0;
    }
    
    return perpDistKm;
  }
  
  /// * Calculate direction deviation from expected route
  double _calculateDeviationAngle(
    LatLng current,
    LatLng previous,
    LatLng destination,
  ) {
    // * Calculate bearing from previous to current (actual movement)
    final actualBearing = _calculateBearing(previous, current);
    // * Calculate expected bearing to destination
    final expectedBearing = _calculateBearing(current, destination);
    // * Return angle difference (0-180)
    var diff = (actualBearing - expectedBearing).abs();
    if (diff > 180) diff = 360 - diff;
    return diff;
  }
  
  /// * Calculate bearing between two points in degrees
  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);
    
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - 
              math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    
    var bearing = math.atan2(y, x);
    bearing = bearing * (180 / math.pi);
    bearing = (bearing + 360) % 360;
    
    return bearing;
  }
  
  /// * Check if safety alert should be triggered
  void _checkSafetyAlert(double? offRouteDistanceKm) {
    if (offRouteDistanceKm == null) return;
    
    final safetySettings = _state.settings.safetySettings;
    if (!safetySettings.enabled) return;
    
    // * Check if in cooldown
    if (_state.isInAlertCooldown) {
      debugPrint("[CommuteService] In alert cooldown, skipping check");
      return;
    }
    
    // * Get effective threshold (adjusted for time of day)
    final threshold = _state.effectiveOffRouteThresholdKm;
    
    // * Check if we've exceeded the threshold
    if (offRouteDistanceKm >= threshold) {
      // * First detection - start the sustained timer
      if (_state.offRouteStartedAt == null) {
        debugPrint("[CommuteService] WARNING: Off-route detected, starting sustained timer...");
        _state = _state.copyWith(offRouteStartedAt: DateTime.now());
        _notifyStateChanged();
        return;
      }
      
      // * Check if sustained (meets time threshold)
      if (!_state.isSustainedOffRoute) {
        // * Not sustained yet, keep waiting
        final elapsed = DateTime.now().difference(_state.offRouteStartedAt!).inSeconds;
        debugPrint("[CommuteService] Off-route for ${elapsed}s / ${safetySettings.sustainedOffRouteSeconds}s");
        return;
      }
      
      // * Sustained off-route! Trigger alert
      if (!_state.safetyAlertTriggered) {
        debugPrint("[CommuteService] ALERT: SUSTAINED OFF-ROUTE DETECTED! ${offRouteDistanceKm.toStringAsFixed(1)}km from route");
        debugPrint("[CommuteService] Night mode: ${_state.isNightMode}, Effective threshold: ${threshold.toStringAsFixed(1)}km");
        
        _state = _state.copyWith(
          safetyAlertTriggered: true,
          status: CommuteStatus.danger,
          lastAlertTriggeredAt: DateTime.now(),
        );
        
        HapticFeedback.heavyImpact();
        
        // * Auto-send SMS if enabled and cooldown passed
        if (safetySettings.autoSmsEnabled) {
          final lastSms = _state.lastSafetySmsAt;
          final cooldownPassed = lastSms == null ||
              DateTime.now().difference(lastSms).inMinutes >= safetySettings.smsCooldownMinutes;
          
          if (cooldownPassed && safetySettings.emergencyContacts.isNotEmpty) {
            // * SMS will be triggered from UI after countdown
            debugPrint("[CommuteService] Auto-SMS enabled, will trigger from overlay");
          }
        }
      }
    } else {
      // * Back on route - reset the off-route timer
      if (_state.offRouteStartedAt != null) {
        debugPrint("[CommuteService] OK: Back on route, resetting off-route timer");
        _state = _state.copyWith(clearOffRouteStartedAt: true);
      }
    }
  }
  
  /// * Check and update commute status based on distance
  void _checkAndUpdateStatus(double distance, double minDistance) {
    // * Skip if we're in danger mode (safety takes priority)
    if (_state.status == CommuteStatus.danger) return;
    
    final settings = _state.settings;
    
    // * Check for lagpas-baba (passed destination)
    // * If we were very close (<100m) and now distance is increasing significantly
    if (minDistance < 100 && distance > minDistance + 50) {
      if (!_state.hasPassedDestination) {
        debugPrint("[CommuteService] WARNING: LAGPAS-BABA detected!");
        
        // * Calculate overshoot distance
        final overshootDistance = distance - minDistance;
        
        // * Generate recovery hint
        final recoveryHint = _generateRecoveryHint();
        
        _state = _state.copyWith(
          status: CommuteStatus.passed,
          hasPassedDestination: true,
          overshootDistanceMeters: overshootDistance,
          overshootRecoveryHint: recoveryHint,
        );
        _triggerLagpasAlert();
        return;
      }
    }
    
    // * Check for arrival (within 50m)
    if (distance < 50) {
      if (_state.status != CommuteStatus.arrived) {
        debugPrint("[CommuteService] OK: Arrived at destination!");
        _state = _state.copyWith(status: CommuteStatus.arrived);
        _triggerArrivalNotification();
        return;
      }
    }
    
    // * Get effective alarm distance (smart or fixed)
    final alarmDistance = _state.smartAlarmDistanceMeters;
    
    // * Check for approaching (within alarm distance)
    if (distance <= alarmDistance) {
      if (!_state.alarmTriggered) {
        debugPrint("[CommuteService] ALARM: Approaching destination! (${distance.round()}m <= ${alarmDistance.round()}m)");
        
        if (settings.useMultiStageAlarm) {
          _handleMultiStageAlarm(distance);
        } else {
          _state = _state.copyWith(status: CommuteStatus.approaching);
          _triggerApproachingAlarm();
        }
        return;
      }
    }
    
    // * Check time-based backup alarm
    if (settings.useTimeBackupAlarm && _state.etaToDestination != null) {
      if (_state.etaToDestination!.inMinutes <= settings.backupAlarmMinutes) {
        if (!_state.alarmTriggered && _state.status == CommuteStatus.active) {
          debugPrint("[CommuteService] ALARM: Time-based alarm triggered!");
          _state = _state.copyWith(status: CommuteStatus.approaching);
          _triggerApproachingAlarm();
        }
      }
    }
    
    // * Multi-stage alarm updates (if already triggered)
    if (_state.alarmTriggered && settings.useMultiStageAlarm) {
      _handleMultiStageAlarm(distance);
    }
  }
  
  /// * Handle multi-stage alarm progression
  void _handleMultiStageAlarm(double distance) {
    final newStage = _determineAlarmStage(distance, _state.currentSpeedMs);
    final currentStage = _state.alarmStage;
    
    // * Only escalate, never de-escalate once started
    if (newStage.index > currentStage.index) {
      debugPrint("[CommuteService] ALARM: Alarm escalating: $currentStage -> $newStage");
      _triggerAlarmStage(newStage);
    }
  }
  
  /// * Determine alarm stage based on ETA/distance
  AlarmStage _determineAlarmStage(double distanceMeters, double? speedMs) {
    if (speedMs == null || speedMs <= 0) {
      // * Fallback to distance-based
      if (distanceMeters < 100) return AlarmStage.stage3Loud;
      if (distanceMeters < 250) return AlarmStage.stage2Medium;
      if (distanceMeters < _state.smartAlarmDistanceMeters) return AlarmStage.stage1Soft;
      return AlarmStage.none;
    }
    
    final etaSeconds = distanceMeters / speedMs;
    if (etaSeconds < 30) return AlarmStage.stage3Loud;
    if (etaSeconds < 60) return AlarmStage.stage2Medium;
    if (etaSeconds < 90) return AlarmStage.stage1Soft;
    return AlarmStage.none;
  }
  
  /// * Trigger alarm for specific stage
  void _triggerAlarmStage(AlarmStage stage) {
    _state = _state.copyWith(
      alarmTriggered: true,
      alarmStage: stage,
      status: CommuteStatus.approaching,
    );
    
    switch (stage) {
      case AlarmStage.stage1Soft:
        debugPrint("[CommuteService] ALARM: Stage 1: Soft vibration");
        HapticFeedback.lightImpact();
        // * Repeat soft vibration
        _stage1Timer?.cancel();
        _stage1Timer = Timer.periodic(const Duration(seconds: 10), (timer) {
          if (_state.alarmDismissed || _state.alarmStage != AlarmStage.stage1Soft) {
            timer.cancel();
            return;
          }
          HapticFeedback.lightImpact();
        });
        break;
        
      case AlarmStage.stage2Medium:
        debugPrint("[CommuteService] ALARM: Stage 2: Medium vibration + sound");
        _stage1Timer?.cancel();
        HapticFeedback.mediumImpact();
        _notificationService.showCommuteAlarm(
          title: "Getting Close!",
          body: "${_state.formattedDistance} to ${_state.destinationName}",
        );
        // * Repeat medium vibration
        _stage2Timer?.cancel();
        _stage2Timer = Timer.periodic(const Duration(seconds: 8), (timer) {
          if (_state.alarmDismissed || _state.alarmStage != AlarmStage.stage2Medium) {
            timer.cancel();
            return;
          }
          HapticFeedback.mediumImpact();
          _notificationService.showCommuteAlarm(
            title: "Almost There!",
            body: "${_state.formattedDistance} to ${_state.destinationName}",
          );
        });
        break;
        
      case AlarmStage.stage3Loud:
        debugPrint("[CommuteService] ALARM: Stage 3: LOUD continuous alarm!");
        _stage1Timer?.cancel();
        _stage2Timer?.cancel();
        _state = _state.copyWith(alarmSoundPlaying: true);
        HapticFeedback.heavyImpact();
        _notificationService.showCommuteAlarm(
          title: "GET READY NOW!",
          body: "${_state.formattedDistance} - ALIGHT SOON!",
        );
        // * Continuous alarm
        _stage3Timer?.cancel();
        _stage3Timer = Timer.periodic(const Duration(seconds: 3), (timer) {
          if (_state.alarmDismissed) {
            timer.cancel();
            return;
          }
          HapticFeedback.heavyImpact();
          _notificationService.showCommuteAlarm(
            title: "BUMABA KA NA!",
            body: "${_state.formattedDistance} to ${_state.destinationName}",
          );
        });
        break;
        
      case AlarmStage.none:
        break;
    }
    
    _notifyStateChanged();
  }
  
  /// * Trigger approaching alarm (legacy single-stage)
  void _triggerApproachingAlarm() {
    _state = _state.copyWith(alarmTriggered: true);
    
    // * Haptic feedback
    if (_state.settings.vibrateOnAlarm) {
      HapticFeedback.heavyImpact();
    }
    
    // * Show alarm notification
    _notificationService.showCommuteAlarm(
      title: "Get Ready!",
      body: "${_state.formattedDistance} to ${_state.destinationName}",
    );
    
    // * Start repeat alarm until dismissed
    _startAlarmRepeat();
  }
  
  /// * Start repeating alarm
  void _startAlarmRepeat() {
    _alarmRepeatTimer?.cancel();
    
    // * Repeat every 15 seconds until dismissed
    _alarmRepeatTimer = Timer.periodic(
      const Duration(seconds: 15),
      (timer) {
        if (_state.alarmDismissed || !_state.isActive) {
          timer.cancel();
          return;
        }
        
        debugPrint("[CommuteService] ALARM: Alarm repeat");
        
        if (_state.settings.vibrateOnAlarm) {
          HapticFeedback.heavyImpact();
        }
        
        _notificationService.showCommuteAlarm(
          title: "Almost there!",
          body: "${_state.formattedDistance} to ${_state.destinationName}",
        );
      },
    );
  }
  
  /// * Generate recovery hint for lagpas-baba
  String _generateRecoveryHint() {
    // * Bilingual hint
    return "Bumaba ka sa susunod, tumawid, sakay pabalik\n"
           "Get off at next stop, cross the street, ride back";
  }
  
  /// * Trigger lagpas-baba alert
  void _triggerLagpasAlert() {
    debugPrint("[CommuteService] ALERT: LAGPAS-BABA ALERT!");
    
    // * Strong haptic feedback
    HapticFeedback.heavyImpact();
    
    // * Show lagpas alert
    _notificationService.showLagpasAlert(
      destinationName: _state.destinationName ?? "your stop",
    );
    
    // * Start aggressive repeat
    _alarmRepeatTimer?.cancel();
    _alarmRepeatTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        if (_state.alarmDismissed) {
          timer.cancel();
          return;
        }
        
        HapticFeedback.heavyImpact();
        _notificationService.showLagpasAlert(
          destinationName: _state.destinationName ?? "your stop",
        );
      },
    );
  }
  
  /// * Trigger arrival notification
  void _triggerArrivalNotification() {
    HapticFeedback.mediumImpact();
    
    _notificationService.showCommuteArrival(
      destinationName: _state.destinationName ?? "your destination",
    );
  }
  
  /// * Calculate distance between two points in meters
  double _calculateDistanceMeters(LatLng from, LatLng to) {
    const double earthRadiusM = 6371000.0;
    final double dLat = _toRadians(to.latitude - from.latitude);
    final double dLon = _toRadians(to.longitude - from.longitude);
    
    final double a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(from.latitude)) * math.cos(_toRadians(to.latitude)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }
  
  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
  
  /// * Estimate ETA based on distance and average speed
  Duration _estimateEta(double distanceMeters) {
    double avgSpeedKmh = _defaultSpeedKmh;
    
    if (_recentSpeeds.isNotEmpty) {
      avgSpeedKmh = _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
      // * Clamp to reasonable values
      avgSpeedKmh = avgSpeedKmh.clamp(5.0, 60.0);
    }
    
    final distanceKm = distanceMeters / 1000.0;
    final hours = distanceKm / avgSpeedKmh;
    final minutes = (hours * 60).round();
    
    return Duration(minutes: minutes);
  }
  
  /// * Notify listeners of state change
  void _notifyStateChanged() {
    onStateChanged?.call(_state);
  }
}

