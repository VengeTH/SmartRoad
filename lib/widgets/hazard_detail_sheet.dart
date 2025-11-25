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
  
  Color _getSeverityColor(SeverityLevel severity) {
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
    final theme = Theme.of(context);
    final severityColor = _getSeverityColor(hazard.severity);
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // * Handle bar
          Container(
            margin: const EdgeInsets.only(top: AppTheme.spacingMD),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // * Content
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // * Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingSM),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: severityColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hazard.type.value.toUpperCase(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimeAgo(hazard.createdAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: onClose,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMD),
                // * Description
                Text(
                  hazard.description,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                // * Metadata
                Wrap(
                  spacing: AppTheme.spacingSM,
                  runSpacing: AppTheme.spacingSM,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMD,
                        vertical: AppTheme.spacingSM,
                      ),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.priority_high_rounded,
                            size: 16,
                            color: severityColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hazard.severity.value,
                            style: TextStyle(
                              color: severityColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hazard.userName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMD,
                          vertical: AppTheme.spacingSM,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hazard.userName!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                // * Image
                if (hazard.imageUrl != null) ...[
                  const SizedBox(height: AppTheme.spacingLG),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    child: Image.network(
                      hazard.imageUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: AppTheme.surfaceVariant,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: AppTheme.textTertiary,
                                ),
                                const SizedBox(height: AppTheme.spacingSM),
                                Text(
                                  "Failed to load image",
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingMD),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

