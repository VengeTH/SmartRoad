# SmartRoad — MapLibre Migration Guide

## Architecture Overview

```
lib/
├── core/
│   ├── map/
│   │   ├── map_types.dart              # Shared types (MapCoord, MapBounds, MapCameraPosition)
│   │   ├── map_config.dart             # Implementation toggle + style config
│   │   ├── map_controller_interface.dart # IMapController abstract interface
│   │   ├── map_marker.dart             # Platform-agnostic marker model
│   │   ├── map_polyline.dart           # Platform-agnostic polyline model
│   │   └── map_polygon.dart            # Platform-agnostic polygon model
│   ├── constants/
│   ├── theme/
│   └── services/
│
├── features/
│   ├── map/
│   │   ├── map_screen_bridge.dart      # Toggles between FlutterMap / MapLibre
│   │   ├── maplibre_map_screen.dart    # Main MapLibre map screen
│   │   ├── maplibre_map_controller.dart # SmartRoad MapLibre controller wrapper
│   │   ├── maplibre_layer_controller.dart # Layer/source manager for MapLibre
│   │   └── widgets/
│   │       └── map_controls.dart       # Reusable zoom/location/search buttons
│   │
│   ├── navigation/
│   │   └── navigation_controller.dart  # Turn-by-turn navigation logic
│   │
│   ├── weather/
│   │   └── weather_controller.dart     # Weather data + layer management
│   │
│   ├── hazards/
│   │   └── hazard_controller.dart      # Hazard GeoJSON generation + clustering
│   │
│   ├── community/                      # (future) Community layer module
│   ├── hoa/                            # (future) HOA intelligence module
│   └── marketplace/                    # (future) Route marketplace module
│
├── screens/                            # LEGACY — being migrated to features/
│   ├── map/map_screen.dart             # Original FlutterMap implementation (preserved)
│   └── main_navigation_screen.dart     # Updated to use MapScreenBridge
│
├── services/                           # Services remain unchanged during migration
│   ├── routing_service.dart
│   ├── weather_service.dart
│   ├── location_service.dart
│   └── ...
│
├── providers/                          # Riverpod providers remain unchanged
│   └── ...
│
├── widgets/                            # Shared UI widgets remain unchanged
│   ├── hazard_marker.dart
│   ├── weather_tile_layers.dart        # LEGACY FlutterMap weather layers
│   └── ...
│
└── models/                             # Data models remain unchanged
    └── ...
```

## Implementation Toggle

The `MapConfig` class in `lib/core/map/map_config.dart` controls which map engine is active:

```dart
// Enable MapLibre
MapConfig.enableMapLibre();

// Switch back to FlutterMap (for comparison/testing)
MapConfig.disableMapLibre();
```

The `MapScreenBridge` widget in `lib/features/map/map_screen_bridge.dart` reads this config and renders the appropriate implementation.

## Migration Phases

### ✅ PHASE 1 — Foundation (DONE)
- [x] MapLibre dependency added (`maplibre_gl: ^0.19.0`)
- [x] Core abstraction types created (`lib/core/map/`)
- [x] Feature directory structure created (`lib/features/`)
- [x] Bridge widget created (`MapScreenBridge`)
- [x] `main_navigation_screen.dart` updated to use bridge

### ✅ PHASE 2 — Core Map (DONE)
- [x] `MapLibreMapScreen` created with full map widget
- [x] `SmartRoadMapController` wrapping `MapLibreMapController`
- [x] Camera controls (animate, move, fit bounds)
- [x] User location tracking
- [x] Zoom controls
- [x] Compass support (built-in MapLibre)
- [x] Search functionality

### ✅ PHASE 3 — Routing (DONE)
- [x] Route polyline rendering via `MapLibreLayerController`
- [x] Alternative route polylines
- [x] Navigation overlay UI
- [x] Route preview sheet
- [x] `NavigationController` for turn-by-turn logic
- [x] Off-route detection
- [x] Arrival detection

### ✅ PHASE 4 — Weather Engine (PARTIAL)
- [x] Weather layer controller
- [x] RainViewer / OpenWeatherMap tile integration
- [x] Cloud layer tiles
- [x] Temperature layer tiles
- [x] Weather feature controller
- [x] Toggleable layers with opacity control
- [ ] Fog / UV layers (not yet available from data sources)

### ✅ PHASE 5 — Disaster Intelligence (PARTIAL)
- [x] Flood zone polygon rendering support
- [x] Hazard GeoJSON generation (`HazardFeatureController`)
- [ ] Live PAGASA / Project NOAH integration

### ✅ PHASE 6 — Community Layer (PARTIAL)
- [x] Hazard marker rendering with clustering support
- [ ] Complete community report integration

### ✅ PHASE 7 — HOA Intelligence (PARTIAL)
- [x] HOA entrance marker rendering support
- [ ] Full HOA polygon + restricted roads rendering

### 🔄 PHASE 8 — Marketplace Layer (NOT STARTED)
- [ ] Shared/public/premium route rendering
- [ ] Route creator markers

### 🔄 PHASE 9 — Performance Optimization (NOT STARTED)
- [ ] 60 FPS validation
- [ ] Marker clustering
- [ ] Lazy loading verification
- [ ] Memory profiling

### 🔄 PHASE 10 — Architecture Refactor (IN PROGRESS)
- [x] Feature directory structure
- [x] Core map abstractions
- [x] Controller/Service separation
- [ ] Complete migration of all screens to `lib/features/`
- [ ] Removal of legacy `lib/screens/map/map_screen.dart` (after full validation)

## Key Migration Decisions

1. **Keep existing services**: All services (`RoutingService`, `WeatherService`, `LocationSearchService`, etc.) remain unchanged. They are consumed by both the old FlutterMap and new MapLibre screens.

2. **Keep existing providers**: Riverpod providers (`hazardsProvider`, `stickerProvider`, etc.) remain unchanged.

3. **Keep existing models**: Data models (`Hazard`, `Place`, `Sticker`, etc.) remain unchanged.

4. **New layer system**: MapLibre uses GeoJSON sources and style layers instead of FlutterMap's widget-based layers. The `MapLibreLayerController` manages this.

5. **Parallel run**: Both implementations coexist until the MapLibre version is fully validated.

## Testing the Migration

To test the MapLibre implementation:

1. **Development**: Use the debug FAB (added to main navigation) to toggle between implementations at runtime.

2. **Configuration**: Set `MapConfig._useMapLibre = true` in `map_config.dart` to permanently enable MapLibre.

3. **Validation checklist**:
   - [ ] Map renders OSM tiles correctly
   - [ ] User location shows and follows
   - [ ] Search works and pans to location
   - [ ] Route calculation and rendering
   - [ ] Navigation with turn-by-turn
   - [ ] Weather layers toggle and display
   - [ ] Hazard markers appear on map
   - [ ] HOA entrances show
   - [ ] Flood zones render
   - [ ] Map rotation and compass work
   - [ ] Zoom controls function

## Dependencies

### Added
- `maplibre_gl: ^0.19.0` — MapLibre GL Flutter plugin

### Preserved (still needed by legacy code)
- `flutter_map: ^8.2.0` — Still used when `MapConfig.useMapLibre == false`
- `latlong2: ^0.9.1` — Still used by services and models
- `flutter_compass: ^0.8.1` — Still used by both implementations

## Rollback Plan

If the MapLibre implementation has issues:

1. Set `MapConfig.disableMapLibre()` to fall back to FlutterMap immediately
2. Fix issues in the MapLibre implementation
3. Re-enable with `MapConfig.enableMapLibre()`

No existing functionality is lost since all features continue to work with the FlutterMap fallback.
