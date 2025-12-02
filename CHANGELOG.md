# SmartRoad - Changelog

This document tracks all version updates, feature additions, and significant changes to the SmartRoad application.

---

## Version 2.3.1 - Branding Update

**Release Date:** 2025  
**Focus:** Consistent Branding Across All Platforms

### Changes

- **App Name Standardization**: Updated all user-facing display names to "SmartRoad" (proper capitalization)
  - Web app title and manifest
  - Android app label
  - iOS display name and bundle name
  - Windows window title and product information
  - Linux window title
  - All platform-specific metadata

### Technical Notes

- Package names and bundle identifiers remain lowercase (`smartroad`, `com.example.smartroad`) per platform conventions
- Email addresses remain lowercase (`demo@smartroad.app`) per email format standards
- Binary/executable names remain lowercase for file system compatibility
- No breaking changes to package structure or identifiers

---

## Version 2.3.0 - Physical Sticker Upload & HOA Access Types

**Release Date:** 2025  
**Focus:** Enhanced Sticker Management & Access Control

### New Features

#### Physical Sticker Upload with AI Verification
- **My Stickers Screen**: New screen for managing all user stickers
  - View all stickers (physical and digital)
  - Upload physical stickers with photo verification
  - AI-powered verification using Google Gemini
  - Access from Profile screen → "My Stickers" card

- **AI Sticker Verification**:
  - Integration with Google Gemini 2.5 Flash model
  - Automatic verification of uploaded sticker photos
  - Validates if image contains a valid HOA sticker
  - Rejects blurry or invalid images
  - Free tier API usage

- **Physical Sticker Upload Flow**:
  - Select HOA from dropdown
  - Optional sticker number input
  - Photo upload (camera or gallery)
  - AI verification with loading state
  - Automatic save to database upon verification
  - Photo stored in Supabase Storage

- **Gate Pass Screen Updates**:
  - Different UI for physical vs digital stickers
  - Physical stickers: "Physical Sticker Verified - Present Vehicle for Inspection" card
  - No QR code generation for physical stickers
  - Displays uploaded sticker photo
  - Shows AI verification badge

#### HOA Access Types (Strict vs. Open)
- **Access Type System**:
  - `public_shortcut`: Outsiders can buy a pass (Pay-to-Pass available)
  - `residents_only`: Outsiders CANNOT buy a pass (Strict residents/guests only)

- **Visual Indicators on Map**:
  - **Red Gate Icon**: Strict HOA (Residents/Guests Only)
  - **Green Gate Icon**: Open HOA (Pay-to-Pass Available)
  - HOA gate markers displayed on map with color coding
  - Tap marker to see HOA name and access type

- **Routing Logic Updates**:
  - Hard Block: `residents_only` HOAs block routing if user has no sticker (Cost = Infinity)
  - Soft Block: `public_shortcut` HOAs allow routing if user agrees to buy pass
  - Routing service now receives HOA access type information
  - Backend can implement permission-based road weighting

### Database Changes

- **New Columns in `user_stickers` table**:
  - `is_physical_sticker` (boolean): True for uploads, False for in-app QR purchases
  - `verified_by_ai` (boolean): True if Gemini confirms the image looks like a sticker
  - `sticker_photo_url` (text): Path to the uploaded sticker image

- **New Enum and Column in `hoas` table**:
  - `hoa_access_type` enum: `'public_shortcut'` or `'residents_only'`
  - `access_type` column with default `'public_shortcut'`

- **RLS Policy Updates**:
  - Users can insert their own physical stickers (after AI verification)
  - Users can update their own physical stickers

### Technical Implementation

- **New Dependencies**:
  - `google_generative_ai` package removed (using direct HTTP API calls)
  - Using Dio for Gemini API communication

- **New Services**:
  - `StickerVerifierService`: AI-powered sticker image verification
  - Web-compatible image handling (Image.memory for web, Image.file for mobile)

- **New Screens**:
  - `ManageStickersScreen`: Complete sticker management interface

- **New Widgets**:
  - `HOAGateMarker`: Custom marker widget for HOA gates with color coding

- **Environment Configuration**:
  - Added `GEMINI_API_KEY` environment variable support

### Security Features

- AI verification prevents fake sticker uploads
- Physical stickers require photo verification
- RLS policies ensure users can only manage their own stickers
- Photo validation before database insertion

### UI/UX Improvements

- Web compatibility for image uploads
- Loading states during AI verification
- Clear error messages for rejected photos
- Visual distinction between physical and digital stickers
- Color-coded HOA gate markers for quick identification

---

## Version 2.2.1 - Bug Fixes & UI Improvements

**Release Date:** 2025  
**Focus:** UI Polish & Bug Fixes

### Bug Fixes

- **Profile Screen Error Fix**: Fixed CircleAvatar assertion error when profile photo is null
  - Conditional `onBackgroundImageError` callback (only when backgroundImage exists)
  - Improved error handling in profile provider
  - Added fallback demo user creation if initialization fails

- **Navigation Bar Fixes**:
  - Removed duplicate bottom toolbar from Map screen (was conflicting with MainNavigationScreen)
  - Fixed bottom overflow issues by optimizing navigation bar height and spacing
  - Reduced navigation bar height from 70px to 65px with optimized padding
  - Used `IntrinsicHeight` for better layout fitting

- **Search Bar UI Fix**:
  - Fixed border radius not being applied correctly
  - Wrapped search bar in `ClipRRect` to ensure smooth rounded corners
  - All TextField borders properly set to `InputBorder.none` to match container

- **Report Hazard Screen**:
  - Fixed capitalization of hazard types (Pothole, Flood, Accident, etc.)
  - Improved visual consistency

### Technical Improvements

- Enhanced debug logging in profile provider and SupabaseService
- Improved demo mode initialization checks
- Better error handling with graceful fallbacks
- Removed unused `_ToolbarButton` widget

---

## Version 2.2.0 - Sticker & Gate Security Module

**Release Date:** 2025  
**Focus:** Revenue Generation - Digital Sticker & Gate Management System

### New Features

#### Sticker & Gate Security Module
- **Digital Sticker Wallet**: Users can hold multiple HOA stickers (e.g., "BF Resort", "BF Homes")
  - Sticker model with expiry dates and validation
  - Support for multiple active stickers per user
  - Sticker status tracking (active, expired, days remaining)

- **Gate Pass Screen**: QR code generation for gate access
  - Dynamic QR code containing UserID + StickerID + Timestamp
  - Auto-refreshes every 4 minutes to prevent screenshot reuse
  - Security: QR codes expire after 5 minutes
  - Sticker selector dropdown for users with multiple stickers
  - Displays sticker details (issued date, expiry, days remaining)
  - Empty states for users with no stickers or expired stickers

- **Guard Scanner Mode**: Camera-based QR code validation
  - Real-time QR code scanning using mobile_scanner
  - Visual scanning overlay with corner indicators
  - Success/error feedback with full-screen overlays
  - Haptic feedback for scan results
  - Flash toggle for low-light conditions
  - Validates QR codes against database in real-time

- **Permission-Based Routing Preparation**
  - RoutingService now accepts `userStickerIds` parameter
  - Map screen passes active sticker IDs to routing service
  - Prepared for future GraphHopper integration
  - Will enable dynamic road weighting based on sticker permissions
  - Future: "If user has Sticker A, weight Road A as 0.0 (Passable)"

### Database Changes

- **New Tables**:
  - `hoas` - Homeowners Associations/Gates table
  - `user_stickers` - User sticker/permit records
  
- **Schema Updates**:
  - Added indexes for performance (user_id, hoa_id, expires_at, is_active)
  - Row Level Security (RLS) policies for data protection
  - Unique constraint for active stickers per user+HOA

### Technical Implementation

- **New Dependencies**:
  - `qr_flutter: ^4.1.0` - QR code generation
  - `mobile_scanner: ^5.2.3` - QR code scanning

- **New Services**:
  - `StickerService` - Handles all sticker and HOA database operations
  - Demo mode support for testing without database

- **New Providers**:
  - `stickerServiceProvider` - Service instance provider
  - `userStickersProvider` - All user stickers
  - `activeUserStickersProvider` - Only valid/active stickers
  - `userStickerIdsProvider` - List of active sticker IDs (for routing)
  - `hoasProvider` - All HOAs list

- **New Screens**:
  - `GatePassScreen` - User-facing QR code display
  - `GuardScannerScreen` - Guard-facing QR code scanner

- **UI Integration**:
  - Added "Gate Pass" card in Profile screen
  - Navigation to Gate Pass screen from profile

### Security Features

- QR codes include timestamp to prevent screenshot reuse
- QR codes expire after 5 minutes
- Auto-refresh every 4 minutes (before expiry)
- Database validation on every scan
- RLS policies ensure data privacy

### Architecture Notes

- **Service-Oriented Architecture**: Security module is cleanly separated from navigation core
- **Future-Ready**: Routing service prepared for permission-based routing
- **Modular Design**: Models, services, providers, and screens are independently maintainable
- **Demo Mode**: Full demo support for testing without database setup

---

## Version 2.1.0 - Routing & Map Enhancements

**Release Date:** 2025

### New Features

#### Login Screen Redesign
- **Two-Panel Layout**: Split-screen design with story panel on left and login card on right (desktop) or stacked (mobile)
- **Less AI-Generated Look**: Removed excessive gradients and animations, replaced with clean, professional design
- **Story Panel**: Features The Heedful branding, value propositions, and key statistics
- **Simplified Animations**: Subtle fade and slide transitions instead of complex animations

#### Map Screen Enhancements
- **Bottom Toolbar**: Added floating toolbar at bottom with quick access to:
  - Navigate (opens search/directions)
  - Report (hazard reporting)
  - Layers (map layer options)
  - Settings (app settings)
- **Improved Top Bar**: Enhanced search bar with better visual hierarchy
- **Location Accuracy**: Default location set to STI College Las Piñas (14.4244°N, 120.9883°E)
- **High-Accuracy Location**: Using `bestForNavigation` accuracy mode for precise location tracking

#### Routing Integration
- **Backend-Powered Routing**: Integrated with SmartRoad backend API for route calculation
- **MVP Routing**: Supports car and motorcycle modes with toll avoidance
- **Simplified UI**: Cleaner navigation options with clear mode selection

### Design System Additions
- **Spacing Constants**: Added spacing system (XS, SM, MD, LG, XL, XXL)
- **Border Radius Constants**: Added radius system (SM, MD, LG, XL, Full)
- **Shadow System**: Added shadow variants (Small, Medium, Large, Glow)
- **Info Color**: Added info color for informational messages
- **Border Color**: Added border color for consistent borders

---

## Version 2.0.0 - Premium Edition

**Release Date:** 2025

### Major Updates

#### Premium UI Enhancements
- Gradient buttons with glow effects
- Sophisticated screen entrance animations
- Haptic feedback integration
- Keyboard navigation support (Enter key)
- Enhanced transitions and micro-interactions

#### The Heedful Branding
- Brand badge on authentication screens
- Consistent brand presence throughout
- Premium aesthetic aligned with startup identity

#### UX Improvements
- Auto-focus on form fields
- Clear buttons in input fields
- Improved error handling with icons
- Floating snackbars with better styling

#### Enhanced Components
- Premium login/signup screens
- Animated logo and brand elements
- Gradient FABs
- Enhanced card designs

---

## Version 1.0.0 - Initial Release

**Release Date:** 2025

### Core Features

- **Authentication**: Email/password authentication via Supabase Auth
- **Interactive Map**: OpenStreetMap integration with real-time hazard markers
- **Hazard Reporting**: Report road hazards with type, severity, description, and photos
- **Feed View**: Reverse-chronological list of all reported hazards
- **User Profiles**: View and update profile information
- **Realtime Updates**: Live updates when hazards are added/updated/deleted
- **Offline Support**: Cache hazards locally for offline viewing
- **Local Notifications**: Get notified when hazards are created within 2km

### Initial Design System
- Dark-first theme
- Complete component library
- Comprehensive documentation

---

## Future Roadmap

### Planned Features

1. **Permission-Based Routing** (Phase 2)
   - GraphHopper integration with sticker-based road weighting
   - Dynamic route calculation based on user permissions
   - "If user has Sticker A, weight Road A as 0.0 (Passable)"

2. **HOA Admin Panel**
   - Allow HOAs to create and manage stickers
   - Sticker sales and payment integration
   - Analytics and reporting

3. **Weather Radar Integration**
   - Real-time weather data overlay on map
   - Weather-based routing suggestions

4. **AI Incident Prediction**
   - Machine learning for hazard prediction
   - Proactive route adjustments

5. **Ride-Hailing Integration**
   - Integration with ride-hailing services
   - Driver-passenger matching

---

## Migration Notes

### Upgrading to Version 2.3.1

1. **No Action Required**: This is a branding update only
   - App will display "SmartRoad" on all platforms
   - No database changes
   - No code changes required
   - Rebuild app to see updated branding

### Upgrading to Version 2.3.0

1. **Database Migration**:
   ```sql
   -- Run the updated supabase_schema.sql in Supabase SQL Editor
   -- This adds:
   -- 1. hoa_access_type enum
   -- 2. access_type column to hoas table
   -- 3. is_physical_sticker, verified_by_ai, sticker_photo_url columns to user_stickers table
   -- 4. New RLS policies for physical sticker uploads
   ```

2. **Environment Configuration**:
   ```bash
   # Add GEMINI_API_KEY to your environment
   --dart-define=GEMINI_API_KEY=your_gemini_api_key_here
   ```

3. **Dependencies**:
   ```bash
   flutter pub get
   ```

4. **Storage Bucket**:
   - Ensure Supabase storage bucket allows uploads for sticker images
   - Or create a new `stickers` folder in your existing bucket

### Upgrading to Version 2.2.1

1. **Dependencies**:
   ```bash
   flutter pub get
   ```

2. **No Database Changes Required**: This is a bug fix release

3. **UI Changes**:
   - Bottom toolbar removed from Map screen (now uses main navigation bar only)
   - Navigation bar height optimized to prevent overflow

### Upgrading to Version 2.2.0

1. **Database Migration**:
   ```sql
   -- Run the updated supabase_schema.sql in Supabase SQL Editor
   -- This adds hoas and user_stickers tables
   ```

2. **Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Permissions**:
   - Ensure camera permissions are granted for Guard Scanner
   - Update AndroidManifest.xml and Info.plist if needed

4. **Backend Update** (Optional):
   - Update Node.js backend to accept `user_sticker_ids` in `/route` endpoint
   - Currently prepared but not actively used

---

## Breaking Changes

### Version 2.3.1
- None (branding update only)

### Version 2.3.0
- None (additive changes only)
- Database migration required for new columns

### Version 2.2.1
- None (bug fixes only)

### Version 2.2.0
- None (additive changes only)

### Version 2.1.0
- None (additive changes only)

### Version 2.0.0
- None (additive changes only)

---

## Known Issues

- QR code scanning requires camera permissions (handled gracefully)
- Demo mode stickers are static (for testing only)
- Permission-based routing logic not yet implemented (structure prepared)
- AI verification requires GEMINI_API_KEY to be configured
- Physical sticker upload requires Supabase Storage bucket setup

---

## Contributors

- The Heedful Development Team

---

*This changelog is maintained alongside the project and updated with each release.*

