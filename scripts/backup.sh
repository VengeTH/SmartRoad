#!/usr/bin/env bash
# =============================================================================
# SmartRoad — Automated Backup Script
# =============================================================================
# Creates daily + weekly backups of databases and critical configuration.
# Designed to run via cron (root).
#
# Installation:
#   sudo crontab -e
#   # Add:
#   0 3 * * * /opt/smartroad/scripts/backup.sh daily   >> /var/log/smartroad-backup.log 2>&1
#   0 4 * * 0 /opt/smartroad/scripts/backup.sh weekly  >> /var/log/smartroad-backup.log 2>&1
#
# Restore:
#   See docs/disaster-recovery.md
# =============================================================================

set -euo pipefail

# --- Config ------------------------------------------------------------------
BACKUP_DIR="/var/backups/smartroad"
RETENTION_DAYS_DAILY=7
RETENTION_WEEKS=4
RETENTION_MONTHLY=3

# PostgreSQL
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_DATABASE="${PG_DATABASE:-smartroad}"
PG_USER="${PG_USER:-smartroad}"

# Docker volumes to backup (space-separated)
DOCKER_VOLUMES="graphhopper-data"

# Remote backup (optional) — set to "" to skip
REMOTE_BACKUP_PATH=""
# REMOTE_BACKUP_PATH="user@backup-server:/backups/smartroad"

# Healthcheck URL (optional) — ping after successful backup
HEALTHCHECK_URL=""
# HEALTHCHECK_URL="https://hc-ping.com/your-uuid-here"
# -----------------------------------------------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
err()  { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }

BACKUP_TYPE="${1:-daily}"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
BACKUP_FILE_PREFIX="${BACKUP_DIR}/${BACKUP_TYPE}/${BACKUP_TYPE}_smartroad_${TIMESTAMP}"

# --- Create backup directories -----------------------------------------------
mkdir -p "${BACKUP_DIR}/daily"
mkdir -p "${BACKUP_DIR}/weekly"
mkdir -p "${BACKUP_DIR}/monthly"
mkdir -p "${BACKUP_DIR}/logs"

echo ""
echo "=============================================="
echo "  SmartRoad Backup — ${BACKUP_TYPE}"
echo "  Started: $(date)"
echo "=============================================="
echo ""

# --- 1. PostgreSQL Backup ----------------------------------------------------
log "Starting PostgreSQL dump..."

if command -v pg_dump &>/dev/null; then
  if PGPASSWORD="${PG_PASSWORD:-}" pg_isready -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -q 2>/dev/null; then
    BACKUP_FILE="${BACKUP_FILE_PREFIX}_db.sql.gz"
    PGPASSWORD="${PG_PASSWORD:-}" pg_dump \
      -h "$PG_HOST" \
      -p "$PG_PORT" \
      -U "$PG_USER" \
      -d "$PG_DATABASE" \
      --clean \
      --if-exists \
      --no-owner \
      --no-privileges \
      2>"${BACKUP_DIR}/logs/pg_dump_${TIMESTAMP}.log" | gzip > "$BACKUP_FILE"

    if [[ -f "$BACKUP_FILE" ]]; then
      SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
      log "PostgreSQL dump complete: $SIZE"
    else
      warn "PostgreSQL dump failed — check logs/pg_dump_${TIMESTAMP}.log"
    fi
  else
    warn "PostgreSQL not reachable — skipping database backup."
  fi
else
  warn "pg_dump not installed — skipping database backup."
fi

# --- 2. Docker Volume Backup -------------------------------------------------
log "Backing up Docker volumes..."

for VOLUME in $DOCKER_VOLUMES; do
  BACKUP_FILE="${BACKUP_FILE_PREFIX}_volume_${VOLUME}.tar.gz"
  if docker volume inspect "$VOLUME" &>/dev/null; then
    docker run --rm \
      -v "${VOLUME}:/volume" \
      -v "${BACKUP_DIR}/${BACKUP_TYPE}:/backup" \
      alpine \
      tar czf "/backup/$(basename ${BACKUP_FILE})" -C /volume . 2>/dev/null
    
    if [[ -f "$BACKUP_FILE" ]]; then
      SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
      log "Volume '$VOLUME' backed up: $SIZE"
    else
      warn "Volume '$VOLUME' backup may have failed."
    fi
  else
    warn "Volume '$VOLUME' not found — skipping."
  fi
done

# --- 3. Configuration Backup -------------------------------------------------
log "Backing up configuration files..."

BACKUP_FILE="${BACKUP_FILE_PREFIX}_config.tar.gz"
tar czf "$BACKUP_FILE" \
  -C /opt/smartroad \
  docker-compose.yml \
  --exclude='graphhopper-data' \
  --exclude='node_modules' \
  2>/dev/null || true

if [[ -f "$BACKUP_FILE" ]]; then
  SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  log "Configuration backed up: $SIZE"
fi

# --- 4. Retention Cleanup ----------------------------------------------------
log "Cleaning up old backups..."

case "$BACKUP_TYPE" in
  daily)
    find "${BACKUP_DIR}/daily" -name "daily_*" -mtime +${RETENTION_DAYS_DAILY} -delete
    log "Cleaned daily backups older than ${RETENTION_DAYS_DAILY} days."
    ;;
  weekly)
    find "${BACKUP_DIR}/weekly" -name "weekly_*" -mtime +$((RETENTION_WEEKS * 7)) -delete
    log "Cleaned weekly backups older than ${RETENTION_WEEKS} weeks."
    ;;
  monthly)
    find "${BACKUP_DIR}/monthly" -name "monthly_*" -mtime +$((RETENTION_MONTHLY * 30)) -delete
    log "Cleaned monthly backups older than ${RETENTION_MONTHLY} months."
    ;;
esac

# --- 5. Remote Backup (optional) ---------------------------------------------
if [[ -n "$REMOTE_BACKUP_PATH" ]]; then
  log "Syncing to remote backup location..."
  rsync -avz --delete "${BACKUP_DIR}/" "$REMOTE_BACKUP_PATH" 2>/dev/null && \
    log "Remote backup sync complete." || \
    warn "Remote backup sync failed."
fi

# --- 6. Healthcheck ping (optional) -----------------------------------------
if [[ -n "$HEALTHCHECK_URL" ]]; then
  curl -fsSL -o /dev/null "$HEALTHCHECK_URL" 2>/dev/null || true
fi

# --- Summary ----------------------------------------------------------------
echo ""
echo "=============================================="
echo "  Backup Complete: ${BACKUP_TYPE}"
echo "  Finished: $(date)"
echo "=============================================="
echo ""
log "Backup location: ${BACKUP_DIR}/${BACKUP_TYPE}/"
ls -lh "${BACKUP_DIR}/${BACKUP_TYPE}/" | tail -n +2
echo ""
