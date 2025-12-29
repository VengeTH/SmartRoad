#!/bin/bash

# Fix 403 Forbidden errors from RainViewer
# Run this on your server where the proxy is installed

echo "🔧 Fixing RainViewer 403 Forbidden errors..."
echo "=============================================="
echo ""

# Navigate to proxy directory
cd ~/weather-proxy || cd weather-proxy || {
  echo "❌ Error: weather-proxy directory not found!"
  echo "Please run this script from the directory containing weather-proxy/"
  exit 1
}

# Backup original server.js
echo "📦 Backing up server.js..."
cp server.js server.js.backup

# Create fixed server.js
echo "🔧 Creating fixed server.js..."
cat > server.js << 'EOF'
const express = require('express');
const fetch = require('node-fetch');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// * Enable CORS for all routes
app.use(cors());

// * In-memory cache for Open-Meteo responses
const openMeteoCache = new Map();
const CACHE_DURATION = 5 * 60 * 1000; // * 5 minutes

// * Proxy endpoint for RainViewer tiles
app.get('/rainviewer/:timestamp/:z/:x/:y', async (req, res) => {
  try {
    const { timestamp, z, x, y } = req.params;
    const url = `https://tilecache.rainviewer.com/v2/radar/${timestamp}/${z}/${x}/${y}/2/1_1.png`;
    
    console.log(`[RainViewer] Fetching: ${url}`);
    
    // * Add proper headers to mimic a browser request
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://www.rainviewer.com/',
      'Accept': 'image/png,image/*;q=0.8,*/*;q=0.5',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Sec-Fetch-Dest': 'image',
      'Sec-Fetch-Mode': 'no-cors',
      'Sec-Fetch-Site': 'cross-site',
    };
    
    const response = await fetch(url, { headers });
    
    if (!response.ok) {
      console.error(`[RainViewer] Error ${response.status}: ${url}`);
      return res.status(response.status).json({ 
        error: `Failed to fetch tile: ${response.status} ${response.statusText}` 
      });
    }
    
    // * Get image buffer
    const buffer = await response.buffer();
    
    // * Set proper response headers
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'public, max-age=300'); // * Cache for 5 minutes
    res.setHeader('Content-Length', buffer.length);
    res.send(buffer);
    
    console.log(`[RainViewer] Success: ${timestamp}/${z}/${x}/${y}`);
  } catch (error) {
    console.error('[RainViewer] Error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// * Proxy endpoint for RainViewer weather maps (timestamps)
app.get('/rainviewer/weather-maps', async (req, res) => {
  try {
    const url = 'https://api.rainviewer.com/public/weather-maps.json';
    
    console.log(`[RainViewer] Fetching weather maps: ${url}`);
    
    // * Add proper headers
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://www.rainviewer.com/',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    
    const response = await fetch(url, { headers });
    
    if (!response.ok) {
      console.error(`[RainViewer] Error ${response.status} fetching weather maps`);
      return res.status(response.status).json({ 
        error: `Failed to fetch weather maps: ${response.status}` 
      });
    }
    
    const data = await response.json();
    
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.json(data);
    
    console.log(`[RainViewer] Weather maps fetched successfully`);
  } catch (error) {
    console.error('[RainViewer] Error fetching weather maps:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// * Proxy endpoint for Open-Meteo forecast API
app.get('/open-meteo/forecast', async (req, res) => {
  try {
    const { latitude, longitude, current } = req.query;
    
    if (!latitude || !longitude || !current) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }
    
    const cacheKey = `${latitude}_${longitude}_${current}`;
    
    // * Check cache
    if (openMeteoCache.has(cacheKey)) {
      const cached = openMeteoCache.get(cacheKey);
      if (Date.now() - cached.timestamp < CACHE_DURATION) {
        console.log(`[Open-Meteo] Cache HIT: ${cacheKey}`);
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('X-Cache', 'HIT');
        return res.json(cached.data);
      }
    }
    
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current=${current}`;
    
    console.log(`[Open-Meteo] Fetching: ${url}`);
    
    // * Add proper headers for Open-Meteo
    const headers = {
      'User-Agent': 'SmartRoad-WeatherProxy/1.0',
      'Accept': 'application/json',
    };
    
    const response = await fetch(url, { headers });
    
    if (!response.ok) {
      console.error(`[Open-Meteo] Error ${response.status}: ${url}`);
      return res.status(response.status).json({ error: 'Failed to fetch forecast' });
    }
    
    const data = await response.json();
    
    // * Cache response
    openMeteoCache.set(cacheKey, {
      data,
      timestamp: Date.now()
    });
    
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('X-Cache', 'MISS');
    res.json(data);
    
    console.log(`[Open-Meteo] Success: ${latitude}, ${longitude}`);
  } catch (error) {
    console.error('[Open-Meteo] Error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// * Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// * Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🌤️  Weather Proxy Server running on port ${PORT}`);
  console.log(`📍 Health check: http://localhost:${PORT}/health`);
  console.log(`🌧️  RainViewer: http://localhost:${PORT}/rainviewer/:timestamp/:z/:x/:y`);
  console.log(`🌡️  Open-Meteo: http://localhost:${PORT}/open-meteo/forecast`);
});
EOF

echo ""
echo "✅ Server.js updated!"
echo ""
echo "🔄 Restarting proxy server..."
pm2 restart weather-proxy

echo ""
echo "✅ Fix applied!"
echo ""
echo "📊 Check logs: pm2 logs weather-proxy"
echo "📊 Check status: pm2 status"
echo ""

