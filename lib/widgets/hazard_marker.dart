import "package:flutter/material.dart";
import "../models/hazard.dart";
import "../core/theme/app_theme.dart";

/// * Custom marker widget for hazards
class HazardMarker extends StatelessWidget {
  final Hazard hazard;

  const HazardMarker({super.key, required this.hazard});

  IconData _getIconForType(HazardType type) {
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
      case HazardType.fallenTree:
        return Icons.park_outlined;
      case HazardType.traffic:
        return Icons.traffic_outlined;
      case HazardType.debris:
        return Icons.cleaning_services_outlined;
    }
  }

  Color _getColorForSeverity(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return AppTheme.successColor;
      case SeverityLevel.medium:
        return AppTheme.warningColor;
      case SeverityLevel.high:
        return AppTheme.errorColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _getColorForSeverity(hazard.severity);
    final icon = _getIconForType(hazard.type);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.95),
        shape: BoxShape.circle,
        border: Border.all(color: severityColor.withOpacity(0.9), width: 2),
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Icon(icon, color: severityColor, size: 18),
    );
  }
}
