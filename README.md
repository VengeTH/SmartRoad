# SmartRoad

A Flutter mobile application for reporting and viewing road hazards in real-time, built with Supabase backend.

## Features

- **Authentication**: Email/password authentication via Supabase Auth
- **Interactive Map**: OpenStreetMap integration with real-time hazard markers
- **Hazard Reporting**: Report road hazards with type, severity, description, and photos
- **Feed View**: Reverse-chronological list of all reported hazards
- **User Profiles**: View and update profile information
- **Realtime Updates**: Live updates when hazards are added/updated/deleted
- **Offline Support**: Cache hazards locally for offline viewing
- **Local Notifications**: Get notified when hazards are created within 2km
- **Sticker & Gate Security**: Digital and physical HOA sticker management
  - Digital sticker wallet with QR code gate passes
  - Physical sticker upload with AI verification (Google Gemini)
  - Guard scanner for QR code validation
  - HOA access type system (Strict vs. Open gates)
  - Color-coded gate markers on map (Red = Strict, Green = Open)
- **Responsive Design**: Optimized for all screen sizes
  - Mobile-first design with adaptive layouts
  - Larger touch targets for better usability
  - Responsive padding and spacing
  - Content width constraints for desktop
- **Modern UI/UX**: Enhanced visual design
  - Improved button sizes and styling
  - Better input field design with focus states
  - Hidden scrollbars for cleaner appearance
  - Updated icons for better navigation context

## Prerequisites

- Flutter SDK 3.7+ (with Dart 3.x)
- Android Studio / Xcode (for mobile development)
- Supabase account and project
- PostGIS extension enabled in Supabase

## Setup Instructions

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd SmartRoad
flutter pub get
```

### 2. Supabase Setup

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

### 3. Environment Configuration

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

### 4. Android Configuration

Add location permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### 5. iOS Configuration

Add location permissions to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby hazards and allow you to report hazards.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to show nearby hazards and allow you to report hazards.</string>
```

### 6. Build and Run

```bash
# For Android
flutter run

# For iOS
flutter run

# Build APK
flutter build apk --debug
# or
flutter build apk --release
```

## Demo Account

For investor demos, use the pre-seeded demo account:
- Email: `demo@smartroad.app`
- Password: `DemoPass123!`

*Note: You need to create this user in Supabase Auth dashboard first.*

## Project Structure

```
lib/
├── core/
│   ├── config/          # Environment configuration
│   ├── constants/       # App constants
│   └── theme/           # App theme
├── models/              # Data models (Hazard, UserProfile)
├── providers/           # Riverpod state providers
├── screens/             # UI screens
│   ├── auth/           # Login, Signup
│   ├── map/            # Map screen
│   ├── feed/            # Feed screen
│   ├── profile/         # Profile screen
│   ├── report/          # Report hazard screen
│   ├── gate/            # Gate Pass, Guard Scanner
│   └── stickers/        # Manage Stickers screen
├── services/            # Business logic services
│   ├── supabase_service.dart
│   ├── location_service.dart
│   ├── notification_service.dart
│   ├── offline_cache_service.dart
│   ├── routing_service.dart
│   ├── sticker_service.dart
│   └── sticker_verifier_service.dart
└── widgets/             # Reusable widgets
```

## Key Dependencies

- `flutter_riverpod`: State management
- `supabase_flutter`: Backend integration
- `flutter_map`: Map display (OpenStreetMap)
- `geolocator`: Location services
- `image_picker`: Image selection
- `hive_flutter`: Offline caching
- `flutter_local_notifications`: Local notifications
- `qr_flutter`: QR code generation for gate passes
- `mobile_scanner`: QR code scanning for guard validation
- `dio`: HTTP client for API calls (including Gemini AI)

## Troubleshooting

### Location Permission Issues
- Ensure permissions are added to AndroidManifest.xml and Info.plist
- Check device location settings

### Supabase Connection Issues
- Verify SUPABASE_URL and SUPABASE_ANON_KEY are correct
- Check Supabase project status
- Verify RLS policies are set correctly

### Image Upload Issues
- Ensure storage bucket exists and is public
- Check file size limits
- Verify MIME type restrictions

### Sticker & Gate Features
- **Physical Sticker Upload**: Requires GEMINI_API_KEY for AI verification
- **Gate Markers**: Ensure HOAs have valid latitude/longitude coordinates
- **QR Code Scanning**: Requires camera permissions on device
- **AI Verification**: Check Gemini API key is valid and has quota remaining

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

## Demo Script (30-60 seconds)

1. **Login**: Use demo account or create new account
2. **View Map**: See hazards on map, tap markers for details
3. **Report Hazard**: Tap "Report Hazard" button, fill form, submit
4. **View Feed**: Switch to Feed tab, see all hazards
5. **Profile**: View profile, update name/photo
6. **Gate Pass**: View QR code for gate access (if you have stickers)
7. **My Stickers**: Manage stickers, upload physical stickers (requires GEMINI_API_KEY)
8. **HOA Gates**: See color-coded gate markers on map (Red = Strict, Green = Open)
9. **Realtime**: Open app on two devices, report on one, see update on other

## Production Notes

- Replace demo account with proper authentication flow
- Implement proper error handling and retry logic
- Add analytics and crash reporting
- Optimize map marker rendering for large datasets
- Implement proper image compression before upload
- Add rate limiting for hazard creation
- Implement proper offline queue for pending reports

## License

Copyright © 2025 The Heedful. All rights reserved.
