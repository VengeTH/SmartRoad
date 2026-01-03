/// * Route Preview Sheet
/// * Shows route details and sticker suggestions before navigation starts
import "package:flutter/material.dart";
import "../core/theme/app_theme.dart";
import "../services/routing_service.dart";

/// * Route preview sheet widget
class RoutePreviewSheet extends StatelessWidget {
  final RouteData route;
  final VehicleType vehicleType;
  final String vehicleModeName;
  final VoidCallback onStartNavigation;
  final VoidCallback onCancel;
  final VoidCallback? onApplyForSticker; // * CTA for sticker application
  final VoidCallback? onEditRoute; // * Edit route with waypoints
  
  const RoutePreviewSheet({
    super.key,
    required this.route,
    required this.vehicleType,
    required this.vehicleModeName,
    required this.onStartNavigation,
    required this.onCancel,
    this.onApplyForSticker,
    this.onEditRoute,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = route.metadata;
    final hasBlockedShortcut = metadata?.blockedShortcut ?? false;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // * Handle bar
            Container(
              margin: const EdgeInsets.only(top: AppTheme.spacingMD),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // * Title
                    Text(
                      "Route Preview",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    
                    // * Vehicle type info
                    Row(
                      children: [
                        Icon(
                          vehicleType.icon,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Text(
                          vehicleModeName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    
                    // * Route details - Improved card design
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingLG),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                        border: Border.all(
                          color: AppTheme.borderColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _RouteDetailItem(
                            icon: Icons.straighten,
                            label: "Distance",
                            value: "${route.distance.toStringAsFixed(1)} km",
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppTheme.borderColor.withOpacity(0.3),
                          ),
                          _RouteDetailItem(
                            icon: Icons.access_time,
                            label: "Duration",
                            value: _formatDuration(route.duration),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    
                    // * Sticker suggestion banner (if blocked shortcut exists)
                    if (hasBlockedShortcut && metadata != null) ...[
                      _StickerSuggestionBanner(
                        hoaName: metadata.hoaName ?? "Restricted Area",
                        timeSavedMinutes: metadata.timeSavedMinutes ?? 15,
                        onApplyForSticker: onApplyForSticker,
                      ),
                      const SizedBox(height: AppTheme.spacingLG),
                    ],
                    
                    // * Edit Route button (if available)
                    if (onEditRoute != null) ...[
                      OutlinedButton.icon(
                        onPressed: onEditRoute,
                        icon: const Icon(Icons.edit_location_alt),
                        label: const Text("Adjust Route Path"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacingMD,
                          ),
                          side: BorderSide(color: AppTheme.primaryColor),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                    ],
                    // * Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacingMD,
                              ),
                              side: BorderSide(color: AppTheme.borderColor),
                            ),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: onStartNavigation,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacingMD,
                              ),
                              backgroundColor: AppTheme.primaryColor,
                            ),
                            child: const Text("Start Navigation"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }
}

/// * Route detail item widget (for improved UI)
class _RouteDetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  
  const _RouteDetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 24,
        ),
        const SizedBox(height: AppTheme.spacingSM),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// * Route detail card widget
class _RouteDetailCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  
  const _RouteDetailCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// * Sticker suggestion banner widget
class _StickerSuggestionBanner extends StatelessWidget {
  final String hoaName;
  final int timeSavedMinutes;
  final VoidCallback? onApplyForSticker;
  
  const _StickerSuggestionBanner({
    required this.hoaName,
    required this.timeSavedMinutes,
    this.onApplyForSticker,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: AppTheme.warningColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.warningColor,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Text(
                  "Apply for $hoaName Sticker to save $timeSavedMinutes minutes",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (onApplyForSticker != null) ...[
            const SizedBox(height: AppTheme.spacingMD),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onApplyForSticker,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.warningColor),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingSM,
                  ),
                ),
                child: Text(
                  "Apply for Sticker",
                  style: TextStyle(
                    color: AppTheme.warningColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

