#!/bin/bash

# SmartRoad Flutter Run Script
# Usage: ./run.sh [android|ios]

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if required environment variables are set
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set"
    echo "Either create a .env file or export them as environment variables"
    exit 1
fi

# Build dart-define flags
DART_DEFINES="--dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"

# Add storage bucket if provided
if [ -n "$STORAGE_BUCKET_NAME" ]; then
    DART_DEFINES="$DART_DEFINES --dart-define=STORAGE_BUCKET_NAME=$STORAGE_BUCKET_NAME"
fi

# Run Flutter
if [ "$1" == "ios" ]; then
    flutter run --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY -d ios
elif [ "$1" == "android" ]; then
    flutter run --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY -d android
else
    flutter run --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
fi

