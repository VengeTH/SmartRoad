/// * Route Preview Sheet
/// * Shows route details, target arrival time, required speed, and legal warnings
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../core/theme/app_theme.dart";
import "../models/required_speed_result.dart";
import "../services/routing_service.dart";
import "../services/speed_limit_service.dart";
import "../services/target_speed_service.dart";

/// * Route preview sheet widget
class RoutePreviewSheet extends StatefulWidget {
  final RouteData route;
  final VehicleType vehicleType;
  final String vehicleModeName;
  final String mode;
  final VoidCallback onStartNavigation;
  final void Function(DateTime? targetArrivalTime, RequiredSpeedResult? speedResult)?
      onStartWithTarget;
  final VoidCallback onCancel;
  final VoidCallback? onApplyForSticker; // * CTA for sticker application
  final VoidCallback? onEditRoute; // * Edit route with waypoints
  final VoidCallback? onSaveRoute; // * Save route without starting navigation
  final DateTime? initialTargetArrivalTime;
  final SpeedLimitResult? currentSpeedLimit;

  const RoutePreviewSheet({
    super.key,
    required this.route,
    required this.vehicleType,
    required this.vehicleModeName,
    this.mode = "car",
    required this.onStartNavigation,
    this.onStartWithTarget,
    required this.onCancel,
    this.onApplyForSticker,
    this.onEditRoute,
    this.onSaveRoute,
    this.initialTargetArrivalTime,
    this.currentSpeedLimit,
  });

  @override
  State<RoutePreviewSheet> createState() => _RoutePreviewSheetState();
}

class _RoutePreviewSheetState extends State<RoutePreviewSheet> {
  DateTime? _targetArrivalTime;
  RequiredSpeedResult? _speedResult;
  final TargetSpeedService _speedService = TargetSpeedService();

  @override
  void initState() {
    super.initState();
    _targetArrivalTime = widget.initialTargetArrivalTime;
    _recalculateSpeed();
  }

  void _recalculateSpeed() {
    if (_targetArrivalTime == null) {
      setState(() {
        _speedResult = null;
      });
      return;
    }

    final result = _speedService.computeRequiredSpeed(
      distanceKm: widget.route.distance,
      targetArrivalTime: _targetArrivalTime!,
      mode: widget.mode,
      currentSpeedLimit: widget.currentSpeedLimit,
      baseEstimatedDuration: widget.route.duration,
    );

    setState(() {
      _speedResult = result;
    });
  }

  void _setTargetOffset(Duration offset) {
    setState(() {
      _targetArrivalTime = DateTime.now().add(widget.route.duration).add(offset);
      _recalculateSpeed();
    });
  }

  Future<void> _pickCustomTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _targetArrivalTime != null
          ? TimeOfDay.fromDateTime(_targetArrivalTime!)
          : now,
      helpText: "Select Target Arrival Time",
    );

    if (picked != null) {
      final today = DateTime.now();
      var selected = DateTime(
        today.year,
        today.month,
        today.day,
        picked.hour,
        picked.minute,
      );
      // * If selected time is before now, assume next day
      if (selected.isBefore(today)) {
        selected = selected.add(const Duration(days: 1));
      }
      setState(() {
        _targetArrivalTime = selected;
        _recalculateSpeed();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = widget.route.metadata;
    final hasBlockedShortcut = metadata?.blockedShortcut ?? false;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                          widget.vehicleType.icon,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Text(
                          widget.vehicleModeName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    
                    // * Route details - Distance and Duration
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
                            value: "${widget.route.distance.toStringAsFixed(1)} km",
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppTheme.borderColor.withOpacity(0.3),
                          ),
                          _RouteDetailItem(
                            icon: Icons.access_time,
                            label: "Est. Duration",
                            value: _formatDuration(widget.route.duration),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),

                    // * Target Arrival Time & Required Speed Section
                    _buildTargetArrivalSection(theme),
                    const SizedBox(height: AppTheme.spacingLG),
                    
                    // * Sticker suggestion banner (if blocked shortcut exists)
                    if (hasBlockedShortcut && metadata != null) ...[
                      _StickerSuggestionBanner(
                        hoaName: metadata.hoaName ?? "Restricted Area",
                        timeSavedMinutes: metadata.timeSavedMinutes ?? 15,
                        onApplyForSticker: widget.onApplyForSticker,
                      ),
                      const SizedBox(height: AppTheme.spacingLG),
                    ],
                    
                    // * Edit Route button (if available)
                    if (widget.onEditRoute != null) ...[
                      OutlinedButton.icon(
                        onPressed: widget.onEditRoute,
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
                    // * Save Route button (optional)
                    if (widget.onSaveRoute != null) ...[
                      ElevatedButton.icon(
                        onPressed: widget.onSaveRoute,
                        icon: const Icon(Icons.save),
                        label: const Text("Save Route"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacingMD,
                          ),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                    ],
                    // * Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onCancel,
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
                            onPressed: () {
                              if (widget.onStartWithTarget != null) {
                                widget.onStartWithTarget!(
                                  _targetArrivalTime,
                                  _speedResult,
                                );
                              }
                              widget.onStartNavigation();
                            },
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

  Widget _buildTargetArrivalSection(ThemeData theme) {
    final timeFormat = DateFormat("h:mm a");
    final hasTarget = _targetArrivalTime != null;
    final speedResult = _speedResult;
    final isExceeding = speedResult?.isExceedingLegalLimit ?? false;
    final isModerate = speedResult?.status == RequiredSpeedStatus.moderate;

    final Color statusColor = isExceeding
        ? AppTheme.errorColor
        : (isModerate ? Colors.amber.shade800 : AppTheme.successColor);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: isExceeding
            ? AppTheme.errorColor.withOpacity(0.08)
            : AppTheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isExceeding
              ? AppTheme.errorColor.withOpacity(0.5)
              : AppTheme.borderColor,
          width: isExceeding ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.alarm_on,
                size: 20,
                color: isExceeding ? AppTheme.errorColor : AppTheme.primaryColor,
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                "Target Arrival Time",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (hasTarget)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _targetArrivalTime = null;
                      _recalculateSpeed();
                    });
                  },
                  visualDensity: VisualDensity.compact,
                  child: const Text("Clear", style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            "Set your desired arrival time to calculate the required travel speed taking into account traffic delays and pedestrian lane stops.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),

          // * Quick preset chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text("On ETA", style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                onPressed: () => _setTargetOffset(Duration.zero),
              ),
              ActionChip(
                label: const Text("+15m buffer", style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                onPressed: () => _setTargetOffset(const Duration(minutes: 15)),
              ),
              ActionChip(
                label: const Text("+30m buffer", style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                onPressed: () => _setTargetOffset(const Duration(minutes: 30)),
              ),
              ActionChip(
                avatar: const Icon(Icons.edit_calendar, size: 14),
                label: Text(
                  hasTarget ? timeFormat.format(_targetArrivalTime!) : "Pick Time",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: hasTarget ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                visualDensity: VisualDensity.compact,
                backgroundColor: hasTarget
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : null,
                onPressed: _pickCustomTime,
              ),
            ],
          ),

          // * Speed computation display & legal warnings
          if (speedResult != null) ...[
            const SizedBox(height: AppTheme.spacingMD),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Required Speed",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                speedResult.requiredSpeedKph > 0
                                    ? "${speedResult.requiredSpeedKph.toStringAsFixed(0)} km/h"
                                    : "—",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  speedResult.statusBadge.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Legal Limit",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${speedResult.legalSpeedLimitKph} km/h",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Icon(Icons.traffic, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        "Includes ~${speedResult.pedestrianDelayMinutes.toStringAsFixed(1)}m pedestrian & traffic stops",
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  // * Legal warning message
                  if (speedResult.warningMessage != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isExceeding
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            speedResult.warningMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (speedResult.legalDisclaimer != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      speedResult.legalDisclaimer!,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary.withOpacity(0.9),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
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

