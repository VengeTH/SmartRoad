-- ============================================================================
-- SmartRoad — Create SmartRoad Database Schema
-- ============================================================================
-- This migration creates the SmartRoad schema and configures search paths.
-- All SmartRoad tables, functions, types, and policies live in this schema.
-- Run this FIRST before any other migration.
-- ============================================================================

-- Create the SmartRoad schema (if not exists)
CREATE SCHEMA IF NOT EXISTS SmartRoad;

-- Set search path so SmartRoad is the default schema
ALTER DATABASE smartroad SET search_path TO SmartRoad, public, extensions;

-- Grant usage on the new schema
GRANT USAGE ON SCHEMA SmartRoad TO anon, authenticated, service_role;

-- Function to create SmartRoad-compatible enum types
-- (Enums are schema-bound, so create them in SmartRoad schema)

-- Enable PostGIS extension (shared across schemas)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
