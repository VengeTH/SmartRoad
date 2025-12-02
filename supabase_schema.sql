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
CREATE TABLE public.profiles (
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
CREATE TABLE public.hazards (
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
CREATE INDEX idx_hazards_location ON public.hazards USING GIST(location);
CREATE INDEX idx_hazards_created_at ON public.hazards(created_at DESC);
CREATE INDEX idx_hazards_type ON public.hazards(type);
CREATE INDEX idx_hazards_user_id ON public.hazards(user_id);
CREATE INDEX idx_profiles_email ON public.profiles(email);

-- * Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hazards ENABLE ROW LEVEL SECURITY;

-- * RLS Policies for profiles table
-- * Anyone can read profiles
CREATE POLICY "Profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

-- * Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- * Users can insert their own profile
CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- * RLS Policies for hazards table
-- * Anyone can read hazards (guests can view map/feed)
CREATE POLICY "Hazards are viewable by everyone"
  ON public.hazards FOR SELECT
  USING (true);

-- * Only authenticated users can insert hazards
CREATE POLICY "Authenticated users can insert hazards"
  ON public.hazards FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- * Only owner or admin can update their hazard
CREATE POLICY "Users can update own hazards"
  ON public.hazards FOR UPDATE
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Only owner or admin can delete their hazard
CREATE POLICY "Users can delete own hazards"
  ON public.hazards FOR DELETE
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email)
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
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- * Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- * Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_hazards_updated_at
  BEFORE UPDATE ON public.hazards
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- * Function to increment valid_reports_count (can be called when a report is validated)
CREATE OR REPLACE FUNCTION public.increment_valid_reports(user_uuid UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.profiles
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

-- * Create HOAs (Homeowners Associations) table
-- * Represents gates/communities that require stickers for access
CREATE TABLE public.hoas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- * Create user_stickers table
-- * Represents digital stickers/permit that users can purchase from HOAs
CREATE TABLE public.user_stickers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  hoa_id UUID REFERENCES public.hoas(id) ON DELETE CASCADE NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- * Prevent duplicate active stickers for same user + HOA
  CONSTRAINT unique_active_user_hoa_sticker 
    UNIQUE NULLS NOT DISTINCT (user_id, hoa_id, is_active)
    WHERE is_active = true
);

-- * Create indexes for stickers
CREATE INDEX idx_user_stickers_user_id ON public.user_stickers(user_id);
CREATE INDEX idx_user_stickers_hoa_id ON public.user_stickers(hoa_id);
CREATE INDEX idx_user_stickers_expires_at ON public.user_stickers(expires_at);
CREATE INDEX idx_user_stickers_is_active ON public.user_stickers(is_active);
CREATE INDEX idx_hoas_is_active ON public.hoas(is_active);

-- * Enable Row Level Security for new tables
ALTER TABLE public.hoas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_stickers ENABLE ROW LEVEL SECURITY;

-- * RLS Policies for HOAs table
-- * Anyone can read active HOAs (for gate pass display)
CREATE POLICY "HOAs are viewable by everyone"
  ON public.hoas FOR SELECT
  USING (is_active = true);

-- * Only admins can manage HOAs (insert/update/delete)
CREATE POLICY "Admins can manage HOAs"
  ON public.hoas FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * RLS Policies for user_stickers table
-- * Users can read their own stickers
CREATE POLICY "Users can view own stickers"
  ON public.user_stickers FOR SELECT
  USING (auth.uid() = user_id);

-- * Guards/admins can read all stickers (for validation)
CREATE POLICY "Guards can view all stickers for validation"
  ON public.user_stickers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND reporter_level IN ('Admin', 'Expert')
    )
  );

-- * Only admins can insert/update/delete stickers (HOAs sell stickers)
CREATE POLICY "Admins can manage stickers"
  ON public.user_stickers FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND reporter_level = 'Admin'
    )
  );

-- * Trigger for updated_at on new tables
CREATE TRIGGER update_hoas_updated_at
  BEFORE UPDATE ON public.hoas
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_user_stickers_updated_at
  BEFORE UPDATE ON public.user_stickers
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- * Sample HOA data (optional - for testing)
-- * INSERT INTO public.hoas (name, description, latitude, longitude)
-- * VALUES 
-- *   ('BF Resort', 'BF Resort Village', 14.4244, 120.9883),
-- *   ('BF Homes', 'BF Homes Parañaque', 14.5000, 121.0000);

