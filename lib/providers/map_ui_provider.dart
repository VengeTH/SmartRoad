import "package:flutter_riverpod/flutter_riverpod.dart";

/// * Lightweight UI state for the Map screen.
/// *
/// * This is used by shared UI (e.g., global FAB) to avoid covering navigation UI.
final mapIsNavigatingProvider = StateProvider<bool>((ref) {
  return false;
});
