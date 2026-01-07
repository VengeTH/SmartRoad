import "package:flutter/material.dart";
import "../core/theme/app_theme.dart";
import "package:latlong2/latlong.dart";

/// * Dialog for creating a new route with options to draw or use navigation
class CreateRouteDialog extends StatelessWidget {
  final LatLng? currentLocation;
  
  const CreateRouteDialog({
    super.key,
    this.currentLocation,
  });
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppTheme.spacingLG),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(
              color: AppTheme.borderColor,
              width: 1,
            ),
            boxShadow: AppTheme.shadowLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.35),
                          AppTheme.secondaryColor.withOpacity(0.18),
                        ],
                      ),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      color: AppTheme.textPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Create Route",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Choose how you want to build your route.",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Close",
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLG),
              _CreateRouteOptionTile(
                icon: Icons.edit_location_alt_rounded,
                title: "Draw Route",
                subtitle: "Manually draw a safe path right on the map.",
                accent: AppTheme.primaryColor,
                onTap: () => Navigator.pop(context, CreateRouteOption.draw),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              _CreateRouteOptionTile(
                icon: Icons.navigation_rounded,
                title: "Use Navigation",
                subtitle: "Search a destination and refine the suggested route.",
                accent: AppTheme.secondaryColor,
                onTap: () => Navigator.pop(context, CreateRouteOption.navigation),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRouteOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _CreateRouteOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant.withOpacity(0.45),
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(
            color: accent.withOpacity(0.28),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: accent.withOpacity(0.28),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

enum CreateRouteOption {
  draw,
  navigation,
}
