import "package:flutter/material.dart";

import "../core/theme/app_theme.dart";
import "../services/speed_limit_service.dart";

/// * Compact speed HUD (Waze/Google Maps-like): current speed + speed limit sign.
class NavigationSpeedHud extends StatelessWidget {
  final double? speedKph;
  final SpeedLimitResult speedLimit;
  final bool isOverspeeding;
  final VoidCallback? onTapLimit;

  const NavigationSpeedHud({
    super.key,
    required this.speedKph,
    required this.speedLimit,
    required this.isOverspeeding,
    this.onTapLimit,
  });

  String _formatSpeed(double? kph) {
    if (kph == null || !kph.isFinite || kph < 0) {
      return "—";
    }
    return kph.round().toString();
  }

  Color _limitColor(SpeedLimitSource source) {
    return switch (source) {
      SpeedLimitSource.userOverride => AppTheme.infoColor,
      SpeedLimitSource.osmMaxspeed => AppTheme.textPrimary,
      SpeedLimitSource.highwayDefault => AppTheme.textSecondary,
      SpeedLimitSource.unknown => AppTheme.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final speedText = _formatSpeed(speedKph);
    final limit = speedLimit.speedLimitKph;
    final limitText = limit != null ? limit.toString() : "—";

    final speedBg = isOverspeeding
        ? AppTheme.errorColor.withOpacity(0.15)
        : AppTheme.surfaceColor.withOpacity(0.92);
    final speedBorder = isOverspeeding
        ? AppTheme.errorColor.withOpacity(0.65)
        : AppTheme.borderColor.withOpacity(0.8);

    return Semantics(
      label: "Speed: $speedText km/h. Speed limit: $limitText.",
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: speedBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(color: speedBorder, width: 1.2),
          boxShadow: AppTheme.shadowLarge,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  speedText,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isOverspeeding ? AppTheme.errorColor : AppTheme.textPrimary,
                        height: 1,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  "km/h",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (isOverspeeding) ...[
                  const SizedBox(height: 4),
                  Text(
                    "SLOW",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: AppTheme.spacingMD),
            GestureDetector(
              onTap: onTapLimit,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.shade600,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    limitText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _limitColor(speedLimit.source),
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

