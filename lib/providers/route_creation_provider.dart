import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";
import "../models/saved_route.dart";

/// * Provider to trigger route creation dialog
final routeCreationTriggerProvider = StateProvider<RouteCreationAction?>((ref) => null);

enum RouteCreationAction {
  showDialog,
  startDrawing,
  useNavigation,
}

/// * Provider for route drawing state
final routeDrawingProvider = StateNotifierProvider<RouteDrawingNotifier, RouteDrawingState>((ref) {
  return RouteDrawingNotifier();
});

class RouteDrawingState {
  final bool isDrawing;
  final List<LatLng> drawnPoints;
  
  RouteDrawingState({
    this.isDrawing = false,
    this.drawnPoints = const [],
  });
  
  RouteDrawingState copyWith({
    bool? isDrawing,
    List<LatLng>? drawnPoints,
  }) {
    return RouteDrawingState(
      isDrawing: isDrawing ?? this.isDrawing,
      drawnPoints: drawnPoints ?? this.drawnPoints,
    );
  }
}

class RouteDrawingNotifier extends StateNotifier<RouteDrawingState> {
  RouteDrawingNotifier() : super(RouteDrawingState());
  
  void startDrawing() {
    state = state.copyWith(isDrawing: true, drawnPoints: []);
  }
  
  void addPoint(LatLng point) {
    state = state.copyWith(
      drawnPoints: [...state.drawnPoints, point],
    );
  }
  
  void clearPoints() {
    state = state.copyWith(drawnPoints: []);
  }
  
  void stopDrawing() {
    state = state.copyWith(isDrawing: false);
  }
  
  void confirmRoute() {
    state = state.copyWith(isDrawing: false);
  }
}

/// * Provider for saved route following mode
final savedRouteFollowingProvider = StateNotifierProvider<SavedRouteFollowingNotifier, SavedRouteFollowingState>((ref) {
  return SavedRouteFollowingNotifier();
});

class SavedRouteFollowingState {
  final String? routeId;
  final List<LatLng>? routeGeometry;
  final bool strictMode; // * If true, follow exact route, no reroute unless blocked
  final bool allowReroute; // * If true, allow reroute when blocked
  
  SavedRouteFollowingState({
    this.routeId,
    this.routeGeometry,
    this.strictMode = false,
    this.allowReroute = true,
  });
  
  bool get isFollowing => routeId != null && routeGeometry != null;
  
  SavedRouteFollowingState copyWith({
    String? routeId,
    List<LatLng>? routeGeometry,
    bool? strictMode,
    bool? allowReroute,
  }) {
    return SavedRouteFollowingState(
      routeId: routeId ?? this.routeId,
      routeGeometry: routeGeometry ?? this.routeGeometry,
      strictMode: strictMode ?? this.strictMode,
      allowReroute: allowReroute ?? this.allowReroute,
    );
  }
}

class SavedRouteFollowingNotifier extends StateNotifier<SavedRouteFollowingState> {
  SavedRouteFollowingNotifier() : super(SavedRouteFollowingState());
  
  void startFollowing({
    required String routeId,
    required List<LatLng> routeGeometry,
    bool strictMode = true,
    bool allowReroute = true,
  }) {
    state = state.copyWith(
      routeId: routeId,
      routeGeometry: routeGeometry,
      strictMode: strictMode,
      allowReroute: allowReroute,
    );
  }
  
  void stopFollowing() {
    state = SavedRouteFollowingState();
  }
}

/// * Provider for route editing - holds the route to edit
final routeEditingProvider = StateProvider<SavedRoute?>((ref) => null);
