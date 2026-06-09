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
-- * One row per guard scan event — serves as the transaction/proof record
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

