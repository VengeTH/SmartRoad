import "package:flutter/material.dart";

/// * Application theme configuration
/// Heedful brand-aligned: dark graphite foundations, yellow emphasis, neutral gray support.
/// Yellow stays an accent, never a blanket fill — interface remains premium and readable.
class AppTheme {
  // * Heedful Brand Colors
  // Background: main canvas (dark graphite)
  static const Color backgroundColor = Color(0xFF0F0F0F);
  // Surface: cards and panels
  static const Color surfaceColor = Color(0xFF1A1A1A);
  // Secondary Surface: layered depth
  static const Color surfaceVariant = Color(0xFF2B2B2B);
  // Primary Gray: neutral structural support
  static const Color borderColor = Color(0xFF424242);

  // * Functional Colors
  // Primary: indigo for interactive elements (buttons, nav indicators, links)
  static const Color primaryColor = Color(0xFF6366F1);
  // Secondary: purple for secondary interactive elements
  static const Color secondaryColor = Color(0xFF8B5CF6);
  // Brand Accent: Heedful yellow — reserved for emphasis, active states, key metrics
  static const Color brandAccentColor = Color(0xFFFFC107);
  // Brand Accent Dark: deeper yellow for gradients/hover
  static const Color brandAccentDarkColor = Color(0xFFFFB300);

  // * Semantic Colors
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color successColor = Color(0xFF10B981); // Green
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color infoColor = Color(0xFF3B82F6); // Blue
  static const Color accentColor = Color(0xFFEC4899); // Pink

  // * Text Colors (Heedful spec)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFBDBDBD);
  static const Color textTertiary = Color(0xFF757575);

  // * Extended Surface Colors
  // Tertiary Surface: elevated cards, modals, dialogs
  static const Color surfaceElevated = Color(0xFF2B2B2B);
  // Overlay: glass/blur surfaces
  static const Color surfaceOverlay = Color(0x1A0F0F0F);

  // * Spacing
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  
  // * Border Radius
  static const double radiusSM = 6.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 9999.0;
  
  // * Shadows
  static const List<BoxShadow> shadowSmall = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
  
  static const List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: Color(0x33FFC107),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  // * Brand gradient colors (Heedful: yellow → deep yellow → gray)
  static const List<Color> brandGradientColors = [
    Color(0xFFFFC107),
    Color(0xFFFFB300),
    Color(0xFF6B6B6B),
  ];
  
  // * Animation Constants
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  static const Curve animationCurve = Curves.easeInOut;
  static const Curve animationCurveBounce = Curves.easeOutBack;
  
  // * Responsive Breakpoints
  static const double breakpointMobile = 600.0;
  static const double breakpointTablet = 900.0;
  static const double breakpointDesktop = 1024.0;
  static const double breakpointWideDesktop = 1440.0;

  // * Responsive Helpers
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < breakpointMobile;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= breakpointMobile && width < breakpointDesktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= breakpointDesktop;
  }

  static bool isWideDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= breakpointWideDesktop;
  }

  static double responsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) {
      return spacingMD; // 16px for mobile
    } else if (width < breakpointTablet) {
      return spacingLG; // 24px for tablet
    } else if (width < breakpointDesktop) {
      return spacingXL; // 32px for small desktop
    } else {
      return spacingXXL; // 48px for wide desktop
    }
  }

  static double responsiveButtonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) {
      return 48.0; // Compact for mobile
    } else if (width < breakpointDesktop) {
      return 52.0; // Standard for tablet
    } else {
      return 56.0; // Full size for desktop
    }
  }

  static double responsiveFontSize(BuildContext context, {required double mobile, required double desktop}) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) {
      return mobile;
    } else {
      return desktop;
    }
  }

  static double maxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointDesktop) {
      return double.infinity;
    } else if (width < breakpointWideDesktop) {
      return 900.0; // Standard desktop
    } else {
      return 1100.0; // Wide desktop
    }
  }

  /// * Max width for narrow content (forms, auth cards)
  static double maxNarrowWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointDesktop) {
      return double.infinity;
    } else {
      return 520.0;
    }
  }

  /// * Sidebar width for desktop navigation
  static double sidebarWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointWideDesktop) {
      return 72.0; // Icon-only rail
    } else {
      return 260.0; // Full sidebar with labels
    }
  }
  
  // * Hazard Type Colors
  static const Map<String, Color> hazardColors = {
    'pothole': Color(0xFFF59E0B), // Amber
    'flood': Color(0xFF3B82F6), // Blue
    'accident': Color(0xFFEF4444), // Red
    'closure': Color(0xFF8B5CF6), // Purple
    'landslide': Color(0xFFDC2626), // Dark Red
    'roadblock': Color(0xFF6B7280), // Gray
  };
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: brandAccentColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
        background: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          side: const BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(
            color: borderColor,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(
            color: borderColor,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(
            color: brandAccentColor,
            width: 2.0,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor.withOpacity(0.96),
        indicatorColor: brandAccentColor.withOpacity(0.15),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final isSelected = states.contains(MaterialState.selected);
          return TextStyle(
            color: isSelected ? textPrimary : textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0.3,
          );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          final isSelected = states.contains(MaterialState.selected);
          return IconThemeData(
            color: isSelected ? brandAccentColor : textSecondary,
            size: 24,
          );
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: brandAccentColor,
        dividerColor: borderColor,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceVariant,
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          side: const BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: brandAccentColor.withOpacity(0.20),
        side: const BorderSide(color: borderColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandAccentColor,
          foregroundColor: Color(0xFF0F0F0F), // Dark text on yellow (Heedful spec)
          elevation: 2,
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 20,
          ),
          minimumSize: const Size(120, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandAccentColor,
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 20,
          ),
          minimumSize: const Size(120, 56),
          side: BorderSide(
            color: brandAccentColor,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandAccentColor,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          minimumSize: const Size(88, 48),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary),
        displayMedium: TextStyle(color: textPrimary),
        displaySmall: TextStyle(color: textPrimary),
        headlineLarge: TextStyle(color: textPrimary),
        headlineMedium: TextStyle(color: textPrimary),
        headlineSmall: TextStyle(color: textPrimary),
        titleLarge: TextStyle(color: textPrimary),
        titleMedium: TextStyle(color: textPrimary),
        titleSmall: TextStyle(color: textPrimary),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textTertiary),
      ),
    );
  }
}

