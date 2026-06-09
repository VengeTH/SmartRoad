# SmartRoad

A Flutter mobile application for reporting and viewing road hazards in real-time, powered by a self-hosted PostgreSQL backend and GraphHopper routing engine. Features comprehensive navigation with multiple vehicle types, location search, and real-time hazard tracking.

## Project Structure

```
smartroad/
├── mobile/                 # Flutter app (current location - root level)
│   └── smartroad_flutter/  # TODO: Move Flutter app here for proper monorepo structure
├── backend/                # Backend services
│   ├── graphhopper/        # Self-hosted routing engine (Docker)
│   ├── api/                # SmartRoad API (placeholder - future)
│   └── docker-compose.yml  # Unified backend orchestration
├── docs/                   # Documentation
└── README.md
```

**Note:** The Flutter app currently resides at the root level. For proper monorepo structure, it should be moved to `mobile/smartroad_flutter/` (see migration guide below).

## ⚠️ Current Status: Demo Mode Only

**Important:** As of now, SmartRoad is running in **demo mode only**. No database has been set up on the server yet, and backend API integration has not been implemented. All features work with local/demo data.

**Database integration will be added in the future** after the backend API (Phase 5) is built. Until then, the app operates completely offline with sample data, making it perfect for testing and demos.

**What this means:**
- All user data (profiles, hazards, routes, place photos/comments/ratings) is stored locally or uses demo data
- No persistent storage across devices
- No real-time sync between users
- The `DatabaseService` is ready to connect to the backend API when deployed
- Full functionality available for testing without backend setup

## Features

### Core Features
- **Authentication (Optional)**: Email/password authentication via Supabase Auth with demo mode support
- **Guest Mode**: Use SmartRoad without logging in (navigation + map browsing)
- **Interactive Map**: OpenStreetMap integration with real-time hazard markers

- **Bottom Sheet UX Improvements**: Place and fuel detail sheets are more expandable (initial ~45% → max ~95%), include a visible drag handle, and support desktop drag-to-resize and an expand/collapse control; recently searched places show a "Recently searched" badge when applicable.
- **Demo-mode Authentication Semantics**: Demo sessions act as authenticated demo users by default (allowing in-app contributions in demo storage). To test limited/anonymous flows, choose **Continue as Guest** at login.
- **Hazard Reporting**: Report road hazards with type, severity, description, and photos (requires login)
- **Feed View**: Reverse-chronological list of all reported hazards
- **User Profiles**: View and update profile information
- **Realtime Updates**: Live updates when hazards are added/updated/deleted
- **Offline Support**: Cache hazards locally for offline viewing
- **Local Notifications**: Get notified when hazards are created within 2km

### Navigation & Routing
- **Multi-Vehicle Routing**: Support for 5 vehicle types:
  - Big Bike (400cc+) - High displacement motorcycles, tolls optional
  - Motorcycle (≤399cc) - Standard motorcycles, avoids tolls
  - Car (Private) - Private vehicles, tolls optional
  - Truck - Commercial vehicles
  - Pedestrian - Walking routes
- **Permission-Based Routing (MVP)**:
  - Roads can be tagged as restricted/private (HOA roads)
  - Users with stickers can access restricted roads
  - Users without stickers are routed around private areas
  - Route preview shows blocked shortcut suggestions with time savings
  - Sticker application CTA (payment integration planned)
- **GraphHopper Integration**: Self-hosted routing engine with Philippines OSM data
- **Location Search**: OpenStreetMap Nominatim API integration for geocoding
  - **Route Distance Display**: Search results show route-based distances on the right side
  - **Real-time Calculation**: Distances calculated using actual route (GraphHopper) with fallback to straight-line distance
  - **Instant Display**: Fallback distance shows immediately while route calculation completes in background
  - **Auto-update**: Distance updates from fallback to actual route distance when calculation completes
- **Real-time Navigation**:
  - Live location updates during navigation (1m accuracy)
  - Off-route detection and automatic rerouting
  - Route progress tracking (traveled vs upcoming segments)
  - Visual route display with color-coded segments
  - Route preview sheet before navigation starts
- **Speed HUD + Speed Limits**:
  - Shows current speed (km/h) while navigating
  - Best-effort speed limit sign (OSM Overpass + defaults)
  - Overspeed warnings (tolerance configurable)
- **Customizable Navigation Avatar**:
  - Choose arrow/car/motorcycle/etc. icon for the user marker
- **Location Options**: Long-press map to pin location with options (Get Directions, Save, Share, View on Map)

### Music Control
- **Floating Mini-Player**: Control music without leaving navigation; shows track, artist, and album art when playing
- **Universal Support**: Works with Spotify, YouTube Music, and other supported apps (Android media session)
- **Open Music When Idle**: When no music is playing, the map chip shows "No music playing" or "Open {AppName}" if a default is set
  - **Tap**: Opens the default music app (if set) or an **installed music app picker**
  - **Long-press**: Always opens the music app picker to choose or switch app
- **Default Music App**: Set and change your preferred app in **Profile → Music Controls → Default music app** (Change / Clear)
- **Music App Picker**: Bottom sheet listing only **installed** supported apps (Spotify, YouTube Music, YouTube, Apple Music, SoundCloud, Deezer, Amazon Music, Samsung Music, VLC) with "Remember as default" option
- **Deep Links**: Other apps can open SmartRoad via `smartroad://map` or `smartroad://music`; supports "apps open SmartRoad" integration
- **Smart UI**: Expands for play/pause/skip when media is active; collapses to save space

### Commute Mode V2 (Security & Convenience)
- **Smart Alarms**: Speed-adaptive wake-up alerts for accurate arrival
- **Multi-Stage Alarm**: Progressive wake-up (Vibrate -> Sound -> Alarm)
- **Safety System**: Off-route detection with auto-SMS, grace period, and night mode
- **Manual SOS**: Immediate emergency alert button
- **Low Power**: Battery saver mode for long commutes
- **Overshoot Recovery**: Bilingual guidance when passing destination
- **Smart ETA (v2.8.0)**:
  - Vehicle type selection (Jeepney, Bus, Car, Motorcycle, Tricycle, Walking) with realistic base/max speeds
  - Rain-aware ETA: light rain ×0.85, heavy rain ×0.70; sunny/cloudy/heat have no impact
  - Traffic light estimation via OSM Overpass API (~30s per signal added to ETA)
  - Active commute chip shows vehicle type, weather, and 🚦 traffic light count

### Map Features
- **Hazard Filtering**: Filter by type, severity, and expiry status
- **Search Bar**: Location search with autocomplete and debouncing
  - **Smart Country-Prioritized Search**:
    - Prioritizes search results from user's current country (e.g., Philippines)
    - Also searches globally but only shows main cities (cities, towns, municipalities) from other countries
    - Prevents showing random streets or small places from other countries
    - Works globally: if user is in Japan, prioritizes Japan; if in Europe, prioritizes Europe
  - **Dynamic Country Detection**: Detects country code from current location using reverse geocoding
  - **Distance Indicators**: Each search result displays route distance on the right side
  - **Loading State**: Small spinner appears next to distance while route is being calculated
  - **Fallback Distance**: Straight-line distance shown immediately, replaced by route distance when available
- **Ambient Landmarks**:
  - Dynamically shows POIs (restaurants, schools, fuel, etc.) based on zoom level
  - Powered by **OpenStreetMap Overpass API** for reliable landmark data
  - Rich icons and color-coding for 20+ categories (Hospital, Bank, Mall, etc.)
  - Optimized for performance with zoom-tiered loading (major landmarks at low zoom, fine detail at high zoom)
- **Community Fuel Pricing (Beta)**:
  - Fuel POIs open a dedicated fuel station sheet
  - Multi-fuel submissions in one action (`91`, `95`, `97`, `diesel`)
  - Distance/photo rules for submissions:
    - `<= 50m`: no photo required
    - `50m-200m`: photo required
    - `> 200m`: submission rejected
  - Long-press map supports `Add Fuel Station`
  - Admin review tools for pending stations and incorrect price reports
- **Current Location**: Real-time location tracking with platform-specific optimizations. GPS timeout increased to 15s for reliable lock on real devices.
- **Map Controls**: Zoom in/out, center on location, filter panel, weather layers, and fuel prices — all as **circular** floating buttons for a modern look.
  - **Zoom Limits**: Restricted to Philippines area (minZoom: 6.8, maxZoom: 18.0)
  - **Geographic Bounds**: Map panning restricted to Philippines boundaries
  - **Continuous Enforcement**: Zoom and bounds limits enforced automatically
  - **Smart Center Button**: First press centers; subsequent presses cycle zoom in/out
  - **Speed-Based Auto-Zoom**: Zoom adjusts dynamically to vehicle speed during navigation
  - **Independent Button Groups**: Each button group (Zoom, Weather, Fuel, Location) is independently anchored so panels never overlap other controls
  - **No gray flashing**: Map background set to OSM tile beige `#F2EFE9` and tiles pre-cached with `keepBuffer:5`
- **HOA Gate Markers**: Color-coded gate markers (Red = Strict, Green = Open)

### Place Previews (Known Places + Community)
- **Known place markers** (starting set includes VTX, Festival Mall Alabang, SM City San Pablo)
- **Place preview sheet** with:
  - Approved photos (with admin moderation workflow)
  - Likes + comments
  - Ratings (1–5 stars)
- **Weather Tile Layers**:
  - Real-time weather visualization as map tile overlays
  - Three weather layers: Rain (precipitation), Heat (temperature), Clouds (cloud coverage)
  - Toggleable layers with opacity control (heat layer capped at 50% for better accuracy perception)
  - Smooth, curved rendering - no square tile artifacts
  - Works at all zoom levels (2-18)
  - Real-time data from OpenWeatherMap API
  - Works on mobile/desktop natively
  - **Web Support**: Requires API key via `--dart-define` or backend proxy (see Weather Layers Setup below)
  - Uses OpenWeatherMap tile service for all layers
  - ⚠️ Visual only - no rerouting based on weather yet
- **Live Traffic Layer**:
  - Real-time traffic flow visualization using TomTom Traffic Flow API
  - Toggleable traffic overlay in map filter panel
  - Color-coded traffic conditions:
    - 🟢 Green: Free flow (fast)
    - 🟡 Yellow: Moderate traffic
    - 🔴 Red: Heavy traffic / Slow
    - ⚫ Dark red: Very slow / Standstill
  - Transparent PNG overlay that doesn't obstruct map visibility
  - **API Key Required**: Set `TOMTOM_API_KEY` in `.env` file (see Environment Setup)
  - Free tier: 2,500 requests/day
  - ⚠️ Visual only - no rerouting based on traffic yet

### Sticker & Gate Security
- **Digital Sticker Wallet**: Users can hold multiple HOA stickers
- **Physical Sticker Upload**: AI-powered verification using Google Gemini
- **Gate Pass Screen**: QR code generation for gate access (auto-refreshes every 4 minutes)
- **Guard Scanner**: Camera-based QR code validation for guards
- **HOA Access Types**: Strict (residents only) vs Open (pay-to-pass available)
- **Color-coded Gate Markers**: Visual indicators on map for gate access types

### Demo Mode (Current Default)
- **Full Functionality Without Database**: App works completely offline with demo data
- **Demo Account**: Pre-configured demo credentials for testing
- **Sample Data**: Demo stickers, HOAs, and hazards for testing
- **No Setup Required**: Perfect for quick demos and testing
- **⚠️ Note**: Currently, SmartRoad runs exclusively in demo mode. Database integration will be implemented in the future after server setup is complete.

### Guest vs Logged-in Capabilities
- **Available without login**:
  - Browse map, search locations, get directions, and navigate
  - View hazards and hazard details (including comments)
  - View known places / POIs and place previews (approved photos, comments, rating averages)
  - Customize navigation avatar + speed HUD preferences (local settings)
- **Requires login**:
  - Report hazards
  - Comment / like / rate places
  - Upload place photos (moderated)
  - Save routes

### Platform Support
- **Mobile**: Android and iOS with native location services
- **Web**: Full web support with platform-specific location handling
- **Responsive Design**: Optimized for all screen sizes (mobile, tablet, desktop)

### Branding & Identity
- **App Name**: SmartRoad
- **Company**: The Heedful
- **Motto**: "Be Heedful on the Road"
- **Secondary Line**: "Smart navigation for real road conditions"
- **Splash Screen**: Minimal branding on app launch (2-3 seconds)
- **About Screen**: Complete app information accessible from Profile
- **Demo Mode Screen**: Branding displayed on login screen
- **Footer Branding**: Subtle, non-intrusive branding in settings/profile
- **Safety-First**: No branding on navigation screens or during active navigation

## Prerequisites

### Mobile Development
- Flutter SDK 3.7+ (with Dart 3.x)
- Android Studio / Xcode (for mobile development)
- Supabase account and project (optional - demo mode available)

### Backend Services (Optional for MVP)
- Docker and Docker Compose
- 4GB+ RAM available for Docker
- 10GB+ free disk space (for GraphHopper OSM data)

### Optional Services
- **GraphHopper**: Required for routing features (can run without for basic map)
- **Supabase**: Required for production, optional for demo mode
- **Google Gemini API**: Required for physical sticker AI verification
- **OpenWeatherMap API**: Required for weather layers (free tier available)
- **TomTom Traffic API**: Required for live traffic layer (free tier: 2,500 requests/day)
- **Weather Proxy Server**: Required for weather layers on web (optional, see setup below)

## Setup Instructions

### 1. Clone Repository

```bash
git clone <repository-url>
cd SmartRoad
```

### 2. Backend Setup (Optional for MVP)

**GraphHopper Routing Engine:**

```bash
cd backend
docker-compose up -d graphhopper
```

**First run:** GraphHopper will download and process Philippines OSM data (30-60 minutes). Subsequent runs use cached data (~1-2 minutes).

**Documentation:** See [backend/README.md](./backend/README.md) and [backend/graphhopper/README.md](./backend/graphhopper/README.md)

**Note:** For MVP, the Flutter app can work without GraphHopper (uses Supabase only). GraphHopper is required for routing features.

### 3. Flutter App Setup

```bash
# Install dependencies
flutter pub get
```

### 4. Supabase Setup (Future - Currently Not Required)

**⚠️ Note:** Database integration is not yet implemented. The app currently runs in demo mode only. The following setup instructions are for **future reference** when database integration is added.

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Enable PostGIS extension in your Supabase project:
   - Go to Database → Extensions
   - Enable `postgis` extension
3. Run the SQL schema script:
   - Go to SQL Editor in Supabase dashboard
   - Copy and paste the contents of `supabase_schema.sql`
   - Execute the script
   - Then run `supabase_places_schema.sql` to enable place previews (comments/likes/photos/ratings)
  - Then run `supabase_fuel_schema.sql` to enable fuel stations/prices/reports/admin RPCs
4. Create Storage Buckets:
   - Go to Storage in Supabase dashboard
   - Create a bucket named `hazard-images` (for hazard photos)
     - Set it to Public
     - Configure allowed MIME types: `image/jpeg`, `image/png`, `image/webp`
     - Set file size limit to 5MB
   - Create a bucket or folder for `stickers` (for physical sticker photos)
     - Same configuration as hazard-images
   - Create `fuel-proofs` bucket (for fuel price proof photos)
   - Create `fuel-stations` bucket (for station submission photos)

**Current Status:** The app automatically uses **Demo Mode** with sample data. No database setup is required at this time.

### 5. Weather Layers Setup

Weather layers work natively on mobile/desktop. On web, you need either an OpenWeatherMap API key or a backend proxy.

**Option 1: OpenWeatherMap API Key (Recommended for Web)**

1. **Get a free API key** from [OpenWeatherMap](https://openweathermap.org/api)
   - Free tier: 1,000 calls/day, 60 calls/minute

2. **Set up API key using one of these methods:**

   **Method A: Using `.env` file (Easiest)**
   ```bash
   # Create .env file in project root
   OPENWEATHERMAP_API_KEY=your_api_key_here
   ```

   Then run:
   - Windows: `run.bat`
   - Linux/Mac: `./run-with-env.sh`

   **Method B: Using `--dart-define`**
   ```bash
   flutter run --dart-define=OPENWEATHERMAP_API_KEY=your_api_key_here
   ```

   **Method C: Configure in Android Studio**
   - Run → Edit Configurations...
   - Additional run args: `--dart-define=OPENWEATHERMAP_API_KEY=your_api_key_here`

**Option 2: Backend Proxy (Alternative for Web)**

If you prefer using a backend proxy instead of direct API access:

1. **Upload setup script to your server:**
   ```bash
   scp setup-proxy.sh username@your-server-ip:~/
   ```

2. **SSH into your server and run:**
   ```bash
   ssh username@your-server-ip
   chmod +x setup-proxy.sh
   ./setup-proxy.sh
   ```

3. **Copy the proxy URL shown** (e.g., `http://192.168.1.100:3000`)

4. **Run Flutter with proxy URL:**
   ```bash
   flutter run --dart-define=WEATHER_PROXY_URL=http://YOUR-SERVER-IP:3000
   ```

**For detailed instructions**, see:
- `OPENWEATHERMAP_SETUP.md` - OpenWeatherMap API key setup
- `ENV_SETUP.md` - Environment variable configuration
- `SELF_HOSTED_SETUP.md` - Backend proxy setup guide
- `WEATHER_LAYERS_TROUBLESHOOTING.md` - Troubleshooting guide

**Note:** Weather layers are automatically disabled on web if neither API key nor proxy is configured (no errors, graceful fallback).

### 6. Environment Configuration

Create a `.env` file in the project root (see `.env.example` for template):

```bash
# Supabase (Optional - Demo mode available)
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
STORAGE_BUCKET_NAME=hazard-images

# Google Gemini (Required for physical sticker AI verification)
GEMINI_API_KEY=your_gemini_api_key

# Weather Layers (Required for web, optional for mobile/desktop)
OPENWEATHERMAP_API_KEY=your_openweathermap_api_key  # Get from https://openweathermap.org/api
WEATHER_PROXY_URL=http://your-server-ip:3000  # Alternative: Backend proxy URL
```

**Running with `.env` file:**

- **Windows:** Use `run.bat` (automatically loads `.env` and runs Flutter)
- **Linux/Mac:** Use `./run-with-env.sh` (automatically loads `.env` and runs Flutter)

**Or use `--dart-define` flags directly:**

```bash
flutter run \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_key \
  --dart-define=GEMINI_API_KEY=your_gemini_key \
  --dart-define=OPENWEATHERMAP_API_KEY=your_openweathermap_key \
  --dart-define=WEATHER_PROXY_URL=http://your-server-ip:3000
```

**See `ENV_SETUP.md` for detailed instructions on environment variable configuration.**

**Demo Mode:** If environment variables are not set, the app automatically runs in demo mode with sample data.

### 7. Android Configuration

Add location permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/> <!-- For QR scanning -->
```

### 8. iOS Configuration

Add location permissions to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby hazards and allow you to report hazards.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to show nearby hazards and allow you to report hazards.</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes</string>
```

### 9. Build and Run

```bash
# For Android
flutter run

# For iOS
flutter run

# For Web
flutter run -d chrome

# Build APK
flutter build apk --debug
# or
flutter build apk --release
```

## Demo Mode

SmartRoad includes a comprehensive **Demo Mode** that works without any database setup:

### Features Available in Demo Mode
- ✅ Full map functionality with demo hazards
- ✅ Location search and routing (requires GraphHopper)
- ✅ Hazard reporting (stored locally)
- ✅ Gate Pass with demo stickers
- ✅ Guard Scanner with demo QR codes
- ✅ HOA gate markers on map
- ✅ Profile management
- ✅ All UI features

### Demo Account
- **Email**: `demo@smartroad.app`
- **Password**: `DemoPass123!`

**Note:** In demo mode, you can use any credentials - the app will automatically authenticate with demo data.

### Demo Data
- **Stickers**: BF Resort, BF Homes (with expiry dates)
- **HOAs**: Sample HOAs with different access types
- **Hazards**: Sample hazards for testing

## Project Structure

```
lib/
├── core/
│   ├── config/          # Environment configuration
│   ├── constants/       # App constants
│   └── theme/           # App theme
├── models/              # Data models (Hazard, UserProfile, Sticker, MusicAppDescriptor)
├── providers/           # Riverpod state providers
│   ├── auth_provider.dart
│   ├── hazards_provider.dart
│   ├── location_provider.dart
│   ├── map_filter_provider.dart
│   └── sticker_provider.dart
├── screens/             # UI screens
│   ├── auth/           # Login, Signup
│   ├── splash/          # Splash screen with branding
│   ├── about/           # About SmartRoad screen
│   ├── map/            # Map screen with routing
│   ├── feed/            # Feed screen
│   ├── profile/         # Profile screen
│   ├── report/          # Report hazard screen
│   ├── gate/            # Gate Pass, Guard Scanner
│   └── stickers/        # Manage Stickers screen
├── services/            # Business logic services
│   ├── supabase_service.dart
│   ├── location_service.dart
│   ├── location_search_service.dart
│   ├── routing_service.dart
│   ├── notification_service.dart
│   ├── offline_cache_service.dart
│   ├── sticker_service.dart
│   ├── sticker_verifier_service.dart
│   ├── weather_service.dart
│   ├── weather_layer_manager.dart
│   ├── weather_tile_generator.dart
│   ├── rainviewer_service.dart
│   ├── music_control_service.dart
│   ├── music_app_launcher_service.dart
│   └── deep_link_service.dart
└── widgets/             # Reusable widgets
    ├── hazard_marker.dart
    ├── hazard_detail_sheet.dart
    ├── hoa_gate_marker.dart
    ├── distance_indicator_widget.dart
    ├── weather_layer_controls.dart
    ├── weather_tile_layers.dart
    ├── music_control_widget.dart
    ├── music_control_settings_card.dart
    └── music_app_picker_sheet.dart
```

## Key Dependencies

- `flutter_riverpod`: State management
- `supabase_flutter`: Backend integration
- `flutter_map`: Map display (OpenStreetMap)
- `geolocator`: Location services
- `http`: HTTP client (Nominatim API, GraphHopper)
- `dio`: HTTP client for API calls (including Gemini AI)
- `image_picker`: Image selection
- `hive_flutter`: Offline caching
- `flutter_local_notifications`: Local notifications
- `qr_flutter`: QR code generation for gate passes
- `mobile_scanner`: QR code scanning for guard validation
- `permission_handler`: Location and camera permissions
- `flutter_media_controller`: Media session control (Android)
- `app_links`: Deep link handling (`smartroad://` schemes)
- `android_intent_plus`: Launch installed music apps (Android)
- `url_launcher`: SMS, URLs, and fallbacks

## Troubleshooting

### Weather Layer Issues
- **Web**: Weather layers require OpenWeatherMap API key or backend proxy (see Weather Layers Setup above)
- **Mobile/Desktop**: Weather layers work natively with OpenWeatherMap API key
- **CORS Errors**: Set up backend proxy for web support
- **Rate Limiting**: Backend proxy includes caching to reduce API calls
- **See**: `WEATHER_LAYERS_TROUBLESHOOTING.md` for detailed troubleshooting

### Traffic Layer Issues
- **400 Errors**: Ensure `TOMTOM_API_KEY` is set correctly in `.env` file
- **No Traffic Display**: Check that Traffic API service is enabled for your TomTom API key
- **API Key**: Get free API key from https://developer.tomtom.com/ (2,500 requests/day free tier)
- **Coordinate Errors**: Ensure coordinates are integers (z, x, y) - automatically handled in code
- **URL Format**: Must use `/tile/flow/relative/{z}/{x}/{y}.png` format (already implemented)
- **See**: `ENV_SETUP.md` for API key configuration instructions

### Location Permission Issues
- Ensure permissions are added to AndroidManifest.xml and Info.plist
- Check device location settings
- On web, ensure HTTPS (required for location API)
- Web may need longer timeout (15 seconds vs 5 seconds on mobile)

### Supabase Connection Issues
- Verify SUPABASE_URL and SUPABASE_ANON_KEY are correct
- Check Supabase project status
- Verify RLS policies are set correctly
- **Note:** App works in demo mode without Supabase

### GraphHopper Connection Issues
- Ensure GraphHopper is running: `docker-compose ps`
- Check GraphHopper logs: `docker-compose logs graphhopper`
- Verify port 8989 is not blocked
- **Note:** Routing features require GraphHopper, but basic map works without it

### Image Upload Issues
- Ensure storage bucket exists and is public
- Check file size limits
- Verify MIME type restrictions

### Sticker & Gate Features
- **Physical Sticker Upload**: Requires GEMINI_API_KEY for AI verification
- **Gate Markers**: Ensure HOAs have valid latitude/longitude coordinates
- **QR Code Scanning**: Requires camera permissions on device
- **AI Verification**: Check Gemini API key is valid and has quota remaining

### Demo Mode Issues
- Demo mode activates automatically if Supabase is not configured
- Demo data is static (won't sync with database)
- Demo QR codes expire after 5 minutes (security feature)

## UI/UX Features

### Responsive Design
- **Mobile (< 600px)**: Optimized layouts with stacked buttons, reduced padding
- **Tablet (600-1200px)**: Balanced layouts with medium padding
- **Desktop (≥ 1200px)**: Max-width content constraints, generous padding

### Visual Improvements
- **Buttons**: Minimum 52-56px height for better touch targets
- **Inputs**: 20px vertical padding for improved usability
- **Icons**: Updated location icons (navigation compass for navigation mode)
- **Scrollbars**: Hidden for cleaner appearance while maintaining functionality

### Navigation Features
- **Search Bar**: Location search with autocomplete and debouncing
- **Filter Panel**: Slide-out panel for hazard filtering
- **Location Options**: Long-press map to show location options sheet
- **Route Selection**: Vehicle type selection with route preview
- **Navigation Overlay**: Real-time navigation with distance and duration
- **Distance Indicators**: Route-based distance tracking to destination, next turn, gate, and delivery entrance

## Demo Script (30-60 seconds)

1. **Login**: Use demo account or create new account (or use demo mode)
2. **View Map**: See hazards on map, tap markers for details
3. **Search Location**: Use search bar to find locations
   - Notice route distances displayed on the right side of each search result
   - Distance updates from fallback (straight-line) to actual route distance when calculation completes
4. **Get Directions**: Long-press map or select from search, choose vehicle type
5. **Route Preview**: View route preview sheet with distance, duration, and sticker suggestions (if shortcut blocked)
6. **Start Navigation**: Tap "Start Navigation" to begin real-time navigation
7. **Distance Indicators**: View remaining distance to destination, next turn, gate, and delivery entrance during navigation
8. **Weather Layers**: Toggle weather layers (Rain, Heat, Clouds) to see real-time weather conditions on map
   - Heat layer opacity is capped at 60% for better visibility
   - All layers use OpenWeatherMap tile service
9. **Traffic Layer**: Open map filter panel, toggle "Live Traffic" to see real-time traffic flow
   - Color-coded traffic conditions: Green (free flow), Yellow (moderate), Red (heavy), Dark red (standstill)
   - Transparent overlay that doesn't obstruct map visibility
   - Requires TOMTOM_API_KEY (see Environment Setup)
10. **Report Hazard**: Tap "Report Hazard" button, fill form, submit
11. **View Feed**: Switch to Feed tab, see all hazards
12. **Profile**: View profile, update name/photo
13. **Music Control**: When no music is playing, tap the music chip on the map to open the music app picker; choose an app (e.g. Spotify) and optionally set it as default; in Profile → Music Controls you can change or clear the default music app
14. **Gate Pass**: View QR code for gate access (if you have stickers)
15. **My Stickers**: Manage stickers, upload physical stickers (requires GEMINI_API_KEY)
16. **HOA Gates**: See color-coded gate markers on map (Red = Strict, Green = Open)
16. **Permission-Based Routing**: Test routing with/without stickers to see blocked shortcuts
17. **Realtime**: Open app on two devices, report on one, see update on other

## Production Notes

- Replace demo account with proper authentication flow
- Implement proper error handling and retry logic
- Add analytics and crash reporting
- Optimize map marker rendering for large datasets
- Implement proper image compression before upload
- Add rate limiting for hazard creation
- Implement proper offline queue for pending reports
- Configure GraphHopper for production (consider cloud deployment)
- Set up proper monitoring for GraphHopper service
- **Branding**: Follow DESIGN_GUIDE.md for branding guidelines. Ensure no branding appears on navigation screens.

## Post-MVP Features (Planned)

The following features are planned but not yet implemented:
- **Payment Integration**: GCash, PayMaya, Stripe for sticker purchases
- **Weather-Aware Rerouting**: Automatic route adjustments based on weather (ETA adjustment ✅ done; rerouting planned)
- **HOA Admin Dashboard**: Management interface for HOA administrators
- **Multi-Country Expansion**: Support for multiple countries beyond Philippines
- **PostGIS Route Intersection**: Full PostGIS-based route intersection checks for restricted areas
- **Push Notifications (FCM)**: Cloud-based push notifications
- **AI Incident Prediction**: Predictive analytics for road incidents
- **Traffic-Aware Rerouting**: Use TomTom traffic data to suggest alternate routes (visual layer ✅ done; rerouting planned)

## License

Copyright © 2025 The Heedful. All rights reserved.
