/// * Map Filter Panel
/// * Slide-out panel for map filters (hazards, traffic, etc.)
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../core/theme/app_theme.dart";
import "../providers/map_filter_provider.dart";
import "../models/hazard.dart";

/// * Map Filter Panel Widget
/// * Slide-out panel with filter controls
class MapFilterPanel extends ConsumerWidget {
  final VoidCallback onClose;
  
  const MapFilterPanel({
    required this.onClose,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(mapFilterProvider);
    final filterNotifier = ref.read(mapFilterProvider.notifier);
    
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: AppTheme.shadowLarge,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppTheme.radiusXL),
          bottomRight: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // * Header
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(AppTheme.radiusXL),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Text(
                    "Map Filters",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  color: AppTheme.textSecondary,
                  iconSize: 20,
                ),
              ],
            ),
          ),
          // * Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // * Traffic Toggle
                  _FilterSection(
                    title: "Traffic",
                    icon: Icons.traffic,
                    iconColor: Colors.orange,
                    children: [
                      SwitchListTile(
                        title: const Text("Live Traffic"),
                        subtitle: const Text("Show real-time traffic conditions"),
                        value: filterState.showTraffic,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          filterNotifier.setShowTraffic(value);
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  // * Hazard Type Filters
                  _FilterSection(
                    title: "Hazard Types",
                    icon: Icons.warning,
                    iconColor: AppTheme.warningColor,
                    children: [
                      Wrap(
                        spacing: AppTheme.spacingSM,
                        runSpacing: AppTheme.spacingSM,
                        children: HazardType.values.map((type) {
                          final isSelected = filterState.selectedTypes.contains(type);
                          final displayName = type.value[0].toUpperCase() + type.value.substring(1);
                          return FilterChip(
                            label: Text(displayName),
                            selected: isSelected,
                            onSelected: (selected) {
                              HapticFeedback.lightImpact();
                              filterNotifier.toggleType(type);
                            },
                            selectedColor: AppTheme.primaryColor.withOpacity(0.25),
                            checkmarkColor: AppTheme.primaryColor,
                            backgroundColor: AppTheme.surfaceVariant,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  // * Severity Filters
                  _FilterSection(
                    title: "Severity",
                    icon: Icons.priority_high,
                    iconColor: AppTheme.errorColor,
                    children: [
                      Wrap(
                        spacing: AppTheme.spacingSM,
                        runSpacing: AppTheme.spacingSM,
                        children: SeverityLevel.values.map((severity) {
                          final isSelected = filterState.selectedSeverities.contains(severity);
                          Color severityColor;
                          switch (severity) {
                            case SeverityLevel.low:
                              severityColor = AppTheme.successColor;
                              break;
                            case SeverityLevel.medium:
                              severityColor = AppTheme.warningColor;
                              break;
                            case SeverityLevel.high:
                              severityColor = AppTheme.errorColor;
                              break;
                          }
                          return FilterChip(
                            label: Text(severity.value),
                            selected: isSelected,
                            onSelected: (selected) {
                              HapticFeedback.lightImpact();
                              filterNotifier.toggleSeverity(severity);
                            },
                            selectedColor: severityColor.withOpacity(0.25),
                            checkmarkColor: severityColor,
                            backgroundColor: AppTheme.surfaceVariant,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  // * Expiry Filter
                  _FilterSection(
                    title: "Options",
                    icon: Icons.settings,
                    iconColor: AppTheme.textSecondary,
                    children: [
                      SwitchListTile(
                        title: const Text("Show Expired"),
                        subtitle: const Text("Show hazards older than 24 hours"),
                        value: filterState.showExpired,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          filterNotifier.setShowExpired(value);
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  // * Reset Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        filterNotifier.resetFilters();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text("Reset Filters"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingMD,
                          horizontal: AppTheme.spacingLG,
                        ),
                        side: BorderSide(
                          color: AppTheme.primaryColor.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  // * Bottom padding for safe area
                  const SizedBox(height: AppTheme.spacingMD),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// * Filter Section Widget
class _FilterSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  
  const _FilterSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: AppTheme.spacingSM),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ...children,
      ],
    );
  }
}
