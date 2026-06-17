/// * SmartRoad Map Screen Bridge
/// *
/// * Selects the active map implementation based on MapConfig.
/// * FlutterMap → MapLibre transition without breaking existing code.
/// *
/// * When MapConfig.useMapLibre is true, renders MapLibreMapScreen.
/// * Otherwise, falls back to the original FlutterMap-based MapScreen.
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/map/map_config.dart";
import "../../screens/map/map_screen.dart";
import "maplibre_map_screen.dart";

/// * Bridge widget that selects the active map implementation
class MapScreenBridge extends ConsumerWidget {
  const MapScreenBridge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MapConfig.useMapLibre) {
      return const MapLibreMapScreen();
    }
    // * Fall back to the original FlutterMap implementation
    return const MapScreen();
  }
}

/// * Simple toggle widget for development
class MapImplementationToggle extends StatelessWidget {
  final Widget child;

  const MapImplementationToggle({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// * Toggle FAB for switching map implementations (debug only)
class MapToggleFab extends StatelessWidget {
  const MapToggleFab({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return FloatingActionButton.small(
      onPressed: () {
        if (MapConfig.useMapLibre) {
          MapConfig.disableMapLibre();
        } else {
          MapConfig.enableMapLibre();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              MapConfig.useMapLibre
                  ? "🗺️ Switched to MapLibre"
                  : "🗺️ Switched to FlutterMap",
            ),
            duration: const Duration(seconds: 1),
          ),
        );
        (context as Element).markNeedsBuild();
      },
      tooltip: "Toggle Map Engine",
      child: Text(
        MapConfig.useMapLibre ? "ML" : "FM",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
