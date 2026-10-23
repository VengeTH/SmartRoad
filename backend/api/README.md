# SmartRoad Backend API (Go)

High-performance Golang backend service for SmartRoad navigation, routing, authentication, hazard reporting, community interactions, and route marketplace.

## Architecture

```
Flutter App / Web Clients
         │
         ▼
SmartRoad Go API (port 3000)
 ├── Middleware: CORS, Security headers, Rate Limiting, Logging, JWT Auth
 ├── Routing:
 │    └── GraphHopper Routing Engine (port 8989) with straight-line fallback
 │    └── Smart Routing: Flood zone & hazard risk scoring, HOA sticker check
 ├── Auth & Profiles: JWT-based authentication & user profiles
 ├── Hazards: Road hazard reports with bounding box and proximity queries
 ├── Weather: Open-Meteo & PAGASA proxy with in-memory caching
 ├── Community: Comments, likes, 5-star ratings
 ├── Village Entrances: Verified HOA entry points & scam-pin mitigation
 ├── Realtime: WebSocket hub on `/ws` (pub/sub for hazards, ratings, comments)
 └── Route as a Product: Save and discover community routes (`/api/v1/routes`)
```

## Tech Stack

- **Language:** Go 1.24+ (Standard library `net/http` with Go 1.22+ pattern routing)
- **Concurrency & Realtime:** Gorilla WebSocket (`/ws` channel pub/sub)
- **Security & Tokens:** `golang-jwt/jwt/v5`, `golang.org/x/crypto/bcrypt`
- **Routing Engine:** GraphHopper (self-hosted Docker container with OSM Philippines PBF)
- **Containerization:** Multi-stage lightweight Docker image (`alpine:3.20`)

## Endpoints Summary

### System & Health
- `GET /api/health` — API health check and version info

### Routing & Navigation
- `POST /api/routing/route` — Calculate navigation route (GraphHopper + fallback + safety score)
- `GET /api/routing/vehicles` — List supported vehicle profiles (car, motorcycle, big bike, truck, etc.)
- `GET /api/routing/health` — Routing subsystem health

### Authentication & Profiles
- `POST /api/auth/register` — Register a new user account
- `POST /api/auth/login` — Sign in and receive JWT token
- `GET /api/auth/me` — Current authenticated user profile (Bearer token required)
- `GET /api/profile` — Get profile details (Bearer token required)
- `PUT /api/profile` — Update user profile (Bearer token required)

### Hazards & Alerts
- `GET /api/hazards` — List hazards with pagination & filters (`type`, `severity`, `userId`)
- `POST /api/hazards` — Report a road hazard (emits `hazards:all` WebSocket event)
- `GET /api/hazards/nearby` — Find hazards near coordinates (`lat`, `lng`, `radiusKm`)
- `GET /api/hazards/bounds` — Find hazards within bounding box (`minLat`, `maxLat`, `minLng`, `maxLng`)
- `GET /api/hazards/:id` — Retrieve hazard by ID
- `PUT /api/hazards/:id` — Update hazard (owner or admin)
- `DELETE /api/hazards/:id` — Remove hazard (owner or admin)

### Weather
- `GET /api/weather/current` — Current weather by coordinates (`lat`, `lon`), cached 10 mins
- `GET /api/weather/alerts` — 3-day precipitation and severe weather warnings

### Community (Comments, Likes, Ratings)
- `GET /api/community/comments` — List comments (`parentType`, `parentId`)
- `POST /api/community/comments` — Add comment (Bearer token required)
- `PUT /api/community/comments/:id` — Edit comment (owner or admin)
- `DELETE /api/community/comments/:id` — Delete comment (owner or admin)
- `POST /api/community/likes/toggle` — Toggle like for item
- `GET /api/community/likes/count` — Get like count
- `POST /api/community/ratings` — Submit 1–5 star rating
- `GET /api/community/ratings/summary` — Aggregate rating and count
- `GET /api/community/ratings/mine` — Current user rating

### HOA & Entrances
- `GET /api/hoas` — List active homeowner associations
- `POST /api/hoas/register` — Register HOA (Bearer token required)
- `GET /api/hoas/:id` — HOA details
- `GET /api/entrances` — List subdivision gates and entrances
- `POST /api/entrances` — Submit subdivision entrance (Bearer token required)
- `PUT /api/entrances/:id/verify` — Admin gate verification
- `GET /api/entrances/nearby` — Entrances near a point

### Flood Zones
- `GET /api/flood-zones` — List monitored flood zones
- `POST /api/flood-zones` — Register flood zone (Bearer token required)
- `GET /api/flood-zones/nearby` — Check if point is inside active flood risk zone

### Route as a Product (`/api/v1/routes`)
- `POST /api/v1/routes/save` — Save recorded route
- `GET /api/v1/routes/discover` — Search routes by proximity (`lat`, `lng`, `radius_meters`, `tags`)
- `GET /api/v1/routes/:id` — Get route details

### Realtime Pub/Sub (`/ws`)
Connect via WebSocket to `ws://<host>:3000/ws`:
```json
{ "type": "subscribe", "channel": "hazards:all" }
{ "type": "ping" }
```

## Local Development

### Prerequisites
- Go 1.22+
- Docker & Docker Compose (for GraphHopper, Postgres, Redis)

### Running Locally
```bash
# In backend/api
go run ./cmd/server
```

### Running Tests
```bash
# In backend/api
go test ./... -v
```

### Building Binary
```bash
# Linux
CGO_ENABLED=0 GOOS=linux go build -o bin/server ./cmd/server

# Windows
go build -o bin/server.exe ./cmd/server
```

## Docker Deployment

Build and run with docker-compose:
```bash
cd backend
docker-compose up -d --build api
```



