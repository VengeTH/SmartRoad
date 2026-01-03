# Route as a Product - Complete Architecture

## Executive Summary

**Core Principle:** Navigation-first design. Routes enhance navigation, they don't replace it.

SmartRoad's "Route as a Product" system allows users to:
1. Save routes they've navigated
2. Share routes with others
3. Sell premium routes
4. Discover routes optimized for specific conditions (rain, flood, night)

All while maintaining seamless navigation functionality.

---

## 1. Database Schema Design

### Geometry Choice: LINESTRING (PostGIS)

**Why LINESTRING, not MULTILINESTRING?**
- Routes are single continuous paths from A to B
- MULTILINESTRING would be for disconnected segments (not our use case)
- LINESTRING is simpler and more efficient for spatial queries

**Why PostGIS GEOGRAPHY, not GEOMETRY?**
- GEOGRAPHY uses spherical calculations (accurate for real-world distances)
- GEOMETRY uses planar calculations (faster but less accurate over long distances)
- For route distances, GEOGRAPHY is more accurate

**GraphHopper Integration:**
- We store the **actual driven polyline**, not a GraphHopper route ID
- GraphHopper can recalculate if needed, but we preserve the original
- This allows routes to remain valid even if OSM data changes

**Key Tables:**
1. `saved_routes` - Main route storage
2. `route_purchases` - Tracks who bought what
3. `route_ratings` - User ratings
4. `route_shares` - Shareable links
5. `route_usage_log` - Usage tracking

See `supabase_routes_schema.sql` for complete schema.

---

## 2. Route Creation Flow (Navigation-First)

### User Journey

```
1. User starts navigation normally
   ↓
2. GraphHopper calculates route
   ↓
3. User navigates (route is displayed)
   ↓
4. User taps "Save this route" button
   ↓
5. System captures:
   - Actual driven polyline (up to current position)
   - Current weather conditions
   - Hazard count near route
   - Distance/duration
   ↓
6. User provides:
   - Route name
   - Description (optional)
   - Tags (rain_safe, flood_safe, etc.)
   - Price (0 = free)
   ↓
7. Route saved to database
```

### Edge Cases

**User modifies route mid-navigation:**
- Save the route up to the deviation point
- Mark as "partial" or allow user to choose which segment to save
- Future: Allow saving multiple route segments

**Partial route save:**
- User can save route before reaching destination
- Route is marked with current position as end point
- User can complete it later (update end point)

**Offline save queue:**
- Store route in local SQLite
- Sync to Supabase when online
- Handle conflicts (route already exists, etc.)

### Implementation

```dart
// * In MapScreen, during navigation
void _saveCurrentRoute() async {
  final routeService = RouteService();
  
  // * Get current route geometry (traveled + upcoming)
  final fullRoute = [..._traveledRoute, ..._upcomingRoute];
  
  // * Save route
  final savedRoute = await routeService.saveCurrentRoute(
    name: "My Route",
    geometry: fullRoute,
    startPoint: _navigationOrigin!,
    endPoint: _currentLocation,
    distanceMeters: _routeDistance * 1000,
    estimatedDurationSeconds: _routeDuration.inSeconds,
    vehicleType: _getVehicleTypeFromMode(_navigationMode!),
    tags: {
      'rain_safe': _isRainSafe(),
      'flood_safe': _isFloodSafe(),
      'toll_free': _avoidTollsToggle,
    },
  );
}
```

---

## 3. Route Sharing

### Shareable Links

**Format:**
- Deep link: `smartroad://route/{token}`
- Web link: `https://smartroad.app/route/{token}`

**Sharing Modes:**

1. **Strict Mode:**
   - Follow exact route, no rerouting
   - User must stay on route
   - Best for: Verified routes, time-critical paths

2. **Flexible Mode:**
   - Allow rerouting only when blocked
   - System detects if route is blocked (hazard, closure)
   - Best for: General sharing, most common use case

3. **Suggested Mode:**
   - Use as suggestion, allow full rerouting
   - User can deviate freely
   - Best for: Route discovery, inspiration

### UX Behavior

**When user opens shared route:**

1. **Free Route:**
   - Show route preview immediately
   - User can start navigation
   - Route is imported to their saved routes

2. **Paid Route:**
   - Show route preview (distance, duration, benefits)
   - Show purchase button
   - After purchase, full navigation unlocked

**During Navigation (Shared Route):**

- **Strict Mode:**
  - No rerouting allowed
  - If user deviates, show warning
  - If route blocked, show error (route invalid)

- **Flexible Mode:**
  - Normal navigation
  - If route blocked, recalculate from current position
  - Continue to original destination

- **Suggested Mode:**
  - Normal navigation
  - User can reroute freely
  - Route shown as overlay (different color)

---

## 4. Route Selling (Lightweight)

### Pricing Model

- **Free Routes:** `price_cents = 0`
- **Paid Routes:** `price_cents > 0`

### Preview vs Full Access

**Preview (Unpaid Routes):**
- Distance, duration, trust score
- Start/end points
- Tags (rain_safe, etc.)
- Creator info
- **NO geometry** (polyline not accessible)

**Full Access (Free or Purchased):**
- Everything in preview
- **Full geometry** (polyline)
- Can start navigation

### Payment Logic (Abstracted)

For MVP, payment is abstracted:
```dart
Future<void> purchaseRoute(String routeId) async {
  // * TODO: Integrate with Stripe/PayPal/etc.
  // * For now, just insert purchase record
  await routeService.purchaseRoute(routeId);
}
```

**Backend Validation:**
- Never return geometry for unpaid routes
- Check purchase status before allowing navigation
- Prevent polyline extraction via API

---

## 5. Route Discovery (Inside Navigation)

### Discovery Points

Discovery appears **natively in navigation**, not as separate screen:

1. **During Route Preview:**
   - Show "Popular routes to this destination"
   - Show "Best routes for current conditions"

2. **During Navigation:**
   - Show "Alternative routes nearby"
   - Show "Routes optimized for rain/flood"

3. **Route Selection:**
   - When user searches destination
   - Show saved routes alongside calculated routes

### Discovery Queries

**Popular routes near you:**
```sql
SELECT * FROM saved_routes
WHERE ST_DWithin(start_point, ST_MakePoint($lng, $lat)::geography, 5000)
  AND is_public = true AND is_active = true
ORDER BY usage_count DESC, trust_score DESC
LIMIT 10;
```

**Rain-safe routes:**
```sql
SELECT * FROM saved_routes
WHERE tags->>'rain_safe' = 'true'
  AND is_public = true AND is_active = true
ORDER BY trust_score DESC
LIMIT 10;
```

**Routes for specific vehicle:**
```sql
SELECT * FROM saved_routes
WHERE vehicle_type = 'motorcycle'
  AND is_public = true AND is_active = true
ORDER BY trust_score DESC, usage_count DESC
LIMIT 10;
```

### UI Integration

**Route Cards (Minimal, Map-Centric):**

```
┌─────────────────────────────────┐
│ 🏍️ Makati to BGC (Rain Safe)    │
│ 12.5 km • 30 min • ⭐ 4.5 (30)  │
│ 🆓 Free • 👥 150 uses           │
│ [Preview] [Use Route]           │
└─────────────────────────────────┘
```

**Visual Indicators:**
- Free routes: Green badge
- Paid routes: Gold badge with price
- Trust score: Progress bar (0-100)
- Tags: Icons (🌧️ rain_safe, 🌊 flood_safe, 🌙 night_safe)

---

## 6. Route Trust & Safety

### Trust Score Formula

```
trust_score = usage_score + recency_score + rating_score

usage_score = min(usage_count * 2, 30)  // * Caps at 30 points
recency_score = 30 if verified < 30 days ago, decreases to 0 after 365 days
rating_score = (rating_avg / 5.0) * 40 if rating_count >= 3, else 0
```

**Maximum Trust Score:** 100 points

### Auto-Downgrade Triggers

1. **Hazard Reported:**
   - When hazard created within 100m of route
   - Decrease trust by 5 points
   - Mark route as needing verification

2. **Route Not Verified:**
   - If `last_verified_at` > 365 days ago
   - Recency score = 0
   - Show warning during navigation

3. **Low Usage:**
   - If route not used for 90+ days
   - Usage score decreases
   - Route appears lower in discovery

### Verification

**Manual Verification:**
- User can mark route as "verified" after using it
- Updates `last_verified_at`
- Increases trust score

**Automatic Verification:**
- Route auto-verified if used successfully (completion > 90%)
- No hazards reported during usage
- Updates `last_verified_at`

---

## 7. UI Integration (Flutter)

### Route Overlay on Map

**Visual Differentiation:**

1. **Calculated Routes (GraphHopper):**
   - Blue polyline (default)
   - Standard route color

2. **Saved Routes (Free):**
   - Green polyline
   - Dashed line style
   - Label: "Saved Route"

3. **Saved Routes (Paid, Purchased):**
   - Gold polyline
   - Solid line style
   - Label: "Premium Route"

4. **Shared Routes:**
   - Purple polyline
   - Dotted line style
   - Label: "Shared Route"

### Route Cards

**Minimal Design (Map-Centric):**

```dart
RouteCard(
  route: savedRoute,
  onTap: () => _showRouteDetails(savedRoute),
  onUse: () => _startNavigationWithRoute(savedRoute),
)
```

**Card Content:**
- Route name
- Distance, duration
- Trust score (progress bar)
- Tags (icons)
- Price (if paid)
- Action buttons (Preview, Use, Purchase)

### Navigation Integration

**When Following Saved Route:**

1. **Route Overlay:**
   - Show saved route polyline
   - Different color from calculated route
   - Label indicating route type

2. **Navigation Instructions:**
   - Standard navigation instructions
   - Additional info: "Following saved route"
   - Trust score indicator

3. **Deviation Handling:**
   - If strict mode: Warn user
   - If flexible mode: Recalculate if blocked
   - If suggested mode: Allow free deviation

### Route Discovery UI

**Discovery appears in:**

1. **Route Preview Sheet:**
   - "Popular routes to this destination"
   - "Best routes for current conditions"
   - Swipeable route cards

2. **Navigation Overlay:**
   - "Alternative routes nearby"
   - Minimal cards, tap to switch

3. **Search Results:**
   - Saved routes appear alongside search results
   - Badge indicating "Saved Route"

---

## 8. Architecture Diagram (Text)

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Client)                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  MapScreen    │  │ RouteService │  │RouteProvider │     │
│  │  (Navigation) │──│  (Business   │──│  (State)     │     │
│  │               │  │   Logic)     │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                  │                  │            │
│         │                  │                  │            │
│         ▼                  ▼                  ▼            │
│  ┌──────────────────────────────────────────────────┐     │
│  │         Supabase Client (Flutter SDK)             │     │
│  └──────────────────────────────────────────────────┘     │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│              SUPABASE (PostgreSQL + PostGIS)                 │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ saved_routes │  │route_purchases│ │route_ratings │     │
│  │  (Geometry)  │  │               │ │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │route_shares  │  │route_usage_log│                       │
│  │              │  │               │                        │
│  └──────────────┘  └──────────────┘                       │
│                                                               │
│  PostGIS Functions:                                           │
│  - ST_DWithin (spatial queries)                               │
│  - ST_Distance (distance calculations)                        │
│  - ST_Intersects (hazard detection)                           │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                             │
                             │ (for route calculation)
                             ▼
┌─────────────────────────────────────────────────────────────┐
│              GRAPHHOPPER (Self-Hosted)                       │
│                                                               │
│  - Route calculation                                          │
│  - Alternative routes                                          │
│  - Recalculation on deviation                                 │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

**Data Flow:**

1. **Route Creation:**
   - User navigates → Flutter captures polyline → RouteService → Supabase

2. **Route Discovery:**
   - User location → RouteService → Supabase (spatial query) → Flutter

3. **Route Purchase:**
   - User taps purchase → RouteService → Supabase (insert purchase) → Flutter

4. **Route Navigation:**
   - User selects route → Flutter loads geometry → MapScreen displays → Navigation starts

---

## 9. Non-Goals (Explicitly Avoided)

### ❌ NOT Implemented

1. **HOA Admin Dashboards:**
   - Route selling is user-to-user
   - No admin interface for route management

2. **Subscription Systems:**
   - No monthly/yearly subscriptions
   - Pay-per-route only (for MVP)

3. **AI Prediction Engines:**
   - No ML-based route optimization
   - No traffic prediction
   - Routes are based on actual navigation

4. **Ride-Hailing Integrations:**
   - No Uber/Grab integration
   - Focus on personal navigation only

5. **Separate Marketplace Screen:**
   - Discovery is integrated into navigation
   - No standalone "Route Store"

---

## 10. Implementation Checklist

### Phase 1: Core Functionality
- [x] Database schema
- [x] Route model (Flutter)
- [x] RouteService (Flutter)
- [ ] Route creation UI (Save button in navigation)
- [ ] Route discovery UI (in navigation)
- [ ] Route sharing (deep links)

### Phase 2: Monetization
- [ ] Route purchase flow
- [ ] Payment integration (abstracted for MVP)
- [ ] Purchase validation

### Phase 3: Trust & Safety
- [ ] Trust score calculation
- [ ] Auto-downgrade on hazards
- [ ] Route verification UI

### Phase 4: Advanced Features
- [ ] Route versioning
- [ ] Route analytics (for creators)
- [ ] Route recommendations

---

## Summary

**Route as a Product** enhances SmartRoad's navigation without replacing it. Users can:
- Save routes they've navigated
- Share routes with others
- Discover routes optimized for conditions
- Sell premium routes

All while maintaining seamless, navigation-first UX.

**Key Design Decisions:**
1. Store actual driven polyline (not GraphHopper ID)
2. PostGIS for spatial queries
3. Trust score for route quality
4. Preview-only for unpaid routes
5. Discovery integrated into navigation (not separate screen)
