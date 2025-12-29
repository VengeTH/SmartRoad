/// * Distance Indicator Widgets
/// * UI components for displaying navigation distance indicators
import "package:flutter/material.dart";
import "../core/theme/app_theme.dart";
import "../services/route_distance_tracker.dart";

/// * Compact distance indicator (for navigation overlay)
class CompactDistanceIndicator extends StatelessWidget {
  final double distanceMeters;
  final String label;
  final IconData icon;
  final Color? color;
  
  const CompactDistanceIndicator({
    super.key,
    required this.distanceMeters,
    required this.label,
    required this.icon,
    this.color,
  });
  
  /// * Format distance for display
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.round()} m";
    } else {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSM,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.primaryColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: (color ?? AppTheme.primaryColor).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? AppTheme.primaryColor,
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            "$label: ${_formatDistance(distanceMeters)}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color ?? AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// * Distance indicators panel (for navigation screen)
class DistanceIndicatorsPanel extends StatelessWidget {
  final DistanceIndicators indicators;
  final bool compact;
  
  const DistanceIndicatorsPanel({
    super.key,
    required this.indicators,
    this.compact = false,
  });
  
  /// * Format distance for display
  String _formatDistance(double? meters) {
    if (meters == null) return "—";
    if (meters < 1000) {
      return "${meters.round()} m";
    } else {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!indicators.hasAny) {
      return const SizedBox.shrink();
    }
    
    final items = <Widget>[];
    
    // * Destination distance (always show if available)
    if (indicators.distanceToDestination != null) {
      items.add(_buildIndicatorItem(
        context,
        icon: Icons.place,
        label: "Destination",
        distance: indicators.distanceToDestination!,
        color: AppTheme.primaryColor,
      ));
    }
    
    // * Next turn
    if (indicators.distanceToNextTurn != null) {
      items.add(_buildIndicatorItem(
        context,
        icon: Icons.turn_right,
        label: "Next Turn",
        distance: indicators.distanceToNextTurn!,
        color: AppTheme.infoColor,
      ));
    }
    
    // * Next gate
    if (indicators.nextGate != null && indicators.distanceToNextGate != null) {
      items.add(_buildIndicatorItem(
        context,
        icon: Icons.security,
        label: indicators.nextGate!.hoa.name,
        distance: indicators.distanceToNextGate!,
        color: indicators.nextGate!.hoa.isResidentsOnly 
            ? AppTheme.errorColor 
            : AppTheme.successColor,
        subtitle: indicators.nextGate!.hoa.isResidentsOnly 
            ? "Residents Only" 
            : "Public Access",
      ));
    }
    
    // * Next delivery entrance
    if (indicators.nextDeliveryEntrance != null && 
        indicators.distanceToNextDeliveryEntrance != null) {
      items.add(_buildIndicatorItem(
        context,
        icon: Icons.local_shipping,
        label: indicators.nextDeliveryEntrance!.hoa.name,
        distance: indicators.distanceToNextDeliveryEntrance!,
        color: AppTheme.successColor,
        subtitle: "Delivery Entrance",
      ));
    }
    
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    
    if (compact) {
      // * Horizontal scrollable row
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
        child: Row(
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(right: AppTheme.spacingSM),
                    child: item,
                  ))
              .toList(),
        ),
      );
    } else {
      // * Vertical column
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(
            color: AppTheme.borderColor,
            width: 1.5,
          ),
          boxShadow: AppTheme.shadowLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.straighten,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  "Distance Indicators",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            ...items,
          ],
        ),
      );
    }
  }
  
  Widget _buildIndicatorItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required double distance,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSM),
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXS),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatDistance(distance),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

