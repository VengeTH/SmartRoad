/// * Navigation Controller
/// *
/// * Manages turn-by-turn navigation state:
/// * route following, off-route detection, arrival detection, progress tracking.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// * Navigation state
enum NavigationState { idle, navigating, offRoute, arrived, rerouting }

/// * Navigation progress update
class NavigationProgress {
  final double distanceKm;
  final Duration duration;
  final double currentSpeed;
  final double? averageSpeed;
  final int remainingInstructionIndex;
  final bool isOffRoute;

  const NavigationProgress({
    required this.distanceKm,
    required this.duration,
    required this.currentSpeed,
    this.averageSpeed,
    this.remainingInstructionIndex = 0,
    this.isOffRoute = false,
  });
}

/// * Navigation Controller
class NavigationController {
  final List<LatLng> route;
  final VoidCallback? onOffRoute;
  final VoidCallback? onArrival;
  final ValueChanged<NavigationProgress>? onProgress;

  NavigationState _state = NavigationState.idle;
  Timer? _progressTimer;
  LatLng? _lastPosition;
  DateTime? _lastPositionTime;
  double _totalDistanceTravelled = 0;
  int _currentSegmentIndex = 0;
  double _currentSpeed = 0;
  List<double> _recentSpeeds = [];

  /// * Proximity threshold for off-route detection (meters)
  static const double offRouteThresholdMeters = 100;

  /// * Proximity threshold for arrival (meters)
  static const double arrivalThresholdMeters = 50;

  /// * Proximity threshold for reaching a waypoint (meters)
  static const double waypointThresholdMeters = 30;

  NavigationController({
    required this.route,
    this.onOffRoute,
    this.onArrival,
    this.onProgress,
  })  : assert(route.length >= 2, 'Route must have at least 2 points'),
        _state = NavigationState.idle;

  NavigationState get state => _state;
  double get currentSpeed => _currentSpeed;
  int get currentSegmentIndex => _currentSegmentIndex;
  double get totalDistanceTravelled => _totalDistanceTravelled;

  /// * Total route distance (meters)
  double get totalRouteDistanceMeters {
    double total = 0;
    for (int i = 1; i < route.length; i++) {
      total += _distanceMeters(route[i - 1], route[i]);
    }
    return total;
  }

  /// * Remaining distance (meters)
  double get remainingDistanceMeters {
    double remaining = 0;
    for (int i = _currentSegmentIndex; i < route.length - 1; i++) {
      remaining += _distanceMeters(route[i], route[i + 1]);
    }
    return remaining;
  }

  /// * Start navigation
  void start() {
    _state = NavigationState.navigating;
    _currentSegmentIndex = 0;
    _totalDistanceTravelled = 0;
    _recentSpeeds.clear();

    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == NavigationState.navigating && _lastPosition != null) {
        _emitProgress();
      }
    });

    debugPrint('🧭 [Navigation] Started — ${route.length} waypoints');
  }

  /// * Stop navigation
  void stop() {
    _state = NavigationState.idle;
    _progressTimer?.cancel();
    _progressTimer = null;
    debugPrint('🧭 [Navigation] Stopped');
  }

  /// * Update current location (call frequently from GPS stream)
  void updateLocation(LatLng position) {
    if (_state != NavigationState.navigating &&
        _state != NavigationState.offRoute) return;

    // Calculate speed
    if (_lastPosition != null && _lastPositionTime != null) {
      final distance = _distanceMeters(_lastPosition!, position);
      final elapsed = DateTime.now().difference(_lastPositionTime!);
      if (elapsed.inSeconds > 0) {
        _currentSpeed = (distance / elapsed.inSeconds) * 3.6; // m/s → km/h
        _recentSpeeds.add(_currentSpeed);
        if (_recentSpeeds.length > 10) _recentSpeeds.removeAt(0);
        _totalDistanceTravelled += distance;
      }
    }
    _lastPosition = position;
    _lastPositionTime = DateTime.now();

    // Check if we reached the current waypoint
    if (_currentSegmentIndex < route.length - 1) {
      final target = route[_currentSegmentIndex + 1];
      final distToWaypoint = _distanceMeters(position, target);

      if (distToWaypoint < waypointThresholdMeters) {
        _currentSegmentIndex++;
        debugPrint('🧭 [Navigation] Reached waypoint ${_currentSegmentIndex}');
      }
    }

    // Check arrival
    if (_currentSegmentIndex >= route.length - 1) {
      final destination = route.last;
      final distToDest = _distanceMeters(position, destination);
      if (distToDest < arrivalThresholdMeters) {
        _state = NavigationState.arrived;
        onArrival?.call();
        stop();
        return;
      }
    }

    // Check off-route
    if (_isOffRoute(position)) {
      if (_state != NavigationState.offRoute) {
        _state = NavigationState.offRoute;
        onOffRoute?.call();
        debugPrint('🧭 [Navigation] Off route detected');
      }
    } else {
      if (_state == NavigationState.offRoute) {
        _state = NavigationState.navigating;
        debugPrint('🧭 [Navigation] Back on route');
      }
    }
  }

  /// * Check if position is off the route
  bool _isOffRoute(LatLng position) {
    // Find minimum distance to any segment of the route
    double minDist = double.infinity;
    for (int i = _currentSegmentIndex;
        i < math.min(_currentSegmentIndex + 5, route.length - 1);
        i++) {
      final dist = _distanceToSegment(
          position, route[i], route[i + 1]);
      if (dist < minDist) minDist = dist;
    }
    return minDist > offRouteThresholdMeters * 2; // Convert to radius
  }

  /// * Emit progress update
  void _emitProgress() {
    onProgress?.call(NavigationProgress(
      distanceKm: remainingDistanceMeters / 1000,
      duration: Duration(
        seconds: (remainingDistanceMeters / (_currentSpeed.clamp(1, 200) / 3.6))
            .toInt(),
      ),
      currentSpeed: _currentSpeed,
      averageSpeed: _recentSpeeds.isNotEmpty
          ? _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length
          : null,
      remainingInstructionIndex: _currentSegmentIndex,
      isOffRoute: _state == NavigationState.offRoute,
    ));
  }

  /// * Reroute calculation (call when off-route)
  Future<List<LatLng>?> reroute(LatLng currentPosition) async {
    if (_state == NavigationState.idle) return null;
    // * In production: call routing service to get new route from current position to destination
    // * For now, return null to use straight-line fallback
    return null;
  }

  /// * Dispose
  void dispose() {
    stop();
  }

  // ── Distance Helpers ────────────────────────────────────────

  final Distance _distanceCalc = const Distance();

  double _distanceMeters(LatLng a, LatLng b) {
    return _distanceCalc(a, b).toDouble();
  }

  /// * Minimum distance from point p to segment [a, b]
  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    final ab = _distanceMeters(a, b);
    if (ab < 0.001) return _distanceMeters(p, a);

    // Project p onto ab (approximate using lat/lng proportions)
    final t = ((p.latitude - a.latitude) * (b.latitude - a.latitude) +
            (p.longitude - a.longitude) * (b.longitude - a.longitude)) /
        (ab * ab);

    if (t < 0) return _distanceMeters(p, a);
    if (t > 1) return _distanceMeters(p, b);

    final proj = LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
    return _distanceMeters(p, proj);
  }
}
