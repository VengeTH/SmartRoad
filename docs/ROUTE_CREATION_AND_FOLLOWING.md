# Route Creation and Following System

## Overview
This document describes the route creation and following system that allows users to:
1. Create routes by drawing on the map or using navigation with custom start/end points
2. Edit routes by adding control points to adjust the path
3. Follow saved routes strictly (exact polyline adherence)
4. Smart rerouting that respects route ownership

## Features

### 1. Route Creation

#### Draw Route
- User manually draws a route on the map by tapping points
- Route can be edited after drawing by adding control points
- Route follows the drawn line regardless of terrain/buildings

#### Use Navigation
- User selects custom start and end points on the map
- Route is calculated using GraphHopper (if available) or fallback interpolation
- Control points can be added to customize the route path
- Route automatically calculates when end point is selected
- Preview sheet opens automatically after route calculation

#### Route Editing
- **Control Points**: Tap on route line to add control points
- **Move Control Points**: Tap and drag control points to adjust route
- **Route Updates**: Route geometry updates in real-time when control points are added/moved
- **Recalculate**: Option to recalculate route with GraphHopper using control points as waypoints
- **Clear**: Remove all control points and restore original route

### 2. Route Following Mode
- **Strict Mode**: Follow exact saved route polyline, no reroute unless blocked
- **Flexible Mode**: Allow reroute when deviating, but prefer saved route
- Route is displayed even if it appears to go through buildings/terrain (it's a valid saved route)

### 3. Reroute Logic
- **Owned/Bought Routes**: Always available for reroute
- **Premium Routes**: Only shown if user has purchased
- **Free Routes**: Available to all users
- Filter reroute options based on user's route access

## Implementation Status

### Completed
- ✅ Route creation dialog widget (`CreateRouteDialog`)
- ✅ Custom point selection with draggable bottom sheet
- ✅ Route calculation with waypoints support
- ✅ Control point system for route editing
- ✅ Real-time route geometry updates
- ✅ Fallback route interpolation when GraphHopper unavailable
- ✅ Auto-calculation when end point is selected
- ✅ Route preview sheet integration
- ✅ Route creation provider
- ✅ Saved route following provider
- ✅ Route editing provider

### In Progress
- 🔄 Route following mode implementation
- 🔄 Reroute filtering logic

### Pending
- ⏳ Route drawing gesture handling (draw route feature)
- ⏳ Visual route display improvements
- ⏳ Route ownership checking in reroute
- ⏳ GraphHopper waypoint routing (when GraphHopper is available)

## Technical Details

### Control Points System
- Control points are stored as `List<LatLng> _routeControlPoints`
- When GraphHopper is unavailable, control points are interpolated using linear interpolation
- Route geometry updates immediately when control points are added or moved
- Control points are sorted by distance from route start to ensure correct order

### Fallback Route Creation
- When GraphHopper fails, `RoutingService._createFallbackRoute()` creates interpolated paths
- Route goes: Start → Control Point 1 → Control Point 2 → ... → End
- Intermediate points are generated (~5m spacing) for smooth curves
- Total distance is calculated by summing all segments

### Route Editing Flow
1. User creates route with "Use Navigation"
2. Route is calculated and displayed
3. User taps "Adjust Route Path" or enters edit mode
4. User taps on route line to add control points
5. User can drag control points to adjust route
6. Route updates in real-time
7. User can recalculate with GraphHopper or save the edited route

## Next Steps
1. Complete route drawing gesture handling
2. Integrate route following mode into navigation
3. Update reroute logic to filter by ownership
4. Add visual indicators for saved routes
5. Improve route interpolation for smoother curves
