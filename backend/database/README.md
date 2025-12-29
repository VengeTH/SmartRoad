# Database Setup

Database configuration and setup notes for SmartRoad backend.

## Current Status

**MVP:** Using Supabase (cloud-hosted PostgreSQL with PostGIS)

**Future:** May migrate to self-hosted PostgreSQL for:
- Route caching
- Analytics data
- Custom extensions
- Cost optimization

## Supabase (Current - MVP)

- **Location:** Cloud-hosted
- **Extensions:** PostGIS enabled
- **Schema:** See `supabase_schema.sql` in project root
- **Connection:** Via Supabase client SDK in Flutter app

## Self-Hosted PostgreSQL (Future)

### Planned Setup

When implementing self-hosted database:

```yaml
# In backend/docker-compose.yml
postgres:
  image: postgis/postgis:15-3.3
  environment:
    - POSTGRES_DB=smartroad
    - POSTGRES_USER=smartroad
    - POSTGRES_PASSWORD=change_me_in_production
  volumes:
    - postgres-data:/var/lib/postgresql/data
    - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql
  ports:
    - "5432:5432"
```

### Features

- **PostGIS:** Spatial data support
- **Extensions:** Custom routing extensions (future)
- **Backup:** Automated backup strategy
- **Replication:** Master-slave setup for production

## Migration Path (Future)

1. **Phase 1:** Keep Supabase for MVP
2. **Phase 2:** Add self-hosted PostgreSQL for route caching
3. **Phase 3:** Migrate user data (if needed)
4. **Phase 4:** Full migration (if cost-effective)

## Notes

- Database service is **not implemented in MVP**
- All data currently stored in Supabase
- Future database setup will be documented here



