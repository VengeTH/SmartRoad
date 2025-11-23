# smartroad

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

## Prerequisites

- Flutter SDK 3.7+ (with Dart 3.x)
- Android Studio / Xcode (for mobile development)
- Supabase account and project
- PostGIS extension enabled in Supabase

## Setup Instructions

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd smartroad
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
4. Create Storage Bucket:
   - Go to Storage in Supabase dashboard
   - Create a new bucket named `hazard-images`
   - Set it to Public
   - Configure allowed MIME types: `image/jpeg`, `image/png`, `image/webp`
   - Set file size limit to 5MB

### 3. Environment Configuration

Create a `.env` file in the project root (or use `--dart-define` flags):

```bash
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
STORAGE_BUCKET_NAME=hazard-images
```

**For Flutter, use `--dart-define` flags instead:**

```bash
flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
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
│   └── report/          # Report hazard screen
├── services/            # Business logic services
│   ├── supabase_service.dart
│   ├── location_service.dart
│   ├── notification_service.dart
│   └── offline_cache_service.dart
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

## Demo Script (30-60 seconds)

1. **Login**: Use demo account or create new account
2. **View Map**: See hazards on map, tap markers for details
3. **Report Hazard**: Tap "Report Hazard" button, fill form, submit
4. **View Feed**: Switch to Feed tab, see all hazards
5. **Profile**: View profile, update name/photo
6. **Realtime**: Open app on two devices, report on one, see update on other

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
