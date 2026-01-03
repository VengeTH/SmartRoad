-- ============================================================================
-- * ROUTE AS A PRODUCT - DATABASE SCHEMA
-- ============================================================================
-- Run this after the main supabase_schema.sql
-- 
-- DESIGN DECISIONS:
-- 1. Geometry: LINESTRING (not MULTILINESTRING) - routes are single continuous paths
-- 2. PostGIS integration: Direct storage allows spatial queries (nearby routes, intersection checks)
-- 3. GraphHopper compatibility: Store decoded polyline, GraphHopper can recalculate if needed
-- 4. Versioning: Track route versions for trust/verification (routes can become outdated)
-- 5. Tags: JSONB for flexible metadata (rain_safe, flood_safe, etc.)
-- 6. Trust score: Calculated field (usage + recency + ratings) - updated via trigger
-- ============================================================================

-- * Create enum for vehicle types (matches Flutter VehicleType)
CREATE TYPE route_vehicle_type AS ENUM (
  'motorcycle',
  'big_bike',
  'car',
  'truck',
  'pedestrian'
);

-- * Create enum for route sharing modes
CREATE TYPE route_sharing_mode AS ENUM (
  'strict',      -- * Follow exact route, no rerouting
  'flexible',    -- * Allow rerouting only when blocked
  'suggested'    -- * Use as suggestion, allow full rerouting
);

-- * Create saved_routes table
CREATE TABLE public.saved_routes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  creator_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  
  -- * Basic route info
  name TEXT NOT NULL,
  description TEXT,
  
  -- * Geometry: LINESTRING in WGS84 (SRID 4326)
  -- * Stored as PostGIS geography for accurate distance calculations
  -- * GraphHopper compatibility: We store the actual driven polyline
  -- * GraphHopper can recalculate if needed, but we preserve the original
  geometry GEOGRAPHY(LINESTRING, 4326) NOT NULL,
  
  -- * Start/end points (denormalized for fast queries)
  start_point GEOGRAPHY(POINT, 4326) NOT NULL,
  end_point GEOGRAPHY(POINT, 4326) NOT NULL,
  
  -- * Route metrics (snapshot at save time)
  distance_meters INTEGER NOT NULL,
  estimated_duration_seconds INTEGER NOT NULL,
  
  -- * Route context
  vehicle_type route_vehicle_type NOT NULL,
  country_code CHAR(2), -- * ISO 3166-1 alpha-2 (e.g., 'PH', 'US')
  city TEXT,
  
  -- * Route tags (JSONB for flexible metadata)
  -- * Example: {"rain_safe": true, "flood_safe": false, "toll_free": true, "gate_aware": true, "night_safe": true}
  tags JSONB DEFAULT '{}'::jsonb,
  
  -- * Pricing
  price_cents INTEGER DEFAULT 0, -- * 0 = free, >0 = paid route
  currency_code CHAR(3) DEFAULT 'USD',
  
  -- * Visibility
  is_public BOOLEAN DEFAULT true,
  is_active BOOLEAN DEFAULT true,
  
  -- * Trust & quality metrics
  trust_score NUMERIC(5, 2) DEFAULT 0.0, -- * 0.00 to 100.00
  usage_count INTEGER DEFAULT 0,
  rating_avg NUMERIC(3, 2) DEFAULT 0.0, -- * 0.00 to 5.00
  rating_count INTEGER DEFAULT 0,
  
  -- * Verification
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_verified_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ,
  
  -- * Metadata at save time (snapshot of conditions)
  -- * Weather conditions when route was saved
  weather_at_save JSONB, -- * {"rain": false, "flood_risk": "low", "visibility": "good"}
  -- * Hazard count at save time
  hazard_count_at_save INTEGER DEFAULT 0,
  
  -- * Constraints
  CONSTRAINT valid_price CHECK (price_cents >= 0),
  CONSTRAINT valid_distance CHECK (distance_meters > 0),
  CONSTRAINT valid_duration CHECK (estimated_duration_seconds > 0),
  CONSTRAINT valid_trust_score CHECK (trust_score >= 0 AND trust_score <= 100),
  CONSTRAINT valid_rating CHECK (rating_avg >= 0 AND rating_avg <= 5)
);

-- * Create indexes for performance
CREATE INDEX idx_saved_routes_creator_id ON public.saved_routes(creator_id);
CREATE INDEX idx_saved_routes_geometry ON public.saved_routes USING GIST(geometry);
CREATE INDEX idx_saved_routes_start_point ON public.saved_routes USING GIST(start_point);
CREATE INDEX idx_saved_routes_end_point ON public.saved_routes USING GIST(end_point);
CREATE INDEX idx_saved_routes_vehicle_type ON public.saved_routes(vehicle_type);
CREATE INDEX idx_saved_routes_country_code ON public.saved_routes(country_code);
CREATE INDEX idx_saved_routes_city ON public.saved_routes(city);
CREATE INDEX idx_saved_routes_is_public ON public.saved_routes(is_public) WHERE is_public = true;
CREATE INDEX idx_saved_routes_is_active ON public.saved_routes(is_active) WHERE is_active = true;
CREATE INDEX idx_saved_routes_price ON public.saved_routes(price_cents) WHERE price_cents = 0; -- * Free routes
CREATE INDEX idx_saved_routes_trust_score ON public.saved_routes(trust_score DESC);
CREATE INDEX idx_saved_routes_usage_count ON public.saved_routes(usage_count DESC);
CREATE INDEX idx_saved_routes_created_at ON public.saved_routes(created_at DESC);
CREATE INDEX idx_saved_routes_tags ON public.saved_routes USING GIN(tags); -- * GIN index for JSONB queries

-- * Create route_purchases table (tracks who bought which routes)
CREATE TABLE public.route_purchases (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  route_id UUID REFERENCES public.saved_routes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  price_paid_cents INTEGER NOT NULL,
  currency_code CHAR(3) DEFAULT 'USD',
  purchased_at TIMESTAMPTZ DEFAULT NOW(),
  -- * Prevent duplicate purchases
  CONSTRAINT unique_route_purchase UNIQUE (route_id, user_id)
);

CREATE INDEX idx_route_purchases_user_id ON public.route_purchases(user_id);
CREATE INDEX idx_route_purchases_route_id ON public.route_purchases(route_id);
CREATE INDEX idx_route_purchases_purchased_at ON public.route_purchases(purchased_at DESC);

-- * Create route_ratings table
CREATE TABLE public.route_ratings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  route_id UUID REFERENCES public.saved_routes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- * One rating per user per route
  CONSTRAINT unique_route_rating UNIQUE (route_id, user_id)
);

CREATE INDEX idx_route_ratings_route_id ON public.route_ratings(route_id);
CREATE INDEX idx_route_ratings_user_id ON public.route_ratings(user_id);
CREATE INDEX idx_route_ratings_rating ON public.route_ratings(rating);

-- * Create route_shares table (tracks shared route links)
CREATE TABLE public.route_shares (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  route_id UUID REFERENCES public.saved_routes(id) ON DELETE CASCADE NOT NULL,
  share_token TEXT UNIQUE NOT NULL, -- * Unique token for shareable link
  sharing_mode route_sharing_mode DEFAULT 'flexible',
  expires_at TIMESTAMPTZ, -- * Optional expiration
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL
);

CREATE INDEX idx_route_shares_token ON public.route_shares(share_token);
CREATE INDEX idx_route_shares_route_id ON public.route_shares(route_id);

-- * Create route_usage_log table (tracks when routes are used)
CREATE TABLE public.route_usage_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  route_id UUID REFERENCES public.saved_routes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  completion_percentage NUMERIC(5, 2), -- * 0.00 to 100.00
  -- * Track if user deviated from route
  deviation_count INTEGER DEFAULT 0,
  -- * Track if route was still valid (no major hazards)
  was_valid BOOLEAN DEFAULT true
);

CREATE INDEX idx_route_usage_log_route_id ON public.route_usage_log(route_id);
CREATE INDEX idx_route_usage_log_user_id ON public.route_usage_log(user_id);
CREATE INDEX idx_route_usage_log_started_at ON public.route_usage_log(started_at DESC);

-- * Enable Row Level Security
ALTER TABLE public.saved_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_usage_log ENABLE ROW LEVEL SECURITY;

-- * RLS Policies for saved_routes
-- * Anyone can read public routes
CREATE POLICY "Public routes are viewable by everyone"
  ON public.saved_routes FOR SELECT
  USING (is_public = true AND is_active = true);

-- * Users can read their own routes
CREATE POLICY "Users can view own routes"
  ON public.saved_routes FOR SELECT
  USING (auth.uid() = creator_id);

-- * Authenticated users can create routes
CREATE POLICY "Authenticated users can create routes"
  ON public.saved_routes FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = creator_id);

-- * Users can update their own routes
CREATE POLICY "Users can update own routes"
  ON public.saved_routes FOR UPDATE
  USING (auth.uid() = creator_id)
  WITH CHECK (auth.uid() = creator_id);

-- * Users can delete their own routes
CREATE POLICY "Users can delete own routes"
  ON public.saved_routes FOR DELETE
  USING (auth.uid() = creator_id);

-- * RLS Policies for route_purchases
-- * Users can view their own purchases
CREATE POLICY "Users can view own purchases"
  ON public.route_purchases FOR SELECT
  USING (auth.uid() = user_id);

-- * Route creators can view purchases of their routes
CREATE POLICY "Route creators can view purchases"
  ON public.route_purchases FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.saved_routes
      WHERE id = route_id AND creator_id = auth.uid()
    )
  );

-- * Authenticated users can purchase routes
CREATE POLICY "Authenticated users can purchase routes"
  ON public.route_purchases FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

-- * RLS Policies for route_ratings
-- * Anyone can read ratings for public routes
CREATE POLICY "Ratings are viewable for public routes"
  ON public.route_ratings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.saved_routes
      WHERE id = route_id AND is_public = true
    )
  );

-- * Users can view their own ratings
CREATE POLICY "Users can view own ratings"
  ON public.route_ratings FOR SELECT
  USING (auth.uid() = user_id);

-- * Authenticated users can create/update ratings
CREATE POLICY "Authenticated users can rate routes"
  ON public.route_ratings FOR ALL
  USING (auth.role() = 'authenticated' AND auth.uid() = user_id)
  WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

-- * RLS Policies for route_shares
-- * Anyone can read active shares (for link validation)
CREATE POLICY "Active shares are viewable"
  ON public.route_shares FOR SELECT
  USING (expires_at IS NULL OR expires_at > NOW());

-- * Users can view their own shares
CREATE POLICY "Users can view own shares"
  ON public.route_shares FOR SELECT
  USING (auth.uid() = created_by);

-- * Authenticated users can create shares
CREATE POLICY "Authenticated users can share routes"
  ON public.route_shares FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated' 
    AND auth.uid() = created_by
    AND EXISTS (
      SELECT 1 FROM public.saved_routes
      WHERE id = route_id AND creator_id = auth.uid()
    )
  );

-- * RLS Policies for route_usage_log
-- * Users can view their own usage logs
CREATE POLICY "Users can view own usage logs"
  ON public.route_usage_log FOR SELECT
  USING (auth.uid() = user_id);

-- * Route creators can view usage logs for their routes
CREATE POLICY "Route creators can view route usage"
  ON public.route_usage_log FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.saved_routes
      WHERE id = route_id AND creator_id = auth.uid()
    )
  );

-- * Authenticated users can log route usage
CREATE POLICY "Authenticated users can log route usage"
  ON public.route_usage_log FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- * Functions

-- * Function to update route trust score
-- * Formula: (usage_count * 0.3) + (recency_score * 0.3) + (rating_score * 0.4)
-- * recency_score: 100 if verified < 30 days ago, decreases linearly to 0 after 365 days
-- * rating_score: (rating_avg / 5.0) * 100
CREATE OR REPLACE FUNCTION public.calculate_route_trust_score(route_uuid UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_usage_count INTEGER;
  v_rating_avg NUMERIC;
  v_rating_count INTEGER;
  v_last_verified_at TIMESTAMPTZ;
  v_usage_score NUMERIC;
  v_recency_score NUMERIC;
  v_rating_score NUMERIC;
  v_trust_score NUMERIC;
BEGIN
  SELECT 
    usage_count,
    rating_avg,
    rating_count,
    last_verified_at
  INTO 
    v_usage_count,
    v_rating_avg,
    v_rating_count,
    v_last_verified_at
  FROM public.saved_routes
  WHERE id = route_uuid;
  
  -- * Usage score: min(usage_count * 2, 30) - caps at 30 points
  v_usage_score := LEAST(v_usage_count * 2, 30);
  
  -- * Recency score: 100 if verified < 30 days ago, decreases to 0 after 365 days
  IF v_last_verified_at IS NULL THEN
    v_recency_score := 0;
  ELSE
    DECLARE
      days_since_verification INTEGER;
    BEGIN
      days_since_verification := EXTRACT(DAY FROM NOW() - v_last_verified_at)::INTEGER;
      IF days_since_verification <= 30 THEN
        v_recency_score := 30;
      ELSIF days_since_verification >= 365 THEN
        v_recency_score := 0;
      ELSE
        -- * Linear decrease from 30 to 0 over 335 days
        v_recency_score := 30 * (1 - (days_since_verification - 30)::NUMERIC / 335);
      END IF;
    END;
  END IF;
  
  -- * Rating score: (rating_avg / 5.0) * 40, but requires at least 3 ratings
  IF v_rating_count >= 3 THEN
    v_rating_score := (v_rating_avg / 5.0) * 40;
  ELSE
    v_rating_score := 0; -- * No rating score if insufficient ratings
  END IF;
  
  -- * Total trust score
  v_trust_score := v_usage_score + v_recency_score + v_rating_score;
  
  -- * Update the route
  UPDATE public.saved_routes
  SET trust_score = v_trust_score
  WHERE id = route_uuid;
  
  RETURN v_trust_score;
END;
$$ LANGUAGE plpgsql;

-- * Function to update route rating averages
CREATE OR REPLACE FUNCTION public.update_route_rating_stats()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.saved_routes
  SET 
    rating_avg = (
      SELECT COALESCE(AVG(rating)::NUMERIC(3,2), 0)
      FROM public.route_ratings
      WHERE route_id = COALESCE(NEW.route_id, OLD.route_id)
    ),
    rating_count = (
      SELECT COUNT(*)
      FROM public.route_ratings
      WHERE route_id = COALESCE(NEW.route_id, OLD.route_id)
    )
  WHERE id = COALESCE(NEW.route_id, OLD.route_id);
  
  -- * Recalculate trust score
  PERFORM public.calculate_route_trust_score(COALESCE(NEW.route_id, OLD.route_id));
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- * Function to increment route usage count
CREATE OR REPLACE FUNCTION public.increment_route_usage(route_uuid UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.saved_routes
  SET 
    usage_count = usage_count + 1,
    last_used_at = NOW()
  WHERE id = route_uuid;
  
  -- * Recalculate trust score
  PERFORM public.calculate_route_trust_score(route_uuid);
END;
$$ LANGUAGE plpgsql;

-- * Function to auto-downgrade trust if hazards reported
-- * Called when hazards are created near a route
CREATE OR REPLACE FUNCTION public.check_route_hazard_impact()
RETURNS TRIGGER AS $$
DECLARE
  affected_routes UUID[];
BEGIN
  -- * Find routes within 100m of the new hazard
  SELECT ARRAY_AGG(id)
  INTO affected_routes
  FROM public.saved_routes
  WHERE ST_DWithin(
    geometry::geography,
    ST_GeomFromText(
      'POINT(' || (NEW.location->>'coordinates'->>0)::text || ' ' || (NEW.location->>'coordinates'->>1)::text || ')',
      4326
    )::geography,
    100 -- * 100 meters
  );
  
  -- * Decrease trust score for affected routes
  IF affected_routes IS NOT NULL THEN
    UPDATE public.saved_routes
    SET 
      trust_score = GREATEST(trust_score - 5, 0), -- * Decrease by 5 points, minimum 0
      last_verified_at = NULL -- * Mark as needing verification
    WHERE id = ANY(affected_routes);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- * Triggers

-- * Update route rating stats when ratings change
CREATE TRIGGER update_route_rating_on_rating_change
  AFTER INSERT OR UPDATE OR DELETE ON public.route_ratings
  FOR EACH ROW EXECUTE FUNCTION public.update_route_rating_stats();

-- * Update updated_at timestamp
CREATE TRIGGER update_saved_routes_updated_at
  BEFORE UPDATE ON public.saved_routes
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_route_ratings_updated_at
  BEFORE UPDATE ON public.route_ratings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- * Auto-downgrade trust when hazards are created near routes
-- * Note: This requires the hazards table to have a location field
-- * Uncomment when hazards table is confirmed to have PostGIS geometry
-- CREATE TRIGGER check_route_hazard_impact_on_hazard_create
--   AFTER INSERT ON public.hazards
--   FOR EACH ROW EXECUTE FUNCTION public.check_route_hazard_impact();

-- * Helper function to generate share token
CREATE OR REPLACE FUNCTION public.generate_route_share_token()
RETURNS TEXT AS $$
BEGIN
  RETURN encode(gen_random_bytes(16), 'base64')
    -- * Remove special characters, keep alphanumeric
    -- * Replace + with -, / with _, remove =
    -- * Take first 22 characters for clean URL-safe token
    -- * Result: 22 character token like "aBcD1234eFgH5678iJkL"
    -- * This gives us ~132 bits of entropy, more than enough
    -- * Format: base64url without padding
    -- * Example: "aBcD1234eFgH5678iJkL"
    -- * We'll use this in URLs like: /route/share/aBcD1234eFgH5678iJkL
    -- * Note: PostgreSQL's gen_random_bytes + base64 encoding gives us URL-safe tokens
    -- * We'll handle the URL encoding in the application layer
    -- * For now, return the raw base64 string and let the app handle URL encoding
    -- * Actually, let's make it simpler: use a shorter, more readable format
    -- * Use: encode(gen_random_bytes(12), 'hex') - gives us 24 hex characters
    -- * Or better: use a custom format that's URL-safe
    -- * Final: Use base64url encoding (replace + with -, / with _, remove =)
    -- * But PostgreSQL doesn't have base64url, so we'll do it in the app
    -- * For now, return base64 and handle URL encoding in application
    -- * Actually, let's just use a simple approach: hex encoding
    RETURN encode(gen_random_bytes(12), 'hex');
END;
$$ LANGUAGE plpgsql;

-- * Example queries for route discovery
-- * 
-- * Find popular routes near a point:
-- * SELECT * FROM saved_routes
-- * WHERE ST_DWithin(start_point, ST_MakePoint(lng, lat)::geography, 5000)
-- *   AND is_public = true AND is_active = true
-- * ORDER BY usage_count DESC, trust_score DESC
-- * LIMIT 10;
-- *
-- * Find rain-safe routes:
-- * SELECT * FROM saved_routes
-- * WHERE tags->>'rain_safe' = 'true'
-- *   AND is_public = true AND is_active = true
-- * ORDER BY trust_score DESC
-- * LIMIT 10;
-- *
-- * Find routes for specific vehicle type:
-- * SELECT * FROM saved_routes
-- * WHERE vehicle_type = 'motorcycle'
-- *   AND is_public = true AND is_active = true
-- * ORDER BY trust_score DESC, usage_count DESC
-- * LIMIT 10;
