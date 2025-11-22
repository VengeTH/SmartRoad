import "package:flutter/material.dart";
import "../models/hazard_model.dart";

/// * Custom marker widget for hazards on the map
class HazardMarker extends StatelessWidget {
  final HazardModel hazard;
  final VoidCallback onTap;

  const HazardMarker({
    super.key,
    required this.hazard,
    required this.onTap,
  });

  /// * Get icon for hazard type
  IconData _getHazardIcon() {
    switch (hazard.type) {
      case "pothole":
        return Icons.construction;
      case "flood":
        return Icons.water_drop;
      case "accident":
        return Icons.car_crash;
      case "closure":
        return Icons.block;
      case "roadblock":
        return Icons.construction;
      case "landslide":
        return Icons.landslide;
      default:
        return Icons.warning;
    }
  }

  /// * Get color for severity
  Color _getSeverityColor() {
    switch (hazard.severity.toLowerCase()) {
      case "high":
        return Colors.red;
      case "medium":
        return Colors.orange;
      case "low":
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getSeverityColor(),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          _getHazardIcon(),
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

