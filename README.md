# SmartRoad MVP

The flagship project of The Heedful - A real-time hazard reporting system using Flutter, Supabase, and OpenStreetMap.

## 🚀 Features

- **Real-Time Map**: View hazards on an interactive map with OpenStreetMap tiles
- **Hazard Reporting**: Report potholes, floods, accidents, closures, roadblocks, and landslides
- **Community Feed**: Browse latest hazard reports from the community
- **User Authentication**: Sign up and sign in with email/password
- **Image Upload**: Attach photos to hazard reports
- **Realtime Updates**: See new hazards appear instantly on the map

## 💰 Supabase: Cloud vs Self-Hosted

### Supabase Cloud (Free Tier)
**Perfect for MVP/Demo:**
- ✅ **Free forever** for small projects
- ✅ No server maintenance
- ✅ Automatic backups and updates
- ✅ 500 MB database, 1 GB storage
- ✅ 50,000 monthly active users
- ✅ Quick setup (~2 minutes)

**Limitations:**
- Project pauses after 1 week of inactivity (free tier)
- Limited to 2 projects on free tier
- Data stored on Supabase servers

### Self-Hosted Supabase
**Best for:**
- 🔒 Full data control and privacy
- 🚀 No usage limits
- 💰 Cost-effective at scale
- 🌍 Custom domain and branding
- 📊 Full server access

**Requirements:**
- Server with Docker (2GB+ RAM recommended)
- Basic DevOps knowledge
- Maintenance responsibility

## 📋 Prerequisites

- Flutter SDK (3.7.0 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- **Supabase** (choose one):
  - **Option A**: Supabase Cloud account (free tier available)
  - **Option B**: Self-hosted Supabase instance

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

### 3. Choose Storage Mode

**The app supports TWO modes:**

#### Option A: Local Storage (No Database Required) ⭐ **RECOMMENDED FOR MVP**

Perfect for demos and testing without any backend setup!

1. Open `lib/core/config/app_config.dart`
2. Ensure `useLocalStorage = true` (this is the default)
3. **That's it!** No database setup needed. Data is stored locally on the device.

**Features:**
- ✅ No database setup required
- ✅ Works offline
- ✅ Data persists between app restarts
- ✅ Perfect for MVP/demo
- ⚠️ Data is device-specific (not synced across devices)

#### Option B: Supabase (Database Required)

For production or when you need cloud sync.

1. Open `lib/core/config/app_config.dart`
2. Set `useLocalStorage = false`
3. Follow the Supabase setup below

### 4. Set Up Supabase (Only if using Option B)

#### Option A: Supabase Cloud (Recommended for MVP/Demo)

**Free Tier Includes:**
- 500 MB database storage
- 1 GB file storage
- 2 GB bandwidth per month
- 50,000 monthly active users
- Unlimited API requests
- Realtime subscriptions included

**Setup Steps:**
1. Create a free account at [Supabase](https://app.supabase.com)
2. Create a new project (takes ~2 minutes)
3. Go to Project Settings > API
4. Copy your Project URL and anon/public key

#### Option B: Self-Hosted Supabase

**Requirements:**
- Server with Docker and Docker Compose
- Minimum 2GB RAM, 2 CPU cores
- Domain name (optional, for HTTPS)

**Setup Steps:**
1. Install Supabase using [official self-hosting guide](https://supabase.com/docs/guides/self-hosting)
2. Or use the quick start:
   ```bash
   git clone --depth 1 https://github.com/supabase/supabase
   cd supabase/docker
   cp .env.example .env
   # Edit .env with your configuration
   docker-compose up -d
   ```
3. Access your Supabase instance (usually at `http://your-server:8000`)
4. Get your anon key from the API settings
5. **Important**: For mobile apps, ensure your server is accessible:
   - Use HTTPS (recommended) or HTTP for local testing
   - Configure firewall to allow connections
   - Update CORS settings if needed

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

### 7. Configure Environment Variables (Only if using Supabase)

**Skip this step if using Local Storage mode!**

Create a `.env` file in the root directory (copy from `env.example`):

**For Supabase Cloud:**
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

**For Self-Hosted Supabase:**
```env
SUPABASE_URL=http://your-server-ip:8000
# or with HTTPS:
SUPABASE_URL=https://supabase.yourdomain.com
SUPABASE_ANON_KEY=your-self-hosted-anon-key
```

**Important**: 
- Replace the values with your actual Supabase credentials
- For self-hosted: Ensure your server URL is accessible from mobile devices
- For production: Always use HTTPS

### 8. Run the App!

You're ready! Just run:

```bash
flutter run
```

**If using Local Storage:** The app will work immediately - no additional setup needed!

**If using Supabase:** Make sure you've completed steps 4-7 above.

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

## 🔄 Switching from Local Storage to Supabase

When you're ready to use your self-hosted Supabase:

1. **Set up your Supabase instance** (cloud or self-hosted)
2. **Create the database tables** (see step 4 above)
3. **Create storage buckets** (see step 5 above)
4. **Enable Realtime** (see step 6 above)
5. **Update configuration:**
   - Open `lib/core/config/app_config.dart`
   - Change `useLocalStorage = false`
   - Create `.env` file with your Supabase credentials
6. **Run the app** - it will automatically use Supabase!

**Note:** Data stored locally won't automatically migrate to Supabase. You'll need to export/import manually if needed.

## 🐛 Troubleshooting

### Local Storage Issues

- **Data not persisting**: Check app permissions for file storage
- **Can't find data**: Data is stored in app's documents directory
- **Images not loading**: Check file path permissions

### Supabase Connection Issues

- Verify your `.env` file has correct values (only needed if `useLocalStorage = false`)
- Check that Supabase project is active (cloud) or server is running (self-hosted)
- Ensure RLS policies are correctly set
- **For self-hosted**: Check server accessibility and firewall settings
- **For self-hosted**: Verify CORS is configured if accessing from web
- **If using local storage**: Make sure `useLocalStorage = true` in `app_config.dart`

### Self-Hosted Specific Issues

- **Connection refused**: Check if Supabase services are running (`docker-compose ps`)
- **Network unreachable**: Ensure server IP/domain is accessible from your device
- **HTTPS errors**: Use HTTP for local testing, or configure SSL certificates
- **Port blocked**: Check firewall allows connections on port 8000 (or your configured port)

### Location Permission Issues

- Grant location permissions in device settings
- For Android: Check `AndroidManifest.xml` permissions
- For iOS: Check `Info.plist` location usage descriptions

### Image Upload Issues

- Verify storage buckets exist and are public
- Check bucket names match constants in `app_constants.dart`
- **For self-hosted**: Ensure storage service is running and accessible

## 📝 License

This project is proprietary software of The Heedful.

## 👥 Contributors

The Heedful Development Team
