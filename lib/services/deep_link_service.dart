import "dart:async";

import "package:app_links/app_links.dart";
import "package:flutter/foundation.dart";

/// * Deep Link Service
/// *
/// * Centralizes app link handling (e.g., `smartroad://map`).
/// * This makes it possible for other apps to open SmartRoad via deep link.
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();

  factory DeepLinkService() => _instance;

  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  /// * Starts listening for incoming deep links.
  /// *
  /// * `onLink` is called for both the initial link (cold start) and any
  /// * subsequent links while the app is running.
  Future<void> start({required void Function(Uri uri) onLink}) async {
    if (_started) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        onLink(initial);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [DeepLinkService] Failed to read initial link: $e");
      }
    }

    _subscription = _appLinks.uriLinkStream.listen(
      onLink,
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint("❌ [DeepLinkService] Link stream error: $error");
        }
      },
    );
  }

  /// * Stops listening and releases resources.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}

