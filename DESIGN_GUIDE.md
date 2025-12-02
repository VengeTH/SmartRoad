# SmartRoad Design Guide
## The Heedful - First Project Design System

**Version:** 2.2.0  
**Last Updated:** 2025  
**Purpose:** Comprehensive design system documentation for SmartRoad application  
**Brand:** The Heedful - Premium Startup Experience

> **Note**: This guide focuses exclusively on design patterns, visual elements, and UI/UX guidelines. For version updates, feature changes, and technical implementation details, see [CHANGELOG.md](../CHANGELOG.md).

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Branding - The Heedful](#branding---the-heedful)
3. [Color System](#color-system)
4. [Typography](#typography)
5. [Spacing System](#spacing-system)
6. [Border Radius](#border-radius)
7. [Shadows & Elevation](#shadows--elevation)
8. [Animation & Motion](#animation--motion)
9. [Premium Interactions](#premium-interactions)
10. [Components](#components)
11. [Layout Patterns](#layout-patterns)
12. [Accessibility](#accessibility)
13. [Implementation Guidelines](#implementation-guidelines)

---

## Design Philosophy

### Core Principles

1. **Dark-First Approach**: The design system is built for dark mode as the primary experience, ensuring optimal visibility and reduced eye strain.

2. **Premium & Eye-Catching**: Every element is designed to be beautiful, appealing, aesthetic, and premium - representing The Heedful's commitment to excellence.

3. **Modern & Professional**: Clean, contemporary design that reflects a startup's innovative spirit while maintaining professionalism.

4. **User-Centric**: Every design decision prioritizes user experience, clarity, and ease of use.

5. **Consistency**: Unified visual language across all screens and components.

6. **Accessibility**: High contrast ratios, readable typography, and clear visual hierarchy.

7. **Delightful Interactions**: Smooth animations, haptic feedback, and micro-interactions create a premium feel.

### Design Goals

- **Premium Aesthetic**: Eye-catching, beautiful, and instantly recognizable as a high-quality product
- **Brand Recognition**: The Heedful branding is subtly integrated throughout
- **Clarity**: Information should be immediately understandable
- **Efficiency**: Users should accomplish tasks with minimal friction
- **Delight**: Smooth animations, haptic feedback, and thoughtful details enhance the experience
- **Trust**: Professional appearance builds user confidence
- **First Impression**: The app should instantly showcase The Heedful's quality and attention to detail

---

## Branding - The Heedful

### Brand Identity

**The Heedful** is prominently featured throughout the application to establish brand recognition and showcase the startup's commitment to quality.

### Branding Elements

1. **Brand Badge**
   - Appears on authentication screens (login/signup)
   - Styled as a pill-shaped badge with primary color
   - Text: "THE HEEDFUL" in uppercase, bold, with letter spacing
   - Position: Centered at top of authentication screens

2. **Brand Colors**
   - Primary gradient: Indigo to Purple (`#6366F1` → `#8B5CF6`)
   - Represents innovation, trust, and premium quality

3. **Brand Voice**
   - Professional yet approachable
   - Premium without being pretentious
   - Innovative and forward-thinking

### Branding Guidelines

- **Consistency**: Always use the same styling for brand badge
- **Subtlety**: Branding should enhance, not distract
- **Premium Feel**: Branding elements should feel high-quality
- **First Impression**: Brand should be visible immediately on app launch

---

## Premium Interactions

### Haptic Feedback

Haptic feedback provides tactile responses to user actions, creating a premium, responsive feel.

**Usage:**
```dart
// Light feedback - Success actions
HapticFeedback.lightImpact();

// Medium feedback - Primary actions
HapticFeedback.mediumImpact();

// Heavy feedback - Errors, important actions
HapticFeedback.heavyImpact();
```

**When to Use:**
- **Light**: Successful actions (login, navigation)
- **Medium**: Primary button presses, form submissions
- **Heavy**: Errors, warnings, critical actions

### Keyboard Navigation

All forms support keyboard navigation for premium desktop/web experience.

**Features:**
- **Enter Key**: Submits forms automatically
- **Tab Navigation**: Moves between fields logically
- **Auto-focus**: First field focused on screen load
- **Clear Buttons**: Input fields have clear buttons when text is present

**Implementation:**
```dart
TextFormField(
  textInputAction: TextInputAction.next, // Moves to next field
  onFieldSubmitted: (_) {
    nextFocusNode.requestFocus(); // Or submit if last field
  },
)
```

### Smooth Transitions

All screen transitions use smooth animations for premium feel.

**Transition Types:**
- **Fade**: Used for authentication → main app
- **Slide**: Used for bottom sheets, modals
- **Scale**: Used for FABs, buttons

**Duration:** 300ms for standard transitions, 1200ms for complex animations

---

## Color System

### Primary Colors

The primary color palette is built around a modern indigo-purple gradient system.

```dart
// Primary Colors
primaryColor: #6366F1 (Indigo)
primaryLight: #818CF8 (Lighter Indigo)
primaryDark: #4F46E5 (Darker Indigo)

// Secondary Colors
secondaryColor: #8B5CF6 (Purple)
accentColor: #06B6D4 (Cyan)
```

**Usage:**
- Primary color: Main actions, active states, important highlights
- Secondary color: Supporting elements, alternative actions
- Accent color: Special highlights, notifications, emphasis

### Background Colors

```dart
backgroundColor: #0A0E27 (Deep dark blue)
surfaceColor: #1A1F3A (Elevated surface)
surfaceVariant: #252B4A (Variant surface)
surfaceElevated: #2D3558 (Higher elevation)
```

**Usage:**
- `backgroundColor`: Main app background
- `surfaceColor`: Cards, bottom navigation, app bars
- `surfaceVariant`: Input fields, secondary cards
- `surfaceElevated`: Modals, floating elements

### Semantic Colors

```dart
// Success
successColor: #10B981 (Green)
successLight: #6EE7B7 (Light Green)

// Warning
warningColor: #F59E0B (Amber)
warningLight: #FCD34D (Light Amber)

// Error
errorColor: #EF4444 (Red)
errorLight: #FCA5A5 (Light Red)

// Info
infoColor: #3B82F6 (Blue)
infoLight: #93C5FD (Light Blue)
```

**Usage:**
- Success: Completed actions, positive feedback
- Warning: Cautionary messages, medium severity
- Error: Critical issues, high severity, failures
- Info: Informational messages, low severity

### Text Colors

```dart
textPrimary: #F8FAFC (Almost white) - Primary text
textSecondary: #CBD5E1 (Light gray) - Secondary text
textTertiary: #94A3B8 (Medium gray) - Tertiary text
textDisabled: #64748B (Disabled gray) - Disabled text
```

**Contrast Ratios:**
- Primary text on background: 15.8:1 (WCAG AAA)
- Secondary text on background: 10.2:1 (WCAG AA)
- Tertiary text on background: 7.1:1 (WCAG AA)

### Border & Divider Colors

```dart
borderColor: #334155 (Subtle border)
dividerColor: #1E293B (Divider)
```

### Hazard Type Colors

```dart
hazardColors: {
  'pothole': #F59E0B (Amber)
  'flood': #3B82F6 (Blue)
  'accident': #EF4444 (Red)
  'closure': #8B5CF6 (Purple)
  'landslide': #DC2626 (Dark Red)
  'roadblock': #6B7280 (Gray)
}
```

### Color Usage Guidelines

1. **Never use pure black (#000000)** - Use `backgroundColor` instead
2. **Never use pure white (#FFFFFF)** - Use `textPrimary` for text
3. **Maintain contrast ratios** - Always test accessibility
4. **Use semantic colors consistently** - Don't mix error/warning/success
5. **Apply opacity thoughtfully** - Use `withOpacity()` for overlays

---

## Typography

### Font Family

The app uses the system default font stack (San Francisco on iOS, Roboto on Android).

### Type Scale

```dart
displayLarge: 57px / 400 weight / -0.25 letter-spacing
displayMedium: 45px / 400 weight / 0 letter-spacing
displaySmall: 36px / 400 weight / 0 letter-spacing

headlineLarge: 32px / 600 weight / -0.5 letter-spacing
headlineMedium: 28px / 600 weight / -0.5 letter-spacing
headlineSmall: 24px / 600 weight / 0 letter-spacing

titleLarge: 22px / 600 weight / 0 letter-spacing
titleMedium: 16px / 600 weight / 0.15 letter-spacing
titleSmall: 14px / 600 weight / 0.1 letter-spacing

bodyLarge: 16px / 400 weight / 0.5 letter-spacing
bodyMedium: 14px / 400 weight / 0.25 letter-spacing
bodySmall: 12px / 400 weight / 0.4 letter-spacing

labelLarge: 14px / 600 weight / 0.1 letter-spacing
labelMedium: 12px / 600 weight / 0.5 letter-spacing
labelSmall: 11px / 600 weight / 0.5 letter-spacing
```

### Typography Usage

| Element | Style | Use Case |
|---------|-------|----------|
| Screen Titles | `headlineMedium` | Main screen headers |
| Section Headers | `titleLarge` | Section titles |
| Card Titles | `titleMedium` | Card headers |
| Body Text | `bodyLarge` | Primary content |
| Secondary Text | `bodyMedium` | Descriptions, metadata |
| Captions | `bodySmall` | Timestamps, labels |
| Buttons | `labelLarge` | Button text |
| Chips/Badges | `labelSmall` | Small labels |

### Typography Guidelines

1. **Hierarchy**: Use size and weight to establish clear hierarchy
2. **Line Height**: Default line height is 1.5x font size
3. **Letter Spacing**: Negative for large text, positive for small text
4. **Readability**: Minimum 14px for body text
5. **Truncation**: Use ellipsis for overflow, max 2 lines for descriptions

---

## Spacing System

### 8px Grid System

All spacing values follow an 8px grid for consistency.

```dart
spacingXS: 4px   // Tight spacing
spacingSM: 8px   // Small spacing
spacingMD: 16px  // Medium spacing (default)
spacingLG: 24px  // Large spacing
spacingXL: 32px  // Extra large spacing
spacingXXL: 48px // Extra extra large spacing
```

### Spacing Usage

| Context | Spacing | Example |
|---------|---------|---------|
| Tight elements | `spacingXS` | Icon + text in chips |
| Related elements | `spacingSM` | Form field labels |
| Standard spacing | `spacingMD` | Card padding, form fields |
| Section spacing | `spacingLG` | Between sections |
| Screen padding | `spacingXL` | Screen edges |
| Major sections | `spacingXXL` | Between major UI blocks |

### Padding Guidelines

- **Cards**: `16px` (spacingMD) internal padding
- **Screens**: `24px-32px` (spacingLG-XL) edge padding
- **Buttons**: `16px-24px` (spacingMD-LG) vertical padding
- **Input Fields**: `16px` (spacingMD) internal padding

---

## Border Radius

### Radius System

```dart
radiusSM: 8px   // Small elements (chips, badges)
radiusMD: 12px  // Medium elements (buttons, inputs)
radiusLG: 16px  // Large elements (cards)
radiusXL: 24px  // Extra large (modals, sheets)
radiusFull: 9999px // Fully rounded (avatars, pills)
```

### Radius Usage

| Element | Radius | Example |
|---------|--------|---------|
| Buttons | `radiusMD` | Primary buttons |
| Input Fields | `radiusMD` | Text inputs |
| Cards | `radiusLG` | Content cards |
| Bottom Sheets | `radiusXL` | Modal sheets |
| Avatars | `radiusFull` | Profile pictures |
| Chips | `radiusFull` | Filter chips |

---

## Shadows & Elevation

### Shadow System

```dart
shadowSmall: {
  color: black @ 10% opacity
  blurRadius: 4px
  offset: (0, 2)
}

shadowMedium: {
  color: black @ 15% opacity
  blurRadius: 8px
  offset: (0, 4)
}

shadowLarge: {
  color: black @ 20% opacity
  blurRadius: 16px
  offset: (0, 8)
}

shadowGlow: {
  color: primaryColor @ 30% opacity
  blurRadius: 20px
  spreadRadius: 2px
}
```

### Elevation Usage

| Element | Shadow | Use Case |
|---------|--------|----------|
| Cards | `shadowSmall` | Standard cards |
| Floating buttons | `shadowMedium` | FABs, elevated buttons |
| Modals | `shadowLarge` | Dialogs, bottom sheets |
| Active states | `shadowGlow` | Focused inputs, active buttons |

### Elevation Guidelines

1. **Subtle elevation**: Use shadows sparingly
2. **Consistent depth**: Similar elements use same elevation
3. **No pure black shadows**: Always use opacity
4. **Glow effects**: Only for active/focused states

---

## Animation & Motion

### Duration System

```dart
animationFast: 150ms   // Micro-interactions
animationNormal: 300ms // Standard transitions
animationSlow: 500ms   // Complex animations
animationComplex: 1200ms // Screen entrance animations
```

### Animation Curves

```dart
animationCurve: Curves.easeInOutCubic      // Standard transitions
animationCurveBounce: Curves.easeOutBack   // Playful interactions
```

### Premium Animation Patterns

#### Screen Entrance Animations

Authentication screens use sophisticated entrance animations:

```dart
// Fade + Slide combination
FadeTransition(
  opacity: fadeAnimation,
  child: SlideTransition(
    position: slideAnimation,
    child: content,
  ),
)
```

**Timing:**
- Fade: 0-600ms (60% of duration)
- Slide: 200-1200ms (full duration)
- Creates layered, premium feel

#### Logo Animations

Logos and key visual elements use scale animations:

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.0, end: 1.0),
  duration: Duration(milliseconds: 800),
  curve: Curves.easeOutBack,
  builder: (context, value, child) {
    return Transform.scale(scale: value, child: child);
  },
)
```

### Animation Usage

| Interaction | Duration | Curve | Example |
|------------|----------|-------|---------|
| Button press | `animationFast` | `easeInOutCubic` | Tap feedback |
| Screen transitions | `animationNormal` | `easeInOutCubic` | Navigation |
| Modal appearance | `animationNormal` | Slide from bottom | Bottom sheets |
| Screen entrance | `animationComplex` | Fade + Slide | Login screen |
| Logo/Icon entrance | 800ms | `easeOutBack` | Brand elements |
| Loading states | `animationNormal` | `easeInOutCubic` | Progress indicators |

### Animation Guidelines

1. **Purposeful motion**: Every animation should have a purpose
2. **Performance**: Keep animations under 1200ms for complex, 300ms for simple
3. **Consistency**: Use standard durations and curves
4. **Accessibility**: Respect `prefers-reduced-motion`
5. **Feedback**: Provide immediate visual feedback for interactions
6. **Premium Feel**: Layered animations (fade + slide) create depth
7. **Brand Elements**: Logos and key visuals should have memorable entrances

---

## Components

### Buttons

#### Premium Gradient Button (Primary)

Primary buttons use gradients for a premium, eye-catching appearance:

```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [primaryColor, secondaryColor],
    ),
    borderRadius: BorderRadius.circular(radiusMD),
    boxShadow: shadowGlow,
  ),
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: spacingLG,
        vertical: spacingMD,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMD),
      ),
    ),
    child: Text("Button Text"),
  ),
)
```

**Features:**
- Gradient from primary to secondary color
- Glow shadow effect
- Transparent background to show gradient
- Premium, eye-catching appearance

**Usage**: Primary actions, form submissions, important CTAs

#### Outlined Button (Secondary)

```dart
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: textPrimary,
    side: BorderSide(color: borderColor, width: 1.5),
    padding: EdgeInsets.symmetric(
      horizontal: spacingLG,
      vertical: spacingMD,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMD),
    ),
  ),
  child: Text("Button Text"),
)
```

**Usage**: Secondary actions, alternative options

#### Text Button (Tertiary)

```dart
TextButton(
  style: TextButton.styleFrom(
    foregroundColor: primaryColor,
    padding: EdgeInsets.symmetric(
      horizontal: spacingMD,
      vertical: spacingSM,
    ),
  ),
  child: Text("Button Text"),
)
```

**Usage**: Tertiary actions, links, less important actions

### Input Fields

Premium input fields with enhanced UX:

```dart
TextFormField(
  textInputAction: TextInputAction.next, // Keyboard navigation
  decoration: InputDecoration(
    labelText: "Label",
    prefixIcon: Icon(Icons.icon_name),
    suffixIcon: text.isNotEmpty
        ? IconButton(
            icon: Icon(Icons.clear),
            onPressed: () => clearText(),
          )
        : null,
    filled: true,
    fillColor: surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMD),
      borderSide: BorderSide(color: borderColor, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMD),
      borderSide: BorderSide(color: primaryColor, width: 2),
    ),
  ),
  onFieldSubmitted: (_) {
    nextFocusNode.requestFocus(); // Or submit if last field
  },
)
```

**Features:**
- **Clear Button**: Appears when text is entered
- **Keyboard Navigation**: Tab/Enter moves between fields
- **Auto-focus**: First field focused on load
- **Enter to Submit**: Last field submits form on Enter

**States:**
- **Default**: Gray border, filled background
- **Focused**: Primary color border, 2px width
- **Error**: Red border, error message with icon
- **Disabled**: Reduced opacity, no interaction

### Cards

```dart
Card(
  margin: EdgeInsets.only(bottom: spacingMD),
  child: Padding(
    padding: EdgeInsets.all(spacingMD),
    child: Column(
      children: [
        // Card content
      ],
    ),
  ),
)
```

**Usage**: Content containers, list items, information display

### Chips

```dart
FilterChip(
  label: Text("Label"),
  selected: isSelected,
  onSelected: (selected) {},
  selectedColor: primaryColor.withOpacity(0.2),
  checkmarkColor: primaryColor,
)
```

**Usage**: Filters, tags, selections

### Bottom Navigation

- **Background**: `surfaceColor`
- **Selected**: `primaryColor`
- **Unselected**: `textTertiary`
- **Type**: Fixed (always visible)
- **Elevation**: Medium shadow

### Floating Action Button

- **Background**: `primaryColor`
- **Shape**: Rounded rectangle (`radiusMD`)
- **Elevation**: Medium shadow
- **Animation**: Scale on appear

---

## Layout Patterns

### Screen Structure

```
┌─────────────────────────┐
│      App Bar            │
├─────────────────────────┤
│                         │
│      Content Area       │
│      (padding: XL)       │
│                         │
│                         │
├─────────────────────────┤
│   Bottom Navigation     │
└─────────────────────────┘
```

### Card Layout

```
┌─────────────────────────┐
│  [Icon]  Title          │
│          Description    │
│          Metadata       │
│          [Image]        │
└─────────────────────────┘
```

### Form Layout

```
┌─────────────────────────┐
│  Section Title          │
│  [Input Field]          │
│  [Input Field]          │
│                         │
│  [Primary Button]       │
└─────────────────────────┘
```

### Empty States

- **Icon**: Large (64px), tertiary color
- **Title**: `titleMedium`, secondary text color
- **Description**: `bodyMedium`, tertiary text color
- **Action**: Primary button (optional)

---

## Accessibility

### Color Contrast

- **Text on background**: Minimum 4.5:1 (WCAG AA)
- **Large text**: Minimum 3:1 (WCAG AA)
- **Interactive elements**: Minimum 3:1 (WCAG AA)

### Touch Targets

- **Minimum size**: 44x44 points (iOS) / 48x48 dp (Android)
- **Spacing**: Minimum 8px between touch targets

### Typography

- **Minimum font size**: 12px for body text
- **Line height**: 1.5x font size minimum
- **Letter spacing**: Adjusted for readability

### Screen Reader Support

- **Semantic labels**: All interactive elements
- **Descriptive text**: Clear, concise labels
- **State announcements**: Loading, error, success states

---

## Implementation Guidelines

### Theme Usage

Always use theme values from `AppTheme`:

```dart
import "../../core/theme/app_theme.dart";

// ✅ Good
Container(
  color: AppTheme.surfaceColor,
  padding: EdgeInsets.all(AppTheme.spacingMD),
)

// ❌ Bad
Container(
  color: Color(0xFF1A1F3A),
  padding: EdgeInsets.all(16),
)
```

### Component Consistency

1. **Reuse existing components** before creating new ones
2. **Follow established patterns** for similar functionality
3. **Maintain spacing consistency** using the spacing system
4. **Use semantic colors** for states and feedback

### Responsive Design

- **Breakpoints**: Design for mobile-first (320px+)
- **Flexible layouts**: Use `Expanded`, `Flexible`, `Wrap`
- **Text scaling**: Support system font scaling
- **Touch targets**: Ensure adequate size on all devices

### Performance

1. **Optimize images**: Compress, use appropriate sizes
2. **Lazy loading**: Load content as needed
3. **Animation performance**: Use `AnimatedContainer`, `AnimatedOpacity`
4. **Avoid overdraw**: Minimize nested containers

### Code Organization

```
lib/
├── core/
│   └── theme/
│       └── app_theme.dart    # Theme definitions
├── widgets/
│   └── [component].dart       # Reusable components
└── screens/
    └── [screen].dart          # Screen implementations
```

### Best Practices

1. **Consistent naming**: Use descriptive, consistent names
2. **Comment complex logic**: Explain non-obvious decisions
3. **Extract reusable widgets**: Don't repeat code
4. **Test on multiple devices**: Ensure consistency
5. **Follow Material Design 3**: Use Material 3 components

---

## Design Tokens Reference

### Quick Reference

```dart
// Colors
AppTheme.primaryColor
AppTheme.backgroundColor
AppTheme.textPrimary

// Spacing
AppTheme.spacingXS
AppTheme.spacingMD
AppTheme.spacingXL

// Radius
AppTheme.radiusMD
AppTheme.radiusLG
AppTheme.radiusFull

// Shadows
AppTheme.shadowSmall
AppTheme.shadowMedium
AppTheme.shadowLarge

// Animations
AppTheme.animationFast
AppTheme.animationNormal
AppTheme.animationCurve
```

---

## Version History

> **Note**: For detailed version updates and feature changes, see [CHANGELOG.md](../CHANGELOG.md)

### Design System Evolution

- **v2.2.0**: Added design patterns for Gate Security module (QR codes, scanner overlays, result feedback)
- **v2.0.0**: Premium edition with gradient buttons, enhanced animations, haptic feedback, keyboard navigation
- **v1.0.0**: Initial design system with dark-first theme and complete component library

---

## Resources

- **Material Design 3**: https://m3.material.io/
- **Flutter Design**: https://flutter.dev/docs/development/ui/widgets
- **WCAG Guidelines**: https://www.w3.org/WAI/WCAG21/quickref/

---

## Questions & Support

For design system questions or updates, contact the design team or refer to this guide.

**Remember**: Consistency is key. When in doubt, follow the patterns established in this guide.

---

*This design guide is a living document and will be updated as the design system evolves.*

---

## Design Patterns for Gate Security Module

### QR Code Display
- **Layout**: Large, centered QR code on white background for optimal scanning
- **Size**: 280x280px QR code with padding
- **Container**: White background with rounded corners (radiusLG)
- **Information Hierarchy**: HOA name (titleLarge) → "Gate Pass" (bodyMedium) → QR Code → Expiry info

### Sticker Cards
- **Layout**: Clean card layout showing HOA name, expiry, and status
- **Spacing**: Consistent padding (spacingMD) with proper hierarchy
- **Status Indicators**: Color-coded days remaining (warning for <30 days, success for >30 days)
- **Typography**: TitleMedium for HOA name, bodyMedium for details

### Scanner Overlay
- **Dark Overlay**: Black background with 50% opacity
- **Scanning Frame**: 280x280px frame with primary color border (3px)
- **Corner Indicators**: 40x40px corner brackets for visual guidance
- **Instructions**: Centered text below frame with clear guidance

### Result Feedback
- **Success Overlay**: Full-screen overlay with green border, check icon, and sticker details
- **Error Overlay**: Full-screen overlay with red border, error icon, and error message
- **Animation**: Smooth fade-in with haptic feedback
- **Auto-dismiss**: Overlays automatically dismiss after 2-3 seconds

