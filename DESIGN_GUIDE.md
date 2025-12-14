# SmartRoad Design Guide

## Overview

This design guide establishes the visual identity, branding guidelines, and UI/UX standards for SmartRoad, a road safety and navigation application developed by The Heedful.

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

---

**Remember**: Safety first. Always. If any branding interferes with driver safety, remove it immediately.
