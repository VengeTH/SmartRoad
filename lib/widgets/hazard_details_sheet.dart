import "package:flutter/material.dart";
import "../models/hazard_model.dart";

/// * Bottom sheet showing hazard details
class HazardDetailsSheet extends StatelessWidget {
  final HazardModel hazard;

  const HazardDetailsSheet({
    super.key,
    required this.hazard,
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

  /// * Format time ago
  String _formatTimeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
      return "${difference.inDays} day${difference.inDays > 1 ? "s" : ""} ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} hour${difference.inHours > 1 ? "s" : ""} ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} minute${difference.inMinutes > 1 ? "s" : ""} ago";
    } else {
      return "Just now";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // * Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // * Hazard type and severity
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSeverityColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getHazardIcon(),
                  color: _getSeverityColor(),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hazard.type.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hazard.severity.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // * Description
          Text(
            "Description",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            hazard.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),

          const SizedBox(height: 16),

          // * Image if available
          if (hazard.imageUrl != null && hazard.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                hazard.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // * Time ago
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimeAgo(hazard.createdAt),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // * Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ),
        ],
      ),
    );
  }
}

