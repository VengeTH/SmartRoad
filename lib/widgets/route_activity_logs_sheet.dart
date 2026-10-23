import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "package:latlong2/latlong.dart";

import "../core/theme/app_theme.dart";
import "../models/route_activity_log.dart";
import "../providers/route_activity_log_provider.dart";

/// * Bottom sheet displaying route search time logs and trip initiation logs.
class RouteActivityLogsSheet extends ConsumerStatefulWidget {
  final void Function(LatLng destination, String mode, String label)? onSelectLog;

  const RouteActivityLogsSheet({
    super.key,
    this.onSelectLog,
  });

  static Future<void> show(
    BuildContext context, {
    void Function(LatLng destination, String mode, String label)? onSelectLog,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RouteActivityLogsSheet(onSelectLog: onSelectLog),
    );
  }

  @override
  ConsumerState<RouteActivityLogsSheet> createState() =>
      _RouteActivityLogsSheetState();
}

class _RouteActivityLogsSheetState extends ConsumerState<RouteActivityLogsSheet> {
  RouteActivityType? _filterType;

  final DateFormat _timeFormat = DateFormat("h:mm:ss a");
  final DateFormat _dateFormat = DateFormat("MMM d, yyyy");

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(routeActivityLogsProvider);

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
          children: [
            // * Drag handle
            Container(
              margin: const EdgeInsets.only(top: AppTheme.spacingMD),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // * Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingLG,
                AppTheme.spacingMD,
                AppTheme.spacingLG,
                AppTheme.spacingSM,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Icon(
                      Icons.history_toggle_off,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Search & Trip Time Logs",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Logs when you searched or initiated routes",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: "Clear Logs",
                    onPressed: () => _confirmClear(context),
                  ),
                ],
              ),
            ),
            // * Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: "All",
                    isSelected: _filterType == null,
                    onTap: () => setState(() => _filterType = null),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  _buildFilterChip(
                    label: "Searched Only",
                    icon: Icons.search,
                    isSelected: _filterType == RouteActivityType.searched,
                    onTap: () => setState(
                      () => _filterType = RouteActivityType.searched,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  _buildFilterChip(
                    label: "Ride Initiated",
                    icon: Icons.navigation,
                    isSelected: _filterType == RouteActivityType.initiated,
                    onTap: () => setState(
                      () => _filterType = RouteActivityType.initiated,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            // * Content list
            Expanded(
              child: logsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Center(
                  child: Text(
                    "Failed to load logs: $e",
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                ),
                data: (allLogs) {
                  final filtered = _filterType == null
                      ? allLogs
                      : allLogs.where((l) => l.type == _filterType).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: AppTheme.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          Text(
                            _filterType == null
                                ? "No route search or trip logs yet"
                                : "No ${_filterType!.displayName.toLowerCase()} logs found",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingSM),
                          Text(
                            "Searched routes and initiated rides will appear here.",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingLG,
                      vertical: AppTheme.spacingSM,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.spacingMD),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildLogCard(context, item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMD,
          vertical: AppTheme.spacingXS,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : AppTheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, RouteActivityLog item) {
    final theme = Theme.of(context);
    final isInitiated = item.isRideInitiated;

    final badgeColor =
        isInitiated ? AppTheme.successColor : AppTheme.infoColor;
    final badgeBg = badgeColor.withOpacity(0.12);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isInitiated
              ? AppTheme.successColor.withOpacity(0.4)
              : AppTheme.borderColor.withOpacity(0.5),
          width: isInitiated ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // * Badge & Timestamp Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSM,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isInitiated ? Icons.play_arrow : Icons.search,
                        size: 13,
                        color: badgeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isInitiated ? "RIDE INITIATED" : "SEARCHED ONLY",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _dateFormat.format(item.searchedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: "Remove",
                  onPressed: () {
                    ref.read(routeActivityLogsProvider.notifier).deleteLog(item.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),

            // * Time stamps
            if (isInitiated && item.initiatedAt != null) ...[
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: AppTheme.successColor),
                  const SizedBox(width: 6),
                  Text(
                    "Ride Started: ${_timeFormat.format(item.initiatedAt!)}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "(Searched at ${_timeFormat.format(item.searchedAt)})",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.search, size: 14, color: AppTheme.infoColor),
                  const SizedBox(width: 6),
                  Text(
                    "Searched at: ${_timeFormat.format(item.searchedAt)}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      "Not started",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.spacingMD),

            // * Origin to Destination
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.radio_button_checked, size: 14, color: Colors.green),
                    Container(width: 2, height: 16, color: AppTheme.borderColor),
                    const Icon(Icons.place, size: 16, color: Colors.red),
                  ],
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.originLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.destinationLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),

            // * Metrics (Distance, Duration, Mode)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildMetricChip(
                  icon: Icons.straighten,
                  text: "${item.distanceKm.toStringAsFixed(1)} km",
                ),
                _buildMetricChip(
                  icon: Icons.access_time,
                  text: item.formattedDuration,
                ),
                _buildMetricChip(
                  icon: _getModeIcon(item.mode),
                  text: _getModeName(item.mode),
                ),
              ],
            ),

            // * Target Arrival & Speed Information (if set)
            if (item.targetArrivalTime != null) ...[
              const SizedBox(height: AppTheme.spacingSM),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: item.isExceedingLimit
                      ? AppTheme.errorColor.withOpacity(0.08)
                      : AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: item.isExceedingLimit
                        ? AppTheme.errorColor.withOpacity(0.4)
                        : AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.flag,
                          size: 14,
                          color: item.isExceedingLimit
                              ? AppTheme.errorColor
                              : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Target Arrival: ${_timeFormat.format(item.targetArrivalTime!)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: item.isExceedingLimit
                                ? AppTheme.errorColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        if (item.requiredSpeedKph != null)
                          Text(
                            "Req. Speed: ${item.requiredSpeedKph!.toStringAsFixed(0)} km/h",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (item.isExceedingLimit) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.warning, size: 12, color: AppTheme.errorColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "Exceeds legal speed limit (${item.legalSpeedLimitKph ?? 60} km/h). Drive legally & safely.",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // * Select / Navigate CTA
            if (widget.onSelectLog != null) ...[
              const SizedBox(height: AppTheme.spacingSM),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.navigation, size: 14),
                  label: const Text("View / Navigate Route"),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primaryColor,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onSelectLog!(
                      LatLng(item.destinationLat, item.destinationLon),
                      item.mode,
                      item.destinationLabel,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case "motorcycle_sub400":
        return Icons.two_wheeler;
      case "motorcycle_400plus":
        return Icons.motorcycle;
      case "truck":
        return Icons.local_shipping;
      case "pedestrian":
        return Icons.directions_walk;
      case "car":
      default:
        return Icons.directions_car;
    }
  }

  String _getModeName(String mode) {
    switch (mode) {
      case "motorcycle_sub400":
        return "Motorcycle (≤399cc)";
      case "motorcycle_400plus":
        return "Big Bike (400cc+)";
      case "truck":
        return "Truck";
      case "pedestrian":
        return "Pedestrian";
      case "car":
      default:
        return "Car";
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Clear All Logs?"),
        content: const Text(
          "This will clear your saved route search and trip start time logs. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text("Clear"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(routeActivityLogsProvider.notifier).clearAll();
    }
  }
}
