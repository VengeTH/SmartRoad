import "package:flutter/material.dart";
import "../models/hazard.dart";

/// * Custom marker widget for hazards
class HazardMarker extends StatelessWidget {
  final Hazard hazard;
  
  const HazardMarker({
    super.key,
    required this.hazard,
  });
  
  IconData _getIconForType(HazardType type) {
    switch (type) {
      case HazardType.pothole:
        return Icons.pan_tool; // * Alternative icon for pothole (pothole icon doesn't exist)
      case HazardType.flood:
        return Icons.water_drop;
      case HazardType.accident:
        return Icons.car_crash;
      case HazardType.closure:
        return Icons.block;
      case HazardType.landslide:
        return Icons.landslide;
      case HazardType.roadblock:
        return Icons.construction;
    }
  }
  
  Color _getColorForSeverity(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return Colors.green;
      case SeverityLevel.medium:
        return Colors.orange;
      case SeverityLevel.high:
        return Colors.red;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final color = _getColorForSeverity(hazard.severity);
    final icon = _getIconForType(hazard.type);
    
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

