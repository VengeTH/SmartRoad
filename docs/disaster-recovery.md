# SmartRoad — Disaster Recovery Procedure

> **Last updated:** 2026-06-09

---

## Table of Contents

1. [Backup Locations](#1-backup-locations)
2. [Restore Procedures](#2-restore-procedures)
3. [Recovery Scenarios](#3-recovery-scenarios)
4. [Verification](#4-verification)
5. [Emergency Contacts](#5-emergency-contacts)

---

## 1. Backup Locations

| Type | Location | Retention |
|------|----------|-----------|
| Daily backups | `/var/backups/smartroad/daily/` | 7 days |
| Weekly backups | `/var/backups/smartroad/weekly/` | 4 weeks |
| Monthly backups | `/var/backups/smartroad/monthly/` | 3 months |
| Remote (optional) | Configurable S3/rsync target | Mirrors local |

### What's Backed Up

| Asset | File Pattern | Contents |
|-------|-------------|----------|
| PostgreSQL DB | `*_db.sql.gz` | Full database dump (with `--clean` for restore) |
| Docker volumes | `*_volume_*.tar.gz` | GraphHopper graph cache, etc. |
| Configuration | `*_config.tar.gz` | `docker-compose.yml`, environment files |

---

## 2. Restore Procedures

### Restore PostgreSQL Database

```bash
# 1. Stop services that connect to the database
cd /opt/smartroad && docker-compose stop api

# 2. Drop and recreate the database
PGPASSWORD=<password> dropdb -h localhost -U smartroad smartroad
PGPASSWORD=<password> createdb -h localhost -U smartroad smartroad

# 3. Restore from backup
gunzip -c /var/backups/smartroad/daily/daily_smartroad_20260309_030000_db.sql.gz \
  | PGPASSWORD=<password> psql -h localhost -U smartroad -d smartroad

# 4. Restart services
cd /opt/smartroad && docker-compose start api

# 5. Verify
PGPASSWORD=<password> psql -h localhost -U smartroad -d smartroad -c "SELECT count(*) FROM hazards;"
```

### Restore Docker Volumes

```bash
# Restore GraphHopper data
docker run --rm \
  -v graphhopper-data:/volume \
  -v /var/backups/smartroad/daily:/backup \
  alpine \
  tar xzf "/backup/daily_smartroad_20260309_030000_volume_graphhopper-data.tar.gz" -C /volume

# Restart GraphHopper
cd /opt/smartroad && docker-compose restart graphhopper
```

### Full Server Recovery

```bash
# 1. Provision a new Ubuntu Server
# 2. Run setup script:
sudo ./scripts/server-setup.sh

# 3. Clone the repository:
git clone <repo-url> /opt/smartroad

# 4. Restore configuration:
sudo tar xzf /var/backups/smartroad/weekly/weekly_*.tar.gz -C /opt/smartroad

# 5. Restore Docker volumes (see above)

# 6. Restore PostgreSQL (see above)

# 7. Start all services:
cd /opt/smartroad && docker-compose up -d

# 8. Verify health:
curl http://localhost:8989/health
```

---

## 3. Recovery Scenarios

### Scenario A: GraphHopper Service Failure

**Symptoms:** Routing fails, GraphHopper returns 500 errors.

**Recovery:**
```bash
# Check logs
docker-compose logs graphhopper

# Restart the service
docker-compose restart graphhopper

# If the graph is corrupted, restore from volume backup (see section 2)
# Then rebuild:
docker-compose exec graphhopper java -jar graphhopper.jar --action import
```

### Scenario B: Database Corruption

**Symptoms:** App data is inconsistent, queries fail.

**Recovery:**
1. Stop all services that write to the database
2. Restore from the most recent daily backup
3. If daily backup is also corrupted, use the most recent weekly backup
4. Run integrity checks:
   ```sql
   SELECT count(*) FROM hazards;
   SELECT count(*) FROM profiles;
   -- Verify no orphaned records
   ```

### Scenario C: Full Server Failure

**Symptoms:** Server is unreachable, hardware failure.

**Recovery:**
1. Provision new server hardware
2. Follow "Full Server Recovery" procedure above
3. Update DNS records (if using A records instead of Cloudflare Tunnel)
4. Verify all services are operational
5. Reroute Cloudflare Tunnel to new server IP

### Scenario D: Accidental Data Deletion

**Symptoms:** User reports missing data, routes or hazards disappear.

**Recovery:**
1. Identify the affected tables and approximate time of deletion
2. Restore the specific backup to a temporary database:
   ```bash
   createdb -U smartroad smartroad_restore
   gunzip -c /var/backups/smartroad/daily/daily_*.sql.gz | \
     PGPASSWORD=<password> psql -U smartroad -d smartroad_restore
   ```
3. Export the missing records:
   ```bash
   PGPASSWORD=<password> psql -U smartroad -d smartroad_restore \
     -c "\COPY (SELECT * FROM hazards WHERE created_at > '2026-03-08') TO 'missing_hazards.csv' CSV"
   ```
4. Import into production:
   ```bash
   PGPASSWORD=<password> psql -U smartroad -d smartroad \
     -c "\COPY hazards FROM 'missing_hazards.csv' CSV"
   ```
5. Drop the temporary database:
   ```bash
   dropdb -U smartroad smartroad_restore
   ```

---

## 4. Verification

After any restore operation, verify:

```bash
# PostgreSQL — check row counts
PGPASSWORD=<password> psql -h localhost -U smartroad -d smartroad << 'SQL'
SELECT 'hazards' AS table_name, count(*) FROM public.hazards
UNION ALL
SELECT 'profiles', count(*) FROM public.profiles
UNION ALL
SELECT 'saved_routes', count(*) FROM public.saved_routes
UNION ALL
SELECT 'fuel_stations', count(*) FROM public.fuel_stations
UNION ALL
SELECT 'user_stickers', count(*) FROM public.user_stickers;
SQL

# Docker — check all containers are running
cd /opt/smartroad && docker-compose ps

# GraphHopper — verify routing works
curl -s "http://localhost:8989/health" | head -1

# Monitoring — check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | head -20
```

---

## 5. Emergency Contacts

| Role | Contact | Notes |
|------|---------|-------|
| System Administrator | [admin email] | Primary contact for server issues |
| Database Administrator | [dba email] | Database-specific recovery |
| DevOps Lead | [devops email] | Deployment and infrastructure |
| The Heedful Team | [team email] | General escalation |

---

## Appendix: Quick Reference

| Action | Command |
|--------|---------|
| List available backups | `ls -lh /var/backups/smartroad/daily/` |
| View backup logs | `tail -f /var/log/smartroad-backup.log` |
| Test restore (dry run) | `gunzip -c <backup>.sql.gz > /dev/null && echo "Valid"` |
| Check last backup time | `ls -t /var/backups/smartroad/daily/ \| head -1` |
| Check disk space | `df -h /var/backups` |

---

*"Be Heedful on the Road" — **SmartRoad**, a product of **The Heedful** 🇵🇭*
