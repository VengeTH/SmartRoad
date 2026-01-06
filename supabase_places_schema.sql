-- ============================================================================
-- * PLACE PREVIEWS MODULE (Known Locations: Photos, Likes, Comments, Moderation, Ratings)
-- ============================================================================
-- Run this after the main supabase_schema.sql (and after profiles table exists)
--
-- ⚠️ NOTE: This schema is prepared for future database integration. As of now,
-- SmartRoad runs in demo mode only. No database has been set up on the server yet.
-- Database integration will be added in the future after server infrastructure is fully set up.
--
-- Features enabled:
-- - Place comments (Waze-style)
-- - Place likes
-- - Place photos with admin review (pending → approved/rejected)
-- - Place ratings (1–5 stars)
--
-- Admin check:
-- - Uses `public.profiles.reporter_level = 'Admin'`

-- ============================================================================
-- * PLACE COMMENTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.place_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  place_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT place_comment_text_not_empty CHECK (length(trim(text)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_place_comments_place_id ON public.place_comments(place_id);
CREATE INDEX IF NOT EXISTS idx_place_comments_user_id ON public.place_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_place_comments_created_at ON public.place_comments(created_at DESC);

ALTER TABLE public.place_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Place comments are viewable by everyone"
  ON public.place_comments FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can insert place comments"
  ON public.place_comments FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own place comments"
  ON public.place_comments FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own place comments"
  ON public.place_comments FOR DELETE
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.profiles
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
    DROP TRIGGER IF EXISTS update_place_comments_updated_at ON public.place_comments;
    CREATE TRIGGER update_place_comments_updated_at
      BEFORE UPDATE ON public.place_comments
      FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
  END IF;
END $$;

-- ============================================================================
-- * PLACE PHOTOS (WITH MODERATION)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.place_images (
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

CREATE INDEX IF NOT EXISTS idx_place_images_place_id ON public.place_images(place_id);
CREATE INDEX IF NOT EXISTS idx_place_images_status ON public.place_images(status);
CREATE INDEX IF NOT EXISTS idx_place_images_created_at ON public.place_images(created_at DESC);

ALTER TABLE public.place_images ENABLE ROW LEVEL SECURITY;

-- * Anyone can read approved images.
-- * Owners can read their own submissions (including pending/rejected).
-- * Admin can read everything.
CREATE POLICY "Place images readable with moderation rules"
  ON public.place_images FOR SELECT
  USING (
    status = 'approved' OR
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

CREATE POLICY "Authenticated users can submit place images"
  ON public.place_images FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- * Only Admin can update moderation fields/status.
CREATE POLICY "Admins can update place images"
  ON public.place_images FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Owner can delete their own submissions; Admin can delete anything.
CREATE POLICY "Users can delete own place images"
  ON public.place_images FOR DELETE
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.profiles
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
    DROP TRIGGER IF EXISTS update_place_images_updated_at ON public.place_images;
    CREATE TRIGGER update_place_images_updated_at
      BEFORE UPDATE ON public.place_images
      FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
  END IF;
END $$;

-- ============================================================================
-- * PLACE LIKES
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.place_likes (
  place_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (place_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_place_likes_place_id ON public.place_likes(place_id);
CREATE INDEX IF NOT EXISTS idx_place_likes_user_id ON public.place_likes(user_id);

ALTER TABLE public.place_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Place likes are viewable by everyone"
  ON public.place_likes FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can like places"
  ON public.place_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unlike their own likes"
  ON public.place_likes FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- * PLACE RATINGS (1–5 STARS)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.place_ratings (
  place_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  rating INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (place_id, user_id),
  CONSTRAINT place_rating_valid CHECK (rating >= 1 AND rating <= 5)
);

CREATE INDEX IF NOT EXISTS idx_place_ratings_place_id ON public.place_ratings(place_id);
CREATE INDEX IF NOT EXISTS idx_place_ratings_created_at ON public.place_ratings(created_at DESC);

ALTER TABLE public.place_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Place ratings are viewable by everyone"
  ON public.place_ratings FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can rate places"
  ON public.place_ratings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own place ratings"
  ON public.place_ratings FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own place ratings"
  ON public.place_ratings FOR DELETE
  USING (auth.uid() = user_id);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc
    WHERE proname = 'handle_updated_at'
  ) THEN
    DROP TRIGGER IF EXISTS update_place_ratings_updated_at ON public.place_ratings;
    CREATE TRIGGER update_place_ratings_updated_at
      BEFORE UPDATE ON public.place_ratings
      FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
  END IF;
END $$;

