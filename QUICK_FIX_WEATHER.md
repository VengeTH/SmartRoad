# Quick Fix: Weather Layers Not Working

## Problem
You have the API key in `.env` but weather layers still show "Requires backend proxy" message.

## Solution

Flutter doesn't automatically read `.env` files. You need to pass the API key via `--dart-define` or use the helper script.

### ✅ Easiest Method: Use the Script

**Windows (PowerShell):**
```powershell
.\run-with-env.ps1
```

**Linux/Mac:**
```bash
./run-with-env.sh
```

This script will:
1. Load your `.env` file
2. Extract the `OPENWEATHERMAP_API_KEY`
3. Pass it to Flutter via `--dart-define`
4. Run the app

### Alternative: Manual --dart-define

If you prefer to run Flutter directly:

```bash
flutter run --dart-define=OPENWEATHERMAP_API_KEY=aa839fe66be66533eaef7ac55a80bb75
```

### In Android Studio / VS Code

**Android Studio:**
1. Run > Edit Configurations
2. Additional run args:
   ```
   --dart-define=OPENWEATHERMAP_API_KEY=aa839fe66be66533eaef7ac55a80bb75
   ```

**VS Code (.vscode/launch.json):**
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "SmartRoad",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=OPENWEATHERMAP_API_KEY=aa839fe66be66533eaef7ac55a80bb75"
      ]
    }
  ]
}
```

## Why This Happens

Flutter's `String.fromEnvironment()` only reads values passed via `--dart-define` at compile time. It doesn't read `.env` files automatically.

The `.env` file is just for your convenience - the script reads it and passes the values to Flutter.

## After Running

Once you run with the API key, the weather layers should:
- ✅ Show as available (no warning message)
- ✅ Allow you to toggle them on/off
- ✅ Display weather tiles on the map
