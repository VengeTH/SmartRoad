import "package:flutter_riverpod/flutter_riverpod.dart";
import "../models/saved_route.dart";

/// * Provider for managing navigation with a saved route
final savedRouteNavigationProvider = StateNotifierProvider<SavedRouteNavigationNotifier, SavedRouteNavigationState>((ref) {
  return SavedRouteNavigationNotifier();
});

class SavedRouteNavigationNotifier extends StateNotifier<SavedRouteNavigationState> {
  SavedRouteNavigationNotifier() : super(SavedRouteNavigationState.none());
  
  void startNavigationWithSavedRoute(SavedRoute route) {
    state = SavedRouteNavigationState.following(route);
  }
  
  void stopNavigation() {
    state = SavedRouteNavigationState.none();
  }
  
  void setRerouteMode(bool allowReroute) {
    if (state is _FollowingState) {
      final currentState = state as _FollowingState;
      if (currentState.route != null) {
        state = SavedRouteNavigationState.following(
          currentState.route!,
          allowReroute: allowReroute,
        );
      }
    }
  }
}

class SavedRouteNavigationState {
  final SavedRoute? route;
  final bool isFollowing;
  final bool allowReroute; // * If false, must follow exact route
  
  SavedRouteNavigationState({
    this.route,
    required this.isFollowing,
    this.allowReroute = true,
  });
  
  factory SavedRouteNavigationState.none() {
    return SavedRouteNavigationState(isFollowing: false);
  }
  
  factory SavedRouteNavigationState.following(SavedRoute route, {bool allowReroute = true}) {
    return _FollowingState(route: route, allowReroute: allowReroute);
  }
}

class _FollowingState extends SavedRouteNavigationState {
  _FollowingState({required SavedRoute route, bool allowReroute = true})
      : super(route: route, isFollowing: true, allowReroute: allowReroute);
}
