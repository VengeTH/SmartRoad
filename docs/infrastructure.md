# SmartRoad — Infrastructure Reference

> **Last updated:** 2026-06-09

---

## Network Topology

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────────┐
│   Internet   │────→│  Cloudflare     │────→│  Ubuntu Server   │
│   (Users)    │     │  (CDN + Tunnel) │     │  (Self-hosted)   │
└──────────────┘     └─────────────────┘     └──────────────────┘
                              │                       │
                              │                  ┌────┴────┐
                              │                  │ Docker  │
                              │                  └────┬────┘
                              │                 ┌──────┴──────┐
                              │                 │              │
                              │           ┌─────┴─────┐  ┌────┴─────┐
                              │           │ GraphHopper│  │Monitoring│
                              │           │ (Routing)  │  │(Prom/Graf)│
                              │           └───────────┘  └──────────┘
                              │
                         ┌────┴────┐
                         │  DNS    │
                         │ Records │
                         └─────────┘
```

## Server Specifications

| Component | Requirement | Notes |
|-----------|-------------|-------|
| **OS** | Ubuntu Server 24.04 LTS | |
| **CPU** | 4+ cores | GraphHopper needs multi-core for route calculation |
| **RAM** | 8 GB minimum, 16 GB recommended | GraphHopper + PostgreSQL + monitoring |
| **Storage** | 100 GB SSD minimum | Philippines OSM data + graph cache ~10–20 GB |
| **Network** | Static public IP | Or dynamic DNS with Cloudflare Tunnel |

## Services & Ports

| Service | Port | Protocol | Access | Notes |
|---------|------|----------|--------|-------|
| SSH | 2222 | TCP | Admin only | Non-standard port (hardened) |
| HTTP | 80 | TCP | Cloudflare only | Redirects to HTTPS |
| HTTPS | 443 | TCP | Cloudflare only | TLS terminated at Cloudflare |
| GraphHopper | 8989 | TCP | Docker internal | Not exposed publicly |
| Prometheus | 9090 | TCP | Internal / Tunnel | Metrics storage |
| Grafana | 3001 | TCP | Internal / Tunnel | Dashboards (admin/admin) |
| Node Exporter | 9100 | TCP | Internal | System metrics |

## Cloudflare Configuration

### DNS Records

| Type | Name | Value | Proxy |
|------|------|-------|-------|
| CNAME | routing | `<tunnel-id>.cfargotunnel.com` | Proxied (orange cloud) |
| CNAME | admin | `<tunnel-id>.cfargotunnel.com` | Proxied (orange cloud) |
| CNAME | api | `<tunnel-id>.cfargotunnel.com` | Proxied (orange cloud) |
| CNAME | * | `<tunnel-id>.cfargotunnel.com` | Proxied (catch-all) |

### Security Settings (Cloudflare Dashboard)

| Setting | Recommended Value |
|---------|------------------|
| SSL/TLS encryption mode | Full (strict) |
| Always Use HTTPS | On |
| Automatic HTTPS Rewrites | On |
| Minimum TLS Version | 1.2 |
| Bot Fight Mode | On |
| Browser Integrity Check | On |
| WAF (Web Application Firewall) | On (managed rules) |
| Rate Limiting | 100 requests/minute per IP |

## Docker Network Architecture

```yaml
docker-compose networks:
  smartroad-backend:
    driver: bridge
    ipam:
      config:
        - subnet: "172.20.0.0/16"

services:
  graphhopper:    → 172.20.0.2 (smartroad-backend)
  api:            → 172.20.0.3 (smartroad-backend) [Go API]
  postgres:       → 172.20.0.4 (smartroad-backend)
  redis:          → 172.20.0.5 (smartroad-backend)
  cloudflared:    → 172.20.0.2 (smartroad-backend) [via tunnel]
```

## Storage Layout

```
/opt/smartroad/
├── docker-compose.yml          # Main service orchestration
├── .env                        # Environment variables (not in git)
├── scripts/
│   ├── server-setup.sh         # Server provisioning
│   ├── backup.sh               # Backup automation
│   └── cloudflare-tunnel/      # Tunnel config
├── monitoring/                 # Prometheus + Grafana
├── backend/
│   └── graphhopper/            # GraphHopper config
└── docs/                       # This documentation

/var/backups/smartroad/
├── daily/                      # Daily backups (retention: 7 days)
├── weekly/                     # Weekly backups (retention: 4 weeks)
└── monthly/                    # Monthly backups (retention: 3 months)

/var/log/smartroad/
├── smartroad-backup.log        # Backup logs
├── cloudflared.log             # Tunnel logs
└── monitoring/                 # Prometheus data
```

## Monitoring Stack

| Component | Purpose | URL (via tunnel) |
|-----------|---------|------------------|
| Prometheus | Metrics collection & querying | `https://admin.smartroad.app:9090` |
| Grafana | Dashboards & visualization | `https://admin.smartroad.app` (default: admin/smartroad-admin) |
| Node Exporter | System metrics (CPU, RAM, disk) | Internal only |

### Key Grafana Dashboards

1. **Server Overview** — CPU, memory, disk, network, load
2. **GraphHopper Performance** — Request latency, error rate (requires GraphHopper metrics enabled)
3. **Route Statistics** — Routes calculated, fallback rates

## Backup Schedule

| Frequency | Time | Type | Retention |
|-----------|------|------|-----------|
| Daily | 03:00 AM | Full DB + volumes | 7 days |
| Weekly | Sunday 04:00 AM | Weekly snapshot | 4 weeks |
| Monthly | 1st of month | Monthly archive | 3 months |

## Security Checklist

- [x] SSH on non-standard port (2222)
- [x] SSH key-only authentication
- [x] Root login disabled
- [x] UFW firewall enabled (default deny)
- [x] Fail2Ban active (3 SSH retries → 24h ban)
- [x] Automatic security updates enabled
- [x] Docker containers run as non-root
- [x] Cloudflare Tunnel (no open inbound ports)
- [x] All traffic over HTTPS (TLS 1.2+)
- [x] Database credentials in `.env` file (not in git)
- [ ] Regular security audits (quarterly)
- [ ] Penetration testing (annual)

---

*"Be Heedful on the Road" — **SmartRoad**, a product of **The Heedful** 🇵🇭*
