# SmartRoad Backend Services

Backend infrastructure for the SmartRoad navigation app.

## Structure

```
backend/
├── api/                # SmartRoad Go API service (routing, auth, hazards, realtime)
├── graphhopper/        # Self-hosted routing engine (Docker + OSM Philippines)
├── database/           # PostgreSQL + PostGIS schema and database notes
└── docker-compose.yml  # Unified backend orchestration
```

## Services

### SmartRoad API (Go)

Main backend API service built with Golang:
- **Routing Proxy & Safety Scorer:** Proxies requests to GraphHopper, assesses flood and hazard danger along routes, provides straight-line fallback.
- **Authentication:** JWT tokens and bcrypt password hashing (`/api/auth/register`, `/api/auth/login`, `/api/auth/me`).
- **Hazards & Weather:** Hazard reports with spatial proximity and bounding box queries, weather alerts via Open-Meteo & PAGASA.
- **Community & HOAs:** Comments, likes, 5-star ratings, HOA access verification, village entrances.
- **Realtime Pub/Sub:** WebSocket streaming on `/ws`.
- **Route as a Product:** Save and discover community routes on `/api/v1/routes`.

**Status:** ✅ Active (Go 1.24)

**Documentation:** See [api/README.md](./api/README.md)

### GraphHopper Routing Engine

Self-hosted routing engine providing:
- Motorcycle, car, truck, and pedestrian routing profiles
- Toll avoidance
- Fastest route calculation using Philippines OpenStreetMap data

**Status:** ✅ Active

**Documentation:** See [graphhopper/README.md](./graphhopper/README.md)

### PostgreSQL Database + PostGIS

Database service for:
- User profiles & permissions
- Route as a Product (`saved_routes`)
- Hazards & community comments
- Village entrances and HOA sticker logs

**Status:** ✅ Configured via `docker-compose.yml` and SQL schemas

## Quick Start

### Start All Services

```bash
cd backend
docker-compose up -d
```

### Start Individual Service

```bash
# Start GraphHopper only
docker-compose up -d graphhopper

# Start API only
docker-compose up -d api
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
```

### Stop Services

```bash
docker-compose down
```

## Development Workflow

1. **Routing flow:** Flutter App → SmartRoad Go API (`http://localhost:3000/api/routing/route`) → GraphHopper (`http://graphhopper:8989`).
   *Note:* Flutter never calls GraphHopper directly.
2. If GraphHopper is offline or starting up, the Go API returns a smooth offline fallback route so clients can always navigate.
3. Local Go API can be run natively without Docker:
   ```bash
   cd backend/api
   go run ./cmd/server
   ```

## Environment Variables

Configure in `backend/api/.env` (or via docker-compose environment):

```env
# Server
PORT=3000
APP_ENV=development

# GraphHopper
GRAPH_HOPPER_URL=http://graphhopper:8989
GRAPH_HOPPER_TIMEOUT_MS=15000
GRAPH_HOPPER_MAX_RETRIES=2

# JWT Authentication
JWT_SECRET=your-secret-key-here
JWT_EXPIRES_IN_DAYS=7

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100
```

## Network Architecture

```
┌─────────────────────────────────┐
│          Flutter App            │
└────────────────┬────────────────┘
                 │ HTTP / WS
                 ▼
┌─────────────────────────────────┐
│     SmartRoad Go API (:3000)    │
│  - JWT Auth & User Profiles     │
│  - Safety & Hazard Scoring      │
│  - Realtime Pub/Sub (/ws)       │
│  - Route-as-a-Product (/api/v1) │
└──────┬──────────────────┬───────┘
       │                  │
       ▼ (internal)       ▼ (internal)
┌──────────────┐   ┌──────────────┐
│ GraphHopper  │   │  PostgreSQL  │
│ Routing:8989 │   │ + PostGIS    │
└──────────────┘   └──────────────┘
```

## Troubleshooting

### Port Conflicts

If ports are already in use:
```bash
# Check what's using the port
netstat -ano | findstr :8989  # Windows
lsof -i :8989                  # Linux/Mac

# Change port in docker-compose.yml
ports:
  - "8990:8989"  # Use 8990 externally
```

### Resource Issues

If services fail to start:
```bash
# Check Docker resources
docker stats

# Increase memory limits in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 4G
```

### Volume Issues

To reset volumes:
```bash
# Stop services
docker-compose down

# Remove volumes (WARNING: Data loss)
docker-compose down -v

# Start fresh
docker-compose up -d
```

## Production Considerations

**MVP Note:** Current setup is for local development only.

For production, consider:
- [ ] Reverse proxy (Nginx/Traefik)
- [ ] SSL/TLS certificates
- [ ] Environment-specific configurations
- [ ] Monitoring and logging (Prometheus/Grafana)
- [ ] Backup strategies
- [ ] Resource scaling
- [ ] Security hardening
- [ ] Rate limiting
- [ ] API authentication

## License

See individual service READMEs for license information.



