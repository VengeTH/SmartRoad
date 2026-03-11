import "package:flutter_riverpod/flutter_riverpod.dart";

/// * Provider for managing main navigation tab index
final navigationTabProvider = StateNotifierProvider<NavigationTabNotifier, int>((ref) {
  return NavigationTabNotifier();
});

class NavigationTabNotifier extends StateNotifier<int> {
  NavigationTabNotifier() : super(0);
  
  void switchToTab(int index) {
    state = index;
  }
  
  void switchToMap() {
    state = 0;
  }

  void switchToFeed() {
    state = 1;
  }

  void switchToRoutes() {
    state = 2;
  }

  void switchToProfile() {
    state = 3;
  }
}
