# SmartRoad - Changelog

This document tracks all version updates, feature additions, and significant changes to the SmartRoad application.

---

## Version 2.6.7 - Guest Mode + Ratings + Speed HUD + Navigation Enhancements (Latest)

**Release Date:** January 2026  
**Focus:** Guest navigation access, place ratings, navigation avatar customization, speed HUD + speed limits, comprehensive navigation improvements  
**Status:** Production Ready (Demo Mode Only)

**⚠️ Important Note:** As of this version, SmartRoad runs exclusively in **demo mode**. No database has been set up on the server yet, and database integration has not been implemented. All features work with local/demo data. Database integration will be added in the future after server infrastructure is fully set up.

### New Features

#### Guest Mode (No Login Required)
- ✅ **"Continue as Guest" option on login screen**
  - Users can browse the map and use navigation without logging in
  - Guest Profile screen shows Navigation Settings + About (with sign-in CTA)
  - Contribution features remain gated (reporting, likes, comments, ratings, uploads, route saving)
  - Auth-gated actions show helpful snackbars with "Sign in" action buttons

#### Place Ratings (Waze-style)
- ✅ **1–5 star rating system**
  - Rating average + count shown in place preview
  - Logged-in users can submit/update their rating
  - Ratings stored in Supabase (schema ready; currently demo mode only)

#### Navigation Avatar Customization (Waze-style)
- ✅ **Customizable user location marker**
  - Choose from: Arrow, Car, Motorcycle, Big Bike, Truck, Pedestrian
  - Stored locally in app preferences (Hive)
  - Works for both logged-in and guest users
  - Accessible via Profile → Navigation Settings

#### Speed HUD + Speed Limits + Overspeed Warnings
- ✅ **Speed HUD during navigation**
  - Shows current speed (km/h) from GPS
  - Displays speed limit sign (best-effort lookup)
- ✅ **Speed limit data**
  - OSM Overpass API lookup for `maxspeed` tags (best-effort)
  - Fallback to user-editable defaults per `highway` type
  - Per-road overrides supported (stored locally)
- ✅ **Overspeed warnings**
  - Triggers when speed > (limit + tolerance)
  - Configurable tolerance (default: 5 km/h)
  - Throttled haptic feedback to avoid spamming
  - Visual warning in Speed HUD

#### Navigation Camera Improvements
- ✅ **Auto-follow + map rotation**
  - Map automatically centers and zooms in during navigation
  - Map rotates to match user heading (or route direction on web)
  - User location marker arrow rotates relative to map rotation
- ✅ **Re-center button**
  - Location button acts as "Re-center" during navigation
  - Resumes auto-follow, zoom, and rotation after manual panning

### Technical Changes

#### New Files
- `lib/models/navigation_avatar_style.dart` - Avatar style enum
- `lib/models/navigation_settings.dart` - Navigation preferences model
- `lib/services/app_preferences_service.dart` - Local storage (Hive) for navigation settings
- `lib/providers/navigation_settings_provider.dart` - Riverpod provider for navigation settings
- `lib/screens/profile/navigation_settings_screen.dart` - Settings UI (avatar, speed HUD, speed limits)
- `lib/services/speed_limit_service.dart` - OSM Overpass speed limit lookup + defaults
- `lib/widgets/navigation_speed_hud.dart` - Speed HUD widget (speed + limit + overspeed warning)

#### Modified Files
- `lib/screens/auth/login_screen.dart` - Added "Continue as Guest" button
- `lib/screens/auth/signup_screen.dart` - Routes to MainNavigationScreen after signup
- `lib/screens/profile/profile_screen.dart` - Guest Profile page (Navigation Settings + About + Sign in CTA)
- `lib/screens/main_navigation_screen.dart` - FAB gated with sign-in snackbar
- `lib/screens/map/map_screen.dart` - Guest mode support, speed HUD integration, navigation camera improvements, save route gating
- `lib/widgets/user_location_marker.dart` - Avatar customization support
- `lib/widgets/place_detail_sheet.dart` - Ratings UI + guest gating
- `lib/services/supabase_service.dart` - Place ratings methods (getMyPlaceRating, getPlaceRatingsSummary, setPlaceRating)
- `lib/main.dart` - RouteService initialization

#### Database Schema (Future)
- `supabase_places_schema.sql` - Added `place_ratings` table (ready for future database integration)

---

## Version 2.6.6 - Known Place Previews & Route Editing Fixes

**Release Date:** January 2026  
**Focus:** Known location previews (photos/likes/comments) + curved route editing + route saving UX  
**Status:** Production Ready

### New Features

#### Known Location Previews (Waze-style)
- ✅ **Known place markers on the map**
  - Built-in list (starting set): VTX (Starmall Alabang), Festival Mall Alabang, SM City San Pablo
  - Markers open a place preview with photos, likes, and comments
- ✅ **Place photos with moderation**
  - Users can submit photos (pending review)
  - Admin review screen to approve/reject photos
- ✅ **Place likes + comments**
  - Like button + count
  - Realtime comments (Supabase)

### Fixes

#### Route Creation & Editing
- ✅ **Curved fallback route interpolation**
  - Control-point editing now generates a smooth curve (no sharp kinks)
- ✅ **Save route from preview / editing**
  - "Save Route" available in route preview
  - "Save" available in route editing controls
  - Save action available during active navigation overlay

### Technical Changes

- Added `lib/utils/polyline_smoothing.dart` (Catmull–Rom smoothing)
- Added known places + place preview UI:
  - `assets/known_places.json`
  - `lib/models/place*.dart`, `lib/services/known_places_service.dart`
  - `lib/widgets/place_detail_sheet.dart`
  - `lib/screens/admin/place_photo_review_screen.dart`
- Extended `SupabaseService` for place photos, likes, and comments
- Added `supabase_places_schema.sql` for required DB tables + RLS policies

---

## Version 2.6.5 - Route Creation & Editing System

**Release Date:** January 2026  
**Focus:** Route Creation with Custom Points & Control Point Editing  
**Status:** Production Ready

### New Features

#### Route Creation System
- ✅ **Custom Start/End Point Selection**
  - Added draggable bottom sheet for selecting custom navigation points
  - Support for "Use Current Location" as start point
  - Search integration for location selection
  - Auto-calculates route when end point is selected
  - Route preview sheet opens automatically after calculation

- ✅ **Control Point System for Route Editing**
  - Tap on route line to add control points
  - Drag control points to adjust route path
  - Real-time route geometry updates
  - Control points work as waypoints: Start → CP1 → CP2 → ... → End
  - Route recalculates automatically when control points are moved

- ✅ **Route Editing UI**
  - "Adjust Route Path" button in route preview and save dialogs
  - Visual editing controls (Recalculate, Clear, Done)
  - Control point markers with drag handles
  - Route line becomes thicker and more visible during editing

- ✅ **Fallback Route Interpolation**
  - When GraphHopper is unavailable, routes interpolate through control points
  - Smooth curve generation between waypoints
  - Intermediate points generated for visual smoothness
  - Total distance calculated correctly across all segments

### Improvements

#### UX Enhancements
- ✅ Auto-open route preview when end point is selected
- ✅ Improved dialog closing and state management
- ✅ Better error handling for GraphHopper failures
- ✅ Snackbar notifications for route updates
- ✅ Currency changed to PHP (Philippine Peso)
- ✅ Price field disabled for private routes
- ✅ Duration formatting (hours, minutes, days)

#### UI Polish
- ✅ Removed gradients from login/signup screens
- ✅ Improved custom point selection dialog (draggable, minimizable)
- ✅ Floating button to reopen minimized selection sheet
- ✅ Better visual feedback for control point operations

### Bug Fixes

#### White Screen Issues
- ✅ Fixed white screen after selecting end point
- ✅ Improved context handling for dialog closing
- ✅ Added mounted checks before all setState calls
- ✅ Better async flow management with proper delays

#### Route Calculation
- ✅ Fixed route calculation with waypoints
- ✅ Improved fallback route creation with waypoint interpolation
- ✅ Fixed duration display accuracy (GraphHopper time unit detection)
- ✅ Route updates correctly when control points are added/moved

### Technical Changes

- **MapScreen (`lib/screens/map/map_screen.dart`):**
  - Added `_routeControlPoints` state for managing control points
  - Added `_isEditingRoute` flag for editing mode
  - Implemented `_updateRouteGeometryWithControlPoints()` for fallback interpolation
  - Added `_handleEndPointSelected()` for safe dialog closing
  - Improved `_calculateRouteWithCustomPoints()` with GraphHopper failure detection
  - Added control point markers and editing UI

- **RoutingService (`lib/services/routing_service.dart`):**
  - Updated `calculateRoute()` to accept waypoints parameter
  - Improved `_createFallbackRoute()` to interpolate between waypoints
  - Added smooth curve generation for fallback routes

- **Route Creation Provider (`lib/providers/route_creation_provider.dart`):**
  - Added `routeEditingProvider` for passing routes to edit
  - Route creation trigger system

- **Save Route Dialog (`lib/widgets/save_route_dialog.dart`):**
  - Added "Adjust Route Path" button
  - Currency changed to PHP
  - Price field disabled for private routes
  - Improved duration formatting

### Known Issues

- ✅ Fixed in 2.6.6: Route interpolation now generates smooth curves between control points
- ⚠️ GraphHopper waypoint routing not fully tested (GraphHopper not set up)
- ⚠️ Route drawing feature (draw route) not yet implemented

---

## Version 2.6.4 - Weather Layer Smoothing & Zoom Limits

**Release Date:** January 2026  
**Focus:** Weather Layer Improvements & Map Zoom Restrictions  
**Status:** Production Ready

### Bug Fixes

#### Weather Layer Square Artifacts
- **Fixed Square/Boxy Tile Artifacts:**
  - ✅ Removed `ClipRect` which was creating hard edges between tiles
  - ✅ Implemented extreme blur (7.0-12.0 sigma) to eliminate all visible tile boundaries
  - ✅ Weather layers now display with smooth, curved edges at all zoom levels
  - ✅ Blur extends beyond tile boundaries for seamless blending
  - ✅ Applied to all three weather layers: Rain, Heat, and Clouds
  - ✅ Weather layers now match the smooth appearance from previous versions

#### Map Zoom Limits
- **Fixed Excessive Zoom-Out:**
  - ✅ Set `minZoom` to 6.8 to restrict zoom-out to Philippines area size
  - ✅ Added continuous zoom limit enforcement using periodic timer (100ms checks)
  - ✅ Added Philippines geographic bounds enforcement
  - ✅ Map center is automatically clamped to Philippines bounds when panning
  - ✅ Prevents users from zooming out beyond the Philippines area (similar to Waze)

#### Weather Layer Visibility
- **Fixed Weather Layers Not Showing When Zoomed In:**
  - ✅ Weather layers now work at all zoom levels (2-18)
  - ✅ Fixed tile coordinate calculation for zoom levels > 10
  - ✅ OpenWeatherMap tiles (max zoom 10) are properly scaled for higher zoom levels
  - ✅ Weather layers remain visible when zooming in beyond level 10

#### Heat Layer Accuracy
- **Improved Heat Layer Display:**
  - ✅ Reduced heat layer opacity cap from 60% to 50% for better accuracy perception
  - ✅ Added documentation note about temperature tile accuracy limitations
  - ✅ Heat layer now uses same extreme blur as other layers for smooth appearance

### Technical Changes

- **Weather Tile Layers (`lib/widgets/weather_tile_layers.dart`):**
  - Removed `ClipRect` from all weather layer `tileBuilder` methods
  - Implemented adaptive blur: 7.0-12.0 sigma based on zoom level
  - Blur is stronger at lower zoom levels (12.0 at zoom 2, down to 7.0 at zoom 10+)
  - Fixed tile coordinate scaling for zoom levels beyond OpenWeatherMap's native max (10)

- **Map Screen (`lib/screens/map/map_screen.dart`):**
  - Added `_zoomLimitTimer` for continuous zoom and bounds enforcement
  - Enhanced timer to check both zoom limits and geographic bounds every 100ms
  - Automatically clamps map center to Philippines bounds when outside
  - Properly disposes timer in `dispose()` method

- **App Constants (`lib/core/constants/app_constants.dart`):**
  - Updated `minZoom` from 3.0 to 6.8 for Philippines area restriction
  - Added Philippines geographic bounds constants:
    - `philippinesSouth`: 4.215806
    - `philippinesWest`: 116.147499
    - `philippinesNorth`: 21.321780
    - `philippinesEast`: 127.647621

### Performance Improvements
- **Zoom Enforcement:**
  - Efficient periodic checking (100ms intervals) ensures smooth user experience
  - Bounds checking only triggers corrections when needed
  - No performance impact on map rendering

---

## Version 2.6.3 - Smart Country-Prioritized Location Search

**Release Date:** December 2025  
**Focus:** Search Optimization & Bug Fixes  
**Status:** Production Ready

### New Features

#### Smart Country-Prioritized Location Search
- **Intelligent Search Prioritization:**
  - ✅ Automatically detects user's country from current location using reverse geocoding
  - ✅ **Prioritizes current country results** - shows results from user's country first (e.g., Philippines)
  - ✅ **Global main cities support** - also searches globally but only shows main cities (cities, towns, municipalities) from other countries
  - ✅ Prevents showing random streets or small places from other countries
  - ✅ Works globally - if user is in Japan, prioritizes Japan; if in Europe, prioritizes Europe
  - ✅ Country code caching to avoid repeated reverse geocoding API calls
  - ✅ Faster, more relevant search results by prioritizing local results

### Bug Fixes
- **Search Results Display:**
  - ✅ Fixed RangeError: "Index out of range" when accessing search results
  - ✅ Added proper bounds checking for `itemCount` in ListView to prevent index errors
  - ✅ Ensured `itemCount` never exceeds available search results

### Technical Changes
- **Location Search Service:**
  - Added `getCountryCodeFromCoordinates()` method for reverse geocoding
  - Updated `searchLocation()` to accept optional `countryCode` parameter
  - Country code restriction uses Nominatim's `countrycodes` query parameter

- **Map Screen:**
  - Added `_detectCountryCode()` method to detect and cache country code
  - Updated `_searchLocation()` to use two-phase search:
    1. First searches in current country (prioritized, up to 20 results)
    2. Then searches globally but filters to main cities only (up to 30 results)
  - Added `_isMainCity()` method to filter global results to only main cities/towns
  - Country code detection triggered when location is updated
  - Increased search result limit and improved result deduplication
  - Fixed ListView `itemCount` to use `.clamp()` to prevent index out of range errors

### Performance Improvements
- **Search Optimization:**
  - Faster search results by prioritizing local results
  - Better relevance for local users while maintaining global city search capability
  - Optimized result deduplication to prevent duplicate entries

---

## Version 2.6.2 - Live Traffic Layer Integration

### New Features

#### Live Traffic Layer
- **Traffic Flow Visualization:**
  - ✅ Real-time traffic conditions overlay on map
  - ✅ Toggleable traffic layer in map filter panel
  - ✅ Color-coded traffic flow indicators:
    - Green: Free flow (fast)
    - Yellow: Moderate traffic
    - Red: Heavy traffic / Slow
    - Dark red: Very slow / Standstill
  - ✅ Transparent PNG overlay that doesn't obstruct map visibility
  - ✅ Integrated with existing map filter system

### Technical Changes
- **Traffic Layer Implementation:**
  - Created `TrafficLayer` widget using `TileLayer` from `flutter_map`
  - Implemented `TrafficTileProvider` for TomTom Traffic Flow API integration
  - Added `TrafficConfig` class for API key management and URL construction
  - URL format: `https://api.tomtom.com/traffic/map/4/tile/flow/relative/{z}/{x}/{y}.png?key={apiKey}`
  - Integer coordinate enforcement (z, x, y converted to ints to prevent API errors)
  - Added traffic toggle to `MapFilterProvider` and `MapFilterPanel`
  - Removed technical API key warning messages for non-technical users

### Bug Fixes
- **Traffic API Integration:**
  - Fixed URL format to include `/relative/` path segment
  - Fixed coordinate type conversion (ensured integers, not floats)
  - Fixed coordinate order verification (z, x, y)
  - Resolved 400 "Bad Request" errors by enforcing integer coordinates
  - Improved error handling with transparent placeholder tiles

### Configuration
- **Environment Variables:**
  - Added `TOMTOM_API_KEY` support in `.env` file
  - Updated `run.bat`, `run-with-env.ps1`, and `run-with-env.sh` scripts
  - Updated `ENV_SETUP.md` documentation

---

## Version 2.6.1 - Search Results Distance Display

**Release Date:** December 2025  
**Focus:** Search Results Enhancement  
**Status:** Production Ready

### New Features

#### Search Results Distance Display
- **Route Distance Indicators:**
  - ✅ Search results now display route-based distances on the right side
  - ✅ Distances calculated using actual route (GraphHopper) with fallback to straight-line distance
  - ✅ Fallback distance shows immediately for instant feedback
  - ✅ Distance auto-updates from fallback to actual route distance when calculation completes
  - ✅ Loading spinner appears next to distance while route is being calculated
  - ✅ Graceful error handling with fallback to straight-line distance if route calculation fails

### Technical Changes
- **Search Results UI:**
  - Added `_searchResultDistances` map to store calculated distances
  - Added `_searchResultDistanceLoading` map to track loading states
  - Implemented `_calculateSearchResultDistances()` method for async distance calculation
  - Updated `ListTile` trailing widget to display distance with loading indicator
  - Distance formatting: shows meters for <1km, kilometers for ≥1km

### Bug Fixes
- **Distance Display:**
  - Fixed issue where distance wasn't showing when `isLoading` was true
  - Distance now always displays if available, even during loading state
  - Improved error handling to always show fallback distance on calculation failure

---

## Version 2.6.0 - Weather Layers Fix & Map Wrapping

**Release Date:** December 2025  
**Focus:** Weather Layer Improvements & Map Enhancements  
**Status:** Production Ready

### Bug Fixes & Improvements

#### Weather Layers
- **Fixed Weather Layer Display:**
  - ✅ All three weather layers (rain, heat, clouds) now working correctly
  - ✅ Migrated from RainViewer to OpenWeatherMap for all layers
  - ✅ Heat layer opacity capped at 60% to prevent solid color overlay
  - ✅ Improved tile loading and error handling
  - ✅ Better debugging and logging for weather tile requests
  - ✅ Fixed layer availability checks for all three weather types

#### Map Wrapping
- **Infinite Horizontal Scrolling:**
  - ✅ Upgraded `flutter_map` from 7.0.2 to 8.2.0 for infinite horizontal scrolling support
  - ✅ Map now wraps infinitely when panning left/right
  - ✅ No boundaries or limits on horizontal panning
  - ✅ Proper CRS configuration (Epsg3857) for wrapping support

#### UI Improvements
- **Login Screen:**
  - ✅ Made right panel (login card) more compact
  - ✅ Reduced spacing between elements (XL → MD, LG → MD, MD → SM)
  - ✅ Reduced container padding for better space utilization
  - ✅ Improved visual hierarchy with smaller subtitle text
  - ✅ Reduced button padding for more compact layout

#### Configuration & Setup
- **Environment Variables:**
  - ✅ Added `.env` file support with helper scripts (`run.bat`, `run-with-env.sh`)
  - ✅ Secure API key handling via `--dart-define`
  - ✅ OpenWeatherMap API key configuration
  - ✅ Backend proxy support for web platform
  - ✅ Automatic API key detection and validation

### Technical Changes
- **Dependencies:**
  - Upgraded `flutter_map` to `^8.2.0` for map wrapping support
- **Weather System:**
  - Updated weather tile providers to use OpenWeatherMap
  - Removed RainViewer integration (migrated to OpenWeatherMap)
  - Improved error handling and logging for weather layers
  - Added rate limiting and circuit breaker for API calls
- **Code Quality:**
  - Enhanced UI spacing and padding in login screen
  - Improved code organization and documentation

### Documentation
- Added `MAP_WRAP_INSTRUCTIONS.md` for map wrapping setup
- Added `HEAT_AND_WRAP_FIX.md` for troubleshooting
- Updated `OPENWEATHERMAP_SETUP.md` with API key instructions
- Added `ENV_SETUP.md` for environment variable configuration
- Added `AUTO_RUN_SETUP.md` for automatic API key loading
- Added `MAP_WRAP_UPGRADE.md` for flutter_map upgrade guide

### Breaking Changes
- **Weather Layers:** Changed from RainViewer to OpenWeatherMap (requires API key for web)
- **flutter_map:** Upgraded from 7.0.2 to 8.2.0 (check for breaking changes in your code)

### Migration Guide
- **Weather Layers:** Get OpenWeatherMap API key from https://openweathermap.org/api
- **Map Wrapping:** Run `flutter pub get` to upgrade dependencies
- **Environment Variables:** Use `.env` file with helper scripts or `--dart-define` flags

---

## Version 2.5.0 - Permission-Based Routing & Weather Overlay (MVP)

**Release Date:** 2025  
**Focus:** MVP Readiness - Permission-Based Routing & Weather Visualization  
**Status:** 90% MVP Complete - Investor Demo Ready

### New Features

#### Permission-Based Routing System (MVP)
- **Core Logic Implemented:**
  - Roads can be tagged as restricted/private (HOA roads)
  - Each user has a Digital Sticker Wallet
  - Routing behavior:
    - ✅ If user HAS sticker → include restricted roads
    - ✅ If user DOES NOT HAVE sticker → treat those roads as blocked
- **Route Metadata:**
  - `blocked_shortcut` flag for detected shortcuts
  - `hoa_name` for restricted area identification
  - `time_saved_minutes` for potential time savings calculation
- **Route Preview Sheet:**
  - Shows route distance and duration before navigation
  - Displays vehicle type information
  - Sticker suggestion banner when blocked shortcut exists
  - "Apply for Sticker" CTA (payment integration planned for Post-MVP)
- **User Sticker IDs Provider:**
  - New provider for active sticker IDs
  - Integrated with routing service for permission checks

#### Weather Visual Overlay (Map-Only MVP)
- **Weather States Supported:**
  - ☀️ Sunny (normal conditions)
  - 🔥 Intense Heat (temperature > 35°C)
  - 🌥️ Cloudy
  - 🌧️ Light Rain
  - ⛈️ Heavy Rain
- **Weather Service:**
  - Open-Meteo API integration (free, no API key required)
  - Automatic weather data fetching
  - 10-minute caching for performance
  - Auto-update every 10-15 minutes
- **Weather Overlay Widget:**
  - Toggleable map overlay with semi-transparent color layers
  - Weather icons displayed on affected regions
  - Weather legend with color/icon meanings
  - Floating action button for easy toggle
- **MVP Scope:** Visual only - no rerouting based on weather yet
- **Future:** Weather-aware rerouting logic (Post-MVP)

#### Branding Reinforcement
- **Slogan:** "Be Heedful on the Road"
- **Secondary Line:** "Smart navigation for real road conditions"
- **Branding Locations:**
  - Splash screen (already present)
  - About screen (already present)
  - Demo mode screen (newly added to login screen)
- **Safety-First:** No branding on active navigation screens

### Technical Improvements

#### New Services
- **WeatherService:** Singleton service for weather data fetching and caching
- **Enhanced RoutingService:** Added permission-based routing logic

#### New Models
- **WeatherState:** Enum for weather conditions
- **WeatherData:** Model for weather information with location and timestamp
- **RouteMetadata:** Model for route metadata (blocked shortcuts, time savings)

#### New Widgets
- **RoutePreviewSheet:** Route preview with sticker suggestions
- **WeatherOverlay:** Weather visualization overlay
- **WeatherOverlayToggle:** Toggle button for weather overlay
- **WeatherLegend:** Legend showing weather state meanings

#### Updated Providers
- **sticker_provider.dart:** Added `userStickerIdsProvider` for routing

### Codebase Metrics Update
- **Total Services:** 9 → 10 (added WeatherService)
- **Total Models:** 3 → 4 (added WeatherState/WeatherData)
- **Total Widgets:** 3 → 6 (added RoutePreviewSheet, WeatherOverlay components)

### Post-MVP Features (Planned)
- Payment integration (GCash, PayMaya, Stripe)
- Weather-aware rerouting logic
- HOA admin dashboard
- Multi-country expansion
- Full PostGIS route intersection checks
- Push notifications (FCM)
- AI incident prediction

### Bug Fixes & Improvements
- Fixed null safety issues in weather overlay integration
- Improved route preview UX with better information display
- Enhanced error handling in weather service

---

## Version 2.4.0 - Navigation & Location Enhancements

**Release Date:** 2025  
**Focus:** Comprehensive Navigation System & Location Services

### New Features

#### Multi-Vehicle Routing System
- **5 Vehicle Types Supported**:
  - Big Bike (400cc+) - High displacement motorcycles, tolls optional
  - Motorcycle (≤399cc) - Standard motorcycles, avoids tolls by default
  - Car (Private) - Private vehicles, tolls optional
  - Truck - Commercial vehicles
  - Pedestrian - Walking routes
- **GraphHopper Integration**: Full integration with self-hosted GraphHopper routing engine
- **Route Calculation**: Real-time route calculation with distance and duration
- **Toll Avoidance**: Configurable toll avoidance per vehicle type
- **Route Visualization**: Color-coded route display with traveled/upcoming segments

#### Location Search & Geocoding
- **Nominatim Integration**: OpenStreetMap Nominatim API for free geocoding
- **Location Search**: Search bar with autocomplete and debouncing
- **Reverse Geocoding**: Get address from coordinates
- **Philippines Focus**: Search optimized for Philippines locations
- **Search Results**: Dropdown with location suggestions

#### Real-time Navigation
- **Live Location Updates**: 1-meter accuracy during navigation, 5-meter in normal mode
- **Off-route Detection**: Automatic detection when user deviates from route
- **Automatic Rerouting**: Recalculates route when off-route
- **Route Progress**: Tracks traveled vs upcoming route segments
- **Navigation Overlay**: Real-time navigation UI with distance, duration, and vehicle type
- **Map Following**: Map automatically follows user during navigation

#### Map Enhancements
- **Long Press to Pin**: Long-press map to pin location and show options
- **Location Options Sheet**: Get Directions, Save Location, View on Map, Share options
- **Hazard Filtering**: Filter by type, severity, and expiry status
- **Filter Panel**: Slide-out panel with filter controls
- **Filter Indicators**: Visual indicators for active filters
- **Current Location Button**: Quick access to center on current location

#### Platform-Specific Optimizations
- **Web Support**: Full web platform support with optimized location handling
- **Platform Detection**: Automatic platform detection for location accuracy
- **Web Location**: Uses `LocationAccuracy.high` with 15-second timeout for web
- **Mobile Location**: Uses `LocationAccuracy.bestForNavigation` with 10-second timeout
- **Last Known Position**: Prioritizes cached location for faster initial display

### Technical Implementation

#### New Services
- **LocationSearchService**: OpenStreetMap Nominatim API integration
- **RoutingService**: GraphHopper API integration with vehicle type support
- **Enhanced LocationService**: Platform-specific location handling

#### New Providers
- **mapFilterProvider**: Manages hazard filtering state (type, severity, expiry)

#### Enhanced Services
- **LocationService**: 
  - Platform-specific accuracy settings
  - Better error handling and logging
  - Last known position caching
  - Web-optimized timeouts
- **RoutingService**:
  - Vehicle type enum with GraphHopper parameter mapping
  - Icon support for each vehicle type
  - Fallback route calculation
  - Distance and duration calculation

#### Map Screen Enhancements
- **Location Stream**: Continuous location updates with dynamic distance filter
- **Route Management**: Route splitting, progress tracking, off-route detection
- **Navigation State**: Tracks navigation mode, destination, and route
- **Utility Functions**: Haversine distance, route splitting, distance to route

### UI/UX Improvements

- **Search Bar**: Enhanced search bar with loading indicator and clear button
- **Location Options**: Beautiful bottom sheet for location actions
- **Route Selection**: Vehicle type selection with icons and descriptions
- **Navigation Overlay**: Clean navigation UI with real-time updates
- **Filter Panel**: Smooth slide-out animation with filter controls
- **Error Messages**: Better error messages for location and routing failures

### Bug Fixes

- **Location Loading**: Fixed slow location loading by prioritizing last known position
- **Web Location**: Fixed location not working on web with platform-specific handling
- **Location Stream**: Fixed location stream errors with better error recovery
- **Route Display**: Fixed route visualization with proper polyline rendering
- **Map Interaction**: Changed tap to long-press for location pinning

### Breaking Changes

- None (all changes are additive)

### Migration Notes

1. **GraphHopper Setup** (Required for routing):
   ```bash
   cd backend
   docker-compose up -d graphhopper
   ```

2. **No Database Changes**: All changes are client-side only

3. **Dependencies**: No new dependencies required (uses existing `http` package)

---

## Version 2.3.2 - UI/UX Improvements & Responsive Design

**Release Date:** 2025  
**Focus:** Enhanced User Experience & Visual Design

### UI/UX Improvements

- **Larger Buttons & Inputs**: 
  - Increased button heights (52px mobile, 56px desktop) for better touch targets
  - Enhanced input field padding (20px vertical) for improved usability
  - Better visual hierarchy with improved shadows and borders
  - Font sizes scale appropriately (14-15px mobile, 16-17px desktop)

- **Responsive Design**:
  - Added responsive breakpoints (Mobile: <600px, Tablet: 600-1200px, Desktop: ≥1200px)
  - Adaptive padding and spacing based on screen size
  - Content max-width constraints for better readability on large screens
  - Photo upload buttons stack vertically on mobile, side-by-side on desktop
  - FilterChips and buttons adjust spacing and sizing responsively

- **Visual Enhancements**:
  - Improved input field borders with focus states
  - Enhanced button shadows and elevation
  - Better icon sizing (20-24px) for consistency
  - Consistent spacing using 8px grid system

- **Scrollbar Improvements**:
  - Hidden scrollbars across all screens for cleaner appearance
  - Scrolling functionality maintained without visual scrollbars
  - Applied to Report Hazard, Profile, Manage Stickers, Login, Signup, and Gate Pass screens

- **Icon Updates**:
  - **Location Icons**: Updated to use `Icons.navigation` for navigation mode and `Icons.gps_fixed` for location button
  - **Current Location Marker**: Changed to compass/navigation icon for better navigation context
  - **Search Results**: Updated to `Icons.place` for cleaner appearance
  - **HOA Gate Markers**: Changed to `Icons.security` for better representation of gates/security checkpoints

### Technical Implementation

- Added responsive helper methods to `AppTheme`:
  - `isMobile()`, `isTablet()`, `isDesktop()` - Screen size detection
  - `responsivePadding()` - Adaptive padding based on screen size
  - `responsiveButtonHeight()` - Adaptive button heights
  - `responsiveFontSize()` - Adaptive font sizing
  - `maxContentWidth()` - Content width constraints

- Wrapped all `SingleChildScrollView` widgets with `ScrollConfiguration` to hide scrollbars
- Updated button themes with larger minimum sizes and improved styling
- Enhanced input decoration themes with better borders and focus states

### Breaking Changes

- None (UI improvements only)

---

## Version 2.3.1 - Branding Update

**Release Date:** 2025  
**Focus:** Consistent Branding Across All Platforms

### Changes

- **App Name Standardization**: Updated all user-facing display names to "SmartRoad" (proper capitalization)
  - Web app title and manifest
  - Android app label
  - iOS display name and bundle name
  - Windows window title and product information
  - Linux window title
  - All platform-specific metadata

### Technical Notes

- Package names and bundle identifiers remain lowercase (`smartroad`, `com.example.smartroad`) per platform conventions
- Email addresses remain lowercase (`demo@smartroad.app`) per email format standards
- Binary/executable names remain lowercase for file system compatibility
- No breaking changes to package structure or identifiers

---

## Version 2.3.0 - Physical Sticker Upload & HOA Access Types

**Release Date:** 2025  
**Focus:** Enhanced Sticker Management & Access Control

### New Features

#### Physical Sticker Upload with AI Verification
- **My Stickers Screen**: New screen for managing all user stickers
  - View all stickers (physical and digital)
  - Upload physical stickers with photo verification
  - AI-powered verification using Google Gemini
  - Access from Profile screen → "My Stickers" card

- **AI Sticker Verification**:
  - Integration with Google Gemini 2.5 Flash model
  - Automatic verification of uploaded sticker photos
  - Validates if image contains a valid HOA sticker
  - Rejects blurry or invalid images
  - Free tier API usage

- **Physical Sticker Upload Flow**:
  - Select HOA from dropdown
  - Optional sticker number input
  - Photo upload (camera or gallery)
  - AI verification with loading state
  - Automatic save to database upon verification
  - Photo stored in Supabase Storage

- **Gate Pass Screen Updates**:
  - Different UI for physical vs digital stickers
  - Physical stickers: "Physical Sticker Verified - Present Vehicle for Inspection" card
  - No QR code generation for physical stickers
  - Displays uploaded sticker photo
  - Shows AI verification badge

#### HOA Access Types (Strict vs. Open)
- **Access Type System**:
  - `public_shortcut`: Outsiders can buy a pass (Pay-to-Pass available)
  - `residents_only`: Outsiders CANNOT buy a pass (Strict residents/guests only)

- **Visual Indicators on Map**:
  - **Red Gate Icon**: Strict HOA (Residents/Guests Only)
  - **Green Gate Icon**: Open HOA (Pay-to-Pass Available)
  - HOA gate markers displayed on map with color coding
  - Tap marker to see HOA name and access type

- **Routing Logic Updates**:
  - Hard Block: `residents_only` HOAs block routing if user has no sticker (Cost = Infinity)
  - Soft Block: `public_shortcut` HOAs allow routing if user agrees to buy pass
  - Routing service now receives HOA access type information
  - Backend can implement permission-based road weighting

### Database Changes

- **New Columns in `user_stickers` table**:
  - `is_physical_sticker` (boolean): True for uploads, False for in-app QR purchases
  - `verified_by_ai` (boolean): True if Gemini confirms the image looks like a sticker
  - `sticker_photo_url` (text): Path to the uploaded sticker image

- **New Enum and Column in `hoas` table**:
  - `hoa_access_type` enum: `'public_shortcut'` or `'residents_only'`
  - `access_type` column with default `'public_shortcut'`

- **RLS Policy Updates**:
  - Users can insert their own physical stickers (after AI verification)
  - Users can update their own physical stickers

### Technical Implementation

- **New Dependencies**:
  - `google_generative_ai` package removed (using direct HTTP API calls)
  - Using Dio for Gemini API communication

- **New Services**:
  - `StickerVerifierService`: AI-powered sticker image verification
  - Web-compatible image handling (Image.memory for web, Image.file for mobile)

- **New Screens**:
  - `ManageStickersScreen`: Complete sticker management interface

- **New Widgets**:
  - `HOAGateMarker`: Custom marker widget for HOA gates with color coding

- **Environment Configuration**:
  - Added `GEMINI_API_KEY` environment variable support

### Security Features

- AI verification prevents fake sticker uploads
- Physical stickers require photo verification
- RLS policies ensure users can only manage their own stickers
- Photo validation before database insertion

### UI/UX Improvements

- Web compatibility for image uploads
- Loading states during AI verification
- Clear error messages for rejected photos
- Visual distinction between physical and digital stickers
- Color-coded HOA gate markers for quick identification

---

## Version 2.2.1 - Bug Fixes & UI Improvements

**Release Date:** 2025  
**Focus:** UI Polish & Bug Fixes

### Bug Fixes

- **Profile Screen Error Fix**: Fixed CircleAvatar assertion error when profile photo is null
  - Conditional `onBackgroundImageError` callback (only when backgroundImage exists)
  - Improved error handling in profile provider
  - Added fallback demo user creation if initialization fails

- **Navigation Bar Fixes**:
  - Removed duplicate bottom toolbar from Map screen (was conflicting with MainNavigationScreen)
  - Fixed bottom overflow issues by optimizing navigation bar height and spacing
  - Reduced navigation bar height from 70px to 65px with optimized padding
  - Used `IntrinsicHeight` for better layout fitting

- **Search Bar UI Fix**:
  - Fixed border radius not being applied correctly
  - Wrapped search bar in `ClipRRect` to ensure smooth rounded corners
  - All TextField borders properly set to `InputBorder.none` to match container

- **Report Hazard Screen**:
  - Fixed capitalization of hazard types (Pothole, Flood, Accident, etc.)
  - Improved visual consistency

### Technical Improvements

- Enhanced debug logging in profile provider and SupabaseService
- Improved demo mode initialization checks
- Better error handling with graceful fallbacks
- Removed unused `_ToolbarButton` widget

---

## Version 2.2.0 - Sticker & Gate Security Module

**Release Date:** 2025  
**Focus:** Revenue Generation - Digital Sticker & Gate Management System

### New Features

#### Sticker & Gate Security Module
- **Digital Sticker Wallet**: Users can hold multiple HOA stickers (e.g., "BF Resort", "BF Homes")
  - Sticker model with expiry dates and validation
  - Support for multiple active stickers per user
  - Sticker status tracking (active, expired, days remaining)

- **Gate Pass Screen**: QR code generation for gate access
  - Dynamic QR code containing UserID + StickerID + Timestamp
  - Auto-refreshes every 4 minutes to prevent screenshot reuse
  - Security: QR codes expire after 5 minutes
  - Sticker selector dropdown for users with multiple stickers
  - Displays sticker details (issued date, expiry, days remaining)
  - Empty states for users with no stickers or expired stickers

- **Guard Scanner Mode**: Camera-based QR code validation
  - Real-time QR code scanning using mobile_scanner
  - Visual scanning overlay with corner indicators
  - Success/error feedback with full-screen overlays
  - Haptic feedback for scan results
  - Flash toggle for low-light conditions
  - Validates QR codes against database in real-time

- **Permission-Based Routing Preparation**
  - RoutingService now accepts `userStickerIds` parameter
  - Map screen passes active sticker IDs to routing service
  - Prepared for future GraphHopper integration
  - Will enable dynamic road weighting based on sticker permissions
  - Future: "If user has Sticker A, weight Road A as 0.0 (Passable)"

### Database Changes

- **New Tables**:
  - `hoas` - Homeowners Associations/Gates table
  - `user_stickers` - User sticker/permit records
  
- **Schema Updates**:
  - Added indexes for performance (user_id, hoa_id, expires_at, is_active)
  - Row Level Security (RLS) policies for data protection
  - Unique constraint for active stickers per user+HOA

### Technical Implementation

- **New Dependencies**:
  - `qr_flutter: ^4.1.0` - QR code generation
  - `mobile_scanner: ^5.2.3` - QR code scanning

- **New Services**:
  - `StickerService` - Handles all sticker and HOA database operations
  - Demo mode support for testing without database

- **New Providers**:
  - `stickerServiceProvider` - Service instance provider
  - `userStickersProvider` - All user stickers
  - `activeUserStickersProvider` - Only valid/active stickers
  - `userStickerIdsProvider` - List of active sticker IDs (for routing)
  - `hoasProvider` - All HOAs list

- **New Screens**:
  - `GatePassScreen` - User-facing QR code display
  - `GuardScannerScreen` - Guard-facing QR code scanner

- **UI Integration**:
  - Added "Gate Pass" card in Profile screen
  - Navigation to Gate Pass screen from profile

### Security Features

- QR codes include timestamp to prevent screenshot reuse
- QR codes expire after 5 minutes
- Auto-refresh every 4 minutes (before expiry)
- Database validation on every scan
- RLS policies ensure data privacy

### Architecture Notes

- **Service-Oriented Architecture**: Security module is cleanly separated from navigation core
- **Future-Ready**: Routing service prepared for permission-based routing
- **Modular Design**: Models, services, providers, and screens are independently maintainable
- **Demo Mode**: Full demo support for testing without database setup

---

## Version 2.1.0 - Routing & Map Enhancements

**Release Date:** 2025

### New Features

#### Login Screen Redesign
- **Two-Panel Layout**: Split-screen design with story panel on left and login card on right (desktop) or stacked (mobile)
- **Less AI-Generated Look**: Removed excessive gradients and animations, replaced with clean, professional design
- **Story Panel**: Features The Heedful branding, value propositions, and key statistics
- **Simplified Animations**: Subtle fade and slide transitions instead of complex animations

#### Map Screen Enhancements
- **Bottom Toolbar**: Added floating toolbar at bottom with quick access to:
  - Navigate (opens search/directions)
  - Report (hazard reporting)
  - Layers (map layer options)
  - Settings (app settings)
- **Improved Top Bar**: Enhanced search bar with better visual hierarchy
- **Location Accuracy**: Default location set to STI College Las Piñas (14.4244°N, 120.9883°E)
- **High-Accuracy Location**: Using `bestForNavigation` accuracy mode for precise location tracking

#### Routing Integration
- **Backend-Powered Routing**: Integrated with SmartRoad backend API for route calculation
- **MVP Routing**: Supports car and motorcycle modes with toll avoidance
- **Simplified UI**: Cleaner navigation options with clear mode selection

### Design System Additions
- **Spacing Constants**: Added spacing system (XS, SM, MD, LG, XL, XXL)
- **Border Radius Constants**: Added radius system (SM, MD, LG, XL, Full)
- **Shadow System**: Added shadow variants (Small, Medium, Large, Glow)
- **Info Color**: Added info color for informational messages
- **Border Color**: Added border color for consistent borders

---

## Version 2.0.0 - Premium Edition

**Release Date:** 2025

### Major Updates

#### Premium UI Enhancements
- Gradient buttons with glow effects
- Sophisticated screen entrance animations
- Haptic feedback integration
- Keyboard navigation support (Enter key)
- Enhanced transitions and micro-interactions

#### The Heedful Branding
- Brand badge on authentication screens
- Consistent brand presence throughout
- Premium aesthetic aligned with startup identity

#### UX Improvements
- Auto-focus on form fields
- Clear buttons in input fields
- Improved error handling with icons
- Floating snackbars with better styling

#### Enhanced Components
- Premium login/signup screens
- Animated logo and brand elements
- Gradient FABs
- Enhanced card designs

---

## Version 1.0.0 - Initial Release

**Release Date:** 2025

### Core Features

- **Authentication**: Email/password authentication via Supabase Auth
- **Interactive Map**: OpenStreetMap integration with real-time hazard markers
- **Hazard Reporting**: Report road hazards with type, severity, description, and photos
- **Feed View**: Reverse-chronological list of all reported hazards
- **User Profiles**: View and update profile information
- **Realtime Updates**: Live updates when hazards are added/updated/deleted
- **Offline Support**: Cache hazards locally for offline viewing
- **Local Notifications**: Get notified when hazards are created within 2km

### Initial Design System
- Dark-first theme
- Complete component library
- Comprehensive documentation

---

## Future Roadmap

### Planned Features

1. **Permission-Based Routing** (Phase 2)
   - GraphHopper integration with sticker-based road weighting
   - Dynamic route calculation based on user permissions
   - "If user has Sticker A, weight Road A as 0.0 (Passable)"

2. **HOA Admin Panel**
   - Allow HOAs to create and manage stickers
   - Sticker sales and payment integration
   - Analytics and reporting

3. **Weather Radar Integration**
   - Real-time weather data overlay on map
   - Weather-based routing suggestions

4. **AI Incident Prediction**
   - Machine learning for hazard prediction
   - Proactive route adjustments

5. **Ride-Hailing Integration**
   - Integration with ride-hailing services
   - Driver-passenger matching

---

## Migration Notes

### Upgrading to Version 2.3.1

1. **No Action Required**: This is a branding update only
   - App will display "SmartRoad" on all platforms
   - No database changes
   - No code changes required
   - Rebuild app to see updated branding

### Upgrading to Version 2.3.0

1. **Database Migration**:
   ```sql
   -- Run the updated supabase_schema.sql in Supabase SQL Editor
   -- This adds:
   -- 1. hoa_access_type enum
   -- 2. access_type column to hoas table
   -- 3. is_physical_sticker, verified_by_ai, sticker_photo_url columns to user_stickers table
   -- 4. New RLS policies for physical sticker uploads
   ```

2. **Environment Configuration**:
   ```bash
   # Add GEMINI_API_KEY to your environment
   --dart-define=GEMINI_API_KEY=your_gemini_api_key_here
   ```

3. **Dependencies**:
   ```bash
   flutter pub get
   ```

4. **Storage Bucket**:
   - Ensure Supabase storage bucket allows uploads for sticker images
   - Or create a new `stickers` folder in your existing bucket

### Upgrading to Version 2.2.1

1. **Dependencies**:
   ```bash
   flutter pub get
   ```

2. **No Database Changes Required**: This is a bug fix release

3. **UI Changes**:
   - Bottom toolbar removed from Map screen (now uses main navigation bar only)
   - Navigation bar height optimized to prevent overflow

### Upgrading to Version 2.2.0

1. **Database Migration**:
   ```sql
   -- Run the updated supabase_schema.sql in Supabase SQL Editor
   -- This adds hoas and user_stickers tables
   ```

2. **Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Permissions**:
   - Ensure camera permissions are granted for Guard Scanner
   - Update AndroidManifest.xml and Info.plist if needed

4. **Backend Update** (Optional):
   - Update Node.js backend to accept `user_sticker_ids` in `/route` endpoint
   - Currently prepared but not actively used

---

## Breaking Changes

### Version 2.3.1
- None (branding update only)

### Version 2.3.0
- None (additive changes only)
- Database migration required for new columns

### Version 2.2.1
- None (bug fixes only)

### Version 2.2.0
- None (additive changes only)

### Version 2.1.0
- None (additive changes only)

### Version 2.0.0
- None (additive changes only)

---

## Known Issues

- QR code scanning requires camera permissions (handled gracefully)
- Demo mode stickers are static (for testing only)
- Permission-based routing logic not yet implemented (structure prepared)
- AI verification requires GEMINI_API_KEY to be configured
- Physical sticker upload requires Supabase Storage bucket setup

---

## Contributors

- The Heedful Development Team

---

*This changelog is maintained alongside the project and updated with each release.*

