-- ============================================================================
-- SmartRoad — Database Roles & Permissions
-- ============================================================================
-- Sets up PostgreSQL database roles and granular permissions.
-- Run this once after deploying PostgreSQL schema.
-- ============================================================================

-- ============================================================================
-- 1. APPLICATION ROLES
-- ============================================================================

-- * Anonymous role (not authenticated — used by RLS defaults)
-- * This is built into Supabase; for self-hosted Postgres, ensure it exists:
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END $$;

-- ============================================================================
-- 2. DATABASE USER ROLES
-- ============================================================================

-- * Application user (used by the backend API)
-- * Created by docker-compose, but ensure proper permissions:
GRANT CONNECT ON DATABASE smartroad TO smartroad;
GRANT USAGE ON SCHEMA public TO smartroad;

-- * Grant table permissions (app user inherits from roles)
-- * anon: read-only access to public data
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- * authenticated: read + write own data (RLS handles per-row)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- * service_role: full access (bypasses RLS)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- ============================================================================
-- 3. FUTURE-PROOF: Default privileges for new tables
-- ============================================================================
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;

-- ============================================================================
-- 4. FUNCTION EXECUTION PERMISSIONS
-- ============================================================================

-- * Allow anon/authenticated to execute SECURITY DEFINER functions
GRANT EXECUTE ON FUNCTION SmartRoad.get_cached_weather TO anon, authenticated;
GRANT EXECUTE ON FUNCTION SmartRoad.upsert_weather_cache TO service_role;
GRANT EXECUTE ON FUNCTION SmartRoad.cleanup_expired_weather_cache TO service_role;
GRANT EXECUTE ON FUNCTION SmartRoad.get_nearby_alerts TO anon, authenticated;
GRANT EXECUTE ON FUNCTION SmartRoad.calculate_reputation TO authenticated;
GRANT EXECUTE ON FUNCTION SmartRoad.get_user_standing TO anon, authenticated;
GRANT EXECUTE ON FUNCTION SmartRoad.increment_valid_reports TO service_role;
GRANT EXECUTE ON FUNCTION SmartRoad.submit_fuel_price_update TO anon, authenticated;
GRANT EXECUTE ON FUNCTION SmartRoad.submit_fuel_station TO anon, authenticated;
GRANT EXECUTE ON FUNCTION SmartRoad.get_latest_fuel_prices TO anon, authenticated;
GRANT EXECUTE ON FUNCTION SmartRoad.recalculate_confidence_score TO service_role;
GRANT EXECUTE ON FUNCTION SmartRoad.get_pending_fuel_stations TO authenticated;
GRANT EXECUTE ON FUNCTION SmartRoad.approve_fuel_station TO authenticated;
GRANT EXECUTE ON FUNCTION SmartRoad.reject_fuel_station TO authenticated;
GRANT EXECUTE ON FUNCTION SmartRoad.check_device_fuel_rate_limit TO service_role;
GRANT EXECUTE ON FUNCTION SmartRoad.check_station_fuel_cooldown TO service_role;
GRANT EXECUTE ON FUNCTION SmartRoad.handle_new_user TO service_role;
GRANT EXECUTE ON FUNCTION SmartRoad.handle_updated_at TO service_role;

-- ============================================================================
-- 5. REVOKE DANGEROUS PERMISSIONS FROM PUBLIC
-- ============================================================================

-- * Ensure no one can create functions/tables in public schema except owner
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- * Ensure only service_role can modify schema
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO PUBLIC;

-- * Functions that modify data should only be callable by authenticated users
-- * (Already handled via SECURITY DEFINER + auth checks)

-- ============================================================================
-- 6. AUDIT LOGGING (future)
-- ============================================================================

-- * Create audit trigger function (can be applied to sensitive tables)
CREATE OR REPLACE FUNCTION SmartRoad.audit_table_changes()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO SmartRoad.audit_log (table_name, operation, old_data, new_data, changed_by)
  VALUES (
    TG_TABLE_NAME,
    TG_OP,
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW) ELSE NULL END,
    auth.uid()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- * Create audit_log table
CREATE TABLE IF NOT EXISTS SmartRoad.audit_log (
  id BIGSERIAL PRIMARY KEY,
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL,
  old_data JSONB,
  new_data JSONB,
  changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_table_name ON SmartRoad.audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at ON SmartRoad.audit_log(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_by ON SmartRoad.audit_log(changed_by);

ALTER TABLE SmartRoad.audit_log ENABLE ROW LEVEL SECURITY;

-- * Only admins can read audit logs
CREATE POLICY "Admins can read audit logs"
  ON SmartRoad.audit_log FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Service role can insert audit logs
CREATE POLICY "Service role can insert audit logs"
  ON SmartRoad.audit_log FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

COMMENT ON TABLE SmartRoad.audit_log IS 'Immutable audit trail for sensitive table changes';
COMMENT ON FUNCTION SmartRoad.audit_table_changes IS 'Trigger function that logs INSERT/UPDATE/DELETE operations';

