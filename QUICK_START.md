# 🚀 Quick Start Guide - SmartRoad Go Backend & Proxy

## Simple 3-Step Setup

### Step 1: Start Backend Services

Navigate to the `backend/` directory and start Docker Compose:

```bash
cd backend
docker-compose up -d
```

This launches:
- **SmartRoad Go API** (`http://localhost:3000`)
- **GraphHopper Routing Engine** (`http://localhost:8989`)
- **PostgreSQL Database** (`localhost:5432`)
- **Redis Cache** (`localhost:6379`)

---

### Step 2: Verify Service Health

Check the API health endpoint:

```bash
curl http://localhost:3000/api/health
```

Should return:
```json
{"status":"ok","service":"smartroad-api","version":"1.0.0-go","timestamp":"..."}
```

Check routing vehicles:
```bash
curl http://localhost:3000/api/routing/vehicles
```

---

### Step 3: Run the Flutter App

Launch Flutter with backend connectivity:

```bash
# Windows
run.bat

# PowerShell
./run-with-env.ps1

# Custom API and Weather Proxy URL (e.g. for physical devices)
flutter run \
  --dart-define=API_BASE_URL=http://YOUR-SERVER-IP:3000 \
  --dart-define=WEATHER_PROXY_URL=http://YOUR-SERVER-IP:3000
```

---

## 🔧 Useful Commands

**View container logs:**
```bash
cd backend
docker-compose logs -f api
```

**Restart API:**
```bash
cd backend
docker-compose restart api
```

**Run Go API locally without Docker:**
```bash
cd backend/api
go run ./cmd/server
```

---

## 📖 Need More Details?

- See [SELF_HOSTED_SETUP.md](SELF_HOSTED_SETUP.md) for server provisioning, systemd, and Nginx SSL setup.
- See [backend/api/README.md](backend/api/README.md) for full Go API endpoint documentation.
- See [backend/README.md](backend/README.md) for architecture and container orchestration details.
