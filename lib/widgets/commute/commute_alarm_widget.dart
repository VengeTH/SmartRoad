import "package:flutter/material.dart";

import "../../core/theme/app_theme.dart";
import "../../models/commute_state.dart";

/// * Commute Alarm Widget
/// * Displays a large, glanceable distance/ETA countdown
class CommuteAlarmWidget extends StatelessWidget {
  final String distance;
  final String eta;
  final CommuteStatus status;
  final bool isApproaching;

  const CommuteAlarmWidget({
    super.key,
    required this.distance,
    required this.eta,
    required this.status,
    this.isApproaching = false,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = _getRingColor();
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXL * 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            ringColor.withOpacity(0.15),
            ringColor.withOpacity(0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceColor,
          border: Border.all(
            color: ringColor.withOpacity(0.5),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: ringColor.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ringColor.withOpacity(0.1),
                AppTheme.surfaceColor,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // * Status icon
              Icon(
                _getStatusIcon(),
                color: ringColor,
                size: 32,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              
              // * Large distance text
              Text(
                distance,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              
              // * "to go" label
              Text(
                "to go",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingMD),
              
              // * ETA chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: ringColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: ringColor,
                      size: 14,
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      eta,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ringColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRingColor() {
    switch (status) {
      case CommuteStatus.idle:
        return AppTheme.textSecondary;
      case CommuteStatus.active:
        return AppTheme.successColor;
      case CommuteStatus.approaching:
        return AppTheme.warningColor;
      case CommuteStatus.arrived:
        return AppTheme.successColor;
      case CommuteStatus.passed:
        return AppTheme.errorColor;
      case CommuteStatus.danger:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case CommuteStatus.idle:
        return Icons.notifications_off;
      case CommuteStatus.active:
        return Icons.notifications;
      case CommuteStatus.approaching:
        return Icons.notifications_active;
      case CommuteStatus.arrived:
        return Icons.check_circle;
      case CommuteStatus.passed:
        return Icons.warning;
      case CommuteStatus.danger:
        return Icons.shield;
    }
  }
}

