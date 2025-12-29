# Troubleshooting 403 Forbidden Errors

## Step 1: Run the improved fix

```bash
cd ~/SmartRoad
chmod +x fix-proxy-403-v2.sh
./fix-proxy-403-v2.sh
```

## Step 2: Test with diagnostic endpoint

```bash
# This will show detailed information about what RainViewer is returning
curl http://localhost:3000/test-rainviewer | jq
```

Look for:
- `status`: Should be 200, not 403
- `headers`: Check what RainViewer is sending back
- Any error messages

## Step 3: Check detailed logs

```bash
pm2 logs weather-proxy --lines 100
```

Look for:
- `[RainViewer] Response status: 403 Forbidden` - This means RainViewer is blocking
- `[RainViewer] Error body:` - This might contain a reason
- Any exception messages

## Step 4: Test direct connection

**On your server:**
```bash
# Test if your server IP can access RainViewer directly
curl -I -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  "https://tilecache.rainviewer.com/v2/radar/1766994000/7/107/59/2/1_1.png"
```

**If this also returns 403:**
- Your server IP might be blocked by RainViewer
- This is common for VPS/datacenter IPs
- **Solution:** Use a different approach (see below)

## Possible Causes & Solutions

### Cause 1: IP Address Blocked
**Symptom:** Direct curl from server also returns 403

**Solutions:**
1. **Use a different server/VPS** with a different IP
2. **Use a residential proxy service** (paid)
3. **Contact RainViewer** to whitelist your IP (if you have a legitimate use case)
4. **Use alternative weather data source** (see below)

### Cause 2: Headers Not Being Sent Correctly
**Symptom:** Proxy logs show headers but still 403

**Solution:** The v2 fix script should handle this. Check logs to verify headers are being sent.

### Cause 3: Rate Limiting
**Symptom:** Works sometimes, fails other times

**Solution:** Add delays between requests in the proxy server.

### Cause 4: RainViewer API Changes
**Symptom:** Worked before, stopped working suddenly

**Solution:** Check RainViewer's API documentation for changes.

## Alternative Solutions

If RainViewer continues to block your server:

### Option 1: Use OpenWeatherMap Radar
- Different API, might have different blocking rules
- Requires API key (free tier available)

### Option 2: Use Weather.gov Radar (US only)
- Free, no API key needed
- Only covers United States

### Option 3: Client-Side Only (No Proxy)
- Use RainViewer's official embed/widget
- Less control but guaranteed to work

### Option 4: Use a CDN/Proxy Service
- Services like Cloudflare Workers
- Or use a residential proxy service

## Testing Checklist

- [ ] Proxy server is running (`pm2 status`)
- [ ] Health endpoint works (`curl http://localhost:3000/health`)
- [ ] Test endpoint shows detailed info (`curl http://localhost:3000/test-rainviewer`)
- [ ] Direct curl from server works (if not, IP might be blocked)
- [ ] Logs show proper headers being sent
- [ ] No errors in proxy logs

## Next Steps

1. Run the v2 fix script
2. Test the diagnostic endpoint
3. Check logs for detailed error messages
4. If IP is blocked, consider alternative solutions above
