# SmartRoad MVP Demo Script

## Quick Demo (30-60 seconds)

### Setup
1. Ensure Supabase is configured and running
2. Have demo account created: `demo@smartroad.app` / `DemoPass123!`
3. Open app on device/emulator

### Demo Flow

#### 1. Login (5 seconds)
- Open app
- Tap "Demo Mode" button OR
- Enter demo credentials and login
- **Result**: User is authenticated and sees map
	- **Note**: Demo authentication behaves like an authenticated user by default (you can comment/like/upload in demo storage). To test anonymous/limited flows, use **Continue as Guest** from the login screen.

#### 2. View Map & Hazards (10 seconds)
- Map loads with OpenStreetMap tiles
- Current location is shown (blue dot)
- Hazard markers appear on map (colored icons)
- Tap filter icon to open map filter panel
- Toggle "Live Traffic" to see real-time traffic conditions (requires TOMTOM_API_KEY)
- Traffic colors: Green (free flow), Yellow (moderate), Red (heavy), Dark red (standstill)
- Tap a hazard marker
- **Result**: Bottom sheet shows hazard details (type, description, severity, image if available)
	- **Tip**: Place and fuel detail sheets are expandable — drag the top handle or use the expand icon on desktop to view more content. Recently searched places will show a "Recently searched" badge in the expanded sheet.

#### 3. Report New Hazard (15 seconds)
- Tap "Report Hazard" floating button
- Select hazard type (e.g., "pothole")
- Select severity (e.g., "High")
- Enter description: "Large pothole on main road, causing vehicle damage"
- Tap "Add Photo" and take/select image
- Tap "Submit Report"
- **Result**: Success message, hazard appears on map immediately

#### 4. View Feed (10 seconds)
- Tap "Feed" tab in bottom navigation
- See reverse-chronological list of all hazards
- Each entry shows: type icon, description preview, severity chip, time ago, thumbnail
- Tap an entry
- **Result**: Navigates to map and opens hazard detail sheet

#### 5. Profile & Realtime (10 seconds)
- Tap "Profile" tab
- View user profile: name, email, reporter level, valid reports count
- Update name or photo (optional)
- **Realtime Test**: Open app on second device, report hazard, see it appear on first device
- **Result**: Profile shows user info, realtime updates work

#### 6. Music Control (optional, ~15 seconds)
- From Map tab, find the **music chip** (floating pill)
- If no music is playing: **tap** chip → music app picker (or opens default app if set)
- **Long-press** chip → always opens picker to choose from installed apps (Spotify, YouTube Music, etc.)
- In picker: select an app, optionally enable "Remember as default"
- In **Profile → Music Controls**: use "Default music app" → **Change** to set/switch default, **Clear** to remove
- **Result**: One-tap open of preferred music app from the map; other apps can open SmartRoad via deep links (smartroad://map, smartroad://music)

### Key Features to Highlight

✅ **Real-time Updates**: Hazards appear instantly across all devices
✅ **Offline Support**: App works offline with cached data
✅ **Location-based**: Uses GPS to show nearby hazards
✅ **Image Upload**: Photos attached to hazard reports
✅ **Clean UI**: Dark-friendly, modern design
✅ **Fast Performance**: Smooth map interactions, paginated feed

### Troubleshooting During Demo

- **Location not showing**: Check device location permissions
- **Hazards not loading**: Verify Supabase connection and RLS policies
- **Image upload fails**: Check storage bucket configuration
- **Realtime not working**: Verify Supabase Realtime is enabled

### Post-Demo Notes

- Mention scalability: Can handle thousands of hazards
- Security: Row-level security policies protect data
- Extensibility: Easy to add new hazard types or features
- Production-ready: Error handling, offline support, validation

