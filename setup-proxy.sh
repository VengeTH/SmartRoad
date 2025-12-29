#!/bin/bash

# Weather Proxy Quick Setup Script
# Run this on your self-hosted server

echo "🌤️  Weather Proxy Setup Script"
echo "================================"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Installing..."
    
    # Detect OS and install Node.js
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt install -y nodejs
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL
        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
        sudo yum install -y nodejs
    else
        echo "❌ Unsupported OS. Please install Node.js manually."
        exit 1
    fi
else
    echo "✅ Node.js found: $(node --version)"
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Please install Node.js."
    exit 1
else
    echo "✅ npm found: $(npm --version)"
fi

# Create project directory
echo ""
echo "📁 Creating project directory..."
mkdir -p ~/weather-proxy
cd ~/weather-proxy

# Create package.json
echo "📝 Creating package.json..."
cat > package.json << 'EOF'
{
  "name": "weather-proxy",
  "version": "1.0.0",
  "description": "Weather API proxy for SmartRoad app",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "node-fetch": "^2.7.0",
    "cors": "^2.8.5"
  }
}
EOF

# Create server.js
echo "📝 Creating server.js..."
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
    
    const response = await fetch(url);
    
    if (!response.ok) {
      return res.status(response.status).json({ error: 'Failed to fetch tile' });
    }
    
    const buffer = await response.buffer();
    
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'public, max-age=300'); // * Cache for 5 minutes
    res.send(buffer);
    
    console.log(`[RainViewer] Success: ${timestamp}/${z}/${x}/${y}`);
  } catch (error) {
    console.error('[RainViewer] Error:', error.message);
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
    
    const response = await fetch(url);
    
    if (!response.ok) {
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

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
npm install

# Install PM2 globally
echo ""
echo "📦 Installing PM2..."
sudo npm install -g pm2

# Start server with PM2
echo ""
echo "🚀 Starting server with PM2..."
pm2 start server.js --name weather-proxy

# Save PM2 configuration
echo ""
echo "💾 Saving PM2 configuration..."
pm2 save

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "✅ Setup Complete!"
echo "=================="
echo ""
echo "📍 Server IP: $SERVER_IP"
echo "🌐 Proxy URL: http://$SERVER_IP:3000"
echo ""
echo "📝 Next steps:"
echo "1. Configure firewall: sudo ufw allow 3000/tcp"
echo "2. Test health endpoint: curl http://$SERVER_IP:3000/health"
echo "3. In Flutter, run: flutter run --dart-define=WEATHER_PROXY_URL=http://$SERVER_IP:3000"
echo ""
echo "📊 Useful commands:"
echo "  pm2 status          - Check server status"
echo "  pm2 logs weather-proxy - View logs"
echo "  pm2 restart weather-proxy - Restart server"
echo "  pm2 stop weather-proxy - Stop server"
echo ""
