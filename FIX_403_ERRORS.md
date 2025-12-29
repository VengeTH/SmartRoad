# Fix 403 Forbidden Errors for RainViewer

## Problem
The proxy server is getting **403 Forbidden** errors from RainViewer because it's not sending proper browser-like headers.

## Solution

### Step 1: Run the fix script on your server

1. **Copy the fix script to your server:**
   ```bash
   # On your Windows machine, copy fix-proxy-403.sh to your server
   scp fix-proxy-403.sh venge@112.207.162.79:~/SmartRoad/
   ```

2. **SSH into your server:**
   ```bash
   ssh venge@112.207.162.79
   ```

3. **Run the fix script:**
   ```bash
   cd ~/SmartRoad
   chmod +x fix-proxy-403.sh
   ./fix-proxy-403.sh
   ```

   The script will:
   - Backup your current `server.js`
   - Update it with proper browser headers
   - Restart the proxy server

### Step 2: Verify the fix

**On your server:**
```bash
# Check logs
pm2 logs weather-proxy --lines 50

# Test a tile request
curl -I http://localhost:3000/rainviewer/1766994000/7/107/59
```

You should see `200 OK` instead of `403 Forbidden`.

### Step 3: Test from your local machine

**With SSH tunnel running:**
```powershell
# Test health endpoint
curl http://localhost:3000/health

# Test a tile (should return PNG image headers)
curl -I http://localhost:3000/rainviewer/1766994000/7/107/59
```

### Step 4: Run Flutter app

```bash
flutter run --dart-define=WEATHER_PROXY_URL=http://localhost:3000
```

## What the fix does

The updated proxy server now sends proper browser headers:
- `User-Agent`: Mimics Chrome browser
- `Referer`: Points to rainviewer.com
- `Accept`: Proper image/content types
- Other browser-like headers

This makes RainViewer think the requests are coming from a real browser, not a bot.

## Troubleshooting

### Still getting 403 errors?

1. **Check proxy logs:**
   ```bash
   pm2 logs weather-proxy
   ```

2. **Verify headers are being sent:**
   Look for `[RainViewer] Fetching:` logs in the proxy output

3. **Test direct connection:**
   ```bash
   curl -H "User-Agent: Mozilla/5.0" https://tilecache.rainviewer.com/v2/radar/1766994000/7/107/59/2/1_1.png -I
   ```

### Proxy not restarting?

```bash
# Stop and start manually
pm2 stop weather-proxy
pm2 start server.js --name weather-proxy
pm2 save
```

## Files Changed

- `weather-proxy/server.js` - Updated with proper headers
- `lib/services/rainviewer_service.dart` - Now uses proxy for timestamps when configured

