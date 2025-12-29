# Android Studio: Configure OpenWeatherMap API Key

## Problem
You have the API key in `.env`, but Android Studio doesn't automatically read it. You need to configure Android Studio to pass it via `--dart-define`.

## Solution: Configure Run Configuration

### Step 1: Open Run Configuration

1. In Android Studio, click **Run** → **Edit Configurations...**
2. Or click the dropdown next to the run button → **Edit Configurations...**

### Step 2: Add Dart Define Arguments

1. Select your run configuration (usually "main.dart" or "SmartRoad")
2. Find **"Additional run args"** or **"Dart entrypoint arguments"** field
3. Add this:
   ```
   --dart-define=OPENWEATHERMAP_API_KEY=aa839fe66be66533eaef7ac55a80bb75
   ```

### Step 3: Save and Run

1. Click **Apply** then **OK**
2. Run your app (green play button)
3. Weather layers should now work!

## Alternative: Use Environment Variables

If you want to keep using `.env`:

### Option A: Create a Script Wrapper

Create `run.bat` (Windows) in project root:

```batch
@echo off
REM Load .env and run Flutter
for /f "tokens=1,2 delims==" %%a in (.env) do (
    if "%%a"=="OPENWEATHERMAP_API_KEY" set OPENWEATHERMAP_API_KEY=%%b
)

flutter run --dart-define=OPENWEATHERMAP_API_KEY=%OPENWEATHERMAP_API_KEY%
```

Then in Android Studio:
1. Run → Edit Configurations
2. Set **"Before launch"** → Add → **Run External Tool**
3. Select `run.bat`

### Option B: Use PowerShell Script (Recommended)

1. Use the provided `run-with-env.ps1` script
2. In Android Studio, create an **External Tool** configuration:
   - **Name:** Run with Env
   - **Program:** `powershell.exe`
   - **Arguments:** `-ExecutionPolicy Bypass -File "$ProjectFileDir$\run-with-env.ps1"`
   - **Working directory:** `$ProjectFileDir$`

## Quick Test

After configuring, check the console output when the app starts. You should see:
- ✅ No warning about missing API key
- ✅ Weather layers available in the UI

## Troubleshooting

### Still showing warning?

1. **Check the console** - Look for `⚠️ [WeatherConfig]` messages
2. **Verify the argument** - Make sure `--dart-define=OPENWEATHERMAP_API_KEY=...` is in "Additional run args"
3. **Restart Android Studio** - Sometimes needed for config changes
4. **Check for typos** - API key should be exactly as in your `.env`

### API key not working?

Test it directly:
```bash
flutter run --dart-define=OPENWEATHERMAP_API_KEY=aa839fe66be66533eaef7ac55a80bb75
```

If this works, the issue is just the Android Studio configuration.
