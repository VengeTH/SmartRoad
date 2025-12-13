import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../models/hazard.dart";
import "../core/theme/app_theme.dart";

/// * Bottom sheet showing hazard details
class HazardDetailSheet extends StatelessWidget {
  final Hazard hazard;
  final VoidCallback onClose;
  
  const HazardDetailSheet({
    super.key,
    required this.hazard,
    required this.onClose,
  });
  
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return "${difference.inDays}d ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours}h ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes}m ago";
    } else {
      return "Just now";
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // * Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // * Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hazard.type.value.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hazard.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Chip(
                      label: Text(hazard.severity.value),
                      backgroundColor: hazard.severity == SeverityLevel.high
                          ? Colors.red.withOpacity(0.2)
                          : hazard.severity == SeverityLevel.medium
                              ? Colors.orange.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                    ),
                    const SizedBox(width: 8),
                    if (hazard.userName != null)
                      Text(
                        "by ${hazard.userName}",
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTimeAgo(hazard.createdAt),
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
                if (hazard.imageUrl != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      hazard.imageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 200,
                          child: Center(
                            child: Icon(Icons.broken_image),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

