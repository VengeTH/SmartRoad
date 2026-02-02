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
  
  // * Average speed tracking for ETA calculation
  final List<double> _recentSpeeds = [];
  static const int _maxSpeedSamples = 10;
  static const double _defaultSpeedKmh = 20.0; // * Typical jeepney/bus speed
  
  /// * Initialize the commute service
  Future<void> initialize() async {
    await _notificationService.initialize();
    debugPrint("✅ [CommuteService] Initialized");
  }
  
  /// * Start commute tracking
  Future<bool> startCommute({
    required LatLng destination,
    required String destinationName,
    CommuteSettings? settings,
  }) async {
    try {
      debugPrint("📍 [CommuteService] Starting commute to: $destinationName");
      
      // * Check location permission
      final hasPermission = await _locationService.requestPermission();
      if (!hasPermission) {
        debugPrint("❌ [CommuteService] Location permission denied");
        return false;
      }
      
      // * Get initial position
      final initialPosition = await _locationService.getCurrentPosition();
      if (initialPosition == null) {
        debugPrint("❌ [CommuteService] Could not get initial position");
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
      
      // * Update state
      _state = CommuteState(
        destination: destination,
        destinationName: destinationName,
        settings: settings ?? const CommuteSettings(),
        status: CommuteStatus.active,
        distanceToDestinationMeters: initialDistance,
        initialDistanceMeters: initialDistance, // * Track starting distance
        etaToDestination: initialEta,
        startedAt: DateTime.now(),
        startPosition: currentLocation, // * Track starting position
        minDistanceReached: initialDistance,
        currentPosition: currentLocation,
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
      
      debugPrint("✅ [CommuteService] Commute started: ${initialDistance.round()}m to destination");
      return true;
    } catch (e) {
      debugPrint("❌ [CommuteService] Error starting commute: $e");
      return false;
    }
  }
  
  /// * Stop commute tracking
  Future<void> stopCommute() async {
    debugPrint("📍 [CommuteService] Stopping commute");
    
    // * Cancel location subscription
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    
    // * Cancel alarm repeat timer
    _alarmRepeatTimer?.cancel();
    _alarmRepeatTimer = null;
    
    // * Clear speed samples
    _recentSpeeds.clear();
    
    // * Cancel notifications
    await _notificationService.cancelCommuteNotifications();
    
    // * Reset state
    _state = _state.reset();
    _notifyStateChanged();
    
    debugPrint("✅ [CommuteService] Commute stopped");
  }
  
  /// * Dismiss the alarm
  void dismissAlarm() {
    debugPrint("📍 [CommuteService] Alarm dismissed by user");
    
    _alarmRepeatTimer?.cancel();
    _alarmRepeatTimer = null;
    
    _state = _state.copyWith(
      alarmDismissed: true,
    );
    _notifyStateChanged();
    
    _notificationService.cancelCommuteAlarm();
    _notificationService.cancelLagpasAlert();
  }
  
  /// * Dismiss safety alert (user confirmed safe)
  void dismissSafetyAlert() {
    debugPrint("✅ [CommuteService] Safety alert dismissed - user is safe");
    
    _state = _state.copyWith(
      safetyAlertTriggered: false,
      status: CommuteStatus.active,
      clearOffRouteDistance: true,
    );
    _notifyStateChanged();
  }
  
  /// * Send safety alert to emergency contacts
  Future<void> sendSafetyAlert() async {
    final safetySettings = _state.settings.safetySettings;
    if (safetySettings.emergencyContacts.isEmpty) {
      debugPrint("⚠️ [CommuteService] No emergency contacts configured");
      return;
    }
    
    if (_state.currentPosition == null) {
      debugPrint("⚠️ [CommuteService] No current position available");
      return;
    }
    
    debugPrint("📱 [CommuteService] Sending safety alert SMS...");
    
    await _emergencySmsService.sendEmergencyAlert(
      contacts: safetySettings.emergencyContacts,
      latitude: _state.currentPosition!.latitude,
      longitude: _state.currentPosition!.longitude,
      destinationName: _state.destinationName ?? "Unknown",
    );
    
    _state = _state.copyWith(
      lastSafetySmsAt: DateTime.now(),
    );
    _notifyStateChanged();
  }
  
  /// * Update commute settings
  void updateSettings(CommuteSettings settings) {
    _state = _state.copyWith(settings: settings);
    _notifyStateChanged();
  }
  
  /// * Start listening to location updates
  void _startLocationStream() {
    _positionSubscription?.cancel();
    
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // * Update every 10 meters
    );
    
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        debugPrint("❌ [CommuteService] Location stream error: $e");
      },
    );
    
    debugPrint("📍 [CommuteService] Location stream started");
  }
  
  /// * Handle position updates
  void _onPositionUpdate(Position position) {
    if (_state.status == CommuteStatus.idle) return;
    if (_state.destination == null) return;
    
    final currentLocation = LatLng(position.latitude, position.longitude);
    final destination = _state.destination!;
    
    // * Calculate distance to destination
    final distance = _calculateDistanceMeters(currentLocation, destination);
    
    // * Track speed for ETA calculation
    if (position.speed > 0) {
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
    if (_state.settings.safetySettings.enabled && _state.startPosition != null) {
      offRouteDistance = _calculateOffRouteDistance(
        currentLocation,
        _state.startPosition!,
        destination,
      );
    }
    
    // * Update state
    _state = _state.copyWith(
      distanceToDestinationMeters: distance,
      etaToDestination: eta,
      currentPosition: currentLocation,
      minDistanceReached: newMinDistance,
      offRouteDistanceKm: offRouteDistance,
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
  
  /// * Check if safety alert should be triggered
  void _checkSafetyAlert(double? offRouteDistanceKm) {
    if (offRouteDistanceKm == null) return;
    
    final safetySettings = _state.settings.safetySettings;
    if (!safetySettings.enabled) return;
    
    // * Check if we've exceeded the threshold
    if (offRouteDistanceKm >= safetySettings.offRouteThresholdKm) {
      if (!_state.safetyAlertTriggered) {
        debugPrint("🚨 [CommuteService] OFF-ROUTE DETECTED! ${offRouteDistanceKm.toStringAsFixed(1)}km from route");
        
        _state = _state.copyWith(
          safetyAlertTriggered: true,
          status: CommuteStatus.danger,
        );
        
        HapticFeedback.heavyImpact();
        
        // * Auto-send SMS if enabled and cooldown passed
        if (safetySettings.autoSmsEnabled) {
          final lastSms = _state.lastSafetySmsAt;
          final cooldownPassed = lastSms == null ||
              DateTime.now().difference(lastSms).inMinutes >= safetySettings.smsCooldownMinutes;
          
          if (cooldownPassed && safetySettings.emergencyContacts.isNotEmpty) {
            // * SMS will be triggered from UI after countdown
            debugPrint("📱 [CommuteService] Auto-SMS enabled, will trigger from overlay");
          }
        }
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
        debugPrint("⚠️ [CommuteService] LAGPAS-BABA detected!");
        _state = _state.copyWith(
          status: CommuteStatus.passed,
          hasPassedDestination: true,
        );
        _triggerLagpasAlert();
        return;
      }
    }
    
    // * Check for arrival (within 50m)
    if (distance < 50) {
      if (_state.status != CommuteStatus.arrived) {
        debugPrint("✅ [CommuteService] Arrived at destination!");
        _state = _state.copyWith(status: CommuteStatus.arrived);
        _triggerArrivalNotification();
        return;
      }
    }
    
    // * Check for approaching (within alarm distance)
    if (distance <= settings.alarmDistanceMeters) {
      if (_state.status != CommuteStatus.approaching && !_state.alarmTriggered) {
        debugPrint("🔔 [CommuteService] Approaching destination!");
        _state = _state.copyWith(status: CommuteStatus.approaching);
        _triggerApproachingAlarm();
        return;
      }
    }
    
    // * Check time-based backup alarm
    if (settings.useTimeBackupAlarm && _state.etaToDestination != null) {
      if (_state.etaToDestination!.inMinutes <= settings.backupAlarmMinutes) {
        if (!_state.alarmTriggered && _state.status == CommuteStatus.active) {
          debugPrint("🔔 [CommuteService] Time-based alarm triggered!");
          _state = _state.copyWith(status: CommuteStatus.approaching);
          _triggerApproachingAlarm();
        }
      }
    }
  }
  
  /// * Trigger approaching alarm
  void _triggerApproachingAlarm() {
    _state = _state.copyWith(alarmTriggered: true);
    
    // * Haptic feedback
    if (_state.settings.vibrateOnAlarm) {
      HapticFeedback.heavyImpact();
    }
    
    // * Show alarm notification
    _notificationService.showCommuteAlarm(
      title: "🔔 Get Ready!",
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
        
        debugPrint("🔔 [CommuteService] Alarm repeat");
        
        if (_state.settings.vibrateOnAlarm) {
          HapticFeedback.heavyImpact();
        }
        
        _notificationService.showCommuteAlarm(
          title: "🔔 Almost there!",
          body: "${_state.formattedDistance} to ${_state.destinationName}",
        );
      },
    );
  }
  
  /// * Trigger lagpas-baba alert
  void _triggerLagpasAlert() {
    debugPrint("🚨 [CommuteService] LAGPAS-BABA ALERT!");
    
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

