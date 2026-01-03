-- ============================================================================
-- * HAZARD COMMENTS MODULE (Waze-style commenting)
-- ============================================================================
-- Run this after the main supabase_schema.sql

-- * Create hazard_comments table
CREATE TABLE public.hazard_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  hazard_id UUID REFERENCES public.hazards(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- * Ensure text is not empty
  CONSTRAINT comment_text_not_empty CHECK (length(trim(text)) > 0)
);

-- * Create indexes for comments
CREATE INDEX idx_hazard_comments_hazard_id ON public.hazard_comments(hazard_id);
CREATE INDEX idx_hazard_comments_user_id ON public.hazard_comments(user_id);
CREATE INDEX idx_hazard_comments_created_at ON public.hazard_comments(created_at DESC);

-- * Enable Row Level Security for comments
ALTER TABLE public.hazard_comments ENABLE ROW LEVEL SECURITY;

-- * RLS Policies for hazard_comments table
-- * Anyone can read comments
CREATE POLICY "Comments are viewable by everyone"
  ON public.hazard_comments FOR SELECT
  USING (true);

-- * Only authenticated users can insert comments
CREATE POLICY "Authenticated users can insert comments"
  ON public.hazard_comments FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- * Only owner can update their comment
CREATE POLICY "Users can update own comments"
  ON public.hazard_comments FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- * Only owner or admin can delete their comment
CREATE POLICY "Users can delete own comments"
  ON public.hazard_comments FOR DELETE
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Trigger for updated_at on comments
CREATE TRIGGER update_hazard_comments_updated_at
  BEFORE UPDATE ON public.hazard_comments
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
