# Load .env file and run Flutter with environment variables (Windows PowerShell)
# Usage: .\run-with-env.ps1

# Check if .env exists
if (-not (Test-Path .env)) {
    Write-Host "⚠️  .env file not found!" -ForegroundColor Yellow
    Write-Host "Creating .env.example template..."
    
    @"
# Weather API Configuration
OPENWEATHERMAP_API_KEY=your_openweathermap_api_key_here
WEATHER_PROXY_URL=

# Overpass web toggles
# ENABLE_OVERPASS_WEB_POI=false
# ENABLE_OVERPASS_WEB_FUEL=true

# Traffic API Configuration
TOMTOM_API_KEY=your_tomtom_api_key_here

# Supabase (if needed)
# SUPABASE_URL=your_supabase_url
# SUPABASE_ANON_KEY=your_supabase_anon_key

# Gemini AI (sticker verification, commute guide assistant)
GEMINI_API_KEY=your_gemini_api_key_here
"@ | Out-File -FilePath .env.example -Encoding utf8
    
    Write-Host "✅ Created .env.example" -ForegroundColor Green
    Write-Host "📝 Copy .env.example to .env and fill in your API keys"
    exit 1
}

# Load .env file
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

# Check if API key is set
if (-not $env:OPENWEATHERMAP_API_KEY) {
    Write-Host "⚠️  OPENWEATHERMAP_API_KEY not set in .env" -ForegroundColor Yellow
    Write-Host "Please add it to your .env file"
    exit 1
}

# Build dart-define arguments
$dartDefines = "--dart-define=OPENWEATHERMAP_API_KEY=$env:OPENWEATHERMAP_API_KEY"

if ($env:WEATHER_PROXY_URL) {
    $dartDefines += " --dart-define=WEATHER_PROXY_URL=$env:WEATHER_PROXY_URL"
}

if ($env:TOMTOM_API_KEY) {
    $dartDefines += " --dart-define=TOMTOM_API_KEY=$env:TOMTOM_API_KEY"
}

if ($env:GEMINI_API_KEY) {
    $dartDefines += " --dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY"
}

if ($env:ENABLE_OVERPASS_WEB_POI) {
    $dartDefines += " --dart-define=ENABLE_OVERPASS_WEB_POI=$env:ENABLE_OVERPASS_WEB_POI"
}

if ($env:ENABLE_OVERPASS_WEB_FUEL) {
    $dartDefines += " --dart-define=ENABLE_OVERPASS_WEB_FUEL=$env:ENABLE_OVERPASS_WEB_FUEL"
}

# Run Flutter
Write-Host "Running Flutter with environment variables from .env" -ForegroundColor Green
$keyPreview = $env:OPENWEATHERMAP_API_KEY.Substring(0, [Math]::Min(10, $env:OPENWEATHERMAP_API_KEY.Length))
Write-Host "API Key: ${keyPreview}... (hidden)"
if ($env:WEATHER_PROXY_URL) {
    Write-Host "Proxy URL: $env:WEATHER_PROXY_URL"
}
if ($env:TOMTOM_API_KEY) {
    $tomtomPreview = $env:TOMTOM_API_KEY.Substring(0, [Math]::Min(10, $env:TOMTOM_API_KEY.Length))
    Write-Host "TomTom API Key: ${tomtomPreview}... (hidden)"
}
if ($env:GEMINI_API_KEY) {
    $geminiPreview = $env:GEMINI_API_KEY.Substring(0, [Math]::Min(10, $env:GEMINI_API_KEY.Length))
    Write-Host "Gemini API Key: ${geminiPreview}... (hidden)"
}
Write-Host ""

flutter run $dartDefines $args

