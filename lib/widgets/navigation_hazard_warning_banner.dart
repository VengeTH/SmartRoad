import "package:flutter/material.dart";

import "../core/theme/app_theme.dart";
import "../models/hazard.dart";

/// * Waze-style hazard warning banner shown during active navigation.
/// *
/// * Keeps the UI compact and non-intrusive while still providing timely warnings
/// * for hazards ahead (e.g., potholes, floods).
class NavigationHazardWarningBanner extends StatelessWidget {
  final Hazard hazard;
  final double distanceMeters;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const NavigationHazardWarningBanner({
    super.key,
    required this.hazard,
    required this.distanceMeters,
    required this.onDismiss,
    this.onTap,
  });

  IconData _iconForType(HazardType type) {
    switch (type) {
      case HazardType.pothole:
        return Icons.warning_amber_rounded;
      case HazardType.flood:
        return Icons.water_drop_outlined;
      case HazardType.accident:
        return Icons.car_crash;
      case HazardType.closure:
        return Icons.do_not_disturb_on_outlined;
      case HazardType.landslide:
        return Icons.terrain;
      case HazardType.roadblock:
        return Icons.construction_outlined;
    }
  }

  String _labelForType(HazardType type) {
    switch (type) {
      case HazardType.pothole:
        return "Pothole";
      case HazardType.flood:
        return "Flood";
      case HazardType.accident:
        return "Accident";
      case HazardType.closure:
        return "Road Closure";
      case HazardType.landslide:
        return "Landslide";
      case HazardType.roadblock:
        return "Roadblock";
    }
  }

  Color _colorForSeverity(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return AppTheme.successColor;
      case SeverityLevel.medium:
        return AppTheme.warningColor;
      case SeverityLevel.high:
        return AppTheme.errorColor;
    }
  }

  String _formatDistance(double meters) {
    if (meters < 0) {
      return "—";
    }
    if (meters < 1000) {
      return "${meters.round()} m";
    }
    return "${(meters / 1000).toStringAsFixed(1)} km";
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _colorForSeverity(hazard.severity);
    final icon = _iconForType(hazard.type);
    final title = "${_labelForType(hazard.type)} ahead";
    final distance = _formatDistance(distanceMeters);

    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: severityColor.withOpacity(0.5),
          width: 1.2,
        ),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: severityColor, size: 18),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  distance,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
            color: AppTheme.textSecondary,
            tooltip: "Dismiss",
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: content,
      ),
    );
  }
}

