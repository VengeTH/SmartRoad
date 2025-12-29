# OpenWeatherMap Migration Guide

## Summary

I've started migrating from RainViewer to OpenWeatherMap for weather tiles. The implementation is partially complete but the file got corrupted during editing.

## What's Done ✅

1. ✅ Updated `lib/config/weather_config.dart`:
   - Added `openWeatherMapApiKey` configuration
   - Added methods: `getOpenWeatherMapRainTileUrl()`, `getOpenWeatherMapTempTileUrl()`, `getOpenWeatherMapCloudsTileUrl()`
   - Added `isLayerAvailableOnWeb()` method

2. ✅ Updated `lib/widgets/weather_tile_layers.dart`:
   - Created `OpenWeatherMapTileProvider` class
   - Updated `RainLayer` to use OpenWeatherMap
   - Updated `HeatLayer` to use OpenWeatherMap  
   - Updated `CloudLayer` to use OpenWeatherMap

## What Needs Fixing 🔧

The file `lib/widgets/weather_tile_layers.dart` has corrupted RainViewer code (lines ~90-222) that needs to be removed.

## Next Steps

1. **Get OpenWeatherMap API Key:**
   - Go to: https://openweathermap.org/api
   - Sign up for free account
   - Get your API key from the dashboard
   - Free tier: 1,000 calls/day, 60 calls/minute

2. **Fix the corrupted file:**
   - Remove all RainViewer-related code from `lib/widgets/weather_tile_layers.dart`
   - The `WeatherTileProvider` class should remain (it's used for Open-Meteo fallback if needed)

3. **Update proxy server:**
   - Add OpenWeatherMap tile endpoints to `weather-proxy/server.js`

4. **Run Flutter app:**
   ```bash
   flutter run --dart-define=OPENWEATHERMAP_API_KEY=your_api_key_here
   ```

## OpenWeatherMap Tile URLs

- **Precipitation:** `https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid={apiKey}`
- **Temperature:** `https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid={apiKey}`
- **Clouds:** `https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid={apiKey}`

## Benefits of OpenWeatherMap

- ✅ Free tier: 1,000 calls/day (plenty for development)
- ✅ Well documented
- ✅ Standard tile format
- ✅ No CORS issues (proper headers)
- ✅ Reliable service
- ✅ All weather layers (rain, temp, clouds) in one service
