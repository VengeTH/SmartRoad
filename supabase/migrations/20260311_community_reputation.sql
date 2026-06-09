-- ============================================================================
-- SmartRoad — Community Reputation & Ratings System
-- ============================================================================
-- Adds user reputation tracking and hazard/route rating capabilities
-- to the community system.
--
-- Run after the main schema (supabase_schema_merged.sql).
-- ============================================================================

-- ============================================================================
-- 1. USER REPUTATION
-- ============================================================================

-- * Add reputation columns to profiles table
ALTER TABLE SmartRoad.profiles
  ADD COLUMN IF NOT EXISTS reputation_points INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reports_approved INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS routes_shared INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS badges TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;

-- * Index for leaderboard queries
CREATE INDEX IF NOT EXISTS idx_profiles_reputation_points
  ON SmartRoad.profiles(reputation_points DESC)
  WHERE reputation_points > 0;

-- * Index for active users
CREATE INDEX IF NOT EXISTS idx_profiles_last_active_at
  ON SmartRoad.profiles(last_active_at DESC)
  WHERE last_active_at IS NOT NULL;

-- ============================================================================
-- 2. HAZARD RATINGS (community validation)
-- ============================================================================

-- * Table for upvoting/downvoting hazard reports
CREATE TABLE IF NOT EXISTS SmartRoad.hazard_ratings (
  hazard_id UUID REFERENCES SmartRoad.hazards(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  rating INTEGER NOT NULL, -- * 1 = upvote, -1 = downvote
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (hazard_id, user_id),
  CONSTRAINT hazard_rating_valid CHECK (rating IN (1, -1))
);

CREATE INDEX IF NOT EXISTS idx_hazard_ratings_hazard_id ON SmartRoad.hazard_ratings(hazard_id);
CREATE INDEX IF NOT EXISTS idx_hazard_ratings_user_id ON SmartRoad.hazard_ratings(user_id);

ALTER TABLE SmartRoad.hazard_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Hazard ratings are viewable by everyone"
  ON SmartRoad.hazard_ratings FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can rate hazards"
  ON SmartRoad.hazard_ratings FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

CREATE POLICY "Users can update own hazard ratings"
  ON SmartRoad.hazard_ratings FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own hazard ratings"
  ON SmartRoad.hazard_ratings FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- 3. HAZARD CONFIRMATION (multiple users confirm a hazard still exists)
-- ============================================================================

CREATE TABLE IF NOT EXISTS SmartRoad.hazard_confirmations (
  hazard_id UUID REFERENCES SmartRoad.hazards(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  is_still_active BOOLEAN DEFAULT true, -- * false = hazard is resolved
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (hazard_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_hazard_confirmations_hazard_id
  ON SmartRoad.hazard_confirmations(hazard_id);

ALTER TABLE SmartRoad.hazard_confirmations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Hazard confirmations are viewable by everyone"
  ON SmartRoad.hazard_confirmations FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can confirm hazards"
  ON SmartRoad.hazard_confirmations FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

-- ============================================================================
-- 4. REPUTATION FUNCTION
-- ============================================================================

-- * Calculate and update reputation for a user
CREATE OR REPLACE FUNCTION SmartRoad.calculate_reputation(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_points INTEGER := 0;
  v_hazard_upvotes INTEGER;
  v_hazards_reported INTEGER;
  v_routes_shared INTEGER;
  v_confirmations INTEGER;
BEGIN
  -- * Points from hazard upvotes received
  SELECT COALESCE(SUM(hr.rating), 0) INTO v_hazard_upvotes
  FROM SmartRoad.hazard_ratings hr
  JOIN SmartRoad.hazards h ON hr.hazard_id = h.id
  WHERE h.user_id = p_user_id AND hr.rating > 0;
  
  -- * Points from hazards reported
  SELECT COUNT(*) INTO v_hazards_reported
  FROM SmartRoad.hazards
  WHERE user_id = p_user_id;
  
  -- * Points from routes shared
  SELECT COUNT(*) INTO v_routes_shared
  FROM SmartRoad.saved_routes
  WHERE creator_id = p_user_id;
  
  -- * Points from hazard confirmations (being confirmed as reliable)
  SELECT COUNT(*) INTO v_confirmations
  FROM SmartRoad.hazard_confirmations hc
  JOIN SmartRoad.hazards h ON hc.hazard_id = h.id
  WHERE h.user_id = p_user_id;
  
  -- * Calculate total
  v_points :=
    COALESCE(v_hazard_upvotes * 2, 0) +
    COALESCE(v_hazards_reported * 5, 0) +
    COALESCE(v_routes_shared * 10, 0) +
    COALESCE(v_confirmations * 3, 0);
  
  -- * Update profile
  UPDATE SmartRoad.profiles
  SET
    reputation_points = v_points,
    routes_shared = v_routes_shared,
    -- * Auto-upgrade reporter level based on reputation
    reporter_level = CASE
      WHEN v_points >= 1000 THEN 'Expert'::reporter_level
      WHEN v_points >= 100 THEN 'Verified'::reporter_level
      ELSE 'Novice'::reporter_level
    END
  WHERE id = p_user_id;
  
  RETURN v_points;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- * Trigger to recalculate reputation when a hazard is rated
CREATE OR REPLACE FUNCTION trigger_recalculate_reputation_on_rating()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM SmartRoad.calculate_reputation(
    (SELECT user_id FROM SmartRoad.hazards WHERE id = NEW.hazard_id)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS hazard_rating_reputation_update ON SmartRoad.hazard_ratings;
CREATE TRIGGER hazard_rating_reputation_update
  AFTER INSERT OR UPDATE ON SmartRoad.hazard_ratings
  FOR EACH ROW EXECUTE FUNCTION trigger_recalculate_reputation_on_rating();

-- * Function to get user's community standing
CREATE OR REPLACE FUNCTION SmartRoad.get_user_standing(p_user_id UUID)
RETURNS TABLE (
  reputation_points INTEGER,
  reporter_level TEXT,
  badges TEXT[],
  reports_count INTEGER,
  routes_shared INTEGER,
  rank INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.reputation_points,
    p.reporter_level::TEXT,
    p.badges,
    p.valid_reports_count,
    p.routes_shared,
    (
      SELECT COUNT(*) + 1
      FROM SmartRoad.profiles
      WHERE reputation_points > p.reputation_points
    )::INTEGER AS rank
  FROM SmartRoad.profiles p
  WHERE p.id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE SmartRoad.hazard_ratings IS 'Community upvote/downvote on hazard reports for validation';
COMMENT ON TABLE SmartRoad.hazard_confirmations IS 'User confirmations that a hazard is still active or resolved';
COMMENT ON FUNCTION SmartRoad.calculate_reputation IS 'Recalculates a user reputation score and auto-upgrades reporter level';
COMMENT ON FUNCTION SmartRoad.get_user_standing IS 'Returns user reputation, level, badges, and leaderboard rank';

