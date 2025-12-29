# OpenWeatherMap Setup Guide

## ✅ Migration Complete!

SmartRoad now uses **OpenWeatherMap** for all weather tile layers (rain, temperature, clouds) instead of RainViewer.

## Quick Start

### 1. Create .env File

Create a `.env` file in your project root (it's already in `.gitignore`):

```bash
# .env
OPENWEATHERMAP_API_KEY=your_openweathermap_api_key_here
WEATHER_PROXY_URL=
```

### 2. Run Flutter App

**Option A: Using .env File (Recommended)**
```bash
# Linux/Mac
./run-with-env.sh

# Windows PowerShell
.\run-with-env.ps1
```

**Option B: Direct --dart-define**
```bash
flutter run --dart-define=OPENWEATHERMAP_API_KEY=your_api_key_here
```

**Option C: With Proxy Server**
```bash
# Set API key in proxy server environment
export OPENWEATHERMAP_API_KEY=your_api_key_here

# Run Flutter app
flutter run --dart-define=WEATHER_PROXY_URL=http://localhost:3000
```

### 3. Update Proxy Server (Optional)

If you want to use the proxy server for OpenWeatherMap tiles:

```bash
cd ~/SmartRoad
chmod +x update-proxy-openweathermap.sh
./update-proxy-openweathermap.sh
```

Then set the API key in PM2:
```bash
pm2 restart weather-proxy --update-env --env OPENWEATHERMAP_API_KEY=
```

## OpenWeatherMap Tile URLs

- **Precipitation:** `https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid={apiKey}`
- **Temperature:** `https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid={apiKey}`
- **Clouds:** `https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid={apiKey}`

## Benefits

✅ **Free tier:** 1,000 calls/day, 60 calls/minute  
✅ **No CORS issues:** Proper headers, works on web  
✅ **Reliable service:** Well-maintained API  
✅ **All layers:** Rain, temperature, and clouds in one service  
✅ **Standard format:** Easy tile integration  

## Free Tier Limits

- **1,000 calls/day** - Plenty for development and testing
- **60 calls/minute** - Reasonable rate limit
- **Upgrade available** if you need more

## Troubleshooting

### Tiles not loading?

1. **Check API key is set in .env:**
   ```bash
   # Check .env file exists and has API key
   cat .env | grep OPENWEATHERMAP_API_KEY
   ```

2. **Check API key is valid:**
   ```bash
   # Replace YOUR_API_KEY with your actual key
   curl "https://tile.openweathermap.org/map/precipitation_new/7/107/59.png?appid=YOUR_API_KEY"
   ```

3. **Verify .env is loaded:**
   ```bash
   # Linux/Mac
   ./run-with-env.sh
   
   # Windows
   .\run-with-env.ps1
   ```

3. **Check proxy (if using):**
   ```bash
   curl http://localhost:3000/openweathermap/precipitation/7/107/59
   ```

### Rate limit errors?

- OpenWeatherMap free tier: 60 calls/minute
- If you hit limits, wait a minute or upgrade your plan

## What Changed

- ✅ Replaced RainViewer with OpenWeatherMap
- ✅ Updated all weather layers (rain, heat, clouds)
- ✅ Added API key configuration
- ✅ Updated proxy server support
- ✅ Removed RainViewer dependencies

## Next Steps

1. Test the weather layers in your app
2. Toggle rain, temperature, and cloud layers
3. Adjust opacity sliders
4. Enjoy reliable weather tiles! 🌤️

