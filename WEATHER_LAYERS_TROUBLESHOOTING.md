# Weather Layers Troubleshooting Guide

## 🔍 Problem Summary

### Issue 0: Square/Boxy Tile Artifacts (Fixed in v2.6.4)
- **Problem**: Weather layers display with visible square/boxy tile boundaries
- **Cause**: OpenWeatherMap provides PNG raster tiles with hard square edges. `ClipRect` was creating additional hard boundaries.
- **Solution**: 
  - ✅ Removed `ClipRect` from all weather layer tile builders
  - ✅ Implemented extreme blur (7.0-12.0 sigma) to eliminate tile boundaries
  - ✅ Blur extends beyond tile boundaries for seamless blending
  - ✅ Weather layers now display with smooth, curved edges at all zoom levels
- **Status**: ✅ Fixed in Version 2.6.4

---

Your weather layers are failing on web due to two fundamental issues:

### Issue 1: Rain Layer - CORS Policy
- **Error**: `Access to fetch at 'https://tilecache.rainviewer.com/...' has been blocked by CORS policy`
- **Cause**: RainViewer's server doesn't send CORS headers, so browsers block requests from your web app
- **Impact**: Rain layer cannot work on web without a backend proxy
- **Status**: ✅ Code is correct, but browser security prevents it

### Issue 2: Heat/Clouds Layers - Rate Limiting
- **Error**: `429 (Too Many Requests)` from Open-Meteo API
- **Cause**: Open-Meteo has strict rate limits (likely ~10 requests/minute per IP)
- **Impact**: When map requests many tiles simultaneously (panning/zooming), rate limits are exceeded
- **Status**: ⚠️ Even with 5-second delays, too many tiles requested at once

---

## 🎯 Solution Options

### Option 1: Disable Weather Layers on Web (Quick Fix)

**Pros**: Immediate, no backend needed  
**Cons**: No weather visualization on web

**Steps**:
1. Open `lib/screens/map/map_screen.dart`
2. Find the weather layer rendering section (around line 2447)
3. Add `!kIsWeb` checks to prevent rendering on web:

```dart
// * Weather tile layers (above base map, below routes)
// * Disabled on web due to CORS (rain) and rate limiting (heat/clouds)
if (!kIsWeb) {
  // * Rain layer
  if (_weatherLayerManager.getLayerConfig(WeatherLayerType.rain).enabled)
    RainLayer(
      manager: _weatherLayerManager,
      frame: _weatherLayerManager.getRainFrame(),
    ),
  // * Heat layer
  if (_weatherLayerManager.getLayerConfig(WeatherLayerType.heat).enabled)
    HeatLayer(
      manager: _weatherLayerManager,
    ),
  // * Cloud layer
  if (_weatherLayerManager.getLayerConfig(WeatherLayerType.clouds).enabled)
    CloudLayer(
      manager: _weatherLayerManager,
    ),
}
```

4. Update `WeatherLayerControls` to show "Not available on web" message

---

### Option 2: Implement Backend Proxy (Recommended for Production)

**Pros**: Works on all platforms, bypasses CORS and rate limits  
**Cons**: Requires backend server setup

#### Step-by-Step: Backend Proxy Setup

**Step 1: Create Backend Proxy Endpoint**

Create a new file in your backend (e.g., Node.js/Express):

```javascript
// backend/routes/weather-proxy.js
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
    res.send(buffer);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// * Proxy for Open-Meteo API (with caching)
const openMeteoCache = new Map();
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

router.get('/open-meteo/forecast', async (req, res) => {
  try {
    const { latitude, longitude, current } = req.query;
    const cacheKey = `${latitude}_${longitude}_${current}`;
    
    // * Check cache
    if (openMeteoCache.has(cacheKey)) {
      const cached = openMeteoCache.get(cacheKey);
      if (Date.now() - cached.timestamp < CACHE_DURATION) {
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
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
```

**Step 2: Update Flutter Code to Use Proxy**

1. Add proxy URL configuration:

```dart
// lib/config/weather_config.dart
class WeatherConfig {
  // * Backend proxy URL (set this to your backend URL)
  static const String proxyBaseUrl = String.fromEnvironment(
    'WEATHER_PROXY_URL',
    defaultValue: 'https://your-backend.com/api/weather',
  );
  
  static bool get useProxy => proxyBaseUrl.isNotEmpty;
}
```

2. Update `RainViewerTileProvider`:

```dart
// In lib/widgets/weather_tile_layers.dart
String _buildRainTileUrl(int timestamp, int z, int x, int y) {
  if (WeatherConfig.useProxy) {
    return "${WeatherConfig.proxyBaseUrl}/rainviewer/$timestamp/$z/$x/$y";
  }
  return "https://tilecache.rainviewer.com/v2/radar/$timestamp/$z/$x/$y/2/1_1.png";
}
```

3. Update `WeatherTileGenerator`:

```dart
// In lib/services/weather_tile_generator.dart
Future<double?> _fetchTemperature(double lat, double lon) async {
  final url = WeatherConfig.useProxy
    ? "${WeatherConfig.proxyBaseUrl}/open-meteo/forecast?latitude=$lat&longitude=$lon&current=temperature_2m"
    : "$_apiUrl?latitude=$lat&longitude=$lon&current=temperature_2m";
  
  final response = await http.get(Uri.parse(url));
  // ... rest of the code
}
```

**Step 3: Deploy Backend**

- Deploy to your backend server (e.g., Heroku, AWS, DigitalOcean)
- Set `WEATHER_PROXY_URL` environment variable in Flutter
- Test the proxy endpoints

---

### Option 3: Use Alternative Weather APIs

**Pros**: May have better rate limits or CORS support  
**Cons**: Different data formats, may require API keys

**Alternatives**:
1. **OpenWeatherMap** - Has CORS support, but requires API key
2. **WeatherAPI.com** - Better rate limits, CORS support
3. **Visual Crossing** - Weather tiles API with CORS

**Implementation**: Similar to current Open-Meteo implementation, but update API endpoints and response parsing

---

## 🚀 Recommended Immediate Action

**For now, disable weather layers on web** (Option 1) to prevent console errors and improve user experience. Then plan for Option 2 (backend proxy) for production.

---

## 📝 Next Steps

1. ✅ Implement Option 1 (disable on web) - **Do this now**
2. ⏳ Plan backend proxy setup - **For production**
3. ⏳ Consider alternative APIs if backend proxy is not feasible

---

## 🔧 Testing

After implementing Option 1:
- Weather layers should not attempt to load on web
- No CORS or 429 errors in console
- Weather layers still work on mobile/desktop

After implementing Option 2:
- Weather layers work on all platforms
- No CORS errors
- Reduced rate limit errors (backend caching helps)
