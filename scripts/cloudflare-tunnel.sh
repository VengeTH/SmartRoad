#!/usr/bin/env bash
# =============================================================================
# SmartRoad — Cloudflare Tunnel Setup Script
# =============================================================================
# Sets up a Cloudflare Tunnel to expose SmartRoad services securely without
# opening firewall ports (only outbound connections to Cloudflare).
#
# Prerequisites:
#   - Cloudflare account with domain added
#   - Cloudflare API token or global API key
#   - Docker installed on the server
#
# Usage:
#   chmod +x scripts/cloudflare-tunnel.sh
#   sudo ./scripts/cloudflare-tunnel.sh
#
# After setup, authenticate with:
#   docker-compose exec cloudflared cloudflared tunnel login
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

TUNNEL_DIR="/opt/smartroad/cloudflare"

echo ""
echo "=============================================="
echo "  SmartRoad — Cloudflare Tunnel Setup"
echo "=============================================="
echo ""

# --- Check Docker ------------------------------------------------------------
if ! command -v docker &>/dev/null; then
  err "Docker is not installed. Run scripts/server-setup.sh first."
  exit 1
fi

# --- Create tunnel directory -------------------------------------------------
mkdir -p "$TUNNEL_DIR"

# --- Create docker-compose for cloudflared -----------------------------------
cat > "$TUNNEL_DIR/docker-compose.yml" << 'COMPOSE'
version: "3.8"

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: smartroad-cloudflared
    restart: unless-stopped
    command: tunnel run
    volumes:
      - ./config:/home/nonroot/.cloudflared:ro
    networks:
      - smartroad-backend

networks:
  smartroad-backend:
    external: true
    name: smartroad_backend_smartroad-backend
COMPOSE

log "docker-compose.yml created."

# --- Create setup instructions file ------------------------------------------
cat > "$TUNNEL_DIR/README.md" << 'README'
# Cloudflare Tunnel — Setup Instructions

## Step 1: Authenticate (first time only)

```bash
cd /opt/smartroad/cloudflare
docker-compose run --rm cloudflared tunnel login
```

This opens a browser URL. Log in to Cloudflare and authorize the tunnel.

## Step 2: Create the tunnel

```bash
docker-compose run --rm cloudflared tunnel create smartroad
```

This creates a credentials file in `~/.cloudflared/`.

## Step 3: Copy credentials to config directory

```bash
# Find the credentials file (JSON with tunnel ID as filename)
cp ~/.cloudflared/<tunnel-id>.json config/
```

## Step 4: Create config.yml

Create `config/config.yml`:

```yaml
tunnel: <tunnel-id>
credentials-file: /home/nonroot/.cloudflared/<tunnel-id>.json

ingress:
  # GraphHopper API
  - hostname: routing.smartroad.app
    service: http://graphhopper:8989
    originRequest:
      httpHostHeader: routing.smartroad.app

  # Grafana (admin dashboard)
  - hostname: admin.smartroad.app
    service: http://grafana:3001
    originRequest:
      httpHostHeader: admin.smartroad.app

  # SmartRoad API (future)
  # - hostname: api.smartroad.app
  #   service: http://api:3000

  # Block all other traffic
  - service: http_status:404
```

## Step 5: Configure DNS

```bash
# Route each subdomain through the tunnel
docker-compose run --rm cloudflared tunnel route dns <tunnel-id> routing.smartroad.app
docker-compose run --rm cloudflared tunnel route dns <tunnel-id> admin.smartroad.app
```

## Step 6: Start the tunnel

```bash
docker-compose up -d
```

## Step 7: Verify

```bash
docker-compose logs cloudflared
```

You should see: `Connected to cloudflared`.

## DNS Records

Cloudflare Tunnel handles DNS automatically via `tunnel route dns`. You do NOT need
to create A/AAAA/CNAME records manually — the tunnel creates CNAME records pointing
to `<tunnel-id>.cfargotunnel.com`.

### Manual DNS Records (if not using tunnel route dns)

| Type | Name | Value |
|------|------|-------|
| CNAME | routing | `<tunnel-id>.cfargotunnel.com` |
| CNAME | admin | `<tunnel-id>.cfargotunnel.com` |
| CNAME | api | `<tunnel-id>.cfargotunnel.com` |
README

log "Setup instructions created at $TUNNEL_DIR/README.md"

echo ""
echo "=============================================="
echo "  Cloudflare Tunnel — Ready to Configure"
echo "=============================================="
echo ""
log "Follow the steps in: $TUNNEL_DIR/README.md"
echo ""
