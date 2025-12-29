#!/bin/bash

# Load .env file and run Flutter with environment variables
# Usage: ./run-with-env.sh

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found!"
    echo "Creating .env.example template..."
    cat > .env.example << 'EOF'
# Weather API Configuration
OPENWEATHERMAP_API_KEY=your_openweathermap_api_key_here
WEATHER_PROXY_URL=

# Traffic API Configuration
TOMTOM_API_KEY=your_tomtom_api_key_here

# Supabase (if needed)
# SUPABASE_URL=your_supabase_url
# SUPABASE_ANON_KEY=your_supabase_anon_key
EOF
    echo "✅ Created .env.example"
    echo "📝 Copy .env.example to .env and fill in your API keys"
    exit 1
fi

# Load .env file (skip comments and empty lines)
export $(grep -v '^#' .env | grep -v '^$' | xargs)

# Check if API key is set
if [ -z "$OPENWEATHERMAP_API_KEY" ]; then
    echo "⚠️  OPENWEATHERMAP_API_KEY not set in .env"
    echo "Please add it to your .env file"
    exit 1
fi

# Build dart-define arguments
DART_DEFINES="--dart-define=OPENWEATHERMAP_API_KEY=$OPENWEATHERMAP_API_KEY"

if [ ! -z "$WEATHER_PROXY_URL" ]; then
    DART_DEFINES="$DART_DEFINES --dart-define=WEATHER_PROXY_URL=$WEATHER_PROXY_URL"
fi

if [ ! -z "$TOMTOM_API_KEY" ]; then
    DART_DEFINES="$DART_DEFINES --dart-define=TOMTOM_API_KEY=$TOMTOM_API_KEY"
fi

# Run Flutter
echo "🚀 Running Flutter with environment variables from .env"
echo "📋 API Key: ${OPENWEATHERMAP_API_KEY:0:10}... (hidden)"
if [ ! -z "$WEATHER_PROXY_URL" ]; then
    echo "📋 Proxy URL: $WEATHER_PROXY_URL"
fi
if [ ! -z "$TOMTOM_API_KEY" ]; then
    echo "📋 TomTom API Key: ${TOMTOM_API_KEY:0:10}... (hidden)"
fi
echo ""

flutter run $DART_DEFINES "$@"
