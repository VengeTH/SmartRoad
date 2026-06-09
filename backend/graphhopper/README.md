# GraphHopper Routing Engine

Self-hosted GraphHopper routing engine for SmartRoad navigation app.

## Overview

This service provides routing capabilities for the SmartRoad mobile app, specifically optimized for:
- **Motorcycle routing** (primary use case)
- **Toll avoidance** (avoids toll roads)
- **Fastest route calculation**

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available for Docker
- 10GB+ free disk space (for OSM data and graph cache)
- Internet connection (for initial OSM data download)

## Quick Start

### 1. Start GraphHopper Service

```bash
cd backend/graphhopper
docker-compose up -d
```

### 2. Wait for Initial Processing

**First run only:** GraphHopper will:
1. Download Philippines OSM data (~500MB-1GB)
2. Process the routing graph (30-60 minutes depending on hardware)
3. Start the API server

You can monitor progress:
```bash
docker-compose logs -f graphhopper
```

### 3. Verify Service is Running

Once the health check passes, test the API:

```bash
# Health check
curl http://localhost:8989/health

# Test route (Manila to Quezon City example)
curl "http://localhost:8989/route?point=14.5995,120.9842&point=14.6760,121.0437&vehicle=motorcycle&type=json"
```

## API Endpoints

### Health Check
```
GET http://localhost:8989/health
```

### Route Calculation
```
GET http://localhost:8989/route
```

**Parameters:**
- `point` (required): Start point as `lat,lng` (can specify multiple points)
- `vehicle` (required): Vehicle type (`motorcycle`, `car`, `truck`, `foot`)
- `type` (optional): Response format (`json` or `gpx`, default: `json`)
- `points_encoded` (optional): `true` (default) or `false`
- `instructions` (optional): `true` (default) or `false`
- `calc_points` (optional): `true` (default) or `false`

**Vehicle Profiles:**

| Profile | GraphHopper Vehicle | Description |
|---------|-------------------|-------------|
| `motorcycle` | motorcycle | Standard motorcycle (≤399cc) |
| `big_bike` | motorcycle | Large motorcycle (400cc+) |
| `car` | car | Private vehicle |
| `truck` | truck | Large vehicle |
| `pedestrian` | foot | Walking |
| `delivery_rider` | motorcycle | Shortcut + delivery entrance priority (Flutter-side) |
| `flood_safe` | car | Flood-avoidant routing (Flutter-side) |
| `weather_safe` | car | Weather-aware routing (Flutter-side) |
| `hoa_access` | car | HOA sticker-based routing (Flutter-side) |

**Example:**
```bash
# Standard route
curl "http://localhost:8989/route?point=14.5995,120.9842&point=14.6760,121.0437&vehicle=motorcycle&type=json&instructions=true"

# Long distance test
curl "http://localhost:8989/route?point=14.5995,120.9842&point=13.7563,121.0583&vehicle=car&type=json"
```

### Route Optimization (Future Feature)
```
POST http://localhost:8989/route
```
*Not implemented in MVP - will support multiple waypoints optimization*

## Configuration

### Environment Variables

Edit `docker-compose.yml` to customize:

- **`PBF_URL`**: OSM data source (default: Philippines)
- **`JAVA_OPTS`**: JVM memory settings (default: `-Xmx2g -Xms2g`)
- **`GRAPHOPPER_AVOID_TOLL`**: Enable/disable toll avoidance (default: `true`)
- **`GRAPHOPPER_WEB_CORS`**: CORS settings (default: `*` for development)

### Volume Management

Graph data is stored in Docker volume `graphhopper-data`. To reset:

```bash
# Stop service
docker-compose down

# Remove volume (WARNING: Will require re-processing)
docker volume rm graphhopper_graphhopper-data

# Start again
docker-compose up -d
```

## Integration with SmartRoad API

**FUTURE FEATURE:** The SmartRoad API (`backend/api/`) will:
1. Receive routing requests from Flutter app
2. Call GraphHopper API
3. Apply business logic (permissions, HOA restrictions, etc.)
4. Return formatted response to mobile app

**Current MVP:** Flutter app can call GraphHopper directly for basic routing.

## Performance Notes

- **First startup**: 30-60 minutes (OSM download + graph processing)
- **Subsequent startups**: 1-2 minutes (uses cached graph)
- **Route calculation**: < 1 second for typical routes
- **Memory usage**: ~2-4GB RAM
- **Disk usage**: ~5-10GB (OSM data + graph cache)

## Troubleshooting

### Service won't start
```bash
# Check logs
docker-compose logs graphhopper

# Verify Docker has enough resources
docker stats
```

### Out of memory errors
Increase `JAVA_OPTS` in `docker-compose.yml`:
```yaml
- JAVA_OPTS=-Xmx4g -Xms4g
```

### Slow route calculations
- Ensure graph cache volume exists and is mounted
- Check system resources (CPU/RAM)
- Consider using a more powerful machine for production

### CORS errors from Flutter app
Update `GRAPHOPPER_WEB_CORS` in `docker-compose.yml`:
```yaml
- GRAPHOPPER_WEB_CORS=https://your-domain.com
```

## Future Enhancements (Not in MVP)

### Phase 2: Permission-Based Routing
- User authentication integration
- Route access control based on user permissions
- HOA-restricted area routing

### Phase 3: Route Selling
- Premium route access
- Route monetization logic
- Payment integration

### Phase 4: HOA Sticker Logic
- Sticker-based route access
- Gate pass integration
- Restricted community routing

### Phase 5: Advanced Features
- Multi-waypoint optimization
- Real-time traffic integration
- Custom routing profiles
- Route caching layer (Redis)
- Route analytics

## References

- [GraphHopper Documentation](https://www.graphhopper.com/docs/)
- [GraphHopper GitHub](https://github.com/graphhopper/graphhopper)
- [OpenStreetMap Philippines Data](https://download.geofabrik.de/asia/philippines.html)
- [Docker GraphHopper Image](https://github.com/gis-ops/docker-graphhopper)

## License

GraphHopper is licensed under Apache License 2.0.
OpenStreetMap data is licensed under ODbL.



