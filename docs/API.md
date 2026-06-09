# SmartRoad — API Documentation

> **Last updated:** 2026-06-09

---

## Overview

SmartRoad uses a combination of APIs:
1. **Supabase** — Authentication, database, storage, realtime (backend-as-a-service)
2. **GraphHopper** — Self-hosted routing engine
3. **Open-Meteo** — Weather data (free, no key required)
4. **OpenWeatherMap** — Weather tile layers (requires API key)
5. **TomTom** — Traffic tiles (requires API key)
6. **Nominatim** — Location search (OpenStreetMap)
7. **Overpass API** — Ambient POI data (OpenStreetMap)
8. **RainViewer** — Radar precipitation tiles
9. **Gemini** — AI sticker verification & commute guide augmentation
10. **Future: SmartRoad API** — Custom backend (Node.js/Go/Python)

---

## 1. Supabase API

**Base URL:** Configured via `SUPABASE_URL` environment variable

### Authentication

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/auth/v1/signup` | POST | Create account |
| `/auth/v1/token?grant_type=password` | POST | Sign in |
| `/auth/v1/logout` | POST | Sign out |
| `/auth/v1/user` | GET | Get current user |

### Database (via Supabase client)

| Table | Description | RLS |
|-------|-------------|-----|
| `profiles` | User profiles | Public read, owner write |
| `hazards` | Road hazard reports | Public read, auth insert |
| `hazard_comments` | Comments on hazards | Public read, auth insert |
| `hoas` | Homeowners associations | Public read, admin write |
| `user_stickers` | HOA sticker ownership | Owner read, admin write |
| `gate_access_logs` | Guard scan records | Owner read, guard insert |
| `hoa_day_passes` | Pay-per-day passes | Owner read, auth insert |
| `saved_routes` | Route as a product | Public read (if public), owner write |
| `route_purchases` | Route purchase records | Owner read, auth insert |
| `route_ratings` | Route ratings | Public read, auth insert |
| `route_shares` | Shareable route links | Owner read |
| `route_usage_log` | Route usage analytics | Owner read |
| `place_comments` | Place/landmark comments | Public read, auth insert |
| `place_images` | Place photos (with moderation) | Public read approved, owner insert |
| `place_likes` | Place likes | Public read, auth insert |
| `place_ratings` | Place ratings (1–5 stars) | Public read, auth insert |
| `fuel_stations` | Community fuel stations | Public read, anyone insert |
| `fuel_price_updates` | Fuel price submissions | Public read, RPC insert |
| `fuel_price_reports` | Incorrect price reports | Public read, anyone insert |
| `commute_ai_cache` | Gemini response cache | All authenticated |

---

## 2. GraphHopper Routing API

**Base URL:** `http://localhost:8989` (or via `GRAPH_HOPPER_URL` env)

### Route Calculation

```
GET /route
  ?point={lat},{lon}
  &point={lat},{lon}
  &vehicle={motorcycle|car|truck|foot}
  &type=json
  &instructions=true
  &calc_points=true
  &points_encoded=false
```

| Parameter | Description | Values |
|-----------|-------------|--------|
| `point` | Start, end, and waypoint coordinates | `lat,lon` |
| `vehicle` | Vehicle profile | `motorcycle`, `car`, `truck`, `foot` |
| `type` | Response format | `json` |
| `instructions` | Include turn-by-turn | `true`, `false` |
| `calc_points` | Include geometry | `true`, `false` |
| `points_encoded` | Encoded polyline | `true` (Google), `false` (GeoJSON) |

### Response

```json
{
  "paths": [{
    "distance": 1900.0,
    "time": 138000,
    "points": {
      "coordinates": [[120.9883, 14.4244], ...]
    },
    "instructions": [
      {"text": "Continue on ...", ...}
    ]
  }]
}
```

### Health Check

```
GET /health
```

---

## 3. Open-Meteo Weather API

**Base URL:** `https://api.open-meteo.com/v1`

### Current Weather

```
GET /forecast
  ?latitude={lat}
  &longitude={lon}
  &current=temperature_2m,precipitation,weather_code
  &timezone=Asia/Manila
```

**Note:** Free, no API key required. Limited to current weather per point. For tile layers, use OpenWeatherMap.

---

## 4. OpenWeatherMap Tile API

**Base URL:** `https://tile.openweathermap.org/map/{layer}/{z}/{x}/{y}.png`

| Layer | URL Path | Description |
|-------|----------|-------------|
| Precipitation | `/map/precipitation_new/{z}/{x}/{y}.png` | Rain radar |
| Clouds | `/map/clouds_new/{z}/{x}/{y}.png` | Cloud coverage |
| Temperature | `/map/temp_new/{z}/{x}/{y}.png` | Heat map |

**Auth:** `?appid={API_KEY}` — required for all tile requests

---

## 5. TomTom Traffic API

**Base URL:** `https://api.tomtom.com/traffic/map/4/tile/flow/relative/{z}/{x}/{y}.png`

**Auth:** `?key={TOMTOM_API_KEY}`

**Color Legend:**
- Green: Free flow
- Yellow: Moderate traffic
- Red: Heavy traffic
- Dark red: Standstill / very slow

---

## 6. Nominatim Search API

**Base URL:** `https://nominatim.openstreetmap.org`

### Search

```
GET /search
  ?format=jsonv2
  &q={query}
  &limit=12
  &bounded=1
  &viewbox={west},{north},{east},{south}
  &countrycodes=ph
  &email=contact@smartroad.app
```

**Rate Limit:** 1 request per second (enforced client-side).

---

## 7. Overpass API (Ambient POI)

**Base URL:** `https://overpass-api.de/api/interpreter`

### Query

```
POST /api/interpreter
Body: [out:json];(node[amenity=...](BBOX););out center;
```

Queries OSM by tag category within a bounding box. Zoom-tiered for performance.

---

## 8. RainViewer API

**Base URL:** `https://api.rainviewer.com/public/weather-maps.json`

Returns available radar frame timestamps. Tile URL format:
`https://tilecache.rainviewer.com/v2/radar/{timestamp}/256/{z}/{x}/{y}/2/1_1.png`

---

## 9. Gemini AI API

**Base URL:** `https://generativelanguage.googleapis.com/v1beta`

### Sticker Verification
```json
POST /models/gemini-2.5-flash:generateContent?key={API_KEY}
{
  "contents": [{
    "parts": [
      {"text": "Does this image contain a valid HOA sticker?"},
      {"inline_data": {"mime_type": "image/jpeg", "data": "base64..."}}
    ]
  }]
}
```

### Commute Guide Augmentation
```json
POST /models/gemini-2.5-flash:generateContent?key={API_KEY}
{
  "contents": [{
    "parts": [
      {"text": "Tell the rider where to board..."}
    ]
  }]
}
```

---

## 10. Future: SmartRoad API

**Planned endpoints** (not yet implemented):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `POST /api/auth/login` | POST | Custom authentication |
| `GET /api/routes/:id` | GET | Get route details |
| `POST /api/routes` | POST | Create new route |
| `GET /api/hazards` | GET | List hazards near location |
| `POST /api/hazards` | POST | Report hazard |
| `GET /api/marketplace` | GET | Browse route marketplace |
| `POST /api/marketplace/purchase` | POST | Purchase a route |

---

## Environment Variables Reference

| Variable | Required | API | Default |
|----------|----------|-----|---------|
| `SUPABASE_URL` | No (demo) | Supabase | `''` |
| `SUPABASE_ANON_KEY` | No (demo) | Supabase | `''` |
| `GEMINI_API_KEY` | No | Gemini | `''` |
| `OPENWEATHERMAP_API_KEY` | No | OpenWeatherMap | `''` |
| `TOMTOM_API_KEY` | No | TomTom | `''` |
| `GRAPH_HOPPER_URL` | No | GraphHopper | `http://localhost:8989` |
| `ENABLE_GRAPH_HOPPER_WEB` | No | GraphHopper | `false` |
| `WEATHER_PROXY_URL` | No | Weather proxy | `''` |
| `ENABLE_OVERPASS_WEB_POI` | No | Overpass | `false` |
| `ENABLE_OVERPASS_WEB_FUEL` | No | Overpass | `true` |

---

*"Be Heedful on the Road" — **SmartRoad**, a product of **The Heedful** 🇵🇭*
