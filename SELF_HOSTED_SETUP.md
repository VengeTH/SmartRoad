# Self-Hosted Backend Proxy Setup Guide
## Complete Beginner-Friendly Instructions

This guide will help you set up a weather proxy server on your self-hosted server, even if you've never done this before!

---

## 📋 Prerequisites

Before starting, make sure you have:
- ✅ A self-hosted server (Linux/Ubuntu recommended)
- ✅ SSH access to your server
- ✅ Basic terminal/command line knowledge

---

## 🚀 Step-by-Step Setup

### Step 1: Connect to Your Server

Open your terminal (or PowerShell on Windows) and connect:

```bash
ssh username@your-server-ip
# Example: ssh root@192.168.1.100
```

---

### Step 2: Install Node.js

**Check if Node.js is already installed:**
```bash
node --version
```

**If it shows a version (like v18.x.x or v20.x.x), skip to Step 3.**

**If it says "command not found", install Node.js:**

**For Ubuntu/Debian:**
```bash
# Update package list
sudo apt update

# Install Node.js (version 18 or higher)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node --version
npm --version
```

**For CentOS/RHEL:**
```bash
# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# Verify installation
node --version
npm --version
```

---

### Step 3: Create Project Directory

```bash
# Create a directory for your weather proxy
mkdir ~/weather-proxy
cd ~/weather-proxy
```

---

### Step 4: Create Backend Files

**Create `package.json` file:**
```bash
nano package.json
```

**Paste this content:**
```json
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
```

**Save and exit:** Press `Ctrl+X`, then `Y`, then `Enter`

---

**Create `server.js` file:**
```bash
nano server.js
```

**Paste this content:**
```javascript
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
```

**Save and exit:** Press `Ctrl+X`, then `Y`, then `Enter`

---

### Step 5: Install Dependencies

```bash
npm install
```

This will download all required packages (express, node-fetch, cors).

---

### Step 6: Test the Server (Optional but Recommended)

**Start the server:**
```bash
node server.js
```

You should see:
```
🌤️  Weather Proxy Server running on port 3000
📍 Health check: http://localhost:3000/health
🌧️  RainViewer: http://localhost:3000/rainviewer/:timestamp/:z/:x/:y
🌡️  Open-Meteo: http://localhost:3000/open-meteo/forecast
```

**Test health endpoint (in another terminal or browser):**
```bash
curl http://localhost:3000/health
```

**Stop the server:** Press `Ctrl+C`

---

### Step 7: Set Up PM2 (Keeps Server Running Forever)

**Install PM2:**
```bash
sudo npm install -g pm2
```

**Start server with PM2:**
```bash
pm2 start server.js --name weather-proxy
```

**Save PM2 configuration (so it auto-starts on reboot):**
```bash
pm2 save
pm2 startup
```

**Useful PM2 commands:**
```bash
pm2 status          # Check server status
pm2 logs weather-proxy    # View logs
pm2 restart weather-proxy # Restart server
pm2 stop weather-proxy    # Stop server
```

---

### Step 8: Configure Firewall

**If you have a firewall, allow port 3000:**

**For UFW (Ubuntu):**
```bash
sudo ufw allow 3000/tcp
sudo ufw reload
```

**For firewalld (CentOS/RHEL):**
```bash
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
```

---

### Step 9: Get Your Server URL

**Find your server's IP address:**
```bash
hostname -I
# or
ip addr show
```

**Your proxy URL will be:**
```
http://YOUR-SERVER-IP:3000
# Example: http://192.168.1.100:3000
```

**If you have a domain name:**
```
http://your-domain.com:3000
# or if you set up reverse proxy:
https://api.your-domain.com
```

---

### Step 10: Test Proxy Endpoints

**Test from your local computer (replace with your server IP):**
```bash
# Test health endpoint
curl http://YOUR-SERVER-IP:3000/health

# Test Open-Meteo proxy
curl "http://YOUR-SERVER-IP:3000/open-meteo/forecast?latitude=14.5995&longitude=120.9842&current=temperature_2m"

# Test RainViewer proxy (replace timestamp/z/x/y with real values)
curl http://YOUR-SERVER-IP:3000/rainviewer/1766993400/7/106/58
```

**If these return data (not errors), your proxy is working! ✅**

---

### Step 11: Configure Flutter App

**Option A: Command Line (Development)**
```bash
flutter run --dart-define=WEATHER_PROXY_URL=http://YOUR-SERVER-IP:3000
```

**Option B: Android Studio**
1. Run > Edit Configurations
2. Additional run args: `--dart-define=WEATHER_PROXY_URL=http://YOUR-SERVER-IP:3000`

**Option C: VS Code**
Add to `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=WEATHER_PROXY_URL=http://YOUR-SERVER-IP:3000"
      ]
    }
  ]
}
```

**Option D: Production Build**
For release builds, you'll need to set this in your build configuration or CI/CD pipeline.

---

## 🔒 Optional: Set Up HTTPS (Recommended for Production)

If you want to use HTTPS instead of HTTP:

### Option 1: Use Nginx Reverse Proxy (Recommended)

**Install Nginx:**
```bash
sudo apt install nginx
```

**Create Nginx config:**
```bash
sudo nano /etc/nginx/sites-available/weather-proxy
```

**Paste this (replace YOUR-DOMAIN.com):**
```nginx
server {
    listen 80;
    server_name YOUR-DOMAIN.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

**Enable site:**
```bash
sudo ln -s /etc/nginx/sites-available/weather-proxy /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

**Set up SSL with Let's Encrypt:**
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d YOUR-DOMAIN.com
```

**Then use HTTPS URL in Flutter:**
```
https://YOUR-DOMAIN.com
```

---

## 🐛 Troubleshooting

### Server won't start
```bash
# Check if port 3000 is already in use
sudo lsof -i :3000

# Kill process if needed
sudo kill -9 PID_NUMBER
```

### Can't connect from Flutter app
- ✅ Check firewall allows port 3000
- ✅ Verify server IP is correct
- ✅ Test endpoints with `curl` from your computer
- ✅ Check PM2 logs: `pm2 logs weather-proxy`

### CORS errors
- ✅ Make sure `cors()` middleware is in `server.js`
- ✅ Check server logs for errors

### Rate limit errors
- ✅ Backend caching should help
- ✅ Check Open-Meteo API status
- ✅ Consider adding request throttling

---

## 📝 Quick Reference

**Start server:**
```bash
pm2 start server.js --name weather-proxy
```

**View logs:**
```bash
pm2 logs weather-proxy
```

**Restart server:**
```bash
pm2 restart weather-proxy
```

**Stop server:**
```bash
pm2 stop weather-proxy
```

**Check status:**
```bash
pm2 status
```

---

## ✅ Checklist

- [ ] Node.js installed (`node --version` works)
- [ ] Project directory created (`~/weather-proxy`)
- [ ] `package.json` and `server.js` files created
- [ ] Dependencies installed (`npm install`)
- [ ] Server starts without errors (`node server.js`)
- [ ] PM2 installed and server running (`pm2 status`)
- [ ] Firewall configured (port 3000 open)
- [ ] Endpoints tested with `curl`
- [ ] Flutter app configured with `WEATHER_PROXY_URL`
- [ ] Weather layers work in Flutter app!

---

## 🎉 You're Done!

Once you complete these steps, your weather layers will work on all platforms including web!

If you get stuck at any step, check the logs:
```bash
pm2 logs weather-proxy
```

Good luck! 🚀
