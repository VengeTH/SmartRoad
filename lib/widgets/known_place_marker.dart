import "package:flutter/material.dart";

import "../core/theme/app_theme.dart";
import "../models/place.dart";

/// * Compact marker for known places (malls, terminals, landmarks).
/// *
/// * Designed to be visible but non-intrusive on the map.
class KnownPlaceMarker extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const KnownPlaceMarker({super.key, required this.place, required this.onTap});

  IconData _iconForCategory(String? category) {
    switch (category?.toLowerCase()) {
      case "mall":
        return Icons.storefront_outlined;
      case "terminal":
        return Icons.directions_bus_filled;
      default:
        return Icons.place_outlined;
    }
  }

  Color _colorForCategory(String? category) {
    switch (category?.toLowerCase()) {
      case "mall":
        return AppTheme.primaryColor;
      case "terminal":
        return AppTheme.infoColor;
      default:
        return AppTheme.secondaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconForCategory(place.category);
    final color = _colorForCategory(place.category);

    return Semantics(
      button: true,
      label: place.name,
      child: Tooltip(
        message: place.name,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onTap,
            radius: 22,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withOpacity(0.95),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.borderColor.withOpacity(0.85),
                  width: 1.5,
                ),
                boxShadow: AppTheme.shadowSmall,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}
