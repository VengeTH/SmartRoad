# SmartRoad MVP

The flagship project of The Heedful - A real-time hazard reporting system using Flutter, Supabase, and OpenStreetMap.

## 🚀 Features

- **Real-Time Map**: View hazards on an interactive map with OpenStreetMap tiles
- **Hazard Reporting**: Report potholes, floods, accidents, closures, roadblocks, and landslides
- **Community Feed**: Browse latest hazard reports from the community
- **User Authentication**: Sign up and sign in with email/password
- **Image Upload**: Attach photos to hazard reports
- **Realtime Updates**: See new hazards appear instantly on the map

## 📋 Prerequisites

- Flutter SDK (3.7.0 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Supabase account (free tier works)

## 🛠️ Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd SmartRoad
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Set Up Supabase

1. Create a new project at [Supabase](https://app.supabase.com)
2. Go to Project Settings > API
3. Copy your Project URL and anon/public key

### 4. Create Database Tables

Run these SQL commands in your Supabase SQL Editor:

```sql
-- Create users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  profile_image TEXT,
  reporter_level INTEGER DEFAULT 1
);

-- Create hazards table
CREATE TABLE hazards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  description TEXT NOT NULL,
  severity TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'active'
);

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE hazards ENABLE ROW LEVEL SECURITY;

-- Create policies for users table
CREATE POLICY "Users can view all profiles"
  ON users FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- Create policies for hazards table
CREATE POLICY "Anyone can view active hazards"
  ON hazards FOR SELECT
  USING (status = 'active');

CREATE POLICY "Authenticated users can create hazards"
  ON hazards FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own hazards"
  ON hazards FOR UPDATE
  USING (auth.uid() = user_id);
```

### 5. Create Storage Buckets

1. Go to Storage in your Supabase dashboard
2. Create a bucket named `hazard-images` (public)
3. Create a bucket named `profile-images` (public)

### 6. Enable Realtime

1. Go to Database > Replication in Supabase dashboard
2. Enable replication for the `hazards` table

### 7. Configure Environment Variables

Create a `.env` file in the root directory:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

**Important**: Replace the values with your actual Supabase credentials.

### 8. Update pubspec.yaml

Make sure `flutter_dotenv` is included in your `pubspec.yaml` (already added).

## 🏃 Running the App

### Development

```bash
flutter run
```

### Build Android APK

```bash
flutter build apk --release
```

The APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`

### Build iOS

```bash
flutter build ios --release
```

## 📱 Platform-Specific Setup

### Android

1. Update `android/app/src/main/AndroidManifest.xml`:
   - Add location permissions
   - Add internet permission

### iOS

1. Update `ios/Runner/Info.plist`:
   - Add location usage descriptions
   - Add camera and photo library permissions

## 🗂️ Project Structure

```
lib/
├── core/
│   ├── config/          # Configuration files (Supabase)
│   ├── constants/       # App constants
│   └── theme/           # App theme
├── models/              # Data models
├── providers/           # Riverpod providers
├── screens/             # App screens
│   ├── map_screen.dart
│   ├── report_screen.dart
│   ├── feed_screen.dart
│   └── profile_screen.dart
├── services/            # Business logic services
└── widgets/             # Reusable widgets
```

## 🔐 Security Notes

- Never commit your `.env` file to version control
- Add `.env` to `.gitignore`
- Use environment variables for all sensitive data
- Row Level Security (RLS) is enabled on all tables

## 🐛 Troubleshooting

### Supabase Connection Issues

- Verify your `.env` file has correct values
- Check that Supabase project is active
- Ensure RLS policies are correctly set

### Location Permission Issues

- Grant location permissions in device settings
- For Android: Check `AndroidManifest.xml` permissions
- For iOS: Check `Info.plist` location usage descriptions

### Image Upload Issues

- Verify storage buckets exist and are public
- Check bucket names match constants in `app_constants.dart`

## 📝 License

This project is proprietary software of The Heedful.

## 👥 Contributors

The Heedful Development Team
