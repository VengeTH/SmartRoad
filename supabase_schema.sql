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

