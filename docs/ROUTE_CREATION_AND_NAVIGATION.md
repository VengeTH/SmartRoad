# Route Creation and Navigation System

## Overview

This document describes the comprehensive route creation, following, and rerouting system that allows users to:
1. Create routes by drawing or using navigation
2. Follow saved routes exactly during navigation
3. Reroute with ownership-aware filtering
4. Report invalid or scam routes

## Features

### 1. Route Creation Options

#### Draw Route
- Users can manually draw a route on the map by tapping points
- Long press to finish drawing
- Route is saved as-is (follows drawn line regardless of terrain/buildings)
- Useful for finding fastest/nearest routes that may not be in routing databases

#### Use Navigation
- Traditional flow: search destination → calculate route → save
- Uses GraphHopper routing engine
- Route is calculated based on road network

### 2. Saved Route Following

When a user starts navigation with a saved route:
- The exact route geometry is displayed on the map
- Navigation follows the saved route points
- Route is visible regardless of zoom level (zoomable)
- User can choose:
  - **Strict Mode**: Must follow exact route (no rerouting)
  - **Flexible Mode**: Can reroute if blocked, but prefers saved route

### 3. Rerouting Logic

When user deviates from route (>100m threshold):

#### If Following Saved Route:
1. **Return to Saved Route**: Option to return to original saved route
2. **Use Other Saved Routes**: Show routes user owns/bought (if applicable)
3. **Calculate New Route**: Standard rerouting from current location

#### Ownership Filtering:
- **User owns/bought route**: Can reroute to it
- **User doesn't own route**: Only show free/public reroute options
- **Premium routes**: Only shown if user has purchased them

### 4. Route Reporting

Users can report routes that are:
- Invalid (route doesn't exist)
- Scam (misleading information)
- Dangerous (unsafe conditions)

Reports affect route trust score and visibility.

## Implementation Files

### Core Components

1. **`lib/widgets/create_route_dialog.dart`**
   - Dialog for choosing route creation method
   - Options: Draw Route or Use Navigation

2. **`lib/widgets/route_drawing_widget.dart`**
   - Widget for drawing routes on map
   - Handles tap/long-press interactions
   - Manages drawing state

3. **`lib/providers/saved_route_navigation_provider.dart`**
   - Manages state when following a saved route
   - Tracks if rerouting is allowed
   - Handles route following mode

4. **`lib/widgets/reroute_options_sheet.dart`**
   - Bottom sheet showing reroute options
   - Filters routes based on ownership
   - Shows return to saved route option

### Integration Points

1. **RoutesScreen** (`lib/screens/routes/routes_screen.dart`)
   - "Create Route" button shows `CreateRouteDialog`
   - Routes to MapScreen with appropriate option

2. **MapScreen** (`lib/screens/map/map_screen.dart`)
   - Handles route drawing mode
   - Manages saved route following
   - Implements rerouting with ownership filtering

## Usage Flow

### Creating a Route (Draw)

1. User taps "Create Route" → Selects "Draw Route"
2. Map enters drawing mode
3. User taps points on map to draw route
4. Long press to finish
5. Route preview shown
6. User confirms → Route saved

### Creating a Route (Navigation)

1. User taps "Create Route" → Selects "Use Navigation"
2. User searches for destination
3. Route calculated via GraphHopper
4. User starts navigation
5. During navigation, user can save route

### Following a Saved Route

1. User selects saved route from Routes screen
2. Route loaded into navigation
3. Map shows exact route geometry
4. Navigation follows saved route points
5. If user deviates:
   - Reroute options shown (filtered by ownership)
   - Option to return to saved route
   - Option to use other owned routes
   - Option to calculate new route

## Route Geometry

Routes are stored as:
- **PostGIS LINESTRING** in database
- **List<LatLng>** in Flutter
- Route follows exact geometry (not recalculated)
- Visible on map regardless of terrain/buildings
- Zoomable for detailed inspection

## Trust & Safety

- Routes can be reported as invalid/scam
- Reports affect trust score
- Low trust routes are deprioritized
- Users can verify routes before purchasing

## Future Enhancements

1. **Route Editing**: Modify saved routes
2. **Route Sharing**: Share routes via links
3. **Route Analytics**: Track route performance
4. **Smart Rerouting**: AI-powered reroute suggestions
5. **Offline Route Following**: Cache routes for offline use
