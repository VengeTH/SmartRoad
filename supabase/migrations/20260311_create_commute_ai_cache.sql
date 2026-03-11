-- * Commute AI response cache for SmartRoad (shared across users).
-- * Used to reuse Gemini guide augmentation by normalized key (destination + vehicle + distance band).
CREATE TABLE IF NOT EXISTS commute_ai_cache (
  cache_key TEXT PRIMARY KEY,
  payload JSONB NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  hit_count INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_commute_ai_cache_expires_at ON commute_ai_cache (expires_at);

COMMENT ON TABLE commute_ai_cache IS 'Cached Gemini commute guide augmentation; key = normalized dest+vehicle+distance band';
