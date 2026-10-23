# SmartRoad Development Bible

> **Google Maps** = shortest route
> **Waze** = crowd traffic
> **SmartRoad** = local intelligence routing

**Core mission:**
- Find routes others don't know
- Find routes maps don't show
- Find routes communities trust
- Find routes that remain usable during disasters

---

## Stage 0 — Define the Product

**Goal:** Prevent scope confusion before writing code.

### Create Documents

| Document | Status | Notes |
|----------|--------|-------|
| `/docs/Vision.md` | ✅ Combined | Merged into `docs/vision-mission.md` |
| `/docs/Mission.md` | ✅ Combined | Merged into `docs/vision-mission.md` |
| `/docs/Features.md` | ❌ Not created | — |
| `/docs/BusinessModel.md` | ✅ Done | `docs/business-model.md` covers model, revenue & monetization |
| `/docs/Monetization.md` | 🟡 Partial | Covered within `business-model.md` |
| `/docs/Roadmap.md` | ❌ Not created | — |
| `/docs/UserTypes.md` | ❌ Not created | User roles exist in code (profiles table, roles array) |
| `/docs/SystemArchitecture.md` | ❌ Not created | — |

### Define User Types

- ✅ Driver
- ✅ Motorcycle Rider
- ✅ Delivery Rider
- ✅ Commuter
- ✅ Traveler
- ✅ HOA Admin
- ✅ LGU Admin
- ✅ Emergency Responder
- ✅ Route Creator
- ✅ Route Seller
- ✅ Route Buyer
- ✅ Moderator
- ✅ Super Admin

---

## Stage 1 — Server Foundation

**Goal:** Create permanent infrastructure.

### Server (Current Dell Server)

- [ ] Document: CPU, RAM, Storage, Internet, Power Backup

### Install

- [x] Docker _(confirmed: `docker-compose.yml`, `backend/api/Dockerfile` exist)_
- [x] Docker Compose _(confirmed: `backend/docker-compose.yml` exists)_
- [x] Git _(confirmed: `.git` directory exists)_
- [ ] Nginx _(❌ `nginx.conf` not found in repo — no config committed)_
- [x] Go / Golang _(confirmed: `backend/api/go.mod` exists; Go 1.24 backend service)_
- [x] PostgreSQL _(confirmed: docker-compose postgres service + schema files exist)_
- [x] Redis _(✅ now configured in `docker-compose.yml` — redis:7-alpine service)_
- [x] Cloudflared _(not configured)_
- [x] Ubuntu Server _(cannot verify from codebase)_

### Security

- [x] SSH key only _(requires server access to verify)_
- [ ] Password login disabled _(requires server access to verify)_
- [ ] UFW enabled _(requires server access to verify)_
- [ ] Fail2Ban enabled _(requires server access to verify)_
- [ ] Auto Updates configured _(requires server access to verify)_

### Monitoring & Backups

- [x] Backup script created _(confirmed: `scripts/backup.sh` exists)_
- [ ] Restore script not found _(no `restore-*.sh` in scripts/)_
- [ ] Backups scheduled as cron jobs _(requires server access to verify)_

---

## Stage 2 — Domain & Network

**Goal:** Buy domain and configure Cloudflare.

### Buy Domain (examples)

- smartroad.ph
- smartroad.app
- smartroad.net
- theheedful.me (current domain bought)
- theheedful.com (will be using in the future, after 8 months)
- smartroad.theheedful.me (subdomain that will be used)
- smartroad.theheedful.com (future subdomain)

### Cloudflare Configuration

- [x] Domain connected
- [x] SSL enabled (let's encrypt)
- [x] Tunnel created
- [x] HTTPS working
- [x] Zero Trust configured

---

## Stage 3 — Database Foundation

**Goal:** Create permanent data structure.

### Install

- [x] PostgreSQL _(confirmed: docker-compose postgres service + schema files exist)_
- [x] PostGIS _(✅ now installed: `postgis/postgis:15-3.4` image, `CREATE EXTENSION postgis` in schema)_
- [x] Redis _(✅ now configured: `redis:7-alpine` service in docker-compose)_

### Database Schemas

| Schema | Status | Tables |
|--------|--------|--------|
| `auth` | ✅ Done | `SmartRoad.profiles` (extends `auth.users`), roles, report levels |
| `routing` | ✅ Done | `saved_routes`, `community_routes`, `route_ratings`, `route_shares`, `route_usage_log` |
| `weather` | ✅ Done | `weather_cache`, `weather_alerts` |
| `hazards` | ✅ Done | `hazards` (PostGIS), `hazard_ratings`, `hazard_confirmations`, `hazard_verifications`, `hazard_comments` |
| `community` | ✅ Done | `hazard_comments`, `community_routes`, `place_comments`, `place_likes`, `place_ratings`, `place_images` |
| `hoa` | ✅ Done | `hoas`, `user_stickers`, `gate_access_logs`, `hoa_day_passes`, `village_entrances`, `restricted_roads` |
| `marketplace` | 🟡 Partial | `route_purchases` exists; missing `route_products`, `seller_wallets`, `transactions` |
| `analytics` | 🟡 Partial | `route_usage_log`, `audit_log` exist |
| `admin` | 🟡 Partial | `audit_log` exists, admin review screens exist in Flutter |

---

## Stage 4 — GraphHopper

**Goal:** Build routing engine.

### Setup

- [x] Install Docker _(confirmed)_
- [x] Pull GraphHopper _(confirmed: docker-compose graphhopper service defined)_
- [x] Download Philippines OSM _(confirmed: `PBF_URL` in docker-compose)_
- [x] Import Graph _(confirmed: GraphHopper graphhopper-data volume configured)_

### Verify (to test)

- [ ] Manila → Quezon City _(requires running instance to test)_
- [ ] Batangas → Manila _(requires running instance to test)_
- [ ] Laguna → Batangas _(requires running instance to test)_

### Routing Profiles

- [x] car _(configured in docker-compose: `PROFILES=motorcycle,car,truck,foot`)_
- [x] motorcycle _(configured)_
- [x] truck _(configured)_
- [x] foot / walking _(configured)_
- [x] delivery_rider _(configured as `CUSTOM_PROFILES`)_
- [x] flood_safe _(configured as `CUSTOM_PROFILES`)_
- [x] weather_safe _(configured as `CUSTOM_PROFILES`)_
- [x] hoa_access _(configured as `CUSTOM_PROFILES`)_

---

## Stage 5 — Map System

**Goal:** Show maps.

### Flutter Map Implementation

- [x] OpenStreetMap _(`flutter_map` with OSM tiles in `map_screen.dart`)_
- [ ] MapLibre _(not used — project uses `flutter_map`/OSM)_
- [x] Current Location _(`geolocator` + `user_location_marker.dart`)_
- [x] Search _(`LocationSearchService` via Nominatim OSM)_
- [x] Pins _(`map_poi_marker.dart`, `known_place_marker.dart`)_
- [x] Routes _(`route_preview_sheet.dart`, `route_creation_dialog.dart`, navigation features)_

### Required Features

- [x] Zoom _(standard `flutter_map` feature)_
- [x] Rotate _(`flutter_map` with rotation support)_
- [x] Compass _(`flutter_compass` package)_
- [x] Current Location _(GPS via `geolocator`)_
- [x] Offline Cache _(`OfflineCacheService` using Hive for hazards, pending reports)_

---

## Stage 6 — Backend API

**Goal:** Connect app to services.

### Routing Service

- [x] `POST /api/routing/route` _(✅ `backend/api/internal/handlers/routing_handler.go`)_
- [ ] `GET /api/routing/route` _(not implemented)_
- [ ] `POST /api/routing/optimize` _(not implemented)_
- [x] `GET /api/routing/vehicles` _(✅ lists supported vehicle types)_
- [x] `GET /api/routing/health` _(✅ routing health check)_

### Weather Service

- [x] `GET /api/weather/current` _(✅ `backend/api/internal/handlers/weather_handler.go`)_
- [x] `GET /api/weather/alerts` _(✅ weather alerts endpoint)_
- [ ] `GET /api/weather/layer` _(not implemented — weather tiles rendered client-side)_

### Hazard Service

- [x] `POST /api/hazards` _(✅ report a hazard)_
- [x] `GET /api/hazards` _(✅ list hazards with filters)_
- [x] `GET /api/hazards/nearby` _(✅ hazards near a point)_
- [x] `GET /api/hazards/bounds` _(✅ hazards within bounding box)_
- [x] `GET /api/hazards/:id` _(✅ single hazard)_
- [x] `PUT /api/hazards/:id` _(✅ update hazard)_
- [x] `DELETE /api/hazards/:id` _(✅ delete hazard)_

### Other API Endpoints

- [x] `POST /api/auth/register` _(✅ auth)_
- [x] `POST /api/auth/login` _(✅ auth)_
- [x] `GET /api/auth/me` _(✅ current user)_
- [x] `GET /api/hoas` _(✅ list HOAs)_
- [x] `POST /api/hoas/register` _(✅ register HOA)_
- [x] `GET /api/hoas/:id` _(✅ HOA details)_
- [x] `GET /api/entrances` _(✅ list entrances)_
- [x] `POST /api/entrances` _(✅ suggest entrance)_
- [x] `GET /api/entrances/nearby` _(✅ entrances near point)_
- [x] `PUT /api/entrances/:id/verify` _(✅ verify entrance)_
- [x] `GET /api/flood-zones` _(✅ list flood zones)_
- [x] `POST /api/flood-zones` _(✅ report flood zone)_
- [x] `GET /api/flood-zones/nearby` _(✅ flood zones near point)_
- [x] `POST /api/community/comments` _(✅ community comments)_
- [x] `GET /api/community/comments` _(✅ list comments)_
- [x] `POST /api/community/likes/toggle` _(✅ toggle likes)_
- [x] `POST /api/community/ratings` _(✅ set rating)_

---

## Stage 7 — Weather System

One of SmartRoad's biggest features.

### Weather Sources

- [ ] PAGASA _(not integrated — flood_zones table has `source: 'pagasa'` as a schema option but no live API)_
- [x] OpenMeteo _(✅ `WeatherService` uses `api.open-meteo.com` — free, no API key)_
- [x] RainViewer _(✅ `RainViewerService` fetches radar timestamps)_
- [ ] OpenWeatherMap _(🟡 config exists, needs API key via `--dart-define`)_

### Weather Layers

| Layer | Status | Implementation |
|-------|--------|----------------|
| 🌧️ Rain | ✅ Done | `RainLayer` — OpenWeatherMap precipitation tiles with blur blending |
| 🌧️ Heavy Rain | 🟡 Part of Rain | Not a separate layer; carried within rain layer |
| ⛈️ Storm | ❌ Not implemented | — |
| ☁️ Cloud | ✅ Done | `CloudLayer` — OpenWeatherMap cloud tiles |
| 🌡️ Heat Index | ✅ Done | `HeatLayer` — OpenWeatherMap temperature tiles |
| 🌫️ Fog | ❌ Not implemented | — |
| ☀️ UV | ❌ Not implemented | — |

### Map Overlay

- [x] **Rain overlay** on map _(`weather_tile_layers.dart` — RainLayer, CloudLayer, HeatLayer)_
- [x] **Weather layer controls** _(`weather_layer_controls.dart` — toggle layers on/off, adjust opacity)_
- [x] **Adaptive tile rendering** _(`weather_tile_generator.dart` — blur smoothing between tiles)_
- [x] **Current weather display** _(`weather_overlay.dart` — temperature + conditions)_
- [x] **Weather layer manager** _(`WeatherLayerManager` — manages rain, heat, cloud configs)_

**Goal:** Actual weather visible on map — not icons. User sees rain moving, storm moving, clouds moving, heat zones directly on map.

---

## Stage 8 — Flood Intelligence

### Data Sources

- [ ] PAGASA _(not directly integrated — schema has `source: 'pagasa'` as an option)_
- [ ] Project NOAH _(not integrated)_
- [x] Community Reports _(✅ flood hazard type exists in reports)_
- [ ] Terrain Data _(not implemented)_

### Flood Score

- [x] **Flood risk on roads** _(✅ `SmartRoad.roads.flood_risk` column: 0.00–1.00)_
- [x] **Flood zones table** _(✅ `SmartRoad.flood_zones` — polygon areas with severity: low/moderate/high/extreme)_
- [ ] **0–100 score per road** _(partial — uses 0.00–1.00 numeric scale)_

### Routing Logic

- [x] `flood_safe` vehicle profile _(✅ configured in GraphHopper custom profiles)_
- [x] `FloodSafe` vehicle type in Flutter _(`RoutingService.VehicleType.floodSafe`)_
- [ ] Full Preferred | Avoid | Blocked per road _(not implemented as continuous scoring)_

---

## Stage 9 — Community Reports

**Goal:** Waze-like system.

### Report Types

| Type | Status | Enum Value |
|------|--------|------------|
| 🌊 Flood | ✅ Done | `flood` |
| 🕳️ Pothole | ✅ Done | `pothole` |
| 💥 Accident | ✅ Done | `accident` |
| 🚦 Traffic | ✅ Done | `traffic` |
| ⛰️ Landslide | ✅ Done | `landslide` |
| 🚧 Construction | 🟡 Partial | `closure` / `roadblock` (close equivalents) |
| 🌲 Fallen Tree | ✅ Done | `fallen_tree` |
| 🗑️ Debris | ✅ Done | `debris` |

### Each Report Includes

- [x] **Location** _(✅ PostGIS `GEOGRAPHY(POINT, 4326)` — lat/lon)_
- [x] **Photo** _(✅ `image_url` field + `image_picker` camera/gallery)_
- [x] **Severity** _(✅ `SmartRoad.hazards.severity`: Low / Medium / High)_
- [x] **Time** _(✅ `created_at` timestamp)_
- [x] **Votes / Confirmations** _(✅ `hazard_confirmations` table — users can confirm/resolve)_
- [x] **Comments** _(✅ `hazard_comments` table + API)_
- [x] **Ratings** _(✅ `hazard_ratings` table)_
- [x] **Verifications** _(✅ `hazard_verifications` table — admin/moderator verification)_
- [x] **Sticker flag** _(✅ `sticker_flag` optional metadata)_
- [x] **Offline support** _(✅ `OfflineCacheService` caches hazards locally via Hive)_

---

## Stage 10 — HOA System

Massive SmartRoad differentiator.

### Village Database

- [x] **Villages / HOAs** _(✅ `SmartRoad.hoas` table — name, location, access type)_
- [x] **Subdivisions** _(✅ can be stored as HOAs)_
- [x] **Private Roads** _(✅ `SmartRoad.restricted_roads` — sticker/permit/resident_only/day_pass types)_
- [x] **Gates** _(✅ `SmartRoad.village_entrances` — verified gate locations)_

### Gate Intelligence

| Gate Type | Status | Code Value |
|-----------|--------|------------|
| 🚪 Main Gate | ✅ Done | `main` |
| 🚪 Visitor Gate | ✅ Done | `visitor` |
| 🚚 Delivery Gate | ✅ Done | `delivery` |
| 🚶 Resident Gate | ❌ Not a separate type | — |
| 🚑 Emergency Gate | ✅ Done | `emergency` |
| 🔧 Service Entrance | ✅ Done | `service` |
| 🚶 Pedestrian Gate | ✅ Done | `pedestrian` |

### Sticker System

- [x] **HOA Sticker** _(✅ `SmartRoad.user_stickers` table — links user→HOA)_
- [x] **Validity** _(✅ `issued_at` / `expires_at` — `Sticker.isValid` getter checks expiry)_
- [x] **Owner** _(✅ `user_id` field)_
- [x] **Vehicle** _(✅ `vehicle_plate` field in sticker model)_
- [x] **AI Verification** _(✅ `StickerVerifierService` — uses Gemini AI to verify sticker photos)_
- [x] **QR Code** _(✅ `qr_flutter` package — in-app sticker QR generation)_
- [x] **QR Scanner** _(✅ `mobile_scanner` package — guard scanner screen)_
- [x] **Day Passes** _(✅ `hoa_day_passes` — temporary access for non-residents)_
- [x] **Access Logs** _(✅ `gate_access_logs` — record of gate entries)_
- [x] **HOA API Endpoints** _(✅ `/api/hoas`, `/api/hoas/register`, `/api/hoas/:id`)_

---

## Stage 11 — Permission Routing

Core SmartRoad innovation.

- [x] **User has sticker → Allow shortcut** _(✅ `restricted_roads` + `user_stickers` + `hoa_access` profile)_
- [x] **User no sticker → Block shortcut** _(✅ routing request includes `userStickerIds` / `restrictedHoaIds`)_
- [x] **Sticker verification** _(✅ `StickerVerifierService` — Gemini AI validates sticker photos)_
- [x] **Route logic in Flutter** _(✅ `RoutingService` has `hoaAccess` vehicle type, sticker-aware routing)_

**Example:** Route A = 15 mins, Route B = 5 mins (needs sticker). SmartRoad: "You can save 10 minutes. Apply for Village X sticker."

---

## Stage 12 — Delivery Rider Intelligence

Another major differentiator.

### Entrance Intelligence

- [x] **Correct Gate** _(✅ `SmartRoad.village_entrances` — verified entrance locations)_
- [x] **Delivery Gate** _(✅ `entrance_type: 'delivery'` — specific gate for deliveries)_
- [ ] **Operating Hours** _(❌ not in schema/API)_
- [ ] **Guard Rules** _(❌ not in schema/API)_
- [x] **Entrance API** _(✅ `GET /api/entrances`, `GET /api/entrances/nearby`, `POST /api/entrances`)_
- [x] **Entrance verification** _(✅ `PUT /api/entrances/:id/verify` — admin verification)_
- [x] **Rider notes** _(✅ `notes` field on entrances — "Use Gate 3 for deliveries")_

### Scam Pin Database

- [x] **Wrong Pins handling** _(✅ entrances can be marked `is_verified: true/false`)_
- [x] **Misleading Pins** _(✅ `verified_by` / `verified_at` — admin audit trail)_
- [x] **Known Delivery Issues** _(✅ `notes` field — rider tips about specific entrances)_
- [ ] **"Pin inaccurate" warning** _(❌ not directly implemented as a UI warning)_

---

## Stage 13 — Route Marketplace

Possibly biggest future feature.

### Route Creator

- [x] **Route Creation** _(✅ `route_creation_provider.dart`, `route_creation_dialog.dart`, `create_route_dialog.dart`)_
- [x] **Route Drawing** _(✅ `route_drawing_widget.dart` — draw routes on map)_
- [x] **Description & Tags** _(✅ `community_routes.tags` JSONB, `description` TEXT)_
- [x] **Category** _(✅ route has `vehicle_type`, tags for categorization)_

### Route Sharing

- [x] **Saved Routes** _(✅ `SmartRoad.saved_routes` table — personal saved routes)_
- [x] **Community Routes** _(✅ `SmartRoad.community_routes` — shared routes)_
- [x] **Route Ratings** _(✅ `SmartRoad.route_ratings` — rating_avg, rating_count)_
- [x] **Route Shares** _(✅ `SmartRoad.route_shares` — explicit sharing records)_
- [x] **Route Usage Log** _(✅ `SmartRoad.route_usage_log` — tracking usage)_
- [ ] **Public | Private | Friends** _(🟡 partial — sharing table exists, visibility controls not fully implemented in UI)_

### Route Selling

- [ ] **Pricing (Free / ₱10 / ₱50 / ₱100)** _(❌ not implemented — `route_purchases` table exists but no pricing)_
- [ ] **SmartRoad commission (1% / 2% / 3%)** _(❌ not implemented)_
- [ ] **Seller Wallets** _(❌ not implemented)_
- [ ] **Transactions** _(❌ not implemented)_

---

## Stage 14 — AI Systems

**Future features:**

| Feature | Status | Notes |
|---------|--------|-------|
| 🤖 AI Flood Prediction | ❌ Not started | — |
| 🤖 AI Hazard Detection | 🟡 Partial | `StickerVerifierService` uses Gemini for sticker verification |
| 🤖 AI Route Ranking | ❌ Not started | — |
| 🤖 Commute AI Cache | 🟡 Partial | `commute_ai_cache` table exists (migration) + `CommuteAIAssistantService` |

---

## Stage 15 — LGU Platform

| Feature | Status | Notes |
|---------|--------|-------|
| Dashboard for Cities | ❌ Not implemented | — |
| Dashboard for Municipalities | ❌ Not implemented | — |
| Dashboard for Barangays | ❌ Not implemented | — |
| Flood/Hazard/Traffic views | ❌ Not implemented | — |

---

## Stage 16 — Enterprise Platform

| Feature | Status | Notes |
|---------|--------|-------|
| Routing API for enterprise | 🟡 Partial | Existing public API could serve enterprise, no dedicated enterprise tier |
| Weather API for enterprise | 🟡 Partial | Existing endpoints serve basic needs |
| Hazard API for enterprise | 🟡 Partial | Existing endpoints serve basic needs |
| Gate Intelligence API for enterprise | 🟡 Partial | Existing endpoints serve basic needs |
| Enterprise client program | ❌ Not started | Lalamove, Grab, MoveIt, J&T, LBC, LGUs, HOAs — future |

---

## Stage 17 — Global Scale

| Feature | Status | Notes |
|---------|--------|-------|
| Kubernetes | ❌ Not configured | — |
| Load Balancers | ❌ Not configured | — |
| CDN | ❌ Not configured | — |
| Database Replication | ❌ Not configured | — |
| Multi Region | ❌ Not configured | — |

**Target:** 100 → 1,000 → 10,000 → 100,000 → 1,000,000+ users

---

## Immediate Next Tasks — Current Position

### ✅ Completed

- [x] Ubuntu Server — _user-confirmed (not verifiable from code)_
- [x] Docker — _confirmed (Dockerfiles, `docker-compose.yml` exist)_
- [x] GraphHopper Container — _user-confirmed (not verifiable from code)_
- [x] Philippines OSM Import — _user-confirmed (not verifiable from code)_
- [x] Graph Built Successfully — _user-confirmed (not verifiable from code)_
- [x] **Create PostgreSQL + PostGIS** — _✅ done (postgis/postgis:15-3.4 in docker-compose, `CREATE EXTENSION postgis` in schema)_
- [x] **Design Database Schemas** — _✅ done (7+ migration files, all core tables created)_
- [x] **Build Backend API** — _✅ done (Golang — routing, auth, hazards, weather, community, HOA, entrances, flood-zones, websockets)_
- [x] **Connect Backend → GraphHopper** — _✅ done (`routing_service.go` proxies Flutter requests → GraphHopper with retry + timeout + fallback)_
- [x] **Create Flutter Map** — _✅ done (`map_screen.dart` — OSM, current location, search, pins, routing)_
- [x] **Display Routes** — _✅ done (route preview, navigation overlay, route following)_
- [x] **Navigation MVP** — _✅ done (turn-by-turn, reroute, distance tracking, speed HUD, hazard warnings)_
- [x] **Hazard Reporting MVP** — _✅ done (`ReportHazardScreen`, photo capture, severity, PostGIS)_
- [x] **Weather Overlay MVP** — _✅ done (rain/cloud/heat tile layers, current weather display)_
- [x] **HOA MVP** — _✅ done (stickers, gates, entrances, day passes, QR scanner, AI verification)_

### 🔜 Next Priority

- [ ] Test GraphHopper API (Manila→QC, Batangas→Manila, Laguna→Batangas)
- [ ] Set up domain + Cloudflare (SSL, tunnel, HTTPS)
- [ ] Create missing docs: `/docs/Features.md`, `/docs/Roadmap.md`, `/docs/UserTypes.md`, `/docs/SystemArchitecture.md`
- [ ] Restore script for backups (`scripts/restore.sh`)
- [ ] Nginx reverse proxy config
- [ ] Cloudflared tunnel setup
- [ ] Server security: SSH key only, UFW, Fail2Ban, Auto Updates
- [ ] PAGASA weather data integration
- [ ] Storm, Fog, UV weather layers
- [ ] Flood intelligence: PAGASA + Project NOAH + terrain data, per-road 0–100 score
- [ ] Route marketplace: pricing tiers, seller wallets, transactions
- [ ] Delivery rider: operating hours, guard rules, "pin inaccurate" UI warning
- [ ] LGU dashboard MVP
- [ ] Enterprise API tier
- [ ] Investor Demo MVP