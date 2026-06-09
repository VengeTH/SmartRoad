-- ============================================================================
-- SmartRoad — Geospatial Data Tables (Priority 1)
-- ============================================================================
-- Creates tables for flood zones, roads, village entrances, restricted roads,
-- and community routes. All use PostGIS geography types for spatial queries.
-- Run after 20260308_create_smartroad_schema.sql.
-- ============================================================================

-- ============================================================================
-- 1. ROADS TABLE
-- ============================================================================
-- Stores OSM road segments enriched with SmartRoad metadata
-- (flood risk, surface quality, HOA restrictions, etc.)
CREATE TABLE IF NOT EXISTS SmartRoad.roads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  osm_id BIGINT,                           -- OpenStreetMap way ID
  name TEXT,
  highway_type TEXT,                       -- motorway, primary, secondary, residential, etc.
  geometry GEOGRAPHY(LINESTRING, 4326) NOT NULL,
  surface TEXT,                            -- paved, unpaved, etc.
  maxspeed INTEGER,
  is_toll BOOLEAN DEFAULT false,
  flood_risk NUMERIC(3,2) DEFAULT 0.0,    -- 0.00 (none) to 1.00 (extreme)
  has_hoa_restriction BOOLEAN DEFAULT false,
  hoa_id UUID REFERENCES SmartRoad.hoas(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_roads_geometry ON SmartRoad.roads USING GIST(geometry);
CREATE INDEX IF NOT EXISTS idx_roads_highway_type ON SmartRoad.roads(highway_type);
CREATE INDEX IF NOT EXISTS idx_roads_flood_risk ON SmartRoad.roads(flood_risk);
CREATE INDEX IF NOT EXISTS idx_roads_hoa_id ON SmartRoad.roads(hoa_id);

ALTER TABLE SmartRoad.roads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Roads are viewable by everyone"
  ON SmartRoad.roads FOR SELECT USING (true);

CREATE POLICY "Admins can manage roads"
  ON SmartRoad.roads FOR ALL USING (
    EXISTS (SELECT 1 FROM SmartRoad.profiles WHERE id = auth.uid() AND reporter_level = 'Admin')
  );

-- ============================================================================
-- 2. FLOOD ZONES TABLE
-- ============================================================================
-- Polygon areas representing known flood-prone zones with severity ratings.
CREATE TABLE IF NOT EXISTS SmartRoad.flood_zones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'moderate' CHECK (severity IN ('low', 'moderate', 'high', 'extreme')),
  geometry GEOGRAPHY(POLYGON, 4326) NOT NULL,
  source TEXT DEFAULT 'community' CHECK (source IN ('pagasa', 'lgu', 'community', 'historical', 'ai')),
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  reported_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_flood_zones_geometry ON SmartRoad.flood_zones USING GIST(geometry);
CREATE INDEX IF NOT EXISTS idx_flood_zones_severity ON SmartRoad.flood_zones(severity);
CREATE INDEX IF NOT EXISTS idx_flood_zones_source ON SmartRoad.flood_zones(source);
CREATE INDEX IF NOT EXISTS idx_flood_zones_active ON SmartRoad.flood_zones(is_active) WHERE is_active = true;

ALTER TABLE SmartRoad.flood_zones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Flood zones are viewable by everyone"
  ON SmartRoad.flood_zones FOR SELECT USING (true);

CREATE POLICY "Admins can manage flood zones"
  ON SmartRoad.flood_zones FOR ALL USING (
    EXISTS (SELECT 1 FROM SmartRoad.profiles WHERE id = auth.uid() AND reporter_level = 'Admin')
  );

-- ============================================================================
-- 3. VILLAGE ENTRANCES TABLE
-- ============================================================================
-- Verified gate/entrance points for villages and subdivisions.
-- Solves the "scam pin" problem for delivery riders.
CREATE TABLE IF NOT EXISTS SmartRoad.village_entrances (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  hoa_id UUID REFERENCES SmartRoad.hoas(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,                       -- e.g., "Main Gate", "Delivery Entrance"
  entrance_type TEXT NOT NULL DEFAULT 'main' CHECK (entrance_type IN ('main', 'delivery', 'visitor', 'pedestrian', 'service', 'emergency')),
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  is_verified BOOLEAN DEFAULT false,        -- Admin-verified as correct
  verified_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  verified_at TIMESTAMPTZ,
  notes TEXT,                               -- Rider tips: "Use Gate 3 for deliveries"
  photo_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_village_entrances_location ON SmartRoad.village_entrances USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_village_entrances_hoa_id ON SmartRoad.village_entrances(hoa_id);
CREATE INDEX IF NOT EXISTS idx_village_entrances_type ON SmartRoad.village_entrances(entrance_type);
CREATE INDEX IF NOT EXISTS idx_village_entrances_verified ON SmartRoad.village_entrances(is_verified);

ALTER TABLE SmartRoad.village_entrances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Entrances are viewable by everyone"
  ON SmartRoad.village_entrances FOR SELECT USING (true);

CREATE POLICY "Authenticated users can suggest entrances"
  ON SmartRoad.village_entrances FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage entrances"
  ON SmartRoad.village_entrances FOR ALL USING (
    EXISTS (SELECT 1 FROM SmartRoad.profiles WHERE id = auth.uid() AND reporter_level = 'Admin')
  );

-- ============================================================================
-- 4. RESTRICTED ROADS TABLE
-- ============================================================================
-- Road segments that require HOA stickers or special permission.
CREATE TABLE IF NOT EXISTS SmartRoad.restricted_roads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  hoa_id UUID REFERENCES SmartRoad.hoas(id) ON DELETE CASCADE NOT NULL,
  road_id UUID REFERENCES SmartRoad.roads(id) ON DELETE CASCADE,
  name TEXT,
  geometry GEOGRAPHY(LINESTRING, 4326) NOT NULL,
  restriction_type TEXT NOT NULL DEFAULT 'sticker' CHECK (restriction_type IN ('sticker', 'permit', 'resident_only', 'day_pass')),
  requires_sticker_id UUID REFERENCES SmartRoad.user_stickers(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_restricted_roads_geometry ON SmartRoad.restricted_roads USING GIST(geometry);
CREATE INDEX IF NOT EXISTS idx_restricted_roads_hoa_id ON SmartRoad.restricted_roads(hoa_id);
CREATE INDEX IF NOT EXISTS idx_restricted_roads_type ON SmartRoad.restricted_roads(restriction_type);

ALTER TABLE SmartRoad.restricted_roads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Restricted roads are viewable by everyone"
  ON SmartRoad.restricted_roads FOR SELECT USING (true);

CREATE POLICY "HOAs can manage their restricted roads"
  ON SmartRoad.restricted_roads FOR ALL USING (
    EXISTS (SELECT 1 FROM SmartRoad.profiles WHERE id = auth.uid() AND reporter_level IN ('Admin', 'Expert'))
  );

-- ============================================================================
-- 5. COMMUNITY ROUTES TABLE
-- ============================================================================
-- User-shared shortcut routes (distinct from saved_routes which are personal).
CREATE TABLE IF NOT EXISTS SmartRoad.community_routes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  creator_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  geometry GEOGRAPHY(LINESTRING, 4326) NOT NULL,
  start_point GEOGRAPHY(POINT, 4326) NOT NULL,
  end_point GEOGRAPHY(POINT, 4326) NOT NULL,
  distance_meters INTEGER NOT NULL,
  estimated_duration_seconds INTEGER NOT NULL,
  vehicle_type TEXT NOT NULL DEFAULT 'motorcycle',
  tags JSONB DEFAULT '{}'::jsonb,           -- e.g., {"flood_safe": true, "toll_free": true}
  is_verified BOOLEAN DEFAULT false,
  usage_count INTEGER DEFAULT 0,
  rating_avg NUMERIC(3,2) DEFAULT 0.0,
  rating_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_community_routes_geometry ON SmartRoad.community_routes USING GIST(geometry);
CREATE INDEX IF NOT EXISTS idx_community_routes_creator ON SmartRoad.community_routes(creator_id);
CREATE INDEX IF NOT EXISTS idx_community_routes_vehicle ON SmartRoad.community_routes(vehicle_type);
CREATE INDEX IF NOT EXISTS idx_community_routes_verified ON SmartRoad.community_routes(is_verified) WHERE is_verified = true;

ALTER TABLE SmartRoad.community_routes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Community routes are viewable by everyone"
  ON SmartRoad.community_routes FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create routes"
  ON SmartRoad.community_routes FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own routes"
  ON SmartRoad.community_routes FOR UPDATE USING (auth.uid() = creator_id);

CREATE POLICY "Users can delete own routes"
  ON SmartRoad.community_routes FOR DELETE USING (auth.uid() = creator_id);

-- ============================================================================
-- 6. UPDATE HAZARD TYPE ENUM WITH NEW TYPES
-- ============================================================================
ALTER TYPE hazard_type ADD VALUE IF NOT EXISTS 'fallen_tree';
ALTER TYPE hazard_type ADD VALUE IF NOT EXISTS 'traffic';
ALTER TYPE hazard_type ADD VALUE IF NOT EXISTS 'debris';

-- ============================================================================
-- 7. EXTEND PROFILES WITH RIDER FIELDS
-- ============================================================================
ALTER TABLE SmartRoad.profiles
  ADD COLUMN IF NOT EXISTS vehicle_type TEXT,        -- motorcycle, car, truck, etc.
  ADD COLUMN IF NOT EXISTS preferred_vehicle TEXT,
  ADD COLUMN IF NOT EXISTS is_rider BOOLEAN DEFAULT false,
  ADD COLUMN IF NOTASCADE roles TEXT[] DEFAULT '{}'; -- Array of roles: 'user', 'moderator', 'admin'

-- ============================================================================
-- 8. HAZARD VERIFICATION TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS SmartRoad.hazard_verifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  hazard_id UUID REFERENCES SmartRoad.hazards(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  is_confirmed BOOLEAN NOT NULL DEFAULT true, -- true = hazard exists, false = resolved
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_hazard_verification UNIQUE (hazard_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_hazard_verifications_hazard ON SmartRoad.hazard_verifications(hazard_id);

ALTER TABLE SmartRoad.hazard_verifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Verifications are viewable by everyone"
  ON SmartRoad.hazard_verifications FOR SELECT USING (true);

CREATE POLICY "Authenticated users can verify"
  ON SmartRoad.hazard_verifications FOR INSERT WITH CHECK (auth.role() = 'authenticated');
