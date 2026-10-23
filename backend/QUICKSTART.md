# Backend Quick Start Guide

## Prerequisites Check

```bash
# Check Docker
docker --version
docker-compose --version

# Check available resources
docker system info | grep -i memory
```

**Requirements:**
- Docker 20.10+
- Docker Compose 2.0+
- 4GB+ RAM available
- 10GB+ free disk space

## Start GraphHopper (5 minutes)

### 1. Navigate to Backend Directory

```bash
cd backend
```

### 2. Start Service

```bash
docker-compose up -d graphhopper
```

### 3. Monitor Startup

```bash
# Watch logs
docker-compose logs -f graphhopper
```

**First run:** Wait 30-60 minutes for OSM data download and processing.

**Subsequent runs:** Service starts in 1-2 minutes using cached data.

### 4. Verify Service

```bash
# Health check
curl http://localhost:8989/health

# Test route
curl "http://localhost:8989/route?point=14.5995,120.9842&point=14.6760,121.0437&vehicle=motorcycle&type=json"
```

## Common Commands

### Start Services
```bash
docker-compose up -d
```

### Stop Services
```bash
docker-compose down
```

### View Logs
```bash
docker-compose logs -f graphhopper
```

### Restart Service
```bash
docker-compose restart graphhopper
```

### Check Status
```bash
docker-compose ps
```

### Resource Usage
```bash
docker stats smartroad-graphhopper
```

## Troubleshooting

### Port Already in Use

```bash
# Find process using port 8989
netstat -ano | findstr :8989  # Windows
lsof -i :8989                  # Linux/Mac

# Change port in docker-compose.yml
ports:
  - "8990:8989"  # Use different external port
```

### Out of Memory

```bash
# Increase memory in docker-compose.yml
environment:
  - JAVA_OPTS=-Xmx4g -Xms4g  # Increase from 2g to 4g
```

### Reset Everything

```bash
# Stop and remove everything
docker-compose down -v

# Start fresh
docker-compose up -d
```

## Next Steps

1. ✅ GraphHopper is running on `http://localhost:8989`
2. ✅ SmartRoad Go API is running on `http://localhost:3000`
3. 📱 Flutter app connects to the API via `API_BASE_URL` (default `http://localhost:3000`)
4. 💾 PostgreSQL + PostGIS available for persistent storage

## Integration with Flutter

The Flutter app communicates through the SmartRoad API at `API_BASE_URL`:

```bash
# Windows
run.bat

# PowerShell
./run-with-env.ps1

# Custom API URL (e.g. for physical devices on local network)
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3000
```

**Note:** For physical devices, pass your machine's LAN IP address for `API_BASE_URL`. Routing calls will go to `http://<IP>:3000/api/routing/route`, which forwards to GraphHopper and applies safety checks.



