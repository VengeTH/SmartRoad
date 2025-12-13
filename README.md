# SmartRoad

A Flutter mobile application for reporting and viewing road hazards in real-time, built with Supabase backend and self-hosted GraphHopper routing engine. Features comprehensive navigation with multiple vehicle types, location search, and real-time hazard tracking.

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

## Features

### Core Features
- **Authentication**: Email/password authentication via Supabase Auth with demo mode support
- **Interactive Map**: OpenStreetMap integration with real-time hazard markers
- **Hazard Reporting**: Report road hazards with type, severity, description, and photos
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
- **GraphHopper Integration**: Self-hosted routing engine with Philippines OSM data
- **Location Search**: OpenStreetMap Nominatim API integration for geocoding
- **Real-time Navigation**: 
  - Live location updates during navigation (1m accuracy)
  - Off-route detection and automatic rerouting
  - Route progress tracking (traveled vs upcoming segments)
  - Visual route display with color-coded segments
- **Location Options**: Long-press map to pin location with options (Get Directions, Save, Share, View on Map)

### Map Features
- **Hazard Filtering**: Filter by type, severity, and expiry status
- **Search Bar**: Location search with autocomplete and debouncing
- **Current Location**: Real-time location tracking with platform-specific optimizations
- **Map Controls**: Zoom in/out, center on location, filter panel
- **HOA Gate Markers**: Color-coded gate markers (Red = Strict, Green = Open)

### Sticker & Gate Security
- **Digital Sticker Wallet**: Users can hold multiple HOA stickers
- **Physical Sticker Upload**: AI-powered verification using Google Gemini
- **Gate Pass Screen**: QR code generation for gate access (auto-refreshes every 4 minutes)
- **Guard Scanner**: Camera-based QR code validation for guards
- **HOA Access Types**: Strict (residents only) vs Open (pay-to-pass available)
- **Color-coded Gate Markers**: Visual indicators on map for gate access types

### Demo Mode
- **Full Functionality Without Database**: App works completely offline with demo data
- **Demo Account**: Pre-configured demo credentials for testing
- **Sample Data**: Demo stickers, HOAs, and hazards for testing
- **No Setup Required**: Perfect for quick demos and testing

### Platform Support
- **Mobile**: Android and iOS with native location services
- **Web**: Full web support with platform-specific location handling
- **Responsive Design**: Optimized for all screen sizes (mobile, tablet, desktop)

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

### 4. Supabase Setup (Optional - Demo Mode Available)

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Enable PostGIS extension in your Supabase project:
   - Go to Database → Extensions
   - Enable `postgis` extension
3. Run the SQL schema script:
   - Go to SQL Editor in Supabase dashboard
   - Copy and paste the contents of `supabase_schema.sql`
   - Execute the script
4. Create Storage Buckets:
   - Go to Storage in Supabase dashboard
   - Create a bucket named `hazard-images` (for hazard photos)
     - Set it to Public
     - Configure allowed MIME types: `image/jpeg`, `image/png`, `image/webp`
     - Set file size limit to 5MB
   - Create a bucket or folder for `stickers` (for physical sticker photos)
     - Same configuration as hazard-images

**Note:** If Supabase is not configured, the app will automatically use **Demo Mode** with sample data.

### 5. Environment Configuration

Create a `.env` file in the project root (or use `--dart-define` flags):

```bash
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
STORAGE_BUCKET_NAME=hazard-images
GEMINI_API_KEY=your_gemini_api_key  # Required for physical sticker AI verification
```

**For Flutter, use `--dart-define` flags instead:**

```bash
flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key --dart-define=GEMINI_API_KEY=your_gemini_key
```

Or create a script to run with environment variables (see `.env.example` for reference).

**Demo Mode:** If environment variables are not set, the app automatically runs in demo mode with sample data.

### 6. Android Configuration

Add location permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/> <!-- For QR scanning -->
```

### 7. iOS Configuration

Add location permissions to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby hazards and allow you to report hazards.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to show nearby hazards and allow you to report hazards.</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes</string>
```

### 8. Build and Run

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
├── models/              # Data models (Hazard, UserProfile, Sticker)
├── providers/           # Riverpod state providers
│   ├── auth_provider.dart
│   ├── hazards_provider.dart
│   ├── location_provider.dart
│   ├── map_filter_provider.dart
│   └── sticker_provider.dart
├── screens/             # UI screens
│   ├── auth/           # Login, Signup
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
│   └── sticker_verifier_service.dart
└── widgets/             # Reusable widgets
    ├── hazard_marker.dart
    ├── hazard_detail_sheet.dart
    └── hoa_gate_marker.dart
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

## Troubleshooting

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

## Demo Script (30-60 seconds)

1. **Login**: Use demo account or create new account (or use demo mode)
2. **View Map**: See hazards on map, tap markers for details
3. **Search Location**: Use search bar to find locations
4. **Get Directions**: Long-press map or select from search, choose vehicle type, view route
5. **Start Navigation**: Tap "Start Navigation" to begin real-time navigation
6. **Report Hazard**: Tap "Report Hazard" button, fill form, submit
7. **View Feed**: Switch to Feed tab, see all hazards
8. **Profile**: View profile, update name/photo
9. **Gate Pass**: View QR code for gate access (if you have stickers)
10. **My Stickers**: Manage stickers, upload physical stickers (requires GEMINI_API_KEY)
11. **HOA Gates**: See color-coded gate markers on map (Red = Strict, Green = Open)
12. **Realtime**: Open app on two devices, report on one, see update on other

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

## License

Copyright © 2025 The Heedful. All rights reserved.
