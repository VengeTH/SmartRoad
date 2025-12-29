#!/bin/bash

# Add OpenWeatherMap support to weather proxy server
# Run this on your server where the proxy is installed

echo "🌤️  Adding OpenWeatherMap support to weather proxy..."
echo "======================================================"
echo ""

# Navigate to proxy directory
cd ~/weather-proxy || cd weather-proxy || {
  echo "❌ Error: weather-proxy directory not found!"
  echo "Please run this script from the directory containing weather-proxy/"
  exit 1
}

# Backup server.js
echo "📦 Backing up server.js..."
cp server.js server.js.backup.$(date +%Y%m%d_%H%M%S)

# Read current server.js and add OpenWeatherMap endpoints
echo "🔧 Adding OpenWeatherMap endpoints..."

# Check if OpenWeatherMap endpoints already exist
if grep -q "openweathermap" server.js; then
  echo "⚠️  OpenWeatherMap endpoints already exist in server.js"
  echo "Skipping update..."
else
  # Add OpenWeatherMap endpoints before the health check endpoint
  sed -i '/\/\/ \* Health check endpoint/i\
// * Proxy endpoint for OpenWeatherMap tiles\
app.get("/openweathermap/:type/:z/:x/:y", async (req, res) => {\
  try {\
    const { type, z, x, y } = req.params;\
    const apiKey = process.env.OPENWEATHERMAP_API_KEY || "";\
    \
    if (!apiKey) {\
      return res.status(500).json({ error: "OpenWeatherMap API key not configured" });\
    }\
    \
    // * Map type to OpenWeatherMap tile endpoint\
    let tileType;\
    switch (type) {\
      case "precipitation":\
        tileType = "precipitation_new";\
        break;\
      case "temperature":\
        tileType = "temp_new";\
        break;\
      case "clouds":\
        tileType = "clouds_new";\
        break;\
      default:\
        return res.status(400).json({ error: "Invalid tile type" });\
    }\
    \
    const url = `https://tile.openweathermap.org/map/${tileType}/${z}/${x}/${y}.png?appid=${apiKey}`;\
    \
    console.log(`[OpenWeatherMap] Fetching ${type} tile: ${z}/${x}/${y}`);\
    \
    const headers = {\
      "User-Agent": "SmartRoad-WeatherProxy/1.0",\
      "Accept": "image/png,image/*;q=0.8",\
    };\
    \
    const response = await fetch(url, { headers });\
    \
    if (!response.ok) {\
      console.error(`[OpenWeatherMap] Error ${response.status}: ${url}`);\
      return res.status(response.status).json({ \
        error: `Failed to fetch tile: ${response.status}` \
      });\
    }\
    \
    let buffer;\
    if (response.buffer) {\
      buffer = await response.buffer();\
    } else if (response.arrayBuffer) {\
      const arrayBuffer = await response.arrayBuffer();\
      buffer = Buffer.from(arrayBuffer);\
    } else {\
      const arrayBuffer = await response.arrayBuffer();\
      buffer = Buffer.from(arrayBuffer);\
    }\
    \
    res.setHeader("Content-Type", "image/png");\
    res.setHeader("Access-Control-Allow-Origin", "*");\
    res.setHeader("Cache-Control", "public, max-age=300");\
    res.setHeader("Content-Length", buffer.length);\
    res.send(buffer);\
    \
    console.log(`[OpenWeatherMap] ✅ Success: ${type}/${z}/${x}/${y} (${buffer.length} bytes)`);\
  } catch (error) {\
    console.error("[OpenWeatherMap] Exception:", error.message);\
    res.status(500).json({ error: error.message });\
  }\
});\
' server.js

  echo "✅ OpenWeatherMap endpoints added!"
fi

echo ""
echo "📝 Setting up environment variable..."
echo ""
echo "To set your OpenWeatherMap API key, add it to your environment:"
echo "  export OPENWEATHERMAP_API_KEY="
echo ""
echo "Or add it to PM2:"
echo "  pm2 restart weather-proxy --update-env --env OPENWEATHERMAP_API_KEY="
echo ""

# Restart server
echo "🔄 Restarting proxy server..."
pm2 restart weather-proxy --update-env

echo ""
echo "✅ Update complete!"
echo ""
echo "📊 Test endpoints:"
echo "  curl http://localhost:3000/openweathermap/precipitation/7/107/59"
echo "  curl http://localhost:3000/openweathermap/temperature/7/107/59"
echo "  curl http://localhost:3000/openweathermap/clouds/7/107/59"
echo ""
