# Fix 403 Forbidden Errors for RainViewer

## Status: Resolved in Go Backend

The **403 Forbidden** errors previously experienced by standalone proxy servers were caused by RainViewer blocking automated bot requests that lack standard browser headers.

This is now **built directly into the SmartRoad Go API** (`backend/api`):
- Sends standard browser `User-Agent` (Chrome/Windows NT)
- Sends image `Accept` headers (`image/webp`, `image/apng`, `image/*`)
- Sets `Referer` to `https://www.rainviewer.com/` for tile requests
- Caches radar tiles in memory (5-minute TTL) to avoid hitting rate limits

### How to Run:

Start the Go backend via Docker Compose:
```bash
cd backend
docker-compose up -d
```

Run Flutter with the proxy configured:
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
