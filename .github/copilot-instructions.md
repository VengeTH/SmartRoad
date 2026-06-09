# SmartRoad – Copilot coding agent notes

## Big picture
- This repo root is the Flutter app (see [README.md](../README.md)); `backend/` contains Docker services (GraphHopper routing, Node.js/Express API, PostgreSQL, Redis).
- App boot is in [lib/main.dart](../lib/main.dart): initializes `SupabaseService`, `RouteService`, `OfflineCacheService`, `NotificationService` before `ProviderScope`.
- State management uses Riverpod (`flutter_riverpod`): providers live under `lib/providers/`, UI commonly uses `ConsumerWidget`/`ConsumerStatefulWidget` + `ref.watch(...)`.
- **Routing architecture**: Flutter → SmartRoad Backend API → GraphHopper. Flutter NEVER calls GraphHopper directly.

## Local dev workflows (most common)
- Flutter deps: `flutter pub get`
- Run (loads `.env` and forwards `--dart-define`):
  - Windows: `run.bat` or `flutter_run.bat`
  - Windows PowerShell: `./run-with-env.ps1`
  - macOS/Linux: `./run-with-env.sh`
- Basic checks: `flutter analyze`, `flutter test`

## Environment variables (compile-time)
This project reads config via `String.fromEnvironment(...)` / `bool.fromEnvironment(...)` (not runtime dotenv). Pass values using `--dart-define=...` or the helper scripts above.

- **Backend API** (replaces former Supabase dependency):
  - `API_BASE_URL` (default `http://localhost:3000`); validated in [lib/core/config/env.dart](../lib/core/config/env.dart); when unset the app runs in demo mode with local/in-memory data.
  - Flutter NEVER calls GraphHopper directly. All routing goes through the backend API at `/api/routing/route`.
  - See [backend/api/](../backend/api/) for the Node.js/Express API implementation.
- **Database**: PostgreSQL 15+ with PostGIS extension; schema is under the `SmartRoad` namespace (tables like `SmartRoad.profiles`, `SmartRoad.hazards`). All schema files are in `supabase/` (legacy name preserved for compatibility).
- Gemini (sticker verification; free tier available):
  - `GEMINI_API_KEY` (read in [lib/core/config/env.dart](../lib/core/config/env.dart); used by sticker verification flows under `lib/services/`)
- Weather layers:
  - `OPENWEATHERMAP_API_KEY` and optional `WEATHER_PROXY_URL` (see [lib/config/weather_config.dart](../lib/config/weather_config.dart))
  - On Web, weather layers are available only if an API key or proxy URL is configured.
- Traffic overlay:
  - `TOMTOM_API_KEY` (see [lib/config/traffic_config.dart](../lib/config/traffic_config.dart))
- GraphHopper routing:
  - `GRAPH_HOPPER_URL` (default `http://localhost:8989`) — configured on the backend API, NOT in Flutter
  - Flutter calls the SmartRoad Backend API (`/api/routing/route`) instead of GraphHopper directly
  - The backend API (`backend/api/src/services/routing-service.js`) proxies requests to GraphHopper with retry + timeout
  - Fallback: when the backend API is unreachable, `RoutingService` uses straight-line fallback

## Backend (required for real routing)
- Start all services: `cd backend` then `docker-compose up -d` (starts GraphHopper + API + PostgreSQL + Redis)
- The API service is at `http://localhost:3000`; health check: `curl http://localhost:3000/api/health`
- GraphHopper health check: `curl http://localhost:8989/health`
- First GraphHopper run takes 30–60 minutes (OSM download + graph build). See [backend/QUICKSTART.md](../backend/QUICKSTART.md)
- Routing flow: Flutter → SmartRoad API (`POST /api/routing/route`) → GraphHopper (internal)

## Project-specific conventions to preserve
- Routing must keep the Web-safe fallback/backoff behavior in `RoutingService.calculateRoute(...)` (don’t spam/hammer GraphHopper when unreachable).
- Map behavior is Philippines-focused (zoom + bounds constants in [lib/core/constants/app_constants.dart](../lib/core/constants/app_constants.dart)).
- Many files use the repo’s doc-comment style `/// * ...`; match existing style when editing nearby code.

## Common entry points
- Map UX + navigation flows: [lib/screens/map/map_screen.dart](../lib/screens/map/map_screen.dart)
- App shell (tabs + hazard FAB): [lib/screens/main_navigation_screen.dart](../lib/screens/main_navigation_screen.dart)
- Auth + demo user wiring: [lib/providers/auth_provider.dart](../lib/providers/auth_provider.dart) and [lib/screens/auth/login_screen.dart](../lib/screens/auth/login_screen.dart)
- Routing/GraphHopper + fallback logic: [lib/services/routing_service.dart](../lib/services/routing_service.dart)
- Route “as a product” (save/discover): [lib/services/route_service.dart](../lib/services/route_service.dart) and [lib/screens/routes/routes_screen.dart](../lib/screens/routes/routes_screen.dart)
