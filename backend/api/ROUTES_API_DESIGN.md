# Route as a Product - Backend API Design

## Architecture Overview

**Technology Stack:**
- Go (Golang 1.24+)
- PostgreSQL + PostGIS for spatial queries
- JWT for authentication
- GraphHopper integration (already exists)

**Core Principle:** Navigation-first. Routes enhance navigation, don't replace it.

---

## API Endpoints

### Base URL: `/api/v1/routes`

---

### 1. Route Creation (Navigation-First)

#### `POST /api/v1/routes/save`

**Purpose:** Save a route that user just navigated (or is navigating).

**Request Body:**
```json
{
  "name": "Makati to BGC via EDSA",
  "description": "Fast route avoiding tolls",
  "geometry": {
    "type": "LineString",
    "coordinates": [[lng, lat], [lng, lat], ...]
  },
  "start_point": {"lat": 14.5995, "lng": 120.9842},
  "end_point": {"lat": 14.6760, "lng": 121.0437},
  "distance_meters": 12500,
  "estimated_duration_seconds": 1800,
  "vehicle_type": "motorcycle",
  "country_code": "PH",
  "city": "Manila",
  "tags": {
    "rain_safe": true,
    "flood_safe": false,
    "toll_free": true,
    "gate_aware": true,
    "night_safe": true
  },
  "price_cents": 0,
  "is_public": true,
  "weather_at_save": {
    "rain": false,
    "flood_risk": "low",
    "visibility": "good"
  }
}
```

**Response:**
```json
{
  "id": "uuid",
  "name": "Makati to BGC via EDSA",
  "trust_score": 0.0,
  "created_at": "2025-01-15T10:30:00Z"
}
```

**Logic:**
1. Validate geometry (must be valid LINESTRING)
2. Extract start/end points from geometry
3. Calculate distance/duration if not provided
4. Snapshot current weather/hazard conditions
5. Insert into `saved_routes` table
6. Return created route

**Edge Cases:**
- Partial route save: User saves route mid-navigation
  - Solution: Save geometry up to current position
  - Mark as `is_active = false` if incomplete
- Offline save: Queue for sync when online
  - Solution: Store in local SQLite, sync on reconnect

---

### 2. Route Discovery (Inside Navigation)

#### `GET /api/v1/routes/discover`

**Purpose:** Find routes near user's location or navigation context.

**Query Parameters:**
- `lat` (required): User latitude
- `lng` (required): User longitude
- `radius_meters` (default: 5000): Search radius
- `vehicle_type` (optional): Filter by vehicle
- `tags` (optional): Comma-separated tags (e.g., `rain_safe,flood_safe`)
- `limit` (default: 10): Max results
- `sort` (default: `trust_score`): `trust_score`, `usage_count`, `rating_avg`

**Response:**
```json
{
  "routes": [
    {
      "id": "uuid",
      "name": "Route Name",
      "distance_meters": 12500,
      "estimated_duration_seconds": 1800,
      "trust_score": 85.5,
      "usage_count": 150,
      "rating_avg": 4.5,
      "price_cents": 0,
      "tags": {"rain_safe": true},
      "start_point": {"lat": 14.5995, "lng": 120.9842},
      "end_point": {"lat": 14.6760, "lng": 121.0437},
      "is_purchased": false,
      "distance_to_route_meters": 250
    }
  ]
}
```

**Logic:**
1. Use PostGIS `ST_DWithin` to find routes near point
2. Filter by vehicle type, tags, public/active
3. Calculate distance from user to route
4. Check if user has purchased (if paid route)
5. Sort and limit results
6. Return preview data (NO geometry for unpaid routes)

**Spatial Query:**
```sql
SELECT 
  id, name, distance_meters, estimated_duration_seconds,
  trust_score, usage_count, rating_avg, price_cents, tags,
  ST_X(start_point::geometry) as start_lng,
  ST_Y(start_point::geometry) as start_lat,
  ST_X(end_point::geometry) as end_lng,
  ST_Y(end_point::geometry) as end_lat,
  ST_Distance(geometry::geography, ST_MakePoint($lng, $lat)::geography) as distance_to_route_meters
FROM saved_routes
WHERE ST_DWithin(
  geometry::geography,
  ST_MakePoint($lng, $lat)::geography,
  $radius_meters
)
AND is_public = true AND is_active = true
ORDER BY trust_score DESC, usage_count DESC
LIMIT $limit;
```

---

### 3. Route Details (Preview vs Full)

#### `GET /api/v1/routes/:id`

**Purpose:** Get route details. Returns preview for unpaid routes, full geometry for free/purchased.

**Query Parameters:**
- `include_geometry` (default: false): Include full geometry

**Response (Preview - Unpaid Route):**
```json
{
  "id": "uuid",
  "name": "Route Name",
  "description": "Route description",
  "distance_meters": 12500,
  "estimated_duration_seconds": 1800,
  "trust_score": 85.5,
  "usage_count": 150,
  "rating_avg": 4.5,
  "rating_count": 30,
  "price_cents": 500,
  "tags": {"rain_safe": true},
  "start_point": {"lat": 14.5995, "lng": 120.9842},
  "end_point": {"lat": 14.6760, "lng": 121.0437},
  "is_purchased": false,
  "geometry": null  // * NOT included for unpaid routes
}
```

**Response (Full - Free or Purchased):**
```json
{
  "id": "uuid",
  "name": "Route Name",
  "geometry": {
    "type": "LineString",
    "coordinates": [[lng, lat], ...]
  },
  "is_purchased": true,
  // ... other fields
}
```

**Logic:**
1. Check if route is free (`price_cents == 0`)
2. If paid, check if user purchased it
3. If unpaid and not purchased, return preview only
4. If free or purchased, return full geometry

**Security:** Never return geometry for unpaid routes via this endpoint.

---

### 4. Route Purchase

#### `POST /api/v1/routes/:id/purchase`

**Purpose:** Purchase a paid route (abstracted payment logic).

**Request Body:**
```json
{
  "payment_method": "stripe",  // * Placeholder
  "payment_token": "token"      // * Placeholder
}
```

**Response:**
```json
{
  "purchase_id": "uuid",
  "route_id": "uuid",
  "price_paid_cents": 500,
  "purchased_at": "2025-01-15T10:30:00Z"
}
```

**Logic:**
1. Validate route exists and is paid
2. Check if user already purchased
3. Process payment (abstracted - no real integration yet)
4. Insert into `route_purchases` table
5. Return purchase confirmation

**Future:** Integrate with Stripe/PayPal/etc.

---

### 5. Route Sharing

#### `POST /api/v1/routes/:id/share`

**Purpose:** Create a shareable link for a route.

**Request Body:**
```json
{
  "sharing_mode": "flexible",  // * strict, flexible, suggested
  "expires_at": "2025-02-15T10:30:00Z"  // * optional
}
```

**Response:**
```json
{
  "share_id": "uuid",
  "share_token": "aBcD1234eFgH5678iJkL",
  "share_url": "smartroad://route/aBcD1234eFgH5678iJkL",
  "web_url": "https://smartroad.app/route/aBcD1234eFgH5678iJkL"
}
```

#### `GET /api/v1/routes/share/:token`

**Purpose:** Get route details from share token.

**Response:**
```json
{
  "route": {
    "id": "uuid",
    "name": "Route Name",
    "geometry": {...},  // * Always included for shared routes
    "sharing_mode": "flexible"
  }
}
```

**Logic:**
1. Validate share token exists and not expired
2. Increment view count
3. Return route with geometry (shared routes are always accessible)

---

### 6. Route Usage Tracking

#### `POST /api/v1/routes/:id/usage/start`

**Purpose:** Log when user starts navigating a saved route.

**Response:**
```json
{
  "usage_log_id": "uuid"
}
```

#### `POST /api/v1/routes/:id/usage/complete`

**Purpose:** Log route completion.

**Request Body:**
```json
{
  "usage_log_id": "uuid",
  "completion_percentage": 95.5,
  "deviation_count": 2,
  "was_valid": true
}
```

**Logic:**
1. Update usage log
2. Increment route `usage_count`
3. Update `last_used_at`
4. Recalculate trust score

---

### 7. Route Ratings

#### `POST /api/v1/routes/:id/rate`

**Request Body:**
```json
{
  "rating": 5,
  "comment": "Great route, saved me 20 minutes!"
}
```

**Response:**
```json
{
  "rating_id": "uuid",
  "rating_avg": 4.5,
  "rating_count": 31
}
```

**Logic:**
1. Upsert rating (one per user per route)
2. Recalculate route `rating_avg` and `rating_count`
3. Recalculate trust score
4. Return updated stats

---

### 8. User's Saved Routes

#### `GET /api/v1/routes/my`

**Query Parameters:**
- `limit` (default: 20)
- `offset` (default: 0)

**Response:**
```json
{
  "routes": [
    {
      "id": "uuid",
      "name": "My Route",
      "usage_count": 10,
      "trust_score": 75.0,
      "created_at": "2025-01-15T10:30:00Z"
    }
  ],
  "total": 5
}
```

---

## GraphHopper Integration

**Key Point:** Saved routes store the **actual driven polyline**, not a GraphHopper route ID.

**Why:**
1. GraphHopper routes can change (OSM updates)
2. We want to preserve the exact route user took
3. GraphHopper can recalculate if needed, but we have the original

**When to use GraphHopper:**
- User modifies route mid-navigation → Recalculate from current position
- Route becomes invalid → Offer to recalculate
- User wants alternative → Calculate new route

**Route Recalculation:**
```javascript
// * If user deviates or route becomes invalid
async function recalculateRoute(routeId, currentPosition) {
  const route = await getRoute(routeId);
  const newRoute = await graphhopper.calculateRoute({
    start: currentPosition,
    end: route.endPoint,
    vehicle: route.vehicleType
  });
  
  // * Update route geometry
  await updateRouteGeometry(routeId, newRoute.geometry);
  // * Mark as needing verification
  await markRouteNeedsVerification(routeId);
}
```

---

## Trust Score Calculation

**Formula:**
```
trust_score = (usage_score * 0.3) + (recency_score * 0.3) + (rating_score * 0.4)

usage_score = min(usage_count * 2, 30)  // * Caps at 30 points
recency_score = 30 if verified < 30 days ago, decreases to 0 after 365 days
rating_score = (rating_avg / 5.0) * 40 if rating_count >= 3, else 0
```

**Auto-downgrade:**
- When hazard reported within 100m of route → Decrease trust by 5 points
- When route not verified for 365+ days → Recency score = 0

---

## Security & Validation

1. **Geometry Validation:**
   - Must be valid LINESTRING
   - Must have at least 2 points
   - Points must be valid lat/lng

2. **Price Validation:**
   - `price_cents >= 0`
   - Currency code must be valid ISO 4217

3. **Access Control:**
   - Users can only modify their own routes
   - Paid routes: Geometry only accessible after purchase
   - Shared routes: Always accessible via token

4. **Rate Limiting:**
   - Route creation: 10 per hour per user
   - Route discovery: 100 per hour per user
   - Route purchase: 20 per hour per user

---

## Error Responses

**Standard Error Format:**
```json
{
  "error": {
    "code": "ROUTE_NOT_FOUND",
    "message": "Route not found",
    "details": {}
  }
}
```

**Error Codes:**
- `ROUTE_NOT_FOUND`
- `ROUTE_NOT_PURCHASED` (trying to access paid route without purchase)
- `INVALID_GEOMETRY`
- `ROUTE_ALREADY_PURCHASED`
- `SHARE_TOKEN_EXPIRED`
- `RATE_LIMIT_EXCEEDED`

---

## Future Enhancements (Not in MVP)

1. **Route Analytics Dashboard** (for creators)
2. **Route Versioning** (track changes over time)
3. **Route Recommendations** (ML-based)
4. **Route Bundles** (sell multiple routes together)
5. **Subscription Plans** (unlimited route access)
