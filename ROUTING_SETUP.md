# SmartRoad MVP Routing Setup Guide

This guide explains how to set up and run the SmartRoad routing system using GraphHopper.

## Architecture

```
Flutter App → Backend API (Node.js) → GraphHopper (Self-hosted)
```

## Prerequisites

- Docker and Docker Compose
- Node.js 18+ (for local backend development)
- 4GB+ RAM (for GraphHopper)

## Quick Start

### 1. Start Services with Docker Compose

```bash
docker-compose up -d
```

This will:
- Download and start GraphHopper (first run will download Philippines OSM data)
- Start the backend API server on port 3000
- GraphHopper will be available on port 8989

**Note:** First run will take 10-30 minutes as GraphHopper downloads and imports Philippines OSM data.

### 2. Verify Services

Check GraphHopper:
```bash
curl http://localhost:8989/info
```

Check Backend:
```bash
curl http://localhost:3000/health
```

### 3. Test Route Calculation

```bash
curl -X POST http://localhost:3000/route \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"lat": 14.5995, "lng": 120.9842},
    "destination": {"lat": 14.5500, "lng": 121.0000},
    "mode": "car",
    "avoid_tolls": false
  }'
```

## Manual Setup (Without Docker)

### 1. Setup GraphHopper

1. Download GraphHopper:
```bash
cd graphhopper
wget https://github.com/graphhopper/graphhopper/releases/download/8.0/graphhopper-web-8.0.jar
```

2. Download Philippines OSM data:
```bash
wget https://download.geofabrik.de/asia/philippines-latest.osm.pbf
```

3. Import and start GraphHopper:
```bash
java -Xmx2g -Xms2g \
  -Ddw.graphhopper.datareader.file=philippines-latest.osm.pbf \
  -Ddw.graphhopper.graph.location=graph-cache \
  -jar graphhopper-web-8.0.jar \
  server config.yml
```

### 2. Setup Backend

1. Install dependencies:
```bash
cd backend
npm install
```

2. Copy environment file:
```bash
cp .env.example .env
```

3. Start server:
```bash
npm start
```

## Configuration

### Backend Configuration

Edit `backend/.env`:
```
PORT=3000
GRAPHHOPPER_URL=http://localhost:8989
```

### GraphHopper Configuration

Edit `graphhopper/config.yml` to customize:
- Routing profiles (car, motorcycle)
- Toll avoidance settings
- Memory allocation

## API Endpoints

### POST /route

Calculate route between two points.

**Request:**
```json
{
  "origin": {"lat": 14.5995, "lng": 120.9842},
  "destination": {"lat": 14.5500, "lng": 121.0000},
  "mode": "car" | "motorcycle",
  "avoid_tolls": true | false
}
```

**Response:**
```json
{
  "routes": [
    {
      "geometry": [[lat, lng], ...],
      "distance_meters": 12345,
      "duration_seconds": 900,
      "profile": "car"
    }
  ]
}
```

### GET /health

Health check endpoint.

## Flutter Integration

The Flutter app uses `RoutingService` to call the backend API.

Update `AppConstants.routingApiUrl` if backend is not on localhost:3000.

## Troubleshooting

### GraphHopper not starting

- Check available RAM (needs 2GB+)
- Verify OSM file is downloaded
- Check logs: `docker logs smartroad-graphhopper`

### Backend connection errors

- Verify GraphHopper is running: `curl http://localhost:8989/info`
- Check backend logs: `docker logs smartroad-backend`
- Verify environment variables in `.env`

### Route calculation fails

- Check GraphHopper logs for errors
- Verify coordinates are within Philippines bounds
- Try with `avoid_tolls: false` first

## Production Deployment

1. **Get GraphHopper API key** (optional, for hosted GraphHopper)
2. **Use production OSM data** (updated regularly)
3. **Set up reverse proxy** (nginx) for backend
4. **Configure CORS** properly for production domain
5. **Add rate limiting** to backend API
6. **Monitor GraphHopper memory usage**

## MVP Features Only

This implementation includes ONLY:
- ✅ Basic routing (origin → destination)
- ✅ Car and Motorcycle profiles
- ✅ Toll avoidance toggle
- ✅ 1 alternative route
- ✅ Distance and duration calculation

**NOT included (future features):**
- ❌ Route selling/marketplace
- ❌ HOA sticker avoidance
- ❌ Flood-aware routing
- ❌ Multi-criteria scoring
- ❌ AI prediction
- ❌ Village pass system
- ❌ Hazard-based rerouting

## Testing

Test route calculation:
```bash
# Car route with tolls
curl -X POST http://localhost:3000/route \
  -H "Content-Type: application/json" \
  -d '{"origin":{"lat":14.5995,"lng":120.9842},"destination":{"lat":14.5500,"lng":121.0000},"mode":"car","avoid_tolls":false}'

# Motorcycle route avoiding tolls
curl -X POST http://localhost:3000/route \
  -H "Content-Type: application/json" \
  -d '{"origin":{"lat":14.5995,"lng":120.9842},"destination":{"lat":14.5500,"lng":121.0000},"mode":"motorcycle","avoid_tolls":true}'
```

## Support

For issues or questions, check:
- GraphHopper docs: https://www.graphhopper.com/docs/
- Backend logs: `docker logs smartroad-backend`
- GraphHopper logs: `docker logs smartroad-graphhopper`





