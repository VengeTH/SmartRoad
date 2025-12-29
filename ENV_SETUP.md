# Environment Variables Setup Guide

## 🔒 Security First!

**NEVER commit your `.env` file to Git!** It's already in `.gitignore`, but always double-check.

## Using .env Files with Flutter

Flutter uses `--dart-define` for compile-time environment variables. Here are two ways to use `.env` files:

### Method 1: Load .env and Pass to Flutter (Recommended)

Create a `.env` file in your project root:

```bash
# .env
OPENWEATHERMAP_API_KEY=your_actual_api_key_here
WEATHER_PROXY_URL=http://localhost:3000
TOMTOM_API_KEY=your_tomtom_api_key_here
```

Then create a script to load it:

**Windows (PowerShell) - `run.ps1`:**
```powershell
# Load .env file
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

# Run Flutter with environment variables
flutter run `
    --dart-define=OPENWEATHERMAP_API_KEY=$env:OPENWEATHERMAP_API_KEY `
    --dart-define=WEATHER_PROXY_URL=$env:WEATHER_PROXY_URL `
    --dart-define=TOMTOM_API_KEY=$env:TOMTOM_API_KEY
```

**Linux/Mac (Bash) - `run.sh`:**
```bash
#!/bin/bash
# Load .env file
export $(grep -v '^#' .env | xargs)

# Run Flutter with environment variables
flutter run \
    --dart-define=OPENWEATHERMAP_API_KEY=$OPENWEATHERMAP_API_KEY \
    --dart-define=WEATHER_PROXY_URL=$WEATHER_PROXY_URL \
    --dart-define=TOMTOM_API_KEY=$TOMTOM_API_KEY
```

### Method 2: Direct --dart-define (Simpler)

Just use `--dart-define` directly without `.env`:

```bash
flutter run --dart-define=OPENWEATHERMAP_API_KEY=your_key_here
```

## .env File Template

Create a `.env` file (copy from `.env.example` if it exists):

```bash
# Weather API Configuration
OPENWEATHERMAP_API_KEY=your_openweathermap_api_key_here
WEATHER_PROXY_URL=

# Traffic API Configuration
TOMTOM_API_KEY=your_tomtom_api_key_here

# Supabase (if needed)
# SUPABASE_URL=your_supabase_url
# SUPABASE_ANON_KEY=your_supabase_anon_key
```

## IDE Configuration

### Android Studio / IntelliJ

1. **Run > Edit Configurations**
2. **Additional run args:**
   ```
   --dart-define=OPENWEATHERMAP_API_KEY=your_key_here --dart-define=WEATHER_PROXY_URL=http://localhost:3000 --dart-define=TOMTOM_API_KEY=your_tomtom_key_here
   ```

### VS Code

Edit `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "SmartRoad",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=OPENWEATHERMAP_API_KEY=your_key_here",
        "--dart-define=WEATHER_PROXY_URL=http://localhost:3000",
        "--dart-define=TOMTOM_API_KEY=your_tomtom_key_here"
      ]
    }
  ]
}
```

## Verify .env is Ignored

Check `.gitignore` includes:
```
.env
.env.local
.env.*.local
*.env
```

✅ Already configured in your project!

## Best Practices

1. ✅ **Use `.env` for local development** - Store keys locally
2. ✅ **Use `.env.example`** - Template without real keys (can commit this)
3. ✅ **Never commit `.env`** - Already in `.gitignore`
4. ✅ **Use CI/CD secrets** - For production builds
5. ✅ **Rotate keys regularly** - Especially if exposed

## Current Configuration

Your project uses:
- `OPENWEATHERMAP_API_KEY` - For weather tile layers
- `WEATHER_PROXY_URL` - Optional proxy server URL
- `TOMTOM_API_KEY` - For live traffic flow visualization

All are read via `String.fromEnvironment()` in their respective config files:
- `lib/config/weather_config.dart` - Weather API keys
- `lib/config/traffic_config.dart` - Traffic API key
