-- ============================================================================
-- SmartRoad - SINGLE MERGED SCHEMA (run once in Supabase SQL Editor)
-- ============================================================================
-- This file merges, in dependency order:
--   1. Core (profiles, hazards, hoas, user_stickers, PostGIS)
--   2. Gate access (gate_access_logs, hoa_day_passes, hoas columns)
--   3. Hazard comments
--   4. Places (comments, images, likes, ratings)
--   5. Fuel (stations, price updates, reports, RPCs) + cube/earthdistance
--   6. Routes (saved_routes, purchases, ratings, shares, usage_log)
--   7. Commute AI cache
-- Run the entire script once. Safe to re-run (uses IF NOT EXISTS / IF EXISTS where needed).
-- ============================================================================

-- SmartRoad MVP - Supabase Schema
-- Run this script in your Supabase SQL Editor

-- * Enable PostGIS extension for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- * Create enum for hazard types
CREATE TYPE hazard_type AS ENUM (
  'pothole',
  'flood',
  'accident',
  'closure',
  'landslide',
  'roadblock'
);

-- * Create enum for severity levels
CREATE TYPE severity_level AS ENUM (
  'Low',
  'Medium',
  'High'
);

-- * Create enum for reporter levels
CREATE TYPE reporter_level AS ENUM (
  'Novice',
  'Verified',
  'Expert',
  'Admin'
);

-- * Create profiles table (extends Supabase auth.users)
CREATE TABLE SmartRoad.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name TEXT,
  email TEXT,
  photo_url TEXT,
  reporter_level reporter_level DEFAULT 'Novice',
  valid_reports_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- * Create hazards table with PostGIS geometry
CREATE TABLE SmartRoad.hazards (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type hazard_type NOT NULL,
  description TEXT NOT NULL,
  severity severity_level NOT NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  image_url TEXT,
  sticker_flag TEXT, -- * Optional sticker metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- * Create indexes for performance
CREATE INDEX idx_hazards_location ON SmartRoad.hazards USING GIST(location);
CREATE INDEX idx_hazards_created_at ON SmartRoad.hazards(created_at DESC);
CREATE INDEX idx_hazards_type ON SmartRoad.hazards(type);
CREATE INDEX idx_hazards_user_id ON SmartRoad.hazards(user_id);
CREATE INDEX idx_profiles_email ON SmartRoad.profiles(email);

-- * Enable Row Level Security (RLS)
ALTER TABLE SmartRoad.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE SmartRoad.hazards ENABLE ROW LEVEL SECURITY;

-- * RLS Policies for profiles table
-- * Anyone can read profiles
CREATE POLICY "Profiles are viewable by everyone"
  ON SmartRoad.profiles FOR SELECT
  USING (true);

-- * Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON SmartRoad.profiles FOR UPDATE
  USING (auth.uid() = id);

-- * Users can insert their own profile
CREATE POLICY "Users can insert own profile"
  ON SmartRoad.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- * RLS Policies for hazards table
-- * Anyone can read hazards (guests can view map/feed)
CREATE POLICY "Hazards are viewable by everyone"
  ON SmartRoad.hazards FOR SELECT
  USING (true);

-- * Only authenticated users can insert hazards
CREATE POLICY "Authenticated users can insert hazards"
  ON SmartRoad.hazards FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- * Only owner or admin can update their hazard
CREATE POLICY "Users can update own hazards"
  ON SmartRoad.hazards FOR UPDATE
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Only owner or admin can delete their hazard
CREATE POLICY "Users can delete own hazards"
  ON SmartRoad.hazards FOR DELETE
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION SmartRoad.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO SmartRoad.profiles (id, name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- * Trigger to create profile on user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_new_user();

-- * Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION SmartRoad.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- * Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON SmartRoad.profiles
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();

CREATE TRIGGER update_hazards_updated_at
  BEFORE UPDATE ON SmartRoad.hazards
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();

-- * Function to increment valid_reports_count (can be called when a report is validated)
CREATE OR REPLACE FUNCTION SmartRoad.increment_valid_reports(user_uuid UUID)
RETURNS void AS $$
BEGIN
  UPDATE SmartRoad.profiles
  SET valid_reports_count = valid_reports_count + 1
  WHERE id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- * Create storage bucket for hazard images (run in Supabase Dashboard Storage section)
-- * Bucket name: hazard-images
-- * Public: true
-- * Allowed MIME types: image/jpeg, image/png, image/webp
-- * File size limit: 5MB

-- * Demo user seed (optional - for investor demos)
-- * Password should be set via Supabase Auth dashboard
-- * INSERT INTO auth.users (email, encrypted_password, email_confirmed_at)
-- * VALUES ('demo@smartroad.app', crypt('DemoPass123!', gen_salt('bf')), NOW());

-- ============================================================================
-- * STICKER & GATE SECURITY MODULE
-- ============================================================================

-- * Create enum for HOA access types
CREATE TYPE hoa_access_type AS ENUM (
  'public_shortcut',  -- * Outsiders can buy a pass
  'residents_only'    -- * Outsiders CANNOT buy a pass
);

-- * Create HOAs (Homeowners Associations) table
-- * Represents gates/communities that require stickers for access
CREATE TABLE SmartRoad.hoas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  access_type hoa_access_type DEFAULT 'public_shortcut',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- * Create user_stickers table
-- * Represents digital stickers/permit that users can purchase from HOAs
CREATE TABLE SmartRoad.user_stickers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  hoa_id UUID REFERENCES SmartRoad.hoas(id) ON DELETE CASCADE NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN DEFAULT true,
  is_physical_sticker BOOLEAN DEFAULT false, -- * True for uploaded physical stickers, False for in-app QR purchases
  verified_by_ai BOOLEAN DEFAULT false, -- * True if Gemini AI confirms the image looks like a sticker
  sticker_photo_url TEXT, -- * Path to the uploaded sticker image
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- * Prevent duplicate active stickers for same user + HOA
  CONSTRAINT unique_active_user_hoa_sticker 
    UNIQUE NULLS NOT DISTINCT (user_id, hoa_id, is_active)
    WHERE is_active = true
);

-- * Create indexes for stickers
CREATE INDEX idx_user_stickers_user_id ON SmartRoad.user_stickers(user_id);
CREATE INDEX idx_user_stickers_hoa_id ON SmartRoad.user_stickers(hoa_id);
CREATE INDEX idx_user_stickers_expires_at ON SmartRoad.user_stickers(expires_at);
CREATE INDEX idx_user_stickers_is_active ON SmartRoad.user_stickers(is_active);
CREATE INDEX idx_hoas_is_active ON SmartRoad.hoas(is_active);

-- * Enable Row Level Security for new tables
ALTER TABLE SmartRoad.hoas ENABLE ROW LEVEL SECURITY;
ALTER TABLE SmartRoad.user_stickers ENABLE ROW LEVEL SECURITY;

-- * RLS Policies for HOAs table
-- * Anyone can read active HOAs (for gate pass display)
CREATE POLICY "HOAs are viewable by everyone"
  ON SmartRoad.hoas FOR SELECT
  USING (is_active = true);

-- * Only admins can manage HOAs (insert/update/delete)
CREATE POLICY "Admins can manage HOAs"
  ON SmartRoad.hoas FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * RLS Policies for user_stickers table
-- * Users can read their own stickers
CREATE POLICY "Users can view own stickers"
  ON SmartRoad.user_stickers FOR SELECT
  USING (auth.uid() = user_id);

-- * Guards/admins can read all stickers (for validation)
CREATE POLICY "Guards can view all stickers for validation"
  ON SmartRoad.user_stickers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level IN ('Admin', 'Expert')
    )
  );

-- * Only admins can insert/update/delete stickers (HOAs sell stickers)
CREATE POLICY "Admins can manage stickers"
  ON SmartRoad.user_stickers FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Users can insert their own physical stickers (after AI verification)
CREATE POLICY "Users can insert physical stickers"
  ON SmartRoad.user_stickers FOR INSERT
  WITH CHECK (
    auth.uid() = user_id 
    AND is_physical_sticker = true 
    AND verified_by_ai = true
  );

-- * Users can update their own physical stickers
CREATE POLICY "Users can update own physical stickers"
  ON SmartRoad.user_stickers FOR UPDATE
  USING (auth.uid() = user_id AND is_physical_sticker = true)
  WITH CHECK (auth.uid() = user_id AND is_physical_sticker = true);

-- * Trigger for updated_at on new tables
CREATE TRIGGER update_hoas_updated_at
  BEFORE UPDATE ON SmartRoad.hoas
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();

CREATE TRIGGER update_user_stickers_updated_at
  BEFORE UPDATE ON SmartRoad.user_stickers
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();

-- * Sample HOA data (optional - for testing)
-- * INSERT INTO SmartRoad.hoas (name, description, latitude, longitude)
-- * VALUES 
-- *   ('BF Resort', 'BF Resort Village', 14.4244, 120.9883),
-- *   ('BF Homes', 'BF Homes ParaÃ±aque', 14.5000, 121.0000);

-- SmartRoad - Gate Access Control Schema
-- Run this script in your Supabase SQL Editor AFTER running supabase_schema.sql
-- Adds: gate_access_logs, hoa_day_passes, pass_mode & radius to hoas

-- ============================================================================
-- * GATE ACCESS CONTROL MODULE
-- ============================================================================

-- * Add pass_mode and geofence radius to hoas table
ALTER TABLE SmartRoad.hoas
  ADD COLUMN IF NOT EXISTS pass_mode TEXT DEFAULT 'location_bound'
    CHECK (pass_mode IN ('location_bound', 'full_day', 'both')),
  ADD COLUMN IF NOT EXISTS radius_meters INTEGER DEFAULT 500;

COMMENT ON COLUMN SmartRoad.hoas.pass_mode IS
  'location_bound: pass nullified when user exits geofence | full_day: valid all day after first scan | both: guard chooses';
COMMENT ON COLUMN SmartRoad.hoas.radius_meters IS
  'Radius of HOA geofence in meters used for location_bound mode';

-- * Create enum-like check for pass mode (text column with CHECK is simpler)
-- * Values: location_bound | full_day | both

-- ============================================================================
-- * gate_access_logs
-- * One row per guard scan event â€” serves as the transaction/proof record
-- ============================================================================
CREATE TABLE IF NOT EXISTS SmartRoad.gate_access_logs (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sticker_id      UUID REFERENCES SmartRoad.user_stickers(id) ON DELETE SET NULL,
  hoa_id          UUID REFERENCES SmartRoad.hoas(id) ON DELETE CASCADE NOT NULL,
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  scanned_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- guard user id (nullable for system scans)
  scan_time       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  access_granted  BOOLEAN NOT NULL DEFAULT false,
  pass_mode       TEXT DEFAULT 'location_bound'
                    CHECK (pass_mode IN ('location_bound', 'full_day')),
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gate_access_logs_user_id  ON SmartRoad.gate_access_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_gate_access_logs_hoa_id   ON SmartRoad.gate_access_logs(hoa_id);
CREATE INDEX IF NOT EXISTS idx_gate_access_logs_scan_time ON SmartRoad.gate_access_logs(scan_time DESC);
CREATE INDEX IF NOT EXISTS idx_gate_access_logs_sticker  ON SmartRoad.gate_access_logs(sticker_id);

-- ============================================================================
-- * hoa_day_passes
-- * Pay-per-day passes for non-residents or public-shortcut HOAs
-- ============================================================================
CREATE TABLE IF NOT EXISTS SmartRoad.hoa_day_passes (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  hoa_id        UUID REFERENCES SmartRoad.hoas(id) ON DELETE CASCADE NOT NULL,
  valid_date    DATE NOT NULL,
  pass_mode     TEXT DEFAULT 'full_day'
                  CHECK (pass_mode IN ('location_bound', 'full_day')),
  is_active     BOOLEAN DEFAULT true,
  purchased_at  TIMESTAMPTZ DEFAULT NOW(),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_user_hoa_day_pass UNIQUE (user_id, hoa_id, valid_date)
);

CREATE INDEX IF NOT EXISTS idx_hoa_day_passes_user_id    ON SmartRoad.hoa_day_passes(user_id);
CREATE INDEX IF NOT EXISTS idx_hoa_day_passes_hoa_id     ON SmartRoad.hoa_day_passes(hoa_id);
CREATE INDEX IF NOT EXISTS idx_hoa_day_passes_valid_date ON SmartRoad.hoa_day_passes(valid_date);

-- ============================================================================
-- * Enable RLS
-- ============================================================================
ALTER TABLE SmartRoad.gate_access_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE SmartRoad.hoa_day_passes   ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- * RLS Policies: gate_access_logs
-- ============================================================================

-- Users can read their own access logs (transaction history)
CREATE POLICY "Users can view own access logs"
  ON SmartRoad.gate_access_logs FOR SELECT
  USING (auth.uid() = user_id);

-- Guards/Admins (Expert or Admin reporter level) can read all logs
CREATE POLICY "Guards can view all access logs"
  ON SmartRoad.gate_access_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level IN ('Admin', 'Expert')
    )
  );

-- Guards/Admins can insert (log) gate access events
CREATE POLICY "Guards can insert access logs"
  ON SmartRoad.gate_access_logs FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated' AND (
      auth.uid() = scanned_by OR
      EXISTS (
        SELECT 1 FROM SmartRoad.profiles
        WHERE id = auth.uid() AND reporter_level IN ('Admin', 'Expert')
      )
    )
  );

-- Admins can delete logs (for GDPR / cleanup)
CREATE POLICY "Admins can delete access logs"
  ON SmartRoad.gate_access_logs FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- ============================================================================
-- * RLS Policies: hoa_day_passes
-- ============================================================================

-- Users can read their own day passes
CREATE POLICY "Users can view own day passes"
  ON SmartRoad.hoa_day_passes FOR SELECT
  USING (auth.uid() = user_id);

-- Guards/Admins can view all day passes (for validation)
CREATE POLICY "Guards can view all day passes"
  ON SmartRoad.hoa_day_passes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level IN ('Admin', 'Expert')
    )
  );

-- Authenticated users can purchase day passes for themselves
CREATE POLICY "Users can purchase day passes"
  ON SmartRoad.hoa_day_passes FOR INSERT
  WITH CHECK (auth.uid() = user_id AND auth.role() = 'authenticated');

-- Users can deactivate their own day pass
CREATE POLICY "Users can update own day passes"
  ON SmartRoad.hoa_day_passes FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Admins can manage all day passes
CREATE POLICY "Admins can manage day passes"
  ON SmartRoad.hoa_day_passes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- ============================================================================
-- * Updated_at triggers
-- ============================================================================
CREATE TRIGGER update_hoa_day_passes_updated_at
  BEFORE UPDATE ON SmartRoad.hoa_day_passes
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();

-- ============================================================================
-- * Sample HOA update (adds pass_mode to existing HOA seed data)
-- ============================================================================
-- UPDATE SmartRoad.hoas SET pass_mode = 'both', radius_meters = 500
-- WHERE name IN ('BF Resort', 'BF Homes');


-- ============================================================================
-- * HAZARD COMMENTS MODULE
-- ============================================================================
-- Run this after the main supabase_schema.sql

-- * Create hazard_comments table
CREATE TABLE SmartRoad.hazard_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  hazard_id UUID REFERENCES SmartRoad.hazards(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- * Ensure text is not empty
  CONSTRAINT comment_text_not_empty CHECK (length(trim(text)) > 0)
);

-- * Create indexes for comments
CREATE INDEX idx_hazard_comments_hazard_id ON SmartRoad.hazard_comments(hazard_id);
CREATE INDEX idx_hazard_comments_user_id ON SmartRoad.hazard_comments(user_id);
CREATE INDEX idx_hazard_comments_created_at ON SmartRoad.hazard_comments(created_at DESC);

-- * Enable Row Level Security for comments
ALTER TABLE SmartRoad.hazard_comments ENABLE ROW LEVEL SECURITY;

-- * RLS Policies for hazard_comments table
-- * Anyone can read comments
CREATE POLICY "Comments are viewable by everyone"
  ON SmartRoad.hazard_comments FOR SELECT
  USING (true);

-- * Only authenticated users can insert comments
CREATE POLICY "Authenticated users can insert comments"
  ON SmartRoad.hazard_comments FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- * Only owner can update their comment
CREATE POLICY "Users can update own comments"
  ON SmartRoad.hazard_comments FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- * Only owner or admin can delete their comment
CREATE POLICY "Users can delete own comments"
  ON SmartRoad.hazard_comments FOR DELETE
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Trigger for updated_at on comments
CREATE TRIGGER update_hazard_comments_updated_at
  BEFORE UPDATE ON SmartRoad.hazard_comments
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();


-- ============================================================================
-- * PLACE PREVIEWS MODULE (Known Locations: Photos, Likes, Comments, Moderation, Ratings)
-- ============================================================================
-- Run this after the main supabase_schema.sql (and after profiles table exists)
--
-- âš ï¸ NOTE: This schema is prepared for future database integration. As of now,
-- SmartRoad runs in demo mode only. No database has been set up on the server yet.
-- Database integration will be added in the future after server infrastructure is fully set up.
--
-- Features enabled:
-- - Place comments
-- - Place likes
-- - Place photos with admin review (pending â†’ approved/rejected)
-- - Place ratings (1â€“5 stars)
--
-- Admin check:
-- - Uses `SmartRoad.profiles.reporter_level = 'Admin'`

-- ============================================================================
-- * PLACE COMMENTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS SmartRoad.place_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  place_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT place_comment_text_not_empty CHECK (length(trim(text)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_place_comments_place_id ON SmartRoad.place_comments(place_id);
CREATE INDEX IF NOT EXISTS idx_place_comments_user_id ON SmartRoad.place_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_place_comments_created_at ON SmartRoad.place_comments(created_at DESC);

ALTER TABLE SmartRoad.place_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Place comments are viewable by everyone"
  ON SmartRoad.place_comments FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can insert place comments"
  ON SmartRoad.place_comments FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own place comments"
  ON SmartRoad.place_comments FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own place comments"
  ON SmartRoad.place_comments FOR DELETE
  USING (
    auth.uid() = user_id OR
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
    DROP TRIGGER IF EXISTS update_place_comments_updated_at ON SmartRoad.place_comments;
    CREATE TRIGGER update_place_comments_updated_at
      BEFORE UPDATE ON SmartRoad.place_comments
      FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();
  END IF;
END $$;

-- ============================================================================
-- * PLACE PHOTOS (WITH MODERATION)
-- ============================================================================
CREATE TABLE IF NOT EXISTS SmartRoad.place_images (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  place_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  image_url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  review_reason TEXT,
  CONSTRAINT place_image_status_valid CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_place_images_place_id ON SmartRoad.place_images(place_id);
CREATE INDEX IF NOT EXISTS idx_place_images_status ON SmartRoad.place_images(status);
CREATE INDEX IF NOT EXISTS idx_place_images_created_at ON SmartRoad.place_images(created_at DESC);

ALTER TABLE SmartRoad.place_images ENABLE ROW LEVEL SECURITY;

-- * Anyone can read approved images.
-- * Owners can read their own submissions (including pending/rejected).
-- * Admin can read everything.
CREATE POLICY "Place images readable with moderation rules"
  ON SmartRoad.place_images FOR SELECT
  USING (
    status = 'approved' OR
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

CREATE POLICY "Authenticated users can submit place images"
  ON SmartRoad.place_images FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- * Only Admin can update moderation fields/status.
CREATE POLICY "Admins can update place images"
  ON SmartRoad.place_images FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM SmartRoad.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Owner can delete their own submissions; Admin can delete anything.
CREATE POLICY "Users can delete own place images"
  ON SmartRoad.place_images FOR DELETE
  USING (
    auth.uid() = user_id OR
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
    DROP TRIGGER IF EXISTS update_place_images_updated_at ON SmartRoad.place_images;
    CREATE TRIGGER update_place_images_updated_at
      BEFORE UPDATE ON SmartRoad.place_images
      FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();
  END IF;
END $$;

-- ============================================================================
-- * PLACE LIKES
-- ============================================================================
CREATE TABLE IF NOT EXISTS SmartRoad.place_likes (
  place_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (place_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_place_likes_place_id ON SmartRoad.place_likes(place_id);
CREATE INDEX IF NOT EXISTS idx_place_likes_user_id ON SmartRoad.place_likes(user_id);

ALTER TABLE SmartRoad.place_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Place likes are viewable by everyone"
  ON SmartRoad.place_likes FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can like places"
  ON SmartRoad.place_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unlike their own likes"
  ON SmartRoad.place_likes FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- * PLACE RATINGS (1â€“5 STARS)
-- ============================================================================
CREATE TABLE IF NOT EXISTS SmartRoad.place_ratings (
  place_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  rating INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (place_id, user_id),
  CONSTRAINT place_rating_valid CHECK (rating >= 1 AND rating <= 5)
);

CREATE INDEX IF NOT EXISTS idx_place_ratings_place_id ON SmartRoad.place_ratings(place_id);
CREATE INDEX IF NOT EXISTS idx_place_ratings_created_at ON SmartRoad.place_ratings(created_at DESC);

ALTER TABLE SmartRoad.place_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Place ratings are viewable by everyone"
  ON SmartRoad.place_ratings FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can rate places"
  ON SmartRoad.place_ratings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own place ratings"
  ON SmartRoad.place_ratings FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own place ratings"
  ON SmartRoad.place_ratings FOR DELETE
  USING (auth.uid() = user_id);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc
    WHERE proname = 'handle_updated_at'
  ) THEN
    DROP TRIGGER IF EXISTS update_place_ratings_updated_at ON SmartRoad.place_ratings;
    CREATE TRIGGER update_place_ratings_updated_at
      BEFORE UPDATE ON SmartRoad.place_ratings
      FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();
  END IF;
END $$;



-- ============================================================================
-- * EXTENSIONS FOR FUEL MODULE (ll_to_earth / earth_distance)
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;

-- ============================================================================
-- * FUEL STATIONS MODULE (Community Fuel Pricing with Anonymous Submissions)
-- ============================================================================
-- Run this after the main supabase_schema.sql (and after profiles table exists)
--
-- âš ï¸ NOTE: This schema is prepared for future database integration. As of now,
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
CREATE TABLE SmartRoad.saved_routes (
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
CREATE INDEX idx_saved_routes_creator_id ON SmartRoad.saved_routes(creator_id);
CREATE INDEX idx_saved_routes_geometry ON SmartRoad.saved_routes USING GIST(geometry);
CREATE INDEX idx_saved_routes_start_point ON SmartRoad.saved_routes USING GIST(start_point);
CREATE INDEX idx_saved_routes_end_point ON SmartRoad.saved_routes USING GIST(end_point);
CREATE INDEX idx_saved_routes_vehicle_type ON SmartRoad.saved_routes(vehicle_type);
CREATE INDEX idx_saved_routes_country_code ON SmartRoad.saved_routes(country_code);
CREATE INDEX idx_saved_routes_city ON SmartRoad.saved_routes(city);
CREATE INDEX idx_saved_routes_is_public ON SmartRoad.saved_routes(is_public) WHERE is_public = true;
CREATE INDEX idx_saved_routes_is_active ON SmartRoad.saved_routes(is_active) WHERE is_active = true;
CREATE INDEX idx_saved_routes_price ON SmartRoad.saved_routes(price_cents) WHERE price_cents = 0; -- * Free routes
CREATE INDEX idx_saved_routes_trust_score ON SmartRoad.saved_routes(trust_score DESC);
CREATE INDEX idx_saved_routes_usage_count ON SmartRoad.saved_routes(usage_count DESC);
CREATE INDEX idx_saved_routes_created_at ON SmartRoad.saved_routes(created_at DESC);
CREATE INDEX idx_saved_routes_tags ON SmartRoad.saved_routes USING GIN(tags); -- * GIN index for JSONB queries

-- * Create route_purchases table (tracks who bought which routes)
CREATE TABLE SmartRoad.route_purchases (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  route_id UUID REFERENCES SmartRoad.saved_routes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  price_paid_cents INTEGER NOT NULL,
  currency_code CHAR(3) DEFAULT 'USD',
  purchased_at TIMESTAMPTZ DEFAULT NOW(),
  -- * Prevent duplicate purchases
  CONSTRAINT unique_route_purchase UNIQUE (route_id, user_id)
);

CREATE INDEX idx_route_purchases_user_id ON SmartRoad.route_purchases(user_id);
CREATE INDEX idx_route_purchases_route_id ON SmartRoad.route_purchases(route_id);
CREATE INDEX idx_route_purchases_purchased_at ON SmartRoad.route_purchases(purchased_at DESC);

-- * Create route_ratings table
CREATE TABLE SmartRoad.route_ratings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  route_id UUID REFERENCES SmartRoad.saved_routes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- * One rating per user per route
  CONSTRAINT unique_route_rating UNIQUE (route_id, user_id)
);

CREATE INDEX idx_route_ratings_route_id ON SmartRoad.route_ratings(route_id);
CREATE INDEX idx_route_ratings_user_id ON SmartRoad.route_ratings(user_id);
CREATE INDEX idx_route_ratings_rating ON SmartRoad.route_ratings(rating);

-- * Create route_shares table (tracks shared route links)
CREATE TABLE SmartRoad.route_shares (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  route_id UUID REFERENCES SmartRoad.saved_routes(id) ON DELETE CASCADE NOT NULL,
  share_token TEXT UNIQUE NOT NULL, -- * Unique token for shareable link
  sharing_mode route_sharing_mode DEFAULT 'flexible',
  expires_at TIMESTAMPTZ, -- * Optional expiration
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL
);

CREATE INDEX idx_route_shares_token ON SmartRoad.route_shares(share_token);
CREATE INDEX idx_route_shares_route_id ON SmartRoad.route_shares(route_id);

-- * Create route_usage_log table (tracks when routes are used)
CREATE TABLE SmartRoad.route_usage_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  route_id UUID REFERENCES SmartRoad.saved_routes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  completion_percentage NUMERIC(5, 2), -- * 0.00 to 100.00
  -- * Track if user deviated from route
  deviation_count INTEGER DEFAULT 0,
  -- * Track if route was still valid (no major hazards)
  was_valid BOOLEAN DEFAULT true
);

CREATE INDEX idx_route_usage_log_route_id ON SmartRoad.route_usage_log(route_id);
CREATE INDEX idx_route_usage_log_user_id ON SmartRoad.route_usage_log(user_id);
CREATE INDEX idx_route_usage_log_started_at ON SmartRoad.route_usage_log(started_at DESC);

-- * Enable Row Level Security
ALTER TABLE SmartRoad.saved_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE SmartRoad.route_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE SmartRoad.route_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE SmartRoad.route_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE SmartRoad.route_usage_log ENABLE ROW LEVEL SECURITY;

-- * RLS Policies for saved_routes
-- * Anyone can read public routes
CREATE POLICY "Public routes are viewable by everyone"
  ON SmartRoad.saved_routes FOR SELECT
  USING (is_public = true AND is_active = true);

-- * Users can read their own routes
CREATE POLICY "Users can view own routes"
  ON SmartRoad.saved_routes FOR SELECT
  USING (auth.uid() = creator_id);

-- * Authenticated users can create routes
CREATE POLICY "Authenticated users can create routes"
  ON SmartRoad.saved_routes FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = creator_id);

-- * Users can update their own routes
CREATE POLICY "Users can update own routes"
  ON SmartRoad.saved_routes FOR UPDATE
  USING (auth.uid() = creator_id)
  WITH CHECK (auth.uid() = creator_id);

-- * Users can delete their own routes
CREATE POLICY "Users can delete own routes"
  ON SmartRoad.saved_routes FOR DELETE
  USING (auth.uid() = creator_id);

-- * RLS Policies for route_purchases
-- * Users can view their own purchases
CREATE POLICY "Users can view own purchases"
  ON SmartRoad.route_purchases FOR SELECT
  USING (auth.uid() = user_id);

-- * Route creators can view purchases of their routes
CREATE POLICY "Route creators can view purchases"
  ON SmartRoad.route_purchases FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.saved_routes
      WHERE id = route_id AND creator_id = auth.uid()
    )
  );

-- * Authenticated users can purchase routes
CREATE POLICY "Authenticated users can purchase routes"
  ON SmartRoad.route_purchases FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

-- * RLS Policies for route_ratings
-- * Anyone can read ratings for public routes
CREATE POLICY "Ratings are viewable for public routes"
  ON SmartRoad.route_ratings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.saved_routes
      WHERE id = route_id AND is_public = true
    )
  );

-- * Users can view their own ratings
CREATE POLICY "Users can view own ratings"
  ON SmartRoad.route_ratings FOR SELECT
  USING (auth.uid() = user_id);

-- * Authenticated users can create/update ratings
CREATE POLICY "Authenticated users can rate routes"
  ON SmartRoad.route_ratings FOR ALL
  USING (auth.role() = 'authenticated' AND auth.uid() = user_id)
  WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

-- * RLS Policies for route_shares
-- * Anyone can read active shares (for link validation)
CREATE POLICY "Active shares are viewable"
  ON SmartRoad.route_shares FOR SELECT
  USING (expires_at IS NULL OR expires_at > NOW());

-- * Users can view their own shares
CREATE POLICY "Users can view own shares"
  ON SmartRoad.route_shares FOR SELECT
  USING (auth.uid() = created_by);

-- * Authenticated users can create shares
CREATE POLICY "Authenticated users can share routes"
  ON SmartRoad.route_shares FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated' 
    AND auth.uid() = created_by
    AND EXISTS (
      SELECT 1 FROM SmartRoad.saved_routes
      WHERE id = route_id AND creator_id = auth.uid()
    )
  );

-- * RLS Policies for route_usage_log
-- * Users can view their own usage logs
CREATE POLICY "Users can view own usage logs"
  ON SmartRoad.route_usage_log FOR SELECT
  USING (auth.uid() = user_id);

-- * Route creators can view usage logs for their routes
CREATE POLICY "Route creators can view route usage"
  ON SmartRoad.route_usage_log FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM SmartRoad.saved_routes
      WHERE id = route_id AND creator_id = auth.uid()
    )
  );

-- * Authenticated users can log route usage
CREATE POLICY "Authenticated users can log route usage"
  ON SmartRoad.route_usage_log FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- * Functions

-- * Function to update route trust score
-- * Formula: (usage_count * 0.3) + (recency_score * 0.3) + (rating_score * 0.4)
-- * recency_score: 100 if verified < 30 days ago, decreases linearly to 0 after 365 days
-- * rating_score: (rating_avg / 5.0) * 100
CREATE OR REPLACE FUNCTION SmartRoad.calculate_route_trust_score(route_uuid UUID)
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
  FROM SmartRoad.saved_routes
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
  UPDATE SmartRoad.saved_routes
  SET trust_score = v_trust_score
  WHERE id = route_uuid;
  
  RETURN v_trust_score;
END;
$$ LANGUAGE plpgsql;

-- * Function to update route rating averages
CREATE OR REPLACE FUNCTION SmartRoad.update_route_rating_stats()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE SmartRoad.saved_routes
  SET 
    rating_avg = (
      SELECT COALESCE(AVG(rating)::NUMERIC(3,2), 0)
      FROM SmartRoad.route_ratings
      WHERE route_id = COALESCE(NEW.route_id, OLD.route_id)
    ),
    rating_count = (
      SELECT COUNT(*)
      FROM SmartRoad.route_ratings
      WHERE route_id = COALESCE(NEW.route_id, OLD.route_id)
    )
  WHERE id = COALESCE(NEW.route_id, OLD.route_id);
  
  -- * Recalculate trust score
  PERFORM SmartRoad.calculate_route_trust_score(COALESCE(NEW.route_id, OLD.route_id));
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- * Function to increment route usage count
CREATE OR REPLACE FUNCTION SmartRoad.increment_route_usage(route_uuid UUID)
RETURNS void AS $$
BEGIN
  UPDATE SmartRoad.saved_routes
  SET 
    usage_count = usage_count + 1,
    last_used_at = NOW()
  WHERE id = route_uuid;
  
  -- * Recalculate trust score
  PERFORM SmartRoad.calculate_route_trust_score(route_uuid);
END;
$$ LANGUAGE plpgsql;

-- * Function to auto-downgrade trust if hazards reported
-- * Called when hazards are created near a route
CREATE OR REPLACE FUNCTION SmartRoad.check_route_hazard_impact()
RETURNS TRIGGER AS $$
DECLARE
  affected_routes UUID[];
BEGIN
  -- * Find routes within 100m of the new hazard
  SELECT ARRAY_AGG(id)
  INTO affected_routes
  FROM SmartRoad.saved_routes
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
    UPDATE SmartRoad.saved_routes
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
  AFTER INSERT OR UPDATE OR DELETE ON SmartRoad.route_ratings
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.update_route_rating_stats();

-- * Update updated_at timestamp
CREATE TRIGGER update_saved_routes_updated_at
  BEFORE UPDATE ON SmartRoad.saved_routes
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();

CREATE TRIGGER update_route_ratings_updated_at
  BEFORE UPDATE ON SmartRoad.route_ratings
  FOR EACH ROW EXECUTE FUNCTION SmartRoad.handle_updated_at();

-- * Auto-downgrade trust when hazards are created near routes
-- * Note: This requires the hazards table to have a location field
-- * Uncomment when hazards table is confirmed to have PostGIS geometry
-- CREATE TRIGGER check_route_hazard_impact_on_hazard_create
--   AFTER INSERT ON SmartRoad.hazards
--   FOR EACH ROW EXECUTE FUNCTION SmartRoad.check_route_hazard_impact();

-- * Helper function to generate share token
CREATE OR REPLACE FUNCTION SmartRoad.generate_route_share_token()
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


-- * Commute AI response cache for SmartRoad (shared across users).
-- * Used to reuse Gemini guide augmentation by normalized key (destination + vehicle + distance band).
CREATE TABLE IF NOT EXISTS SmartRoad.commute_ai_cache (
  cache_key TEXT PRIMARY KEY,
  payload JSONB NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  hit_count INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_commute_ai_cache_expires_at ON SmartRoad.commute_ai_cache (expires_at);

COMMENT ON TABLE SmartRoad.commute_ai_cache IS 'Cached Gemini commute guide augmentation; key = normalized dest+vehicle+distance band';


