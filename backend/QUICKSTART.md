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

1. ✅ GraphHopper is running
2. 📱 Integrate with Flutter app (update routing service)
3. 🚧 Implement SmartRoad API (future)
4. 🚧 Add database service (future)

## Integration with Flutter

Update `lib/services/routing_service.dart`:

```dart
// Change GraphHopper URL to:
final String graphhopperUrl = 'http://localhost:8989';  // For emulator
// Or use your machine's IP for physical device:
// final String graphhopperUrl = 'http://192.168.1.100:8989';
```

**Note:** For physical devices, use your computer's local IP address instead of `localhost`.

