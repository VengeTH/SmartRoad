# SmartRoad Design Guide

## Overview

This design guide establishes the visual identity, branding guidelines, and UI/UX standards for SmartRoad, a road safety and navigation application developed by The Heedful.

## ⚠️ Current Status: Demo Mode Only

**Important:** As of now, SmartRoad is running in **demo mode only**. No database has been set up on the server yet, and database integration has not been implemented. All features work with local/demo data.

**Database integration will be added in the future** after the server infrastructure is fully set up. Until then, the app operates completely offline with sample data, making it perfect for testing and demos.

## Brand Identity

### Brand Elements

- **App Name**: SmartRoad
- **Company Name**: The Heedful
- **Official Motto**: "Be Heedful on the Road"

### Brand Values

- **Safety First**: All design decisions prioritize driver safety and minimal distraction
- **Professional**: Clean, modern, investor-ready appearance
- **Calm & Minimal**: Neutral colors, subtle branding, non-intrusive
- **Government-Friendly**: Appropriate for public sector partnerships

## Branding Implementation Rules

### ✅ ALLOWED Branding Locations

1. **Splash Screen**
   - Full branding display on app launch
   - Duration: 2-3 seconds maximum
   - Fade-in animation only (no distracting effects)

2. **About Screen**
   - Complete brand information
   - App description and company details
   - Accessible from Profile screen

3. **Settings / Profile Footer**
   - Small, non-intrusive text at bottom
   - Format: "SmartRoad · by The Heedful"
   - Reduced opacity for subtlety

### ❌ FORBIDDEN Branding Locations

**NO branding on:**
- Map navigation screen
- Route alerts
- Emergency / SOS screens
- Weather overlays
- Hazard notifications
- Active navigation UI

**Navigation UI must remain 100% distraction-free.**

## Color Palette

### Primary Colors

- **Primary**: `#6366F1` (Indigo) - Main brand color
- **Secondary**: `#8B5CF6` (Purple) - Accent color
- **Background**: `#0F172A` (Dark slate) - Main background
- **Surface**: `#1E293B` (Lighter slate) - Card/surface background

### Text Colors

- **Primary Text**: `#F1F5F9` - Main content
- **Secondary Text**: `#94A3B8` - Supporting content
- **Tertiary Text**: `#64748B` - Subtle text (branding, hints)

### Semantic Colors

- **Error**: `#EF4444` (Red)
- **Success**: `#10B981` (Green)
- **Warning**: `#F59E0B` (Amber)
- **Info**: `#3B82F6` (Blue)

### Branding Color Usage

- Use **Tertiary Text** color for secondary branding elements
- Apply **reduced opacity (0.7)** for footer branding
- Never use bright marketing colors for branding
- Maintain neutral, calm appearance

## Typography

### Font Family

- Use system default or Material Design fonts
- Clean, modern, readable
- No decorative or script fonts

### Font Sizes

- **App Name (Splash)**: 42px, Bold
- **Company Name**: 18px, Regular (400)
- **Motto**: 16px, Light (300), Italic
- **Footer Branding**: 14px, Regular, Reduced opacity

### Letter Spacing

- App name: 1.2
- Company name: 0.5
- Motto: 0.3
- Footer: 0.3

## Spacing System

Based on 8px grid system:

- **XS**: 4px
- **SM**: 8px
- **MD**: 16px
- **LG**: 24px
- **XL**: 32px
- **XXL**: 48px

## Animation Guidelines

### Splash Screen

- **Type**: Fade-in only
- **Duration**: 1500ms (1.5 seconds)
- **Curve**: `Curves.easeIn`
- **No other animations**: No scaling, sliding, or bouncing

### General Animations

- **Fast**: 150ms
- **Normal**: 300ms
- **Slow**: 500ms
- **Curve**: `Curves.easeInOut` (default)

## Component Guidelines

### Splash Screen

```dart
// Structure:
- Centered vertical layout
- App name (large, bold)
- Company name (medium, secondary color)
- Motto (small, italic, tertiary color)
- Fade-in animation
- 2-3 second duration
```

### About Screen

```dart
// Structure:
- App name (display size)
- Company name
- Motto (in styled container)
- Description card
- Footer branding
```

### Footer Branding

```dart
// Format:
"SmartRoad · by The Heedful"

// Styling:
- Small text size
- Tertiary color with 0.7 opacity
- Centered alignment
- Bottom padding
```

### Authentication Screens (Login / Sign up)

- **Goal**: Auth screens must look premium (2026+) while staying calm, professional, and non-distracting.
- **No page scrolling**: The auth layout must fit within **one viewport** on most devices. Avoid full-page `SingleChildScrollView` for auth screens.
- **Responsive layout**:
  - **Desktop / Wide**: Use a split layout
    - Left: story/brand panel (value proposition)
    - Right: auth card with max width ≈ 520px
  - **Mobile / Narrow**: Show only the auth card to avoid vertical overflow
    - Keep branding compact (small header row)
    - Move “extra” information into modals (e.g., demo credentials)
- **Demo credentials UX**:
  - Show demo credentials inside a **dialog/modal**, not as a permanently expanded card
  - Provide “Copy” actions for quick testing
- **Background**:
  - Use a subtle dark gradient background (no loud marketing colors)
  - Avoid noisy patterns that distract from form completion

### Map Screen HUD (Search + Controls)

- **Goal**: The map UI must feel modern and “lightweight” while keeping safety-first clarity.
- **Glass HUD**:
  - Use a subtle blurred/glass surface for the top search bar and right-side control dock
  - Keep borders thin and contrast high (avoid washed-out overlays)
- **Search behavior**:
  - When the search field is focused and empty, show **Recents**:
    - Recent searches (selected places)
    - Recent navigation destinations
  - Provide a “Clear” action for recents
  - Recents must be stored locally (works in demo mode)
- **Layout**:
  - Desktop: constrain search width (≈900px max)
  - Mobile: full-width search bar with safe paddings

### Music Controls

- **Goal**: Reduce driver distraction by allowing quick access to a preferred music app without hunting for icons while driving.
- **Map chip behavior**:
  - **When music is playing**: show the compact mini-player with basic controls.
  - **When no music is playing**: show a compact “No music playing” chip.
    - **Tap**: opens the default app (if set) or the **installed music app picker**.
    - **Long-press**: always opens the picker (so the user can switch app without going to settings).
- **Chip label when idle**: show "No music playing" or "Open {AppName}" when a default app is set.
- **Music app picker**:
  - Shows **only installed** supported apps (Spotify, YouTube Music, etc.).
  - Uses a **bottom sheet** with large touch targets.
  - Offers a “Remember as default” option (can be changed later).
- **Settings**:
  - Profile → **Music Controls** includes “Default music app” with **Change** and **Clear** actions.
- **Deep links**:
  - SmartRoad registers `smartroad://map`, `smartroad://music`, and `smartroad://music/open` so other apps can open SmartRoad (e.g. to map tab or music picker).
  - Keep deep-link behavior **non-blocking** and safety-first (no noisy popups during navigation).

### Routes Screen UX

- **Goal**: Routes must feel like a product surface, not a placeholder screen.
- **Empty states**:
  - Use a centered premium empty-state card with clear hierarchy
  - Avoid duplicate CTAs (only one “Create Route” entry point visible at a time)
- **Create Route dialog**:
  - Use a modern dialog with two option tiles (Draw Route / Use Navigation)
  - Clear descriptions and large tap targets

## Location Previews (Known Places)

SmartRoad supports **known-location previews** (e.g., malls, terminals) with community interaction.

### Map Marker Guidelines

- **Visibility**: Markers should be clear but not noisy; avoid large labels on the map.
- **Shape**: Compact circular marker (≈34px) using `surfaceColor` with a subtle border + light shadow.
- **Icons** (category-colored):
  - Mall: `storefront_outlined`
  - Terminal: `directions_bus_filled`
  - Default landmark: `place_outlined`
- **Safety**: Hide known-place markers during **active navigation** to reduce distraction.
- **Zoom behavior**:
  - Zoom < 9: hide known places
  - Zoom ≥ 9: show known places (icon-only)
  - Zoom ≥ 12: show known places with compact labels (pill style)
  - Selected place: show label even if zoom is slightly lower (helps orientation after tap)

### Place Preview Sheet

- **Layout order**:
  - Drag handle (horizontal pill-shaped indicator at top)
  - Place name + optional category chip (with recent search indicator if applicable)
  - Get Directions / Start Navigation (primary action)
  - Rating (average + count + user rating)
  - Photo carousel (approved photos only)
  - Like + Add Photo actions
  - Content guideline note (photo moderation rules)
  - Comments list + comment composer
- **Behavior**: Draggable bottom sheet with generous expandability for content access.
  - Initial: 45% of screen height (shows core info immediately)
  - Min: 24% (compact view)
  - Max: 95% (nearly full-screen for extended content)
  - Drag handle visible at top for discoverability
- **Responsiveness**:
  - Constrain max width on desktop (don't stretch full-width)
  - Drag handle shows pointer cursor on web/desktop for clarity
  - Touch-optimized sizing (48x5px handle) works on all devices
- **Tone**: Helpful, neutral, safety-first (no memes, no loud colors).

## User Location Marker (Map)

- **Style**: Google-Maps-like blue marker (white outer ring + blue inner circle).
- **Heading**: Rotate the arrow when heading is available (device/course heading).
- **Fallback**: If heading is unavailable/invalid, keep arrow unrotated.
- **Navigation**: When the **map is rotated** (navigation mode), the marker rotates **relative** to the map so it still points “forward” on screen.

## Navigation Camera (Active Navigation)

- **Default behavior**: Auto-follow the user with a zoomed-in camera (driver-focused, like common navigation apps).
- **Rotation**: Prefer rotating the **map** to match heading; if heading is missing (common on web), rotate based on the route’s direction.
- **User interaction**: If the user manually pans the map, auto-follow pauses.
- **Re-center**: Provide a dedicated re-center action that restores follow + zoom + rotation.

## Speed HUD & Speed Limits (Active Navigation)

- **Speed HUD**: Show current speed (km/h) plus a speed limit sign.
- **Overspeed warning**:
  - Trigger when speed > (limit + tolerance)
  - Use subtle haptics and throttle warnings to avoid spamming
- **Speed limit sources (best-effort)**:
  - User override (highest priority)
  - OSM `maxspeed` tag (when available)
  - Default per `highway` type (fallback, user-editable)
  - Unknown (hide warning)

### Fuel Station Detail Sheet

- **Layout**: Similar expandable bottom sheet as place preview
  - Drag handle at top for discoverability
- **Behavior**:
  - Initial: 45% of screen height (80% when expanded via toggle)
  - Min: 24%
  - Max: 95%
  - Responsive drag handle with pointer cursor on web/desktop
- **Content**: Station details, fuel prices, navigation actions, and community features

### Drag Handle Standards

All draggable bottom sheets should include a visible drag handle:
- **Size**: 48px wide × 5px tall (touch-optimized)
- **Position**: Centered at top of sheet, 4px vertical margin
- **Color**: Theme divider/border color with 80% opacity
- **Shape**: Rounded pill (2.5px border radius)
- **Interaction**:
  - Mobile: Shows "Swipe to expand" tooltip
  - Desktop: Shows "Drag to expand or collapse" tooltip with grab cursor
  - Click and drag vertically to resize the sheet
- **Desktop Enhancement**: For place sheets, an `unfold_more` icon appears next to the close button with tooltip "Drag sheet to resize"
- **Purpose**: Visual affordance that sheet can be dragged to expand/collapse

### Desktop vs Mobile Interaction Consistency

**Consistency Rules:**
- **Desktop-to-Desktop**: All desktop/laptop/web browsers must have identical interaction patterns
  - Same tooltips ("Drag to expand or collapse")
  - Same cursor indicators (grab cursor on handle)
  - Same expand icons visible
  - Click + drag gesture for resizing
- **Mobile-to-Mobile**: All mobile/tablet devices must have identical interaction patterns
  - Same tooltips ("Swipe to expand")
  - Touch-optimized drag handle sizing
  - Swipe gesture for resizing
- **Desktop vs Mobile**: Different interaction patterns are acceptable when they improve platform-specific UX
  - Desktop shows more detailed tooltips and cursor hints
  - Desktop may show additional expand icons
  - Mobile optimizes for touch gestures

## Guest Mode (No Login)

SmartRoad supports a **guest mode** where the app remains useful without requiring an account.

### Allowed (Guest)
- Browse map, search, route preview, and start navigation
- View hazards + hazard detail sheets
- View place previews (approved photos, public comments, rating average)
- Customize navigation avatar + speed HUD preferences (stored locally)

### Requires Login
- Report hazards
- Upload place photos (moderated)
- Like / comment / rate places
- Save routes

## Dynamic POIs (Google Maps-like Landmarks)

SmartRoad can show extra nearby landmarks when the user zooms in.

- **Source**: OpenStreetMap Nominatim (viewbox-bounded search)
- **Interaction**:
  - Tap opens the **Place Preview Sheet** (same UI as known places) so users can:
    - Get directions / start navigation
    - Upload moderated preview photos
    - Like / comment (community-style)
- **Zoom behavior**:
  - Zoom < 12: hide dynamic POIs
  - Zoom ≥ 12: show POIs (icon-only)
  - Zoom ≥ 15: show labels for only the most prominent POIs (limit to ~15 to prevent clutter)
- **De-duplication**:
  - Filter out POIs that match known places (name/aliases) or are very close to a known place
  - Deduplicate by name + coordinate bucket to avoid showing the same POI multiple times
- **Debounce/Rate-limit**: Always debounce map move requests (avoid spamming Nominatim).

## Hazard & HOA Markers (Map)

SmartRoad uses a consistent marker style across the map to reduce visual noise while keeping safety-critical info easy to spot.

### Hazard Marker Guidelines

- **Priority**: Hazards must remain more attention-grabbing than known places (safety-first).
- **Shape**: Compact circular marker (≈34px) using `surfaceColor` with a **severity-colored ring**.
- **Icons** (type-based):
  - Pothole: `warning_amber_rounded`
  - Flood: `water_drop_outlined`
  - Accident: `car_crash`
  - Closure: `do_not_disturb_on_outlined`
  - Landslide: `terrain`
  - Roadblock: `construction_outlined`
- **Interaction**: Tap opens hazard details. Avoid hover tooltips on desktop/web.

### Navigation Hazard Warnings (Active Navigation)

- **Goal**: Provide hazard and place awareness without distracting the driver.
- **When**: Only during active navigation.
- **UI**: Compact warning banner (“Pothole ahead • 250 m”) with severity color + close button.
- **Logic**:
  - Only show hazards that are **near the route** and **ahead** of the user.
  - Use throttled haptics (subtle) to avoid spamming.
  - Dismiss temporarily mutes that hazard so it doesn’t immediately reappear.

### HOA Gate Marker Guidelines

- **Shape**: Compact circular marker (≈34px) using `surfaceColor` with an access-colored ring.
  - Residents-only: `errorColor`
  - Pay-to-pass: `successColor`
- **Icons**:
  - Residents-only: `lock_outline`
  - Pay-to-pass: `local_offer_outlined`
- **Web UX**: Avoid hover tooltips (they cover the map while panning). Use tap/snackbar or a detail sheet instead.

## Photo Moderation & Content Safety

All user-submitted place photos must follow these rules:

- **Allowed**: Accurate photos of the place/landmark (exterior/interior), signage, entrances.
- **Forbidden**: Nudity/sexual content, violence, hate symbols, unrelated images, spam, personal documents.
- **Workflow**:
  - User uploads → photo is **Pending**
  - Admin reviews → **Approved** or **Rejected** (optional reason)
  - Only **Approved** photos are shown publicly

### Admin Review UI

- **Location**: Profile screen (Admin-only entry)
- **Actions**: Approve / Reject (with optional reason)
- **Feedback**: Short snackbars for success/error states

## Route Editing UX (Use Navigation)

- **Preview-first**: After selecting Start + End, show a route preview sheet immediately.
- **Editability**: Users can adjust the route path via control points.
- **Visual requirement**: When editing, the route line should appear **smooth/curved** (no sharp kinks).
- **Controls**:
  - Recalculate (when control points exist)
  - Clear control points
  - Save route
  - Done (exit editing)

## Safety-First Principles

1. **No Distractions During Navigation**
   - Zero branding on active navigation screens
   - No pop-ups or blocking UI
   - No full-screen ads

2. **Minimal Visual Weight**
   - Subtle, professional appearance
   - Reduced opacity for secondary elements
   - Calm color palette

3. **Context-Appropriate**
   - Branding only in non-critical screens
   - About screen for detailed information
   - Footer for subtle reinforcement

## Implementation Checklist

When adding branding:

- [ ] Is it on an allowed screen?
- [ ] Does it follow color guidelines?
- [ ] Is it non-intrusive?
- [ ] Does it maintain safety-first principle?
- [ ] Is the opacity appropriate?
- [ ] Does it use correct typography?
- [ ] Is spacing consistent?

## Examples

### ✅ Good Branding

- Splash screen with fade-in
- About screen with full information
- Footer branding with reduced opacity
- Profile screen link to About

### ❌ Bad Branding

- Branding on map during navigation
- Pop-up ads or full-screen overlays
- Bright, distracting colors
- Animated logos during navigation
- Branding in emergency screens

## Version History

- **v1.0** (2025-01-XX): Initial branding guidelines established
- **v1.1** (2026-01-XX): Added known-location previews, photo moderation, and route editing UX notes
- **v1.2** (2026-01-07): Refreshed auth screen layout (single-viewport, responsive) and navigation bar styling
- **v1.3** (2026-01-07): Added glass map HUD, map search recents, and routes UX polish (dialog + empty states)
- **v1.4** (2026-02-07): Added music app picker, default music app setting, and `smartroad://` deep links

---

**Remember**: Safety first. Always. If any branding interferes with driver safety, remove it immediately.
