import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "../core/theme/app_theme.dart";
import "../models/sticker.dart";

/// * Custom marker widget for HOA gates
class HOAGateMarker extends StatelessWidget {
  final HOA hoa;
  
  const HOAGateMarker({
    super.key,
    required this.hoa,
  });
  
  /// * Get color based on access type
  /// * Red for residents_only, Green for public_shortcut
  Color _getColorForAccessType() {
    switch (hoa.accessType) {
      case HOAAccessType.residentsOnly:
        return AppTheme.errorColor; // * Strict (Residents/Guests Only)
      case HOAAccessType.publicShortcut:
        return AppTheme.successColor; // * Open (Pay-to-Pass available)
    }
  }
  
  IconData _getIconForAccessType() {
    switch (hoa.accessType) {
      case HOAAccessType.residentsOnly:
        return Icons.lock_outline;
      case HOAAccessType.publicShortcut:
        return Icons.local_offer_outlined;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final color = _getColorForAccessType();
    final icon = _getIconForAccessType();
    
    final marker = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.95),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(0.9),
          width: 2,
        ),
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Icon(
        icon,
        color: color,
        size: 18,
      ),
    );

    // * Avoid hover tooltips on web (they can cover the map while panning).
    if (kIsWeb) {
      return marker;
    }

    return Tooltip(
      message: hoa.accessType == HOAAccessType.residentsOnly
          ? "${hoa.name} · Residents/Guests Only"
          : "${hoa.name} · Pay-to-Pass",
      child: marker,
    );
  }
}

