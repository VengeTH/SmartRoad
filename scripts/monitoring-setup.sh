#!/usr/bin/env bash
# =============================================================================
# SmartRoad — Monitoring Stack Setup (Prometheus + Grafana + Node Exporter)
# =============================================================================
# Run this on the server after Docker is installed.
#
# Usage:
#   chmod +x scripts/monitoring-setup.sh
#   sudo ./scripts/monitoring-setup.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

MONITORING_DIR="/opt/smartroad/monitoring"

echo ""
echo "=============================================="
echo "  SmartRoad — Monitoring Stack Setup"
echo "=============================================="
echo ""

# --- Create monitoring directory ---------------------------------------------
mkdir -p "$MONITORING_DIR"

# --- Create docker-compose for monitoring ------------------------------------
cat > "$MONITORING_DIR/docker-compose.yml" << 'COMPOSE'
version: "3.8"

services:
  # Node Exporter — system metrics
  node-exporter:
    image: prom/node-exporter:latest
    container_name: smartroad-node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - "--path.procfs=/host/proc"
      - "--path.sysfs=/host/sys"
      - "--path.rootfs=/rootfs"
      - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
    ports:
      - "9100:9100"
    networks:
      - smartroad-monitoring

  # Prometheus — metrics storage & querying
  prometheus:
    image: prom/prometheus:latest
    container_name: smartroad-prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - smartroad-monitoring

  # Grafana — visualization & dashboards
  grafana:
    image: grafana/grafana:latest
    container_name: smartroad-grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=smartroad-admin
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
      - GF_SERVER_ROOT_URL=http://localhost:3001
      - GF_SERVER_HTTP_PORT=3001
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana-dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./grafana-datasources:/etc/grafana/provisioning/datasources:ro
    ports:
      - "3001:3001"
    networks:
      - smartroad-monitoring

volumes:
  prometheus-data:
  grafana-data:

networks:
  smartroad-monitoring:
    driver: bridge
COMPOSE

log "docker-compose.yml created."

# --- Create Prometheus config -------------------------------------------------
cat > "$MONITORING_DIR/prometheus.yml" << 'PROM'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers: []

scrape_configs:
  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]
        labels:
          service: "smartroad-server"

  - job_name: "graphhopper"
    metrics_path: "/metrics"
    static_configs:
      - targets: ["graphhopper:8989"]
        labels:
          service: "smartroad-graphhopper"
    # GraphHopper exposes Prometheus metrics at /metrics
    # Only works if GraphHopper is on the same Docker network
    scrape_interval: 30s
PROM

log "Prometheus config created."

# --- Create Grafana datasource config ----------------------------------------
mkdir -p "$MONITORING_DIR/grafana-datasources"
cat > "$MONITORING_DIR/grafana-datasources/datasource.yml" << 'GFDS'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
GFDS

log "Grafana datasource config created."

# --- Create Grafana dashboard config ------------------------------------------
mkdir -p "$MONITORING_DIR/grafana-dashboards"
cat > "$MONITORING_DIR/grafana-dashboards/dashboard.yml" << 'GFD'
apiVersion: 1

providers:
  - name: "SmartRoad"
    orgId: 1
    folder: ""
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /etc/grafana/provisioning/dashboards
GFD

log "Grafana dashboard provider config created."

# --- Create a basic server dashboard ------------------------------------------
cat > "$MONITORING_DIR/grafana-dashboards/server-overview.json" << 'DASH'
{
  "title": "SmartRoad — Server Overview",
  "uid": "smartroad-server",
  "version": 1,
  "schemaVersion": 36,
  "tags": ["smartroad", "server"],
  "time": { "from": "now-1h", "to": "now" },
  "panels": [
    {
      "title": "CPU Usage",
      "type": "gauge",
      "gridPos": { "h": 8, "w": 6, "x": 0, "y": 0 },
      "targets": [
        {
          "expr": "100 - (avg by(instance)(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "legendFormat": "CPU %"
        }
      ]
    },
    {
      "title": "Memory Usage",
      "type": "gauge",
      "gridPos": { "h": 8, "w": 6, "x": 6, "y": 0 },
      "targets": [
        {
          "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100",
          "legendFormat": "Memory %"
        }
      ]
    },
    {
      "title": "Disk Usage",
      "type": "gauge",
      "gridPos": { "h": 8, "w": 6, "x": 12, "y": 0 },
      "targets": [
        {
          "expr": "100 - ((node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100)",
          "legendFormat": "Disk %"
        }
      ]
    },
    {
      "title": "Uptime",
      "type": "stat",
      "gridPos": { "h": 8, "w": 6, "x": 18, "y": 0 },
      "targets": [
        {
          "expr": "node_time_seconds - node_boot_time_seconds",
          "legendFormat": "Uptime (s)"
        }
      ]
    },
    {
      "title": "System Load (1m / 5m / 15m)",
      "type": "timeseries",
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 8 },
      "targets": [
        { "expr": "node_load1", "legendFormat": "1m" },
        { "expr": "node_load5", "legendFormat": "5m" },
        { "expr": "node_load15", "legendFormat": "15m" }
      ]
    },
    {
      "title": "Network Traffic",
      "type": "timeseries",
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 8 },
      "targets": [
        { "expr": "rate(node_network_receive_bytes_total[5m])", "legendFormat": "In" },
        { "expr": "rate(node_network_transmit_bytes_total[5m])", "legendFormat": "Out" }
      ]
    },
    {
      "title": "Disk I/O",
      "type": "timeseries",
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 16 },
      "targets": [
        { "expr": "rate(node_disk_read_bytes_total[5m])", "legendFormat": "Read" },
        { "expr": "rate(node_disk_write_bytes_total[5m])", "legendFormat": "Write" }
      ]
    },
    {
      "title": "Docker Containers",
      "type": "stat",
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 16 },
      "targets": [
        { "expr": "count(node_systemd_units_state{state=\"active\"})", "legendFormat": "Active" }
      ]
    }
  ]
}
DASH

log "Basic Grafana dashboard created."

# --- Start monitoring stack ---------------------------------------------------
log "Starting monitoring stack..."
cd "$MONITORING_DIR"
docker-compose up -d

echo ""
echo "=============================================="
echo "  Monitoring Stack Deployed"
echo "=============================================="
echo ""
log "Prometheus:   http://<server-ip>:9090"
log "Grafana:      http://<server-ip>:3001 (admin / smartroad-admin)"
log "Node Exporter: http://<server-ip>:9100/metrics"
echo ""
log "To add more dashboards, place JSON in: $MONITORING_DIR/grafana-dashboards/"
echo ""
