# SmartRoad – Full Codebase Summary for ChatGPT

This document describes the **SmartRoad** Flutter app (first project of **The Heedful**). Use it to understand the project structure, features, and implementation details when working with ChatGPT or another AI assistant.

---

## 1. Project Overview

- **Name:** SmartRoad  
- **Company:** The Heedful  
- **Motto:** "Be Heedful on the Road"  
- **Description:** Road hazard reporting and real-time navigation app with Supabase backend and self-hosted GraphHopper routing.  
- **Platform:** Flutter (Android, iOS, Web)  
- **Version:** 1.0.0+1 (pubspec), documented as v2.8.x in summaries  
- **SDK:** Dart ^3.7.0  
- **Current status:** Demo mode only; no production database wired yet. All features work with local/demo data.

---

## 2. Repository Structure

```
SmartRoad/
├── lib/                          # Flutter app source
│   ├── main.dart                 # App entry, splash, deep links, auth routing
│   ├── core/
│   │   ├── config/env.dart       # Env vars: SUPABASE_URL, SUPABASE_ANON_KEY, GEMINI_API_KEY, etc.
│   │   ├── constants/app_constants.dart  # Map bounds, zoom, pagination, demo credentials
│   │   └── theme/app_theme.dart  # Dark theme, colors, breakpoints, hazard colors
│   ├── config/
│   │   ├── weather_config.dart   # OpenWeatherMap API key, proxy URL for weather tiles
│   │   ├── traffic_config.dart   # TomTom Traffic API key
│   │   ├── commute_fare_reference.dart  # LTFRB-style fare estimates (jeepney, bus, tricycle)
│   │   └── regional_fuel_defaults.dart  # Regional fuel defaults
│   ├── models/                   # Data models (see section 4)
│   ├── providers/                # Riverpod state (see section 5)
│   ├── screens/                  # Full-screen UIs (see section 6)
│   ├── services/                 # Business logic (see section 7)
│   ├── widgets/                  # Reusable UI (see section 8)
│   └── utils/                    # Helpers (polyline_smoothing, fuel_utils, transparent_image)
├── assets/
│   ├── known_places.json
│   └── app_icon.png
├── pubspec.yaml                  # Dependencies (see below)
├── analysis_options.yaml         # Flutter lints
├── README.md                     # Setup, features, troubleshooting
├── PROJECT_SUMMARY.md            # Feature checklist
├── IMPLEMENTATION_SUMMARY.md     # Detailed implementation notes
├── supabase_schema.sql           # Core schema (profiles, hazards, PostGIS)
├── supabase_places_schema.sql    # Places, comments, likes, photos
├── supabase_fuel_schema.sql      # Fuel stations, prices, reports
├── supabase_gate_access_schema.sql
├── supabase_comments_schema.sql
├── supabase_routes_schema.sql
├── backend/                      # GraphHopper Docker, API placeholder
└── run.bat / run-with-env.sh     # Run with .env (OPENWEATHERMAP_API_KEY, TOMTOM_API_KEY, etc.)
```

---

## 3. Dependencies (pubspec.yaml)

**Production:**  
- **UI:** flutter, cupertino_icons, flutter_svg  
- **State:** flutter_riverpod  
- **Backend:** supabase_flutter  
- **Maps/Location:** flutter_map, latlong2, geolocator, permission_handler  
- **HTTP:** dio, http  
- **Images:** image_picker  
- **Storage:** hive, hive_flutter, sqflite, path_provider  
- **Notifications:** flutter_local_notifications  
- **Utils:** intl, uuid  
- **QR:** qr_flutter, mobile_scanner  
- **Music / links:** flutter_media_controller, app_links, android_intent_plus, url_launcher  

**Dev:** flutter_test, flutter_lints, flutter_launcher_icons  

**Assets:** assets/known_places.json, assets/app_icon.png  

---

## 4. Core Configuration (Excerpts)

### 4.1 core/config/env.dart

- `Env.supabaseUrl`, `Env.supabaseAnonKey` (String.fromEnvironment, default '')  
- `Env.storageBucketName` (default 'hazard-images')  
- `Env.geminiApiKey` (for sticker AI verification)  
- `Env.validate()` true only when Supabase URL and anon key are set; otherwise app runs in demo mode.

### 4.2 core/constants/app_constants.dart

- **Map:** defaultLatitude 14.5995, defaultLongitude 120.9842, defaultZoom 13, minZoom 6.8, maxZoom 18  
- **Philippines bounds:** philippinesSouth 4.215806, philippinesWest 116.147499, philippinesNorth 21.321780, philippinesEast 127.647621  
- **Notifications:** notificationRadiusKm 2.0  
- **Feed:** feedPageSize 20, maxMapMarkers 500  
- **Images:** maxImageSizeBytes 5MB, allowedImageTypes jpeg/png/webp  
- **Demo:** demoEmail 'demo@smartroad.app', demoPassword 'DemoPass123!'

### 4.3 core/theme/app_theme.dart

- **Colors:** primaryColor 0xFF6366F1, backgroundColor 0xFF0F172A, surfaceColor 0xFF1E293B, error/success/warning/info/accent  
- **Breakpoints:** breakpointMobile 600, breakpointTablet 900, breakpointDesktop 1200  
- **Helpers:** isMobile/isTablet/isDesktop(context), responsivePadding, responsiveButtonHeight, maxContentWidth  
- **Hazard colors:** map from hazard type string to Color  
- **ThemeData:** darkTheme (Material 3, dark, cards, inputs, nav bar, buttons, chips, snackbar)

### 4.4 config/weather_config.dart

- OPENWEATHERMAP_API_KEY, WEATHER_PROXY_URL via String.fromEnvironment  
- Tile URL helpers: getOpenWeatherMapRainTileUrl, getOpenWeatherMapTempTileUrl, getOpenWeatherMapCloudsTileUrl  
- areLayersAvailable: on web requires API key or proxy; on other platforms true.

### 4.5 config/commute_fare_reference.dart

- estimateFare(distanceKm, VehicleType): jeepney/bus/tricycle segment-style estimates; car/motorcycle/walking return 0  
- hasFareEstimate(VehicleType): true for jeepney, bus, tricycle.

---

## 5. Models (lib/models/)

| File | Main types | Purpose |
|------|------------|--------|
| hazard.dart | Hazard, HazardType, SeverityLevel | Hazard report; PostGIS location parsing; distanceTo(lat,lon); fromJson/toJson |
| user_profile.dart | UserProfile, ReporterLevel | Profile from Supabase; copyWith |
| sticker.dart | Sticker, HOAAccessType, HOAPassMode, HOA, GatePassData | Stickers, HOAs, gate pass QR payload; isValid, daysUntilExpiration |
| place.dart | Place | Known/community place; id, name, lat/lon, category, aliases; fromJson/toJson |
| fuel_station.dart | FuelStation | Station with FuelPrice list; hasStalePrice, averageConfidence; fromJson/copyWith |
| fuel_price.dart | FuelPrice | Price, fuel type, confidence, isStale |
| fuel_price_update.dart | FuelPriceUpdate | Multi-fuel update payload |
| fuel_station_submission.dart | FuelStationSubmission | Submission model |
| fuel_price_report.dart | FuelPriceReport | Report model |
| commute_state.dart | CommuteStatus, AlarmStage, VehicleType, EmergencyContact, SafetySettings, CommuteSettings, CommuteState | Commute state machine; vehicle speeds; safety/off-route; weather/traffic-light ETA fields |
| weather_state.dart | WeatherState enum, WeatherData | Weather for commute ETA |
| recent_location.dart | RecentLocation, RecentLocationKind | Search/navigation recents |
| saved_route.dart | SavedRoute, RouteSharingMode, RouteShare | Saved routes |
| saved_commute_stop.dart | SavedCommuteStop | Saved commute stops |
| place_comment.dart | PlaceComment | Place comments |
| place_image.dart | PlaceImageStatus, PlaceImage | Place photos |
| hazard_comment.dart | HazardComment | Hazard comments |
| navigation_settings.dart | NavigationSettings | Nav preferences |
| navigation_avatar_style.dart | NavigationAvatarStyle | Avatar style for map |
| music_app.dart | MusicAppDescriptor | Music app id, displayName, package, icon, accentColor |
| map_poi.dart | MapPoi, PoiCategory | POI from Overpass |
| fuel_type.dart | FuelType | Fuel type enum |

---

## 6. Providers (lib/providers/) – Riverpod

| Provider file | Main providers / notifiers | Role |
|---------------|----------------------------|------|
| auth_provider.dart | demoUserStateProvider, authStateProvider, currentUserIdProvider, userProfileProvider, currentUserProfileProvider | Auth state; demo vs Supabase |
| navigation_provider.dart | navigationTabProvider | Bottom nav index (Map/Feed/Routes/Profile); switchToTab, switchToMap |
| hazards_provider.dart | HazardsNotifier, MapHazardsNotifier | Feed hazards; map hazards with realtime |
| map_filter_provider.dart | MapFilterState, MapFilterNotifier | Hazard type/severity/expiry; traffic layer toggle |
| map_ui_provider.dart | mapIsNavigatingProvider, etc. | Map UI state (e.g. navigating) |
| location_provider.dart | locationProvider, lastKnownLocationProvider | Location stream; last known |
| sticker_provider.dart | userStickersProvider, activeUserStickersProvider, hoasProvider | Stickers and HOAs |
| fuel_provider.dart | MapFuelStationsNotifier, NearbyFuelStationsNotifier, SelectedFuelStationNotifier, FuelSubmissionNotifier, FuelSubmissionState | Map fuel stations; selection; submission state |
| route_creation_provider.dart | RouteDrawingState, RouteDrawingNotifier, SavedRouteFollowingNotifier | Draw route; follow saved route |
| saved_route_navigation_provider.dart | SavedRouteNavigationNotifier, SavedRouteNavigationState | Saved route navigation state |
| saved_stops_provider.dart | SavedStopsNotifier | Saved commute stops |
| commute_provider.dart | commute state | Commute mode state |
| music_control_provider.dart | MusicControlProvider | Media session state |
| place_comments_provider.dart | PlaceCommentsNotifier | Place comments async list |
| comments_provider.dart | HazardCommentsNotifier | Hazard comments |
| gate_access_provider.dart | Gate access state | Gate access / history |

---

## 7. Screens (lib/screens/)

| Screen | File | Role |
|--------|------|------|
| Splash | splash/splash_screen.dart | 2–3s splash; branding |
| Login | auth/login_screen.dart | Email/password; demo credentials; guest; signup link |
| Signup | auth/signup_screen.dart | Email/password signup |
| Main nav | main_navigation_screen.dart | IndexedStack: Map, Feed, Routes, Profile; FAB report hazard; Routes tab sign-in guard |
| Map | map/map_screen.dart | FlutterMap; hazards; POIs; fuel; search; navigation overlay; route; long-press location options |
| Feed | feed/feed_screen.dart | Reverse-chronological hazards; tap to map + detail sheet |
| Routes | routes/routes_screen.dart | Discover / My Routes / Popular; create route (draw / use navigation) |
| Profile | profile/profile_screen.dart | Guest vs logged-in; profile; Gate Pass; Guard Scanner; Stickers; Music Controls; About; Nav Settings |
| Report hazard | report/report_hazard_screen.dart | Type, severity, description, image; auth guard |
| Gate Pass | gate/gate_pass_screen.dart | QR for selected sticker; refresh ~4 min |
| Guard Scanner | gate/guard_scanner_screen.dart | Camera QR scan; validate sticker |
| Access history | gate/access_history_screen.dart | Gate access log |
| Manage stickers | stickers/manage_stickers_screen.dart | List stickers; add physical (Gemini verify) |
| Commute mode | commute/commute_mode_screen.dart | Set destination; vehicle type; ETA; alarm; safety; lagpas recovery |
| Fuel prices | fuel/fuel_prices_screen.dart | List fuel stations; sort; open detail |
| Navigation settings | profile/navigation_settings_screen.dart | Avatar, speed HUD, etc. |
| About | about/about_screen.dart | App info, The Heedful |
| Admin | admin/place_photo_review_screen.dart, fuel_station_review_screen.dart, fuel_price_report_review_screen.dart | Moderation / review |

---

## 8. Services (lib/services/)

| Service | Responsibility |
|---------|----------------|
| SupabaseService | Singleton; init Supabase; demo mode; auth (signIn/signOut/signUp); profiles; hazards CRUD + realtime; places/photos/comments/likes/ratings; stickers/HOAs; gate access; fuel stations/prices/reports; storage uploads |
| LocationService | Current position; permission; platform accuracy; last known; distance filter |
| LocationSearchService | Nominatim; forward/reverse geocoding; country-prioritized search; recents; route-distance on results |
| RoutingService | GraphHopper routes; VehicleType (Big Bike, Motorcycle, Car, Truck, Pedestrian); RouteData/RouteMetadata; blocked shortcuts (sticker) |
| RouteService | Init (e.g. Hive); saved routes |
| RouteDistanceTracker | Turn/gate/delivery points; distance indicators along route |
| NotificationService | Flutter local notifications; nearby hazard (2 km); init channels |
| OfflineCacheService | Hive cache for hazards; load/save |
| StickerService | Sticker/HOA CRUD; gate pass validation; demo data |
| StickerVerifierService | Gemini API; verify physical sticker image |
| WeatherService | Point weather (e.g. for commute ETA) |
| WeatherLayerManager | Weather layer state; opacity; config |
| WeatherTileGenerator | Tile generation for weather layers |
| Rainviewer_service | (If used) radar tiles |
| MusicControlService | Media session; play/pause/skip; MediaState; thumbnailUrl |
| MusicAppLauncherService | Resolve installed music apps; launch app; default app (AppPreferencesService) |
| DeepLinkService | app_links; smartroad://map, smartroad://music, smartroad://music/open |
| AppPreferencesService | Local prefs (e.g. default_music_app_id_v1) |
| CommuteService | Commute state machine; ETA (vehicle + weather + traffic lights); alarm stages; off-route; SMS; lagpas |
| EmergencySmsService | Send SMS to emergency contacts |
| FuelService | Fuel stations/prices CRUD; submissions; validation; regional defaults |
| KnownPlacesService | Load known_places.json |
| OverpassPoiService | Overpass API; POIs by zoom tier; categories |
| PoiSearchService | POI search |
| TransitStopService | Transit stop info (cached) |
| SpeedLimitService | Speed limits (Overpass + defaults) |

---

## 9. Widgets (lib/widgets/) – Selected

- **Map / POI:** hazard_marker.dart, map_poi_marker.dart, known_place_marker.dart, user_location_marker.dart, hoa_gate_marker.dart  
- **Sheets:** hazard_detail_sheet.dart, place_detail_sheet.dart, fuel_station_detail_sheet.dart, route_preview_sheet.dart, reroute_options_sheet.dart  
- **Route:** route_drawing_widget.dart, route_card.dart, create_route_dialog.dart, save_route_dialog.dart  
- **Navigation:** distance_indicator_widget.dart (CompactDistanceIndicator, DistanceIndicatorsPanel), navigation_speed_hud.dart, navigation_hazard_warning_banner.dart  
- **Weather:** weather_layer_controls.dart, weather_tile_layers.dart, weather_overlay.dart  
- **Traffic:** traffic_layer.dart (TrafficLayer, TrafficTileProvider)  
- **Music:** music_control_widget.dart, music_control_settings_card.dart, music_app_picker_sheet.dart  
- **Commute:** commute_alarm_widget.dart, commute_empty_state.dart, commute_settings_sheet.dart, safety_settings_sheet.dart, quick_stops_widget.dart, countdown_ring_widget.dart, lagpas_alert_overlay.dart, lagpas_recovery_overlay.dart, arrival_celebration.dart, sos_button.dart  
- **Fuel:** add_fuel_station_dialog.dart, multi_fuel_update_dialog.dart  
- **Other:** route_drawing_widget, transparent_image

---

## 10. main.dart – App Entry and Deep Links

- **Initialization:** WidgetsFlutterBinding; SupabaseService, RouteService, OfflineCacheService, NotificationService.  
- **Splash:** _showSplash true for 2 seconds then set false and process pending deep link.  
- **Deep links:** DeepLinkService listens for `smartroad` scheme.  
  - `smartroad://map` → switch to Map tab.  
  - `smartroad://music` → switch to Map, then show MusicAppPickerSheet.  
  - `smartroad://music/open` → switch to Map, open default music app if set.  
- **Routing:** If _showSplash → SplashScreen; else authStateProvider: user present → MainNavigationScreen, null → LoginScreen. Routes: /login, /signup.

---

## 11. Database (Supabase) – Core Schema

- **PostGIS** enabled.  
- **Enums:** hazard_type, severity_level, reporter_level.  
- **profiles:** id (auth.users), name, email, photo_url, reporter_level, valid_reports_count, created_at, updated_at.  
- **hazards:** id, user_id, type, description, severity, location (GEOGRAPHY(POINT, 4326)), image_url, sticker_flag, created_at, updated_at.  
- **Indexes:** GIST on hazards.location; created_at, type, user_id.  
- **RLS:** Profiles readable by all; users update own. Hazards readable by all; authenticated insert; owner or admin update/delete.  
- **Trigger:** handle_new_user creates profile on signup.  
- Additional schemas: places (comments, likes, photos, ratings), fuel (stations, prices, reports), gate access, routes, etc.

---

## 12. Feature Summary (for ChatGPT)

- **Auth:** Email/password; Supabase; demo user (demo@smartroad.app / DemoPass123!); guest; sign-in required for report, routes, comments/likes/photos.  
- **Map:** OSM (flutter_map); Philippines bounds and zoom limits; hazards; POIs (Overpass); fuel stations; HOA gates (red/green); search with country priority and route distance; long-press location options.  
- **Navigation:** GraphHopper; 5 vehicle types; route preview; live nav; off-route reroute; speed HUD; speed limits; nav avatar; distance to destination/turn/gate/delivery.  
- **Hazards:** Report (type, severity, description, photo); feed; realtime; offline cache.  
- **Places:** Known places + community photos/comments/likes/ratings; place detail sheet.  
- **Fuel:** Community fuel stations and prices; submission rules (distance/photo); admin review.  
- **Stickers & gates:** Digital sticker wallet; physical sticker upload (Gemini); Gate Pass QR (refresh 4 min); Guard Scanner; HOA access types; gate markers.  
- **Commute mode:** Destination; vehicle type (jeepney/bus/car/motorcycle/tricycle/walking); ETA with weather (rain) and traffic lights (Overpass); smart alarm; off-route safety; SMS; lagpas recovery.  
- **Music:** Floating widget; play/pause/skip; default app; picker (installed apps); deep links.  
- **Weather layers:** Rain, heat, clouds (OpenWeatherMap tiles); proxy for web.  
- **Traffic layer:** TomTom Traffic Flow tiles; toggle in filter.  
- **Routes:** Discover / My Routes / Popular; create by draw or navigation; save.  
- **Demo mode:** No DB required; all features with local/demo data.

---

## 13. Environment Variables / Build Args

- **Supabase:** SUPABASE_URL, SUPABASE_ANON_KEY, STORAGE_BUCKET_NAME  
- **Gemini:** GEMINI_API_KEY (sticker verification)  
- **Weather:** OPENWEATHERMAP_API_KEY, WEATHER_PROXY_URL (optional for web)  
- **Traffic:** TOMTOM_API_KEY  

Use run.bat (Windows) or run-with-env.sh (Linux/Mac) to load .env and run Flutter.

---

## 14. File Count (lib)

- **Total Dart files:** ~149 under lib (core, config, models, providers, screens, services, widgets, utils).  
- **SQL:** supabase_schema.sql + supabase_places_schema.sql + supabase_fuel_schema.sql + supabase_gate_access_schema.sql + supabase_comments_schema.sql + supabase_routes_schema.sql.

---

Use this document as the single reference for SmartRoad structure, features, and implementation when prompting ChatGPT or similar tools.
