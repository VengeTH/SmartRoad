-- ============================================================================
-- * FUEL STATIONS MODULE (Community Fuel Pricing with Anonymous Submissions)
-- ============================================================================
-- Run this after the main supabase_schema.sql (and after profiles table exists)
--
-- ⚠️ NOTE: This schema is prepared for future database integration. As of now,
-- SmartRoad runs in demo mode only. No database has been set up on the server yet.
-- Database integration will be added in the future after server infrastructure is fully set up.
--
-- Features enabled:
-- - Fuel stations (OSM-discovered or community-added)
-- - Fuel price updates (anonymous or authenticated)
-- - Incorrect price reports
-- - Rate limiting (device-based and per-fuel)
-- - Admin moderation for pending stations
-- - Confidence scoring based on report counts
--
-- Admin check:
-- - Uses `SmartRoad.profiles.reporter_level = 'Admin'`

-- ============================================================================
-- * FUEL STATIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS SmartRoad.fuel_stations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  brand TEXT,
  province TEXT NOT NULL,
  city TEXT NOT NULL,
  region TEXT,
  verified BOOLEAN DEFAULT FALSE,
  source TEXT NOT NULL DEFAULT 'community',
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by_device_id TEXT,
  CONSTRAINT fuel_station_name_not_empty CHECK (length(trim(name)) > 0),
  CONSTRAINT fuel_station_source_valid CHECK (source IN ('osm', 'community', 'official'))
);

-- * Geospatial index for location queries
CREATE INDEX IF NOT EXISTS idx_fuel_stations_location ON SmartRoad.fuel_stations USING GIST (
  ll_to_earth(latitude, longitude)
);

CREATE INDEX IF NOT EXISTS idx_fuel_stations_province ON SmartRoad.fuel_stations(province);
CREATE INDEX IF NOT EXISTS idx_fuel_stations_city ON SmartRoad.fuel_stations(city);
CREATE INDEX IF NOT EXISTS idx_fuel_stations_verified ON SmartRoad.fuel_stations(verified);
CREATE INDEX IF NOT EXISTS idx_fuel_stations_source ON SmartRoad.fuel_stations(source);
CREATE INDEX IF NOT EXISTS idx_fuel_stations_created_at ON SmartRoad.fuel_stations(created_at DESC);

ALTER TABLE SmartRoad.fuel_stations ENABLE ROW LEVEL SECURITY;

-- * Everyone can read fuel stations
CREATE POLICY "Fuel stations are viewable by everyone"
  ON SmartRoad.fuel_stations FOR SELECT
  USING (true);

-- * Anyone can insert (anonymous submissions allowed via RPC)
CREATE POLICY "Anyone can submit fuel stations"
  ON SmartRoad.fuel_stations FOR INSERT
  WITH CHECK (true);

-- * Only Admin can update/delete
CREATE POLICY "Admins can update fuel stations"
  ON SmartRoad.fuel_stations FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

CREATE POLICY "Admins can delete fuel stations"
  ON SmartRoad.fuel_stations FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc
    WHERE proname = 'handle_updated_at'
  ) THEN
    DROP TRIGGER IF EXISTS update_fuel_stations_updated_at ON SmartRoad.fuel_stations;
    CREATE TRIGGER update_fuel_stations_updated_at
      BEFORE UPDATE ON SmartRoad.fuel_stations
      FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();
  END IF;
END $$;

-- ============================================================================
-- * FUEL PRICE UPDATES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS SmartRoad.fuel_price_updates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  station_id UUID REFERENCES SmartRoad.fuel_stations(id) ON DELETE CASCADE NOT NULL,
  fuel_type TEXT NOT NULL,
  price DOUBLE PRECISION NOT NULL,
  reporter_latitude DOUBLE PRECISION NOT NULL,
  reporter_longitude DOUBLE PRECISION NOT NULL,
  reporter_distance_meters DOUBLE PRECISION,
  photo_url TEXT,
  confidence_score DOUBLE PRECISION DEFAULT 1.0,
  source TEXT NOT NULL DEFAULT 'community',
  device_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT fuel_type_valid CHECK (fuel_type IN ('unleaded_91', 'unleaded_95', 'unleaded_97', 'diesel')),
  CONSTRAINT price_positive CHECK (price > 0),
  CONSTRAINT confidence_valid CHECK (confidence_score >= 0.0 AND confidence_score <= 1.0),
  CONSTRAINT source_valid CHECK (source IN ('community', 'official', 'osm', 'smartroad', 'verified'))
);

CREATE INDEX IF NOT EXISTS idx_fuel_price_updates_station_id ON SmartRoad.fuel_price_updates(station_id);
CREATE INDEX IF NOT EXISTS idx_fuel_price_updates_fuel_type ON SmartRoad.fuel_price_updates(fuel_type);
CREATE INDEX IF NOT EXISTS idx_fuel_price_updates_created_at ON SmartRoad.fuel_price_updates(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fuel_price_updates_device_id ON SmartRoad.fuel_price_updates(device_id);
CREATE INDEX IF NOT EXISTS idx_fuel_price_updates_user_id ON SmartRoad.fuel_price_updates(user_id);

-- * Composite index for latest price queries
CREATE INDEX IF NOT EXISTS idx_fuel_price_updates_station_fuel_time
  ON SmartRoad.fuel_price_updates(station_id, fuel_type, created_at DESC);

-- * Migration: allow source values 'smartroad' and 'verified' (for existing DBs)
ALTER TABLE SmartRoad.fuel_price_updates DROP CONSTRAINT IF EXISTS source_valid;
ALTER TABLE SmartRoad.fuel_price_updates ADD CONSTRAINT source_valid
  CHECK (source IN ('community', 'official', 'osm', 'smartroad', 'verified'));

ALTER TABLE SmartRoad.fuel_price_updates ENABLE ROW LEVEL SECURITY;

-- * Everyone can read price updates
CREATE POLICY "Fuel price updates are viewable by everyone"
  ON SmartRoad.fuel_price_updates FOR SELECT
  USING (true);

-- * Insert via RPC only (enforces rate limiting)
CREATE POLICY "Anyone can submit price updates via RPC"
  ON SmartRoad.fuel_price_updates FOR INSERT
  WITH CHECK (true);

-- ============================================================================
-- * FUEL PRICE REPORTS TABLE (Incorrect Price Flagging)
-- ============================================================================
CREATE TABLE IF NOT EXISTS SmartRoad.fuel_price_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  station_id UUID REFERENCES SmartRoad.fuel_stations(id) ON DELETE CASCADE NOT NULL,
  fuel_type TEXT NOT NULL,
  reported_incorrect_price DOUBLE PRECISION NOT NULL,
  reason TEXT,
  device_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  CONSTRAINT fuel_type_valid CHECK (fuel_type IN ('unleaded_91', 'unleaded_95', 'unleaded_97', 'diesel')),
  CONSTRAINT status_valid CHECK (status IN ('pending', 'reviewed', 'dismissed'))
);

CREATE INDEX IF NOT EXISTS idx_fuel_price_reports_station_id ON SmartRoad.fuel_price_reports(station_id);
CREATE INDEX IF NOT EXISTS idx_fuel_price_reports_fuel_type ON SmartRoad.fuel_price_reports(fuel_type);
CREATE INDEX IF NOT EXISTS idx_fuel_price_reports_status ON SmartRoad.fuel_price_reports(status);
CREATE INDEX IF NOT EXISTS idx_fuel_price_reports_created_at ON SmartRoad.fuel_price_reports(created_at DESC);

ALTER TABLE SmartRoad.fuel_price_reports ENABLE ROW LEVEL SECURITY;

-- * Everyone can read reports (for transparency)
CREATE POLICY "Fuel price reports are viewable by everyone"
  ON SmartRoad.fuel_price_reports FOR SELECT
  USING (true);

-- * Anyone can submit reports
CREATE POLICY "Anyone can submit price reports"
  ON SmartRoad.fuel_price_reports FOR INSERT
  WITH CHECK (true);

-- * Only Admin can update
CREATE POLICY "Admins can update price reports"
  ON SmartRoad.fuel_price_reports FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- ============================================================================
-- * RATE LIMITING HELPER FUNCTIONS
-- ============================================================================

-- * Check if device has exceeded per-fuel submission rate (5 per 10 minutes)
CREATE OR REPLACE FUNCTION check_device_fuel_rate_limit(
  p_device_id TEXT,
  p_fuel_type TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  submission_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO submission_count
  FROM SmartRoad.fuel_price_updates
  WHERE device_id = p_device_id
    AND fuel_type = p_fuel_type
    AND created_at > NOW() - INTERVAL '10 minutes';

  RETURN submission_count < 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- * Check same-station same-fuel cooldown (15 minutes)
CREATE OR REPLACE FUNCTION check_station_fuel_cooldown(
  p_device_id TEXT,
  p_station_id UUID,
  p_fuel_type TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  last_submission TIMESTAMPTZ;
BEGIN
  SELECT MAX(created_at)
  INTO last_submission
  FROM SmartRoad.fuel_price_updates
  WHERE device_id = p_device_id
    AND station_id = p_station_id
    AND fuel_type = p_fuel_type;

  IF last_submission IS NULL THEN
    RETURN TRUE;
  END IF;

  RETURN (NOW() - last_submission) > INTERVAL '15 minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- * FUEL PRICE SUBMISSION RPC
-- ============================================================================

-- * Submit fuel price update with validation and rate limiting
CREATE OR REPLACE FUNCTION submit_fuel_price_update(
  p_station_id UUID,
  p_fuel_type TEXT,
  p_price DOUBLE PRECISION,
  p_reporter_latitude DOUBLE PRECISION,
  p_reporter_longitude DOUBLE PRECISION,
  p_photo_url TEXT,
  p_device_id TEXT,
  p_user_id UUID DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
  v_distance_meters DOUBLE PRECISION;
  v_station_lat DOUBLE PRECISION;
  v_station_lon DOUBLE PRECISION;
  v_new_update_id UUID;
BEGIN
  -- * Validate rate limiting
  IF NOT check_device_fuel_rate_limit(p_device_id, p_fuel_type) THEN
    RETURN json_build_object('success', false, 'error', 'RATE_LIMIT_EXCEEDED', 'message', 'Too many submissions. Please wait.');
  END IF;

  IF NOT check_station_fuel_cooldown(p_device_id, p_station_id, p_fuel_type) THEN
    RETURN json_build_object('success', false, 'error', 'COOLDOWN_ACTIVE', 'message', 'Please wait 15 minutes before updating this fuel type again.');
  END IF;

  -- * Get station location and calculate distance
  SELECT latitude, longitude INTO v_station_lat, v_station_lon
  FROM SmartRoad.fuel_stations
  WHERE id = p_station_id;

  IF v_station_lat IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'STATION_NOT_FOUND', 'message', 'Fuel station not found.');
  END IF;

  v_distance_meters := earth_distance(
    ll_to_earth(p_reporter_latitude, p_reporter_longitude),
    ll_to_earth(v_station_lat, v_station_lon)
  );

  -- * Validate distance rules
  IF v_distance_meters > 200 THEN
    RETURN json_build_object('success', false, 'error', 'TOO_FAR', 'message', 'You must be within 200m of the station.');
  END IF;

  IF v_distance_meters > 50 AND p_photo_url IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'PHOTO_REQUIRED', 'message', 'Photo proof required when more than 50m away.');
  END IF;

  -- * Insert the price update (source and confidence_score set explicitly)
  INSERT INTO SmartRoad.fuel_price_updates (
    station_id,
    fuel_type,
    price,
    reporter_latitude,
    reporter_longitude,
    reporter_distance_meters,
    photo_url,
    source,
    confidence_score,
    device_id,
    user_id
  ) VALUES (
    p_station_id,
    p_fuel_type,
    p_price,
    p_reporter_latitude,
    p_reporter_longitude,
    v_distance_meters,
    p_photo_url,
    'community',
    1.0,
    p_device_id,
    p_user_id
  ) RETURNING id INTO v_new_update_id;

  -- * Update station timestamp
  UPDATE SmartRoad.fuel_stations
  SET updated_at = NOW()
  WHERE id = p_station_id;

  RETURN json_build_object('success', true, 'update_id', v_new_update_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- * SUBMIT NEW FUEL STATION RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION submit_fuel_station(
  p_name TEXT,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_brand TEXT,
  p_province TEXT,
  p_city TEXT,
  p_region TEXT,
  p_photo_url TEXT,
  p_device_id TEXT,
  p_user_id UUID DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
  v_new_station_id UUID;
BEGIN
  -- * Basic validation
  IF length(trim(p_name)) = 0 THEN
    RETURN json_build_object('success', false, 'error', 'INVALID_NAME', 'message', 'Station name is required.');
  END IF;

  IF length(trim(p_province)) = 0 OR length(trim(p_city)) = 0 THEN
    RETURN json_build_object('success', false, 'error', 'INVALID_LOCATION', 'message', 'Province and city are required.');
  END IF;

  -- * Insert the station (unverified)
  INSERT INTO SmartRoad.fuel_stations (
    name,
    latitude,
    longitude,
    brand,
    province,
    city,
    region,
    verified,
    source,
    photo_url,
    created_by_user_id,
    created_by_device_id
  ) VALUES (
    trim(p_name),
    p_latitude,
    p_longitude,
    p_brand,
    trim(p_province),
    trim(p_city),
    p_region,
    FALSE,
    'community',
    p_photo_url,
    p_user_id,
    p_device_id
  ) RETURNING id INTO v_new_station_id;

  RETURN json_build_object('success', true, 'station_id', v_new_station_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- * GET LATEST FUEL PRICES RPC
-- ============================================================================

-- * Get the latest prices for a specific station
CREATE OR REPLACE FUNCTION get_latest_fuel_prices(p_station_id UUID)
RETURNS TABLE (
  fuel_type TEXT,
  price DOUBLE PRECISION,
  updated_at TIMESTAMPTZ,
  source TEXT,
  confidence_score DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (fpu.fuel_type)
    fpu.fuel_type,
    fpu.price,
    fpu.created_at AS updated_at,
    fpu.source,
    fpu.confidence_score
  FROM SmartRoad.fuel_price_updates fpu
  WHERE fpu.station_id = p_station_id
  ORDER BY fpu.fuel_type, fpu.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- * RECALCULATE CONFIDENCE SCORE RPC
-- ============================================================================

-- * Recalculate confidence score based on report counts
CREATE OR REPLACE FUNCTION recalculate_confidence_score(
  p_station_id UUID,
  p_fuel_type TEXT
) RETURNS VOID AS $$
DECLARE
  v_report_count INTEGER;
  v_new_confidence DOUBLE PRECISION;
BEGIN
  -- * Count recent incorrect-price reports (last 7 days)
  SELECT COUNT(*)
  INTO v_report_count
  FROM SmartRoad.fuel_price_reports
  WHERE station_id = p_station_id
    AND fuel_type = p_fuel_type
    AND status = 'pending'
    AND created_at > NOW() - INTERVAL '7 days';

  -- * Calculate new confidence (1.0 decreasing by 0.2 per report, min 0.1)
  v_new_confidence := GREATEST(0.1, 1.0 - (v_report_count * 0.2));

  -- * Update the latest price update
  UPDATE SmartRoad.fuel_price_updates
  SET confidence_score = v_new_confidence
  WHERE id = (
    SELECT id
    FROM SmartRoad.fuel_price_updates
    WHERE station_id = p_station_id
      AND fuel_type = p_fuel_type
    ORDER BY created_at DESC
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- * TRIGGER: Auto-recalculate confidence on new report
-- ============================================================================

CREATE OR REPLACE FUNCTION trigger_recalculate_confidence()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM recalculate_confidence_score(NEW.station_id, NEW.fuel_type);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS fuel_price_report_confidence_update ON SmartRoad.fuel_price_reports;
CREATE TRIGGER fuel_price_report_confidence_update
  AFTER INSERT ON SmartRoad.fuel_price_reports
  FOR EACH ROW EXECUTE FUNCTION trigger_recalculate_confidence();

-- ============================================================================
-- * ADMIN QUERIES
-- ============================================================================

-- * Get pending fuel stations for admin review
CREATE OR REPLACE FUNCTION get_pending_fuel_stations()
RETURNS TABLE (
  id UUID,
  name TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  brand TEXT,
  province TEXT,
  city TEXT,
  region TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ,
  created_by_device_id TEXT
) AS $$
BEGIN
  -- * Only allow Admin
  IF NOT EXISTS (
    SELECT 1 FROM SmartRoad.profiles
    WHERE SmartRoad.profiles.id = auth.uid() AND reporter_level = 'Admin'
  ) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  RETURN QUERY
  SELECT
    fs.id,
    fs.name,
    fs.latitude,
    fs.longitude,
    fs.brand,
    fs.province,
    fs.city,
    fs.region,
    fs.photo_url,
    fs.created_at,
    fs.created_by_device_id
  FROM SmartRoad.fuel_stations fs
  WHERE fs.verified = FALSE
    AND fs.source = 'community'
  ORDER BY fs.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- * Approve fuel station (Admin only)
CREATE OR REPLACE FUNCTION approve_fuel_station(p_station_id UUID)
RETURNS JSON AS $$
BEGIN
  -- * Only allow Admin
  IF NOT EXISTS (
    SELECT 1 FROM SmartRoad.profiles
    WHERE SmartRoad.profiles.id = auth.uid() AND reporter_level = 'Admin'
  ) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Admin access required.');
  END IF;

  UPDATE SmartRoad.fuel_stations
  SET verified = TRUE, updated_at = NOW()
  WHERE id = p_station_id;

  IF FOUND THEN
    RETURN json_build_object('success', true);
  ELSE
    RETURN json_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Station not found.');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- * Reject fuel station (Admin only)
CREATE OR REPLACE FUNCTION reject_fuel_station(p_station_id UUID)
RETURNS JSON AS $$
BEGIN
  -- * Only allow Admin
  IF NOT EXISTS (
    SELECT 1 FROM SmartRoad.profiles
    WHERE SmartRoad.profiles.id = auth.uid() AND reporter_level = 'Admin'
  ) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Admin access required.');
  END IF;

  DELETE FROM SmartRoad.fuel_stations
  WHERE id = p_station_id AND verified = FALSE;

  IF FOUND THEN
    RETURN json_build_object('success', true);
  ELSE
    RETURN json_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Station not found or already verified.');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

