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

## ❌ What You Need To Do (Backend Side)

### Step 1: Create Backend Server

You need to create a backend server that acts as a proxy. Here's a Node.js/Express example:

**File: `backend/routes/weather-proxy.js`**

```javascript
const express = require('express');
const router = express.Router();
const fetch = require('node-fetch');
const cors = require('cors');

router.use(cors());

// * Proxy for RainViewer tiles
router.get('/rainviewer/:timestamp/:z/:x/:y', async (req, res) => {
  try {
    const { timestamp, z, x, y } = req.params;
    const url = `https://tilecache.rainviewer.com/v2/radar/${timestamp}/${z}/${x}/${y}/2/1_1.png`;
    
    const response = await fetch(url);
    const buffer = await response.buffer();
    
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'public, max-age=300'); // * Cache for 5 minutes
    res.send(buffer);
  } catch (error) {
    console.error('RainViewer proxy error:', error);
    res.status(500).json({ error: error.message });
  }
});

// * Proxy for Open-Meteo API (with caching)
const openMeteoCache = new Map();
const CACHE_DURATION = 5 * 60 * 1000; // * 5 minutes

router.get('/open-meteo/forecast', async (req, res) => {
  try {
    const { latitude, longitude, current } = req.query;
    const cacheKey = `${latitude}_${longitude}_${current}`;
    
    // * Check cache
    if (openMeteoCache.has(cacheKey)) {
      const cached = openMeteoCache.get(cacheKey);
      if (Date.now() - cached.timestamp < CACHE_DURATION) {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('X-Cache', 'HIT');
        return res.json(cached.data);
      }
    }
    
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current=${current}`;
    const response = await fetch(url);
    const data = await response.json();
    
    // * Cache response
    openMeteoCache.set(cacheKey, {
      data,
      timestamp: Date.now()
    });
    
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('X-Cache', 'MISS');
    res.json(data);
  } catch (error) {
    console.error('Open-Meteo proxy error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
```

**File: `backend/server.js` (or `app.js`)**

```javascript
const express = require('express');
const weatherProxy = require('./routes/weather-proxy');

const app = express();

// * Mount weather proxy routes
app.use('/api/weather', weatherProxy);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Weather proxy server running on port ${PORT}`);
});
```

**File: `backend/package.json`**

```json
{
  "name": "weather-proxy",
  "version": "1.0.0",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "node-fetch": "^2.6.7",
    "cors": "^2.8.5"
  }
}
```

### Step 2: Deploy Backend Server

Deploy your backend server to a hosting platform:

**Option A: Heroku**
```bash
cd backend
heroku create your-weather-proxy
git push heroku main
```

**Option B: DigitalOcean / AWS / Any VPS**
- Set up Node.js on your server
- Install dependencies: `npm install`
- Run server: `node server.js` (or use PM2: `pm2 start server.js`)

**Option C: Vercel / Netlify Functions**
- Convert to serverless functions (requires different structure)

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

**What I Did:**
- ✅ Created `WeatherConfig` class
- ✅ Updated all weather services to use proxy URLs
- ✅ Updated UI to show proxy status
- ✅ Made layers conditionally available based on proxy configuration

**What You Need To Do:**
- ❌ Create backend server (Node.js/Express example provided)
- ❌ Deploy backend to hosting platform
- ❌ Set `WEATHER_PROXY_URL` environment variable in Flutter
- ❌ Test endpoints and verify everything works

Once you complete these steps, weather layers will work on all platforms including web! 🎉
