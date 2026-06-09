-- ============================================================================
-- SmartRoad — Weather Cache Table
-- ============================================================================
-- Caches weather data fetched from Open-Meteo / OpenWeatherMap to reduce
-- API calls and provide offline fallback.
--
-- Run after the main schema (supabase_schema_merged.sql).
-- ============================================================================

CREATE TABLE IF NOT EXISTS SmartRoad.weather_cache (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- * Grid cell identifier (rounded lat/lon to 0.5° grid)
  grid_lat DOUBLE PRECISION NOT NULL,
  grid_lon DOUBLE PRECISION NOT NULL,
  
  -- * Weather data payload
  temperature_celsius DOUBLE PRECISION,
  precipitation_mmh DOUBLE PRECISION,
  weather_code INTEGER,
  weather_condition TEXT, -- * e.g., "sunny", "cloudy", "light_rain", "heavy_rain"
  
  -- * Source of the data
  source TEXT NOT NULL DEFAULT 'open_meteo',
  
  -- * Timestamps
  fetched_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- * Constraints
  CONSTRAINT weather_cache_unique_cell UNIQUE (grid_lat, grid_lon),
  CONSTRAINT valid_temperature CHECK (temperature_celsius IS NULL OR (temperature_celsius >= -50 AND temperature_celsius <= 60)),
  CONSTRAINT valid_precipitation CHECK (precipitation_mmh IS NULL OR (precipitation_mmh >= 0 AND precipitation_mmh <= 500)),
  CONSTRAINT valid_source CHECK (source IN ('open_meteo', 'openweathermap', 'rainviewer', 'proxy'))
);

-- * Index for fast lookups by grid cell
CREATE INDEX IF NOT EXISTS idx_weather_cache_grid
  ON SmartRoad.weather_cache(grid_lat, grid_lon);

-- * Index for expiration cleanup
CREATE INDEX IF NOT EXISTS idx_weather_cache_expires_at
  ON SmartRoad.weather_cache(expires_at);

-- * Index for source tracking
CREATE INDEX IF NOT EXISTS idx_weather_cache_source
  ON SmartRoad.weather_cache(source);

-- * Enable Row Level Security
ALTER TABLE SmartRoad.weather_cache ENABLE ROW LEVEL SECURITY;

-- * RLS: Anyone can read weather cache (it's public data)
CREATE POLICY "Weather cache is viewable by everyone"
  ON SmartRoad.weather_cache FOR SELECT
  USING (true);

-- * RLS: Only service role can write to cache
CREATE POLICY "Service role can manage weather cache"
  ON SmartRoad.weather_cache FOR ALL
  USING (auth.role() = 'service_role');

-- * Function to get cached weather (returns null if expired)
CREATE OR REPLACE FUNCTION SmartRoad.get_cached_weather(
  p_lat DOUBLE PRECISION,
  p_lon DOUBLE PRECISION
)
RETURNS TABLE (
  temperature_celsius DOUBLE PRECISION,
  precipitation_mmh DOUBLE PRECISION,
  weather_condition TEXT,
  source TEXT,
  fetched_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    wc.temperature_celsius,
    wc.precipitation_mmh,
    wc.weather_condition,
    wc.source,
    wc.fetched_at
  FROM SmartRoad.weather_cache wc
  WHERE wc.grid_lat = round(p_lat * 2) / 2
    AND wc.grid_lon = round(p_lon * 2) / 2
    AND wc.expires_at > NOW()
  ORDER BY wc.fetched_at DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- * Function to upsert weather cache
CREATE OR REPLACE FUNCTION SmartRoad.upsert_weather_cache(
  p_lat DOUBLE PRECISION,
  p_lon DOUBLE PRECISION,
  p_temperature_celsius DOUBLE PRECISION,
  p_precipitation_mmh DOUBLE PRECISION,
  p_weather_code INTEGER,
  p_weather_condition TEXT,
  p_source TEXT,
  p_ttl_minutes INTEGER DEFAULT 10
) RETURNS UUID AS $$
DECLARE
  v_grid_lat DOUBLE PRECISION;
  v_grid_lon DOUBLE PRECISION;
  v_id UUID;
BEGIN
  v_grid_lat := round(p_lat * 2) / 2;
  v_grid_lon := round(p_lon * 2) / 2;
  
  INSERT INTO SmartRoad.weather_cache (
    grid_lat, grid_lon,
    temperature_celsius, precipitation_mmh,
    weather_code, weather_condition,
    source, expires_at
  ) VALUES (
    v_grid_lat, v_grid_lon,
    p_temperature_celsius, p_precipitation_mmh,
    p_weather_code, p_weather_condition,
    p_source, NOW() + (p_ttl_minutes || ' minutes')::INTERVAL
  )
  ON CONFLICT (grid_lat, grid_lon)
  DO UPDATE SET
    temperature_celsius = EXCLUDED.temperature_celsius,
    precipitation_mmh = EXCLUDED.precipitation_mmh,
    weather_code = EXCLUDED.weather_code,
    weather_condition = EXCLUDED.weather_condition,
    source = EXCLUDED.source,
    fetched_at = NOW(),
    expires_at = EXCLUDED.expires_at
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- * Cleanup expired entries (run via pg_cron or Supabase scheduled function)
CREATE OR REPLACE FUNCTION SmartRoad.cleanup_expired_weather_cache()
RETURNS INTEGER AS $$
DECLARE
  v_deleted INTEGER;
BEGIN
  DELETE FROM SmartRoad.weather_cache
  WHERE expires_at < NOW() - INTERVAL '1 hour'
  AND fetched_at < NOW() - INTERVAL '1 day';
  
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE SmartRoad.weather_cache IS 'Cached weather data per 0.5° grid cell with TTL-based expiration';
COMMENT ON FUNCTION SmartRoad.get_cached_weather IS 'Returns non-expired cached weather for a lat/lon point';
COMMENT ON FUNCTION SmartRoad.upsert_weather_cache IS 'Upserts weather data for a grid cell with configurable TTL';
COMMENT ON FUNCTION SmartRoad.cleanup_expired_weather_cache IS 'Removes entries that expired more than 1 hour ago and are older than 1 day';

