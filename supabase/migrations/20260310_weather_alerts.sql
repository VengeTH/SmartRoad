-- ============================================================================
-- SmartRoad — Weather Alerts Table
-- ============================================================================
-- Stores weather alerts (PAGASA advisories, flood warnings, etc.)
-- that can be displayed to users during navigation.
--
-- Run after the main schema (supabase_schema_merged.sql).
-- ============================================================================

-- * Create enum for alert severity
CREATE TYPE alert_severity AS ENUM (
  'advisory',   -- * Informational (e.g., "Light rain expected")
  'watch',      -- * Prepare (e.g., "Possible flooding in low-lying areas")
  'warning',    -- * Take action (e.g., "Heavy rainfall warning")
  'critical'    -- * Emergency (e.g., "Evacuation order")
);

-- * Create enum for alert type
CREATE TYPE alert_type AS ENUM (
  'flood',
  'typhoon',
  'earthquake',
  'landslide',
  'heavy_rain',
  'heat',
  'fog',
  'thunderstorm',
  'traffic',
  'road_closure',
  'other'
);

-- * Create weather_alerts table
CREATE TABLE IF NOT EXISTS SmartRoad.weather_alerts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- * Alert metadata
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  alert_type alert_type NOT NULL,
  alert_severity alert_severity NOT NULL DEFAULT 'advisory',
  
  -- * Geographic scope
  -- * NULL = province-wide or national alert
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  -- * Radius in meters (if lat/lon set, this is the affected area radius)
  radius_meters INTEGER,
  -- * Area description (e.g., "Metro Manila", "Rizal Province")
  affected_area TEXT,
  
  -- * Source of the alert
  source TEXT NOT NULL DEFAULT 'community',
  source_url TEXT, -- * Link to official source (e.g., PAGASA website)
  
  -- * Validity period
  starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  
  -- * Metadata
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- * Admin user who created it
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- * Constraints
  CONSTRAINT valid_radius CHECK (radius_meters IS NULL OR radius_meters > 0),
  CONSTRAINT valid_source CHECK (source IN ('pagasa', 'phivolcs', 'ndrrmc', 'community', 'lgu', 'admin', 'system', 'automatic')),
  CONSTRAINT valid_coordinates CHECK (
    (latitude IS NULL AND longitude IS NULL) OR
    (latitude IS NOT NULL AND longitude IS NOT NULL AND latitude >= -90 AND latitude <= 90 AND longitude >= -180 AND longitude <= 180)
  )
);

-- * Indexes for performance
CREATE INDEX IF NOT EXISTS idx_weather_alerts_type ON SmartRoad.weather_alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_weather_alerts_severity ON SmartRoad.weather_alerts(alert_severity);
CREATE INDEX IF NOT EXISTS idx_weather_alerts_active ON SmartRoad.weather_alerts(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_weather_alerts_expires_at ON SmartRoad.weather_alerts(expires_at);
CREATE INDEX IF NOT EXISTS idx_weather_alerts_created_at ON SmartRoad.weather_alerts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_weather_alerts_location
  ON SmartRoad.weather_alerts(latitude, longitude)
  WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_weather_alerts_starts_at ON SmartRoad.weather_alerts(starts_at);

-- * Enable Row Level Security
ALTER TABLE SmartRoad.weather_alerts ENABLE ROW LEVEL SECURITY;

-- * RLS: Anyone can read active alerts
CREATE POLICY "Active alerts are viewable by everyone"
  ON SmartRoad.weather_alerts FOR SELECT
  USING (is_active = true OR (expires_at IS NOT NULL AND expires_at > NOW()));

-- * RLS: Admins can manage alerts
CREATE POLICY "Admins can manage weather alerts"
  ON SmartRoad.weather_alerts FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * RLS: Service role can insert alerts (for automated PAGASA/PHIVOLCS ingestion)
CREATE POLICY "Service role can insert alerts"
  ON SmartRoad.weather_alerts FOR INSERT
  WITH CHECK (auth.role() = 'service_role' OR auth.role() = 'authenticated');

-- * Function to get active alerts near a location
CREATE OR REPLACE FUNCTION SmartRoad.get_nearby_alerts(
  p_lat DOUBLE PRECISION,
  p_lon DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 50.0
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  alert_type TEXT,
  alert_severity TEXT,
  distance_km DOUBLE PRECISION,
  affected_area TEXT,
  source TEXT,
  starts_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    wa.id,
    wa.title,
    wa.description,
    wa.alert_type::TEXT,
    wa.alert_severity::TEXT,
    CASE
      WHEN wa.latitude IS NOT NULL AND wa.longitude IS NOT NULL THEN
        earth_distance(
          ll_to_earth(p_lat, p_lon),
          ll_to_earth(wa.latitude, wa.longitude)
        ) / 1000.0
      ELSE NULL
    END AS distance_km,
    wa.affected_area,
    wa.source,
    wa.starts_at,
    wa.expires_at
  FROM SmartRoad.weather_alerts wa
  WHERE wa.is_active = true
    AND (wa.expires_at IS NULL OR wa.expires_at > NOW())
    AND wa.starts_at <= NOW()
    AND (
      -- * National alerts (no coordinates) always show
      (wa.latitude IS NULL AND wa.longitude IS NULL)
      OR
      -- * Location-specific alerts within radius
      (wa.latitude IS NOT NULL AND wa.longitude IS NOT NULL
        AND earth_distance(
          ll_to_earth(p_lat, p_lon),
          ll_to_earth(wa.latitude, wa.longitude)
        ) / 1000.0 <= p_radius_km)
    )
  ORDER BY wa.alert_severity DESC, wa.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- * Trigger for updated_at
DROP TRIGGER IF EXISTS update_weather_alerts_updated_at ON SmartRoad.weather_alerts;
CREATE TRIGGER update_weather_alerts_updated_at
  BEFORE UPDATE ON SmartRoad.weather_alerts
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();

COMMENT ON TABLE SmartRoad.weather_alerts IS 'Weather and disaster alerts (PAGASA, PHIVOLCS, NDRRMC, community)';
COMMENT ON FUNCTION SmartRoad.get_nearby_alerts IS 'Returns active alerts near a lat/lon point within a given radius';

