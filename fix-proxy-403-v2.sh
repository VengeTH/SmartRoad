#!/bin/bash

# Fix 403 Forbidden errors from RainViewer - Improved Version
# Run this on your server where the proxy is installed

echo "🔧 Fixing RainViewer 403 Forbidden errors (v2)..."
echo "=================================================="
echo ""

# Navigate to proxy directory
cd ~/weather-proxy || cd weather-proxy || {
  echo "❌ Error: weather-proxy directory not found!"
  echo "Please run this script from the directory containing weather-proxy/"
  exit 1
}

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
echo "📋 Node.js version: $(node -v)"

# Backup original server.js
echo "📦 Backing up server.js..."
cp server.js server.js.backup.$(date +%Y%m%d_%H%M%S)

# Check if we need to update dependencies
echo "📦 Checking dependencies..."
if ! npm list node-fetch &>/dev/null; then
  echo "⚠️  node-fetch not found, installing..."
  npm install node-fetch@2
fi

# Create fixed server.js with better header handling
echo "🔧 Creating improved server.js..."
cat > server.js << 'EOF'
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// * Enable CORS for all routes
app.use(cors());

// * Use native fetch if available (Node 18+), otherwise use node-fetch
let fetch;
try {
  // * Try native fetch first (Node 18+)
  if (typeof globalThis.fetch !== 'undefined') {
    fetch = globalThis.fetch;
    console.log('✅ Using native fetch (Node.js 18+)');
  } else {
    // * Fallback to node-fetch
    fetch = require('node-fetch');
    console.log('✅ Using node-fetch');
  }
} catch (e) {
  console.error('❌ Error loading fetch:', e.message);
  process.exit(1);
}

// * In-memory cache for Open-Meteo responses
const openMeteoCache = new Map();
const CACHE_DURATION = 5 * 60 * 1000; // * 5 minutes

// * Helper to get browser-like headers
function getBrowserHeaders() {
  return {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.rainviewer.com/',
    'Accept': 'image/png,image/webp,image/apng,image/*,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Sec-Fetch-Dest': 'image',
    'Sec-Fetch-Mode': 'no-cors',
    'Sec-Fetch-Site': 'cross-site',
    'DNT': '1',
    'Upgrade-Insecure-Requests': '1',
  };
}

// * Proxy endpoint for RainViewer tiles
app.get('/rainviewer/:timestamp/:z/:x/:y', async (req, res) => {
  try {
    const { timestamp, z, x, y } = req.params;
    const url = `https://tilecache.rainviewer.com/v2/radar/${timestamp}/${z}/${x}/${y}/2/1_1.png`;
    
    console.log(`[RainViewer] Fetching tile: ${timestamp}/${z}/${x}/${y}`);
    
    // * Get browser-like headers
    const headers = getBrowserHeaders();
    
    // * Fetch with proper headers
    const response = await fetch(url, { 
      headers,
      redirect: 'follow',
    });
    
    // * Log response details for debugging
    console.log(`[RainViewer] Response status: ${response.status} ${response.statusText}`);
    
    if (!response.ok) {
      // * Try to get error body
      let errorBody = '';
      try {
        errorBody = await response.text();
        console.error(`[RainViewer] Error body: ${errorBody.substring(0, 200)}`);
      } catch (e) {
        // Ignore
      }
      
      console.error(`[RainViewer] Failed to fetch tile ${timestamp}/${z}/${x}/${y}: ${response.status} ${response.statusText}`);
      return res.status(response.status).json({ 
        error: `Failed to fetch tile: ${response.status} ${response.statusText}`,
        details: errorBody.substring(0, 100)
      });
    }
    
    // * Get image buffer
    let buffer;
    if (response.buffer) {
      buffer = await response.buffer();
    } else if (response.arrayBuffer) {
      const arrayBuffer = await response.arrayBuffer();
      buffer = Buffer.from(arrayBuffer);
    } else {
      // * For native fetch, convert to buffer
      const arrayBuffer = await response.arrayBuffer();
      buffer = Buffer.from(arrayBuffer);
    }
    
    // * Set proper response headers
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'public, max-age=300'); // * Cache for 5 minutes
    res.setHeader('Content-Length', buffer.length);
    res.send(buffer);
    
    console.log(`[RainViewer] ✅ Success: ${timestamp}/${z}/${x}/${y} (${buffer.length} bytes)`);
  } catch (error) {
    console.error('[RainViewer] Exception:', error.message);
    console.error('[RainViewer] Stack:', error.stack);
    res.status(500).json({ error: error.message });
  }
});

// * Proxy endpoint for RainViewer weather maps (timestamps)
app.get('/rainviewer/weather-maps', async (req, res) => {
  try {
    const url = 'https://api.rainviewer.com/public/weather-maps.json';
    
    console.log(`[RainViewer] Fetching weather maps: ${url}`);
    
    // * Get browser-like headers
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://www.rainviewer.com/',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    
    const response = await fetch(url, { headers });
    
    console.log(`[RainViewer] Weather maps response: ${response.status} ${response.statusText}`);
    
    if (!response.ok) {
      let errorBody = '';
      try {
        errorBody = await response.text();
        console.error(`[RainViewer] Error body: ${errorBody.substring(0, 200)}`);
      } catch (e) {
        // Ignore
      }
      
      return res.status(response.status).json({ 
        error: `Failed to fetch weather maps: ${response.status} ${response.statusText}`,
        details: errorBody.substring(0, 100)
      });
    }
    
    const data = await response.json();
    
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.json(data);
    
    console.log(`[RainViewer] ✅ Weather maps fetched successfully`);
  } catch (error) {
    console.error('[RainViewer] Exception fetching weather maps:', error.message);
    console.error('[RainViewer] Stack:', error.stack);
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
    
    console.log(`[Open-Meteo] ✅ Success: ${latitude}, ${longitude}`);
  } catch (error) {
    console.error('[Open-Meteo] Error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// * Test endpoint to diagnose RainViewer issues
app.get('/test-rainviewer', async (req, res) => {
  try {
    const testUrl = 'https://tilecache.rainviewer.com/v2/radar/1766994000/7/107/59/2/1_1.png';
    console.log(`[Test] Fetching: ${testUrl}`);
    
    const headers = getBrowserHeaders();
    console.log(`[Test] Headers:`, JSON.stringify(headers, null, 2));
    
    const response = await fetch(testUrl, { headers });
    
    console.log(`[Test] Status: ${response.status} ${response.statusText}`);
    console.log(`[Test] Headers received:`, JSON.stringify(Object.fromEntries(response.headers.entries()), null, 2));
    
    if (!response.ok) {
      const errorText = await response.text();
      console.log(`[Test] Error body: ${errorText.substring(0, 500)}`);
    }
    
    res.json({
      status: response.status,
      statusText: response.statusText,
      headers: Object.fromEntries(response.headers.entries()),
      url: testUrl,
      ok: response.ok
    });
  } catch (error) {
    console.error('[Test] Exception:', error.message);
    res.status(500).json({ error: error.message, stack: error.stack });
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
echo "✅ Server.js updated with improved header handling!"
echo ""
echo "🔄 Restarting proxy server..."
pm2 restart weather-proxy

echo ""
echo "✅ Fix applied!"
echo ""
echo "📊 Next steps:"
echo "1. Check logs: pm2 logs weather-proxy"
echo "2. Test a tile: curl -v http://localhost:3000/rainviewer/1766994000/7/107/59 2>&1 | head -20"
echo "3. Look for detailed error messages in the logs"
echo ""

