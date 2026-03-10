import "package:flutter/material.dart";

import "../core/theme/app_theme.dart";

/// * Google-Maps-like labeled marker (icon + text pill).
/// *
/// * Used for both:
/// * - built-in known places (major landmarks)
/// * - dynamic POIs (loaded on zoom-in)
class MapPoiMarker extends StatelessWidget {
  // * Layout constants shared with map anchoring logic.
  // * Marker anchors are configured in MapScreen using Marker.computePixelAlignment().
  static const double markerHeight = 40;
  static const double iconBoxSize = 20;
  static const double iconSize = 13;
  static const double pillPaddingHorizontal = 8;
  static const double pillPaddingVertical = 6;

  // * Icon-only marker padding. Keep left padding equal to [pillPaddingHorizontal]
  // * so the anchor point is consistent between labeled and icon-only markers.
  static const double iconOnlyPadding = 8;

  // * Pixel distance from the left edge of the marker box to the icon center.
  // * (left padding + half icon box size)
  static const double anchorLeftPx = pillPaddingHorizontal + (iconBoxSize / 2);

  final IconData icon;
  final Color accentColor;
  final String label;
  final VoidCallback onTap;

  /// * If false, renders an icon-only marker (less visual noise).
  final bool showLabel;

  const MapPoiMarker({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.label,
    required this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final safeLabel = label.trim();
    final shouldShowLabel = showLabel && safeLabel.isNotEmpty;

    final marker = Container(
      padding:
          shouldShowLabel
              ? const EdgeInsets.symmetric(
                horizontal: pillPaddingHorizontal,
                vertical: pillPaddingVertical,
              )
              : const EdgeInsets.all(iconOnlyPadding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.borderColor.withOpacity(0.9),
          width: 1.0,
        ),
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: iconSize),
          ),
          if (shouldShowLabel) ...[
            const SizedBox(width: 6),
            ConstrainedBox(
              // * Keep the label compact to avoid covering roads/POIs.
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                safeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      label: safeLabel,
      child: Tooltip(
        message: safeLabel,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.95, end: 1.0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Align(
                // * Let the pill shrink to its content, while keeping the marker box
                // * stable for consistent map anchoring.
                alignment: Alignment.centerLeft,
                child: marker,
              ),
            ),
          ),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: value, child: child),
            );
          },
        ),
      ),
    );
  }
}
