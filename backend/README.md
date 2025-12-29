# SmartRoad Backend Services

Backend infrastructure for SmartRoad navigation app.

## Structure

```
backend/
├── graphhopper/        # Self-hosted routing engine (Docker)
├── api/                # SmartRoad API (placeholder - future)
├── database/           # Database setup notes (future)
└── docker-compose.yml  # Unified backend orchestration
```

## Services

### GraphHopper (MVP - Active)

Self-hosted routing engine providing:
- Motorcycle routing
- Toll avoidance
- Fastest route calculation

**Status:** ✅ Ready for use

**Documentation:** See [graphhopper/README.md](./graphhopper/README.md)

**Quick Start:**
```bash
cd backend
docker-compose up -d graphhopper
```

### SmartRoad API (Future)

Main backend API service.

**Status:** 🚧 Placeholder only - Not implemented in MVP

**Documentation:** See [api/README.md](./api/README.md)

### Database (Future)

PostgreSQL database for:
- User data
- Route caching
- Analytics

**Status:** 🚧 Not implemented in MVP

**Note:** Currently using Supabase for MVP. Database service will be added in future phases.

## Quick Start

### Start All Services

```bash
cd backend
docker-compose up -d
```

### Start Individual Service

```bash
# GraphHopper only
docker-compose up -d graphhopper
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f graphhopper
```

### Stop Services

```bash
docker-compose down
```

## Development Workflow

### MVP Phase (Current)

1. **GraphHopper** is the only active backend service
2. Flutter app can call GraphHopper directly for routing
3. Supabase handles authentication and data storage

### Future Phases

1. **Phase 2:** Implement SmartRoad API
   - Wrap GraphHopper calls
   - Add authentication middleware
   - Implement basic business logic

2. **Phase 3:** Add permission system
   - Route access control
   - HOA restrictions
   - User role management

3. **Phase 4:** Route selling
   - Payment integration
   - Premium route access
   - Subscription management

4. **Phase 5:** Advanced features
   - Route analytics
   - Traffic integration
   - ML optimization

## Environment Variables

Create a `.env` file in `backend/` directory (optional):

```env
# GraphHopper
GRAPHHOPPER_MEMORY=2g
GRAPHHOPPER_PORT=8989

# API (Future)
API_PORT=3000
NODE_ENV=development

# Database (Future)
POSTGRES_DB=smartroad
POSTGRES_USER=smartroad
POSTGRES_PASSWORD=change_me
```

## Network Architecture

```
┌─────────────────┐
│  Flutter App    │
│  (Mobile)       │
└────────┬────────┘
         │
         │ HTTP/HTTPS
         │
┌────────▼─────────────────────────┐
│  SmartRoad API (Future)          │
│  - Authentication                │
│  - Business Logic                │
│  - Route Processing              │
└────────┬─────────────────────────┘
         │
         │ Internal Network
         │
┌────────▼────────┐    ┌──────────────┐
│  GraphHopper    │    │  PostgreSQL  │
│  (Routing)      │    │  (Future)    │
└─────────────────┘    └──────────────┘
```

**Current MVP:** Flutter app connects directly to GraphHopper (bypassing API layer).

## Troubleshooting

### Port Conflicts

If ports are already in use:
```bash
# Check what's using the port
netstat -ano | findstr :8989  # Windows
lsof -i :8989                  # Linux/Mac

# Change port in docker-compose.yml
ports:
  - "8990:8989"  # Use 8990 externally
```

### Resource Issues

If services fail to start:
```bash
# Check Docker resources
docker stats

# Increase memory limits in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 4G
```

### Volume Issues

To reset volumes:
```bash
# Stop services
docker-compose down

# Remove volumes (WARNING: Data loss)
docker-compose down -v

# Start fresh
docker-compose up -d
```

## Production Considerations

**MVP Note:** Current setup is for local development only.

For production, consider:
- [ ] Reverse proxy (Nginx/Traefik)
- [ ] SSL/TLS certificates
- [ ] Environment-specific configurations
- [ ] Monitoring and logging (Prometheus/Grafana)
- [ ] Backup strategies
- [ ] Resource scaling
- [ ] Security hardening
- [ ] Rate limiting
- [ ] API authentication

## License

See individual service READMEs for license information.



