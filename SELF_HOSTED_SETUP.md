# SmartRoad Self-Hosted Backend & Proxy Setup Guide

Complete instructions for deploying the SmartRoad Go backend, weather proxy, and routing engine on your self-hosted server.

---

## 📋 Overview

The SmartRoad backend is built in **Go (Golang 1.24)** and containerized with Docker. It provides:
1. **Intelligent Routing Proxy:** Calls GraphHopper, validates HOA stickers, scores flood and road hazards, and returns straight-line fallbacks when offline.
2. **Weather & Tile Proxy:** Proxies and caches Open-Meteo forecasts, RainViewer radar tiles, and OpenWeatherMap layers with built-in CORS headers for Web and Mobile.
3. **Hazard Reporting & Community:** Realtime hazard reports, comments, likes, and ratings.
4. **Realtime Streaming:** WebSocket server on `/ws`.

---

## 🚀 Quick Setup with Docker Compose (Recommended)

### Step 1: Clone Repository on Server

```bash
git clone <your-repo-url> SmartRoad
cd SmartRoad/backend
```

### Step 2: Configure Environment

Copy and review environment variables:

```bash
cp api/.env.example api/.env
```

Ensure variables are set:
```env
PORT=3000
APP_ENV=production
GRAPH_HOPPER_URL=http://graphhopper:8989
JWT_SECRET=generate-a-strong-secret-key-here
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100
OPENWEATHERMAP_API_KEY=your_key_here  # Optional: for weather tile layers
```

### Step 3: Start All Services

```bash
docker-compose up -d
```

This starts:
- **`smartroad-api`** (Go Backend API on port 3000)
- **`smartroad-graphhopper`** (GraphHopper on port 8989)
- **`smartroad-postgres`** (PostGIS Database on port 5432)
- **`smartroad-redis`** (Cache on port 6379)

### Step 4: Verify Health

```bash
# API health check
curl http://localhost:3000/api/health

# Routing vehicle profiles
curl http://localhost:3000/api/routing/vehicles

# Weather current check (Manila coordinates)
curl "http://localhost:3000/api/weather/current?lat=14.5995&lon=120.9842"
```

---

## 🛠️ Alternative Setup: Running Go Binary Natively (Systemd)

If you prefer running the Go API natively on Linux without Docker:

### 1. Install Go

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y golang-go

# Verify Go installation (requires Go 1.22+)
go version
```

### 2. Build Static Binary

```bash
cd backend/api
go build -ldflags="-w -s" -o /usr/local/bin/smartroad-api ./cmd/server
```

### 3. Create Systemd Service

Create `/etc/systemd/system/smartroad-api.service`:

```ini
[Unit]
Description=SmartRoad Go Backend API
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/smartroad
ExecStart=/usr/local/bin/smartroad-api
Restart=always
RestartSec=5
Environment=PORT=3000
Environment=APP_ENV=production
Environment=GRAPH_HOPPER_URL=http://127.0.0.1:8989
Environment=JWT_SECRET=your-secure-jwt-secret

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now smartroad-api
sudo systemctl status smartroad-api
```

---

## 🔒 Optional: Set Up Nginx Reverse Proxy with HTTPS

To expose the Go API securely with SSL:

### 1. Nginx Configuration

Create `/etc/nginx/sites-available/smartroad-api`:

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/smartroad-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 2. SSL with Let's Encrypt

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.yourdomain.com
```

---

## 📱 Connect Flutter Application

Point your Flutter app to your self-hosted backend:

```bash
# Run with self-hosted API and Weather proxy
flutter run \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=WEATHER_PROXY_URL=https://api.yourdomain.com
```

For local testing with Android Emulator or Physical Device:
```bash
# Emulator (Android uses 10.0.2.2 for host localhost)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Physical device on same Wi-Fi
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3000
```

---

## ✅ Deployment Checklist

- [ ] Docker & Docker Compose installed (or Go 1.22+ installed)
- [ ] Backend services running (`docker-compose ps` shows all healthy)
- [ ] Port 3000 accessible through firewall (or behind Nginx on 80/443)
- [ ] Health check returns 200 (`curl http://<host>:3000/api/health`)
- [ ] Routing tested (`POST /api/routing/route`)
- [ ] Flutter app configured with `API_BASE_URL` and `WEATHER_PROXY_URL`
