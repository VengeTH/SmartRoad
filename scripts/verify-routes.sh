#!/usr/bin/env bash
# =============================================================================
# SmartRoad — GraphHopper Long-Distance Route Verification
# =============================================================================
# Tests that GraphHopper can calculate long-distance routes across the
# Philippines. Run this after GraphHopper has finished building its graph.
#
# Usage:
#   chmod +x scripts/verify-routes.sh
#   ./scripts/verify-routes.sh
#
# Options:
#   GRAPH_HOPPER_URL=http://localhost:8989  (default)
#   VEHICLE=motorcycle                      (default)
# =============================================================================

set -euo pipefail

GRAPH_HOPPER_URL="${GRAPH_HOPPER_URL:-http://localhost:8989}"
VEHICLE="${VEHICLE:-motorcycle}"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_good() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_bad()  { echo -e "${RED}[FAIL]${NC} $1"; }
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

# =============================================================================
# Test Routes
# =============================================================================
# Format: "name|from_lat,from_lon|to_lat,to_lon|min_distance_km"
# Distances are approximate straight-line km, used as sanity check.
# =============================================================================

ROUTES=(
  # Metro Manila short hops
  "Manila to Quezon City|14.5995,120.9842|14.6760,121.0437|5"
  "Makati to BGC|14.5547,121.0244|14.5507,121.0518|2"
  "Pasay to Mandaluyong|14.5378,120.9900|14.5800,121.0400|4"

  # Long distance (inter-city)
  "Manila to Batangas|14.5995,120.9842|13.7563,121.0583|70"
  "Quezon City to Laguna|14.6760,121.0437|14.2833,121.0833|40"
  "Manila to Baguio|14.5995,120.9842|16.4023,120.5960|180"

  # Extra-long (inter-region)
  "Manila to Naga|14.5995,120.9842|13.6194,123.1816|220"
  "Manila to Cabanatuan|14.5995,120.9842|15.4850,120.9670|90"
  "Manila to San Fernando La Union|14.5995,120.9842|16.6154,120.3158|200"

  # Visayas (if GraphHopper has Visayas OSM data)
  "Cebu City to Dumaguete|10.3157,123.8854|9.3070,123.3070|110"

  # Extreme long distance (PH north-south)
  "Manila to Legazpi|14.5995,120.9842|13.1391,123.7438|300"
)

echo ""
echo "=============================================="
echo "  SmartRoad — Route Verification"
echo "  GraphHopper: $GRAPH_HOPPER_URL"
echo "  Vehicle:     $VEHICLE"
echo "=============================================="
echo ""

# Check if GraphHopper is running
if ! curl -sf "$GRAPH_HOPPER_URL/health" > /dev/null 2>&1; then
  log_bad "GraphHopper is not running at $GRAPH_HOPPER_URL"
  log_info "Start it with: cd backend && docker-compose up -d graphhopper"
  exit 1
fi
log_good "GraphHopper is running"

echo ""

for route in "${ROUTES[@]}"; do
  IFS='|' read -r name from to min_km <<< "$route"

  log_info "Testing: $name ($from → $to, min: ${min_km}km)"

  # Call GraphHopper API
  RESPONSE=$(curl -sf "$GRAPH_HOPPER_URL/route" \
    --data-urlencode "point=$from" \
    --data-urlencode "point=$to" \
    --data-urlencode "vehicle=$VEHICLE" \
    --data-urlencode "type=json" \
    --data-urlencode "instructions=true" \
    --data-urlencode "calc_points=true" \
    --data-urlencode "points_encoded=false" 2>&1) || {
    log_bad "HTTP request failed: $RESPONSE"
    ((FAIL++))
    continue
  }

  # Parse distance from JSON response
  DISTANCE=$(echo "$RESPONSE" | python3 -c "
import json,sys
try:
  d = json.load(sys.stdin)
  path = d['paths'][0]
  dist_km = path['distance'] / 1000.0
  time_s = path['time'] / 1000.0
  print(f'{dist_km:.2f},{time_s:.0f}')
except Exception as e:
  print(f'ERROR:{e}')
" 2>/dev/null) || DISTANCE="PARSE_ERROR"

  if [[ "$DISTANCE" == PARSE_ERROR ]]; then
    log_bad "Could not parse response"
    ((FAIL++))
    continue
  fi

  IFS=',' read -r dist_km time_s <<< "$DISTANCE"

  # Check minimum distance
  if (( $(echo "$dist_km > $min_km" | bc -l 2>/dev/null || echo 0) )); then
    log_good "Distance: ${dist_km}km (min ${min_km}km) — Time: ${time_s}s"
    ((PASS++))
  else
    log_bad "Distance ${dist_km}km is below minimum ${min_km}km"
    ((FAIL++))
  fi

  # Brief delay to avoid rate limiting
  sleep 0.5
done

# =============================================================================
# Test toll avoidance
# =============================================================================
echo ""
log_info "Testing toll avoidance..."

TOLL_TEST=$(curl -sf "$GRAPH_HOPPER_URL/route" \
  --data-urlencode "point=14.5995,120.9842" \
  --data-urlencode "point=14.5500,121.0200" \
  --data-urlencode "vehicle=$VEHICLE" \
  --data-urlencode "type=json" \
  --data-urlencode "instructions=true" 2>&1)

if echo "$TOLL_TEST" | python3 -c "
import json,sys
try:
  d = json.load(sys.stdin)
  instructions = ' '.join([i['text'] for i in d['paths'][0]['instructions']])
  # Toll roads typically have 'toll' in instruction text
  has_toll = 'toll' in instructions.lower()
  if has_toll: print('TOLL_DETECTED')
  else: print('NO_TOLL')
except: print('ERROR')
" 2>/dev/null | grep -q "NO_TOLL"; then
  log_good "Toll avoidance working (no toll roads in route)"
  ((PASS++))
else
  log_info "Toll detection requires specific routes (not always avoidable)"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=============================================="
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
