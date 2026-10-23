# Backend Proxy Setup Guide

## ✅ What Has Been Implemented (Flutter Side)

I've implemented all the Flutter-side code to support a backend proxy for weather layers. Here's what was done:

### 1. Created `lib/config/weather_config.dart`
- Configuration class that reads `WEATHER_PROXY_URL` from environment variables
- Helper methods to build proxy URLs for RainViewer and Open-Meteo
- `areLayersAvailable` getter that returns `true` on web only if proxy is configured

### 2. Updated `lib/widgets/weather_tile_layers.dart`
- `_RainViewerImageProvider` now uses proxy URL when `WeatherConfig.useProxy` is true
- Falls back to direct RainViewer URL if proxy is not configured

### 3. Updated `lib/services/weather_tile_generator.dart`
- `_fetchTemperature()` and `_fetchCloudCover()` now use proxy URL when configured
- Falls back to direct Open-Meteo API if proxy is not configured

### 4. Updated `lib/screens/map/map_screen.dart`
- Weather layers now check `WeatherConfig.areLayersAvailable` instead of just `!kIsWeb`
- Layers will render on web if proxy is configured

### 5. Updated `lib/widgets/weather_layer_controls.dart`
- UI now shows appropriate messages based on proxy configuration
- Shows setup instructions when proxy is not configured on web

---

## ✅ Backend Implementation (Go Backend in `backend/api`)

The backend proxy is now **fully implemented in Go** inside the official `backend/api` service.

### Active Endpoints Handled by the Go Backend:
- `/open-meteo/forecast` (and `/api/weather/open-meteo/forecast`) — Proxies forecast requests with 5-minute memory caching.
- `/rainviewer/{timestamp}/{z}/{x}/{y}` (and `/api/weather/rainviewer/...`) — Proxies radar tiles with binary image caching and CORS.
- `/rainviewer/weather-maps` — Proxies RainViewer map timestamps list.
- `/openweathermap/{layer}/{z}/{x}/{y}` — Proxies tile layers using server-side or query `OPENWEATHERMAP_API_KEY`.
- `/api/weather/current` & `/api/weather/alerts` — High-level location weather reports.

### Starting the Backend
```bash
cd backend
docker-compose up -d
```
The Go API runs on port 3000 by default.

### Step 3: Configure Flutter App

Once your backend is deployed, configure the Flutter app to use it:

**Option A: Command Line**
```bash
flutter run --dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather
```

**Option B: Android Studio**
1. Run > Edit Configurations
2. Additional run args: `--dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather`

**Option C: VS Code**
Add to `launch.json`:
```json
{
  "configurations": [
    {
      "name": "Flutter (with proxy)",
      "args": [
        "--dart-define=WEATHER_PROXY_URL=https://your-backend.com/api/weather"
      ]
    }
  ]
}
```

**Option D: Build Configuration**
For production builds, add to your build script or CI/CD pipeline.

### Step 4: Test

1. **Test Backend Endpoints Directly:**
   ```bash
   # Test RainViewer proxy
   curl https://your-backend.com/api/weather/rainviewer/1766993400/7/106/58
   
   # Test Open-Meteo proxy
   curl "https://your-backend.com/api/weather/open-meteo/forecast?latitude=14.5995&longitude=120.9842&current=temperature_2m"
   ```

2. **Test Flutter App:**
   - Run app with `WEATHER_PROXY_URL` set
   - Enable weather layers
   - Verify layers load without CORS or rate limit errors

---

## 🔍 Troubleshooting

### Backend returns 404
- Check that routes are mounted correctly: `app.use('/api/weather', weatherProxy)`
- Verify URL path matches: `/api/weather/rainviewer/...` or `/api/weather/open-meteo/...`

### Backend returns CORS errors
- Ensure `cors()` middleware is used: `router.use(cors())`
- Check that `Access-Control-Allow-Origin: *` header is set

### Flutter app still shows "Not available on web"
- Verify `WEATHER_PROXY_URL` is set correctly
- Check that URL doesn't have trailing slash: `https://your-backend.com/api/weather` (not `.../weather/`)
- Restart Flutter app after setting environment variable

### Rate limits still occurring
- Backend caching should help, but Open-Meteo may still rate limit
- Consider implementing request queuing/throttling in backend
- Or use alternative weather API with better rate limits

---

## 📝 Summary

**Implementation Status:**
- ✅ Created `WeatherConfig` class in Flutter
- ✅ Updated all weather services to support proxy URLs
- ✅ Updated UI to show proxy status
- ✅ Made layers conditionally available based on proxy configuration
- ✅ Implemented complete Go backend proxy in `backend/api` (Open-Meteo, RainViewer, OpenWeatherMap)
- ✅ Deployed via unified `docker-compose.yml`

To test in Flutter:
```bash
flutter run --dart-define=WEATHER_PROXY_URL=http://localhost:3000
```

Once you complete these steps, weather layers will work on all platforms including web! 🎉
