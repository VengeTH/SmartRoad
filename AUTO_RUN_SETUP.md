# Automatic .env Loading for Flutter Run

## Problem
You want `flutter run` to automatically load your `.env` file without using PowerShell.

## Solution: Use Batch File Wrapper

I've created `run.bat` that automatically loads `.env` and runs Flutter.

### Simple Usage

Instead of:
```bash
flutter run
```

Use:
```bash
run.bat
```

Or:
```bash
flutter_run.bat
```

Both do the same thing - load `.env` and run Flutter with your API key.

## Configure Android Studio to Use It Automatically

### Option 1: Change Run Configuration (Recommended)

1. **Run → Edit Configurations...**
2. Select your configuration
3. In **"Before launch"** section:
   - Click **+** → **Run External Tool**
   - Click **+** again to create new tool
   - **Name:** Load Env
   - **Program:** `cmd.exe`
   - **Arguments:** `/c run.bat`
   - **Working directory:** `$ProjectFileDir$`
   - Click **OK**

**OR** simpler:

1. **Run → Edit Configurations...**
2. **"Before launch"** → **Remove** any existing tasks
3. **"Before launch"** → **+** → **Run External Tool**
4. Select `run.bat` (if it appears) or create new:
   - **Program:** `$ProjectFileDir$\run.bat`
   - **Working directory:** `$ProjectFileDir$`

### Option 2: Use Run Configuration Arguments

1. **Run → Edit Configurations...**
2. **Additional run args:**
   ```
   --dart-define=OPENWEATHERMAP_API_KEY=aa839fe66be66533eaef7ac55a80bb75
   ```
3. Save and run

### Option 3: Create Alias (Command Prompt)

Add to your Windows PATH or create a shortcut:

**Create `flutter-run.bat` in a folder in your PATH:**
```batch
@echo off
cd /d "D:\Programming\Projects\Android Studio\SmartRoad"
call run.bat
```

Then you can just type `flutter-run` anywhere.

## Test It

1. Run `run.bat` from command prompt
2. Check console output - should show API key loaded
3. Weather layers should work!

## Troubleshooting

### Batch file not working?

Make sure `.env` file exists and has:
```
OPENWEATHERMAP_API_KEY=aa839fe66be66533eaef7ac55a80bb75
```

### Still showing warning?

Check console for:
- `🔍 [WeatherLayerControls] API Key configured: true`
- If it says `false`, the API key isn't being passed

### Want to use regular `flutter run`?

You'll need to always pass the API key:
```bash
flutter run --dart-define=OPENWEATHERMAP_API_KEY=aa839fe66be66533eaef7ac55a80bb75
```
