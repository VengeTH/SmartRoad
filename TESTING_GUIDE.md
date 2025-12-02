# SmartRoad - Testing Guide

This guide explains how to access and test the newly added features in SmartRoad, including UI/UX improvements and responsive design.

---

## 🚀 Quick Start

### Prerequisites

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Database Setup** (Optional - Demo Mode Available):
   - If you have Supabase configured, run the updated `supabase_schema.sql` in your Supabase SQL Editor
   - If not, the app will automatically use **Demo Mode** with sample data

3. **Camera Permissions** (For Guard Scanner):
   - Android: Add to `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.CAMERA" />
     ```
   - iOS: Add to `ios/Runner/Info.plist`:
     ```xml
     <key>NSCameraUsageDescription</key>
     <string>This app needs camera access to scan QR codes</string>
     ```

---

## 📍 How to Access New Features

### 1. Gate Pass Screen (User View)

**Location**: Profile Screen → Gate Pass Card

**Access Methods**:
- **Method 1**: Bottom Navigation → **Profile** tab → Gate Pass card (Recommended)
- **Method 2**: Map Screen → Floating Action Button → **Report** (for hazard reporting)

**Steps**:
1. Launch the app and log in (or use demo account)
2. Tap **Profile** tab in bottom navigation (Map | Feed | Profile)
3. Scroll down to find the **"Gate Pass"** card
4. Tap the card to open the Gate Pass screen

**Note**: The bottom toolbar on the Map screen was removed to prevent duplication with the main navigation bar.

**What You'll See**:
- QR code for gate access (if you have active stickers)
- Sticker selector dropdown (if you have multiple stickers)
- Sticker details (issued date, expiry, days remaining)
- Auto-refreshing QR code (every 4 minutes)

**Demo Mode**:
- In demo mode, you'll see 2 sample stickers:
  - "BF Resort" (expires in ~335 days)
  - "BF Homes" (expires in ~350 days)

---

### 2. Guard Scanner Screen (Guard View)

**Location**: Profile Screen → Guard Scanner Card

**Access Methods**:
- **Method 1**: Bottom Navigation → **Profile** tab → Guard Scanner card
- **Method 2**: Map Screen → Bottom Toolbar → **Settings** button → Guard Scanner card

**Steps**:
1. **Option A**: Tap **Profile** tab in bottom navigation
   **Option B**: From Map screen, tap **Settings** button in bottom toolbar
2. Scroll down to find the **"Guard Scanner"** card (below Gate Pass)
3. Tap the card to open the Guard Scanner
4. Grant camera permission when prompted

**What You'll See**:
- Camera view with scanning overlay
- Scanning frame (280x280px) with corner indicators
- Flash toggle button in app bar
- Instructions below the frame

**How to Test**:
1. Open Gate Pass screen on another device (or use a QR code generator)
2. Display the QR code
3. Point the Guard Scanner camera at the QR code
4. You'll see:
   - **Success**: Green overlay with "Access Granted" and sticker details
   - **Error**: Red overlay with "Access Denied" and error message

**Testing Scenarios**:
- ✅ **Valid QR Code**: Scan a fresh QR code from Gate Pass screen → Should show success
- ❌ **Expired QR Code**: Wait 5+ minutes after generating → Should show error
- ❌ **Invalid QR Code**: Scan any random QR code → Should show error
- ❌ **Screenshot**: Take screenshot of QR code and scan later → Should show error (expired)

---

### 3. My Stickers Screen (Physical Sticker Upload)

**Location**: Profile Screen → My Stickers Card

**Access Methods**:
- **Method 1**: Bottom Navigation → **Profile** tab → My Stickers card

**Steps**:
1. Launch the app and log in (or use demo account)
2. Tap **Profile** tab in bottom navigation
3. Scroll down to find the **"My Stickers"** card (below Gate Pass)
4. Tap the card to open the Manage Stickers screen

**What You'll See**:
- List of all your stickers (physical and digital)
- "I have a physical sticker" button
- Sticker cards showing:
  - HOA name
  - Physical/Digital badge
  - Active/Expired status
  - Issued and expiry dates
  - Days remaining
  - Sticker photo (for physical stickers)

**Uploading Physical Sticker**:
1. Tap "I have a physical sticker" button
2. Select HOA from dropdown
3. (Optional) Enter sticker number
4. Take photo or choose from gallery
5. Tap "Submit"
6. Wait for AI verification ("Verifying with AI...")
7. If approved: Sticker saved automatically
8. If rejected: Error message shown

**Testing Scenarios**:
- ✅ **Valid Sticker Photo**: Upload clear photo of actual sticker → Should verify and save
- ❌ **Blurry Photo**: Upload blurry image → Should reject with error message
- ❌ **Non-Sticker Image**: Upload random photo → Should reject
- ✅ **Web Compatibility**: Test on web browser → Should work with image bytes

**Note**: Requires GEMINI_API_KEY to be configured for AI verification.

---

### 4. HOA Gate Markers on Map

**Location**: Map Screen

**Access Methods**:
- **Method 1**: Bottom Navigation → **Map** tab

**Steps**:
1. Launch the app and navigate to Map screen
2. Look for gate icons on the map (colored circles with home icon)

**What You'll See**:
- **Red Gate Icons**: Strict HOAs (Residents/Guests Only)
- **Green Gate Icons**: Open HOAs (Pay-to-Pass Available)
- Gate markers appear at HOA locations (latitude/longitude)

**Testing Scenarios**:
- ✅ **Gate Visibility**: Verify gates appear on map with correct colors
- ✅ **Tap Gate**: Tap on gate marker → Should show snackbar with HOA name and access type
- ✅ **Color Coding**: Verify red for residents_only, green for public_shortcut
- ✅ **Tooltip**: Hover/tap shows tooltip with HOA information

**Demo Mode**:
- In demo mode, you'll see 2 gate markers:
  - BF Resort (Green - public_shortcut)
  - BF Homes (Red - residents_only)

---

## 🧪 Testing Checklist

### Gate Pass Features

- [ ] **Access Gate Pass Screen**
  - Navigate: Profile → Gate Pass Card
  - Verify: Screen loads without errors

- [ ] **QR Code Display**
  - Verify: QR code is visible and scannable
  - Verify: QR code is on white background
  - Verify: QR code size is appropriate (280x280px)

- [ ] **Sticker Selector** (if multiple stickers)
  - Verify: Dropdown shows all active stickers
  - Verify: Selecting different sticker updates QR code
  - Verify: QR code refreshes with new sticker

- [ ] **Auto-Refresh**
  - Verify: QR code refreshes every 4 minutes
  - Verify: Timestamp updates on refresh
  - Verify: Last refresh time is displayed

- [ ] **Sticker Details**
  - Verify: Issued date is displayed
  - Verify: Expiry date is displayed
  - Verify: Days remaining is calculated correctly
  - Verify: Warning color for <30 days remaining

- [ ] **Empty States**
  - Test: User with no stickers → Shows "No Stickers Available"
  - Test: User with only expired stickers → Shows "No Active Stickers"

### Guard Scanner Features

- [ ] **Camera Access**
  - Verify: Camera permission is requested
  - Verify: Camera view displays correctly
  - Verify: Flash toggle works

- [ ] **Scanning Overlay**
  - Verify: Dark overlay with scanning frame
  - Verify: Corner indicators are visible
  - Verify: Instructions are displayed

- [ ] **QR Code Scanning**
  - Test: Scan valid QR code → Success overlay appears
  - Test: Scan expired QR code → Error overlay appears
  - Test: Scan invalid QR code → Error overlay appears
  - Verify: Haptic feedback on scan

- [ ] **Success Overlay**
  - Verify: Green border and check icon
  - Verify: "Access Granted" message
  - Verify: HOA name is displayed
  - Verify: Expiry date is shown
  - Verify: Auto-dismisses after 3 seconds

- [ ] **Error Overlay**
  - Verify: Red border and error icon
  - Verify: "Access Denied" message
  - Verify: Error message is descriptive
  - Verify: Auto-dismisses after 2 seconds

- [ ] **Resume Scanning**
  - Verify: After success/error, scanning resumes automatically
  - Verify: Can scan multiple QR codes in sequence

### My Stickers Features

- [ ] **Access My Stickers Screen**
  - Navigate: Profile → My Stickers Card
  - Verify: Screen loads without errors

- [ ] **Sticker List Display**
  - Verify: All stickers (physical and digital) are listed
  - Verify: Physical stickers show "Physical" badge
  - Verify: Active/Expired status is correct
  - Verify: Sticker photos display for physical stickers

- [ ] **Physical Sticker Upload**
  - Verify: "I have a physical sticker" button opens dialog
  - Verify: HOA dropdown shows available HOAs
  - Verify: Photo can be taken from camera
  - Verify: Photo can be chosen from gallery
  - Verify: Photo preview displays correctly

- [ ] **AI Verification**
  - Test: Upload valid sticker photo → Should verify successfully
  - Test: Upload blurry photo → Should reject with error
  - Test: Upload non-sticker image → Should reject
  - Verify: Loading state shows "Verifying with AI..."
  - Verify: Success message appears after verification

- [ ] **Web Compatibility**
  - Test: Upload photo on web browser → Should work
  - Verify: Image displays correctly on web
  - Verify: Upload process works on web

### HOA Gate Markers

- [ ] **Gate Marker Display**
  - Verify: Gate markers appear on map
  - Verify: Red markers for residents_only HOAs
  - Verify: Green markers for public_shortcut HOAs
  - Verify: Markers at correct locations

- [ ] **Gate Marker Interaction**
  - Verify: Tap on marker shows snackbar
  - Verify: Snackbar shows HOA name
  - Verify: Snackbar shows access type
  - Verify: Tooltip displays on hover/tap

- [ ] **Color Coding**
  - Verify: Red = Residents/Guests Only
  - Verify: Green = Pay-to-Pass Available

### Gate Pass - Physical Stickers

- [ ] **Physical Sticker Display**
  - Verify: Physical stickers show different UI (no QR code)
  - Verify: "Physical Sticker Verified" card appears
  - Verify: "Present Vehicle for Inspection" message
  - Verify: Sticker photo displays if available
  - Verify: AI verification badge shows

- [ ] **Digital vs Physical**
  - Verify: Digital stickers show QR code
  - Verify: Physical stickers show verification card
  - Verify: Sticker selector works for both types

---

## 🔧 Demo Mode Testing

The app includes **Demo Mode** that works without database setup:

### Demo Stickers

When in demo mode, you'll automatically have:
- **BF Resort** sticker (expires in ~335 days) - Digital sticker
- **BF Homes** sticker (expires in ~350 days) - Digital sticker

### Demo HOAs

When in demo mode, you'll see:
- **BF Resort** - Green gate (public_shortcut - Pay-to-Pass available)
- **BF Homes** - Red gate (residents_only - Strict residents only)

### Demo Mode Features

- ✅ Gate Pass screen works with demo stickers
- ✅ QR codes can be generated and scanned
- ✅ Guard Scanner validates demo QR codes
- ✅ HOA gate markers display on map
- ✅ My Stickers screen shows demo stickers
- ⚠️ QR codes expire after 5 minutes (security feature)
- ⚠️ Demo stickers are static (won't update from database)
- ⚠️ Physical sticker upload requires GEMINI_API_KEY (even in demo mode)

### Enabling Demo Mode

Demo mode is **automatic** if:
- Supabase is not configured (no `.env` file)
- Supabase initialization fails

To manually enable:
```dart
SupabaseService().enableDemoMode();
```

---

## 🗄️ Database Testing (With Supabase)

### Setup Steps

1. **Run Database Migration**:
   ```sql
   -- Copy and paste supabase_schema.sql into Supabase SQL Editor
   -- Execute the script
   ```

2. **Create Sample Data** (Optional):
   ```sql
   -- Insert sample HOAs
   INSERT INTO public.hoas (name, description, latitude, longitude)
   VALUES 
     ('BF Resort', 'BF Resort Village', 14.4244, 120.9883),
     ('BF Homes', 'BF Homes Parañaque', 14.5000, 121.0000);
   
   -- Insert sample sticker (replace USER_ID with actual user ID)
   INSERT INTO public.user_stickers (user_id, hoa_id, issued_at, expires_at)
   VALUES 
     ('USER_ID', 'HOA_ID', NOW(), NOW() + INTERVAL '1 year');
   ```

3. **Test with Real Data**:
   - Create stickers through admin panel (future feature)
   - Or insert directly via SQL

---

## 🐛 Troubleshooting

### My Stickers Issues

**Problem**: "Photo rejected. Please take a clear photo of your sticker"
- **Solution**: 
  - Ensure photo is clear and well-lit
  - Make sure the sticker is fully visible in the photo
  - Try taking photo in better lighting
  - Ensure photo shows actual HOA sticker, not random image

**Problem**: AI verification fails or times out
- **Solution**:
  - Check if GEMINI_API_KEY is configured
  - Verify internet connection
  - Check API key is valid and has quota remaining

**Problem**: Photo upload fails on web
- **Solution**: 
  - This is expected - web uses different image handling
  - Ensure image is selected properly
  - Check browser console for errors

**Problem**: Sticker photo not displaying
- **Solution**:
  - Check Supabase Storage bucket is configured
  - Verify storage permissions
  - Check photo URL in database

### HOA Gate Markers Issues

**Problem**: Gate markers not appearing on map
- **Solution**:
  - Check if HOAs have valid latitude/longitude
  - Verify HOAs are active (is_active = true)
  - Check map bounds - gates might be outside visible area
  - Verify demo mode has HOAs configured

**Problem**: Wrong color for gate marker
- **Solution**:
  - Check HOA access_type in database
  - Verify enum values are correct ('public_shortcut' or 'residents_only')
  - Check HOA model parsing in code

### Profile Screen Issues

**Problem**: Profile screen shows "Something went wrong" error
- **Solution**: 
  - Ensure demo mode is enabled (check console for "Demo mode enabled")
  - Tap "Retry" button to refresh profile
  - If issue persists, restart the app completely (not just hot reload)

**Problem**: Profile picture shows error icon
- **Solution**: This is expected in demo mode (no photo URL). The default person icon will display.

### Gate Pass Issues

**Problem**: "No Stickers Available" even in demo mode
- **Solution**: Check if demo mode is enabled. Restart app.

**Problem**: QR code not refreshing
- **Solution**: Check console for errors. Verify timer is running.

**Problem**: QR code not scannable
- **Solution**: Ensure QR code is on white background. Check QR code size.

### Guard Scanner Issues

**Problem**: Camera not opening
- **Solution**: 
  - Check camera permissions in device settings
  - Verify camera permissions in AndroidManifest.xml / Info.plist
  - Restart app after granting permissions

**Problem**: QR code not scanning
- **Solution**:
  - Ensure good lighting
  - Hold device steady
  - Check QR code is in focus
  - Try enabling flash

**Problem**: "Invalid QR code format" error
- **Solution**: Ensure QR code is from Gate Pass screen, not a random QR code

**Problem**: "Invalid or expired gate pass" for valid QR
- **Solution**: 
  - Check if QR code is older than 5 minutes
  - Verify sticker is active and not expired
  - Check database connection (if not in demo mode)

---

## 📱 Testing on Different Devices

### Physical Device (Recommended)

- **Best for**: Guard Scanner (camera testing)
- **Requirements**: Camera access, good lighting
- **Note**: QR codes can be tested by displaying on another device

### Emulator/Simulator

- **Limitations**: 
  - Camera may not work on emulator
  - Guard Scanner requires physical device
- **Workaround**: Test Gate Pass screen on emulator, Guard Scanner on physical device

### Web Browser

- **Limitations**:
  - Camera access may be restricted
  - Guard Scanner may not work
- **Workaround**: Test Gate Pass screen on web, Guard Scanner on mobile

---

## 🎯 Quick Test Scenarios

### Scenario 1: Happy Path
1. Open Gate Pass screen
2. Generate QR code
3. Open Guard Scanner on another device
4. Scan QR code immediately
5. ✅ Should show "Access Granted"

### Scenario 2: Expired QR Code
1. Generate QR code in Gate Pass
2. Wait 6 minutes (longer than 5-minute expiry)
3. Scan with Guard Scanner
4. ❌ Should show "Access Denied - Invalid or expired gate pass"

### Scenario 3: Multiple Stickers
1. Ensure user has multiple active stickers (or use demo mode)
2. Open Gate Pass screen
3. Select different sticker from dropdown
4. Verify QR code updates
5. Scan new QR code
6. ✅ Should validate with selected sticker

### Scenario 4: No Stickers
1. Create test user with no stickers (or clear demo stickers)
2. Open Gate Pass screen
3. ✅ Should show "No Stickers Available" message

### Scenario 5: Physical Sticker Upload
1. Open My Stickers screen
2. Tap "I have a physical sticker"
3. Select HOA from dropdown
4. Take photo of sticker
5. Submit for verification
6. ✅ Should verify and save sticker
7. Verify sticker appears in list
8. Open Gate Pass screen
9. ✅ Should show physical sticker UI (no QR code)

### Scenario 6: HOA Gate Markers
1. Open Map screen
2. Look for gate markers
3. ✅ Should see colored gate icons
4. Tap on green gate → Should show "Pay-to-Pass Available"
5. Tap on red gate → Should show "Residents/Guests Only"

---

## 📝 Notes

- **QR Code Security**: QR codes expire after 5 minutes to prevent screenshot reuse
- **Auto-Refresh**: QR codes refresh every 4 minutes (before expiry)
- **Demo Mode**: Full functionality available without database
- **Camera Permissions**: Required for Guard Scanner and physical sticker upload
- **Database**: Optional - app works in demo mode without Supabase
- **AI Verification**: Requires GEMINI_API_KEY for physical sticker verification
- **HOA Access Types**: Red gates = Strict (residents_only), Green gates = Open (public_shortcut)
- **Physical Stickers**: No QR code generated, shows verification card instead
- **Web Compatibility**: Physical sticker upload works on web with image bytes

---

## 🔗 Related Documentation

- [CHANGELOG.md](./CHANGELOG.md) - Version updates and feature changes
- [DESIGN_GUIDE.md](./DESIGN_GUIDE.md) - Design patterns and UI guidelines
- [README.md](./README.md) - Project setup and overview

---

*Last Updated: 2025*

