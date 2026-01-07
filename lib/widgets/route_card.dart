import "package:flutter/material.dart";
import "../models/saved_route.dart";
import "../core/theme/app_theme.dart";

/// * Route card widget - Displays route information in a card
class RouteCard extends StatelessWidget {
  final SavedRoute route;
  final VoidCallback? onTap;
  final VoidCallback? onUse;
  final VoidCallback? onPurchase;
  final VoidCallback? onEdit;
  final bool showEdit;
  
  const RouteCard({
    super.key,
    required this.route,
    this.onTap,
    this.onUse,
    this.onPurchase,
    this.onEdit,
    this.showEdit = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // * Header row
              Row(
                children: [
                  // * Vehicle type icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Icon(
                      route.vehicleType.icon,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // * Route name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (route.city != null)
                          Text(
                            route.city!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // * Price badge
                  if (!route.isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(
                          color: AppTheme.warningColor.withOpacity(0.55),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        route.formattedPrice,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: const Text(
                        "FREE",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // * Route metrics
              Row(
                children: [
                  _MetricChip(
                    icon: Icons.straighten,
                    label: "${route.distanceKm.toStringAsFixed(1)} km",
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    icon: Icons.access_time,
                    label: "${route.duration.inMinutes} min",
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    icon: Icons.star,
                    label: route.ratingAvg > 0
                        ? route.ratingAvg.toStringAsFixed(1)
                        : "New",
                    color: route.ratingAvg > 0
                        ? AppTheme.warningColor
                        : AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // * Trust score and usage
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Trust: ",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: route.trustScore / 100,
                                backgroundColor: AppTheme.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  route.trustScore >= 70
                                      ? AppTheme.successColor
                                      : route.trustScore >= 40
                                          ? AppTheme.warningColor
                                          : AppTheme.errorColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${route.trustScore.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${route.usageCount} uses",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // * Tags
              if (route.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: route.tags.entries
                      .where((e) => e.value == true)
                      .take(3)
                      .map((e) => _TagChip(tag: e.key))
                      .toList(),
                ),
              ],
              // * Action buttons
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (showEdit && onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("Edit"),
                    ),
                  if (onPurchase != null && !route.isFree && route.isPurchased != true)
                    OutlinedButton.icon(
                      onPressed: onPurchase,
                      icon: const Icon(Icons.shopping_cart, size: 18),
                      label: Text(route.formattedPrice),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber,
                        side: const BorderSide(color: Colors.amber),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (onUse != null)
                    ElevatedButton.icon(
                      onPressed: onUse,
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text("Use"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  
  const _MetricChip({
    required this.icon,
    required this.label,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? AppTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color ?? AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  
  const _TagChip({required this.tag});
  
  IconData _getIconForTag(String tag) {
    switch (tag) {
      case 'rain_safe':
        return Icons.water_drop;
      case 'flood_safe':
        return Icons.waves;
      case 'toll_free':
        return Icons.money_off;
      case 'gate_aware':
        return Icons.security;
      case 'night_safe':
        return Icons.nightlight;
      default:
        return Icons.check_circle;
    }
  }
  
  String _getLabelForTag(String tag) {
    switch (tag) {
      case 'rain_safe':
        return 'Rain Safe';
      case 'flood_safe':
        return 'Flood Safe';
      case 'toll_free':
        return 'Toll Free';
      case 'gate_aware':
        return 'Gate Aware';
      case 'night_safe':
        return 'Night Safe';
      default:
        return tag;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIconForTag(tag),
            size: 14,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            _getLabelForTag(tag),
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
