import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/theme/app_theme.dart";
import "../../models/commute_state.dart";

/// * Commute Settings Sheet
/// * Bottom sheet for configuring commute mode alarm settings
/// * V2: Added smart alarm, multi-stage alarm, and low power mode settings
class CommuteSettingsSheet extends StatefulWidget {
  final CommuteSettings settings;
  final Function(CommuteSettings) onSave;

  const CommuteSettingsSheet({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<CommuteSettingsSheet> createState() => _CommuteSettingsSheetState();
}

class _CommuteSettingsSheetState extends State<CommuteSettingsSheet> {
  // * Basic settings
  late int _alarmDistanceMeters;
  late bool _vibrateOnAlarm;
  late bool _playSoundOnAlarm;
  
  // * Time backup
  late bool _useTimeBackupAlarm;
  late int _backupAlarmMinutes;
  
  // * Smart alarm buffer
  late bool _useSmartAlarmBuffer;
  late int _minSecondsBeforeAlarm;
  late int _maxSecondsBeforeAlarm;
  
  // * Multi-stage alarm
  late bool _useMultiStageAlarm;
  
  // * Low power mode
  late bool _ultraLowPowerMode;
  late int _lowPowerGpsIntervalSeconds;
  late bool _minimizeAlertsWhenActive;
  
  // * Vehicle type
  late VehicleType _vehicleType;
  
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _alarmDistanceMeters = widget.settings.alarmDistanceMeters;
    _vibrateOnAlarm = widget.settings.vibrateOnAlarm;
    _playSoundOnAlarm = widget.settings.playSoundOnAlarm;
    _useTimeBackupAlarm = widget.settings.useTimeBackupAlarm;
    _backupAlarmMinutes = widget.settings.backupAlarmMinutes;
    _useSmartAlarmBuffer = widget.settings.useSmartAlarmBuffer;
    _minSecondsBeforeAlarm = widget.settings.minSecondsBeforeAlarm;
    _maxSecondsBeforeAlarm = widget.settings.maxSecondsBeforeAlarm;
    _useMultiStageAlarm = widget.settings.useMultiStageAlarm;
    _ultraLowPowerMode = widget.settings.ultraLowPowerMode;
    _lowPowerGpsIntervalSeconds = widget.settings.lowPowerGpsIntervalSeconds;
    _minimizeAlertsWhenActive = widget.settings.minimizeAlertsWhenActive;
    _vehicleType = widget.settings.vehicleType;
  }

  void _saveAndClose() {
    final newSettings = widget.settings.copyWith(
      alarmDistanceMeters: _alarmDistanceMeters,
      vibrateOnAlarm: _vibrateOnAlarm,
      playSoundOnAlarm: _playSoundOnAlarm,
      useTimeBackupAlarm: _useTimeBackupAlarm,
      backupAlarmMinutes: _backupAlarmMinutes,
      useSmartAlarmBuffer: _useSmartAlarmBuffer,
      minSecondsBeforeAlarm: _minSecondsBeforeAlarm,
      maxSecondsBeforeAlarm: _maxSecondsBeforeAlarm,
      useMultiStageAlarm: _useMultiStageAlarm,
      ultraLowPowerMode: _ultraLowPowerMode,
      lowPowerGpsIntervalSeconds: _lowPowerGpsIntervalSeconds,
      minimizeAlertsWhenActive: _minimizeAlertsWhenActive,
      vehicleType: _vehicleType,
    );
    widget.onSave(newSettings);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // * Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingLG),
              
              // * Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: const Icon(
                      Icons.alarm_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Alarm Settings",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          "Configure how you're alerted",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacingXL),
              
              // * SECTION: Vehicle Type
              _buildSectionHeader("Vehicle Type", Icons.directions_rounded),
              const SizedBox(height: AppTheme.spacingMD),
              
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select your mode of transport for accurate ETA",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    Wrap(
                      spacing: AppTheme.spacingSM,
                      runSpacing: AppTheme.spacingSM,
                      children: VehicleType.values.map((type) {
                        final isSelected = type == _vehicleType;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _vehicleType = type);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMD,
                              vertical: AppTheme.spacingSM,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.borderColor,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  type.iconData,
                                  size: 16,
                                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  type.label,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Row(
                      children: [
                        Icon(_vehicleType.iconData, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          "${_vehicleType.label}: ~${_vehicleType.baseSpeedKmh.toStringAsFixed(0)} km/h base speed",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingXL),
              
              // * SECTION: Smart Alarm
              _buildSectionHeader("Smart Alarm", Icons.auto_awesome_rounded),
              const SizedBox(height: AppTheme.spacingMD),
              
              // * Smart alarm buffer toggle
              _buildToggleCard(
                icon: Icons.speed_rounded,
                title: "Speed-Adaptive Alarm",
                subtitle: "Adjust alarm timing based on vehicle speed",
                value: _useSmartAlarmBuffer,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _useSmartAlarmBuffer = value);
                },
              ),
              
              if (_useSmartAlarmBuffer) ...[
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Min/Max time before alarm
                _buildSettingCard(
                  icon: Icons.timer_outlined,
                  title: "Alarm lead time",
                  subtitle: "Alert ${_minSecondsBeforeAlarm}s - ${_maxSecondsBeforeAlarm}s before arrival",
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Text(
                      "${_minSecondsBeforeAlarm}s - ${_maxSecondsBeforeAlarm}s",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text("Min", style: Theme.of(context).textTheme.bodySmall),
                          Expanded(
                            child: Slider(
                              value: _minSecondsBeforeAlarm.toDouble(),
                              min: 15,
                              max: 60,
                              divisions: 3,
                              activeColor: AppTheme.primaryColor,
                              onChanged: (value) {
                                HapticFeedback.selectionClick();
                                setState(() => _minSecondsBeforeAlarm = value.round());
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text("Max", style: Theme.of(context).textTheme.bodySmall),
                          Expanded(
                            child: Slider(
                              value: _maxSecondsBeforeAlarm.toDouble(),
                              min: 60,
                              max: 180,
                              divisions: 4,
                              activeColor: AppTheme.primaryColor,
                              onChanged: (value) {
                                HapticFeedback.selectionClick();
                                setState(() => _maxSecondsBeforeAlarm = value.round());
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              
              if (!_useSmartAlarmBuffer) ...[
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Fixed distance slider
                _buildSettingCard(
                  icon: Icons.straighten,
                  title: "Alarm distance",
                  subtitle: "Fixed distance to trigger alarm",
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Text(
                      "${_alarmDistanceMeters}m",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: Slider(
                    value: _alarmDistanceMeters.toDouble(),
                    min: 100,
                    max: 1000,
                    divisions: 9,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _alarmDistanceMeters = value.round());
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: AppTheme.spacingXL),
              
              // * SECTION: Multi-Stage Alarm
              _buildSectionHeader("Multi-Stage Alarm", Icons.graphic_eq_rounded),
              const SizedBox(height: AppTheme.spacingMD),
              
              _buildToggleCard(
                icon: Icons.surround_sound_rounded,
                title: "Progressive Alarm",
                subtitle: "Soft → Medium → Loud as you approach",
                value: _useMultiStageAlarm,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _useMultiStageAlarm = value);
                },
              ),
              
              if (_useMultiStageAlarm) ...[
                const SizedBox(height: AppTheme.spacingSM),
                
                // * Stage preview
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      _buildStagePreview(
                        "Stage 1",
                        "~90s before",
                        "Light vibration",
                        Colors.green,
                        Icons.vibration,
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      _buildStagePreview(
                        "Stage 2",
                        "~60s before",
                        "Medium vibration + sound",
                        Colors.orange,
                        Icons.notifications_active_outlined,
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      _buildStagePreview(
                        "Stage 3",
                        "~30s before",
                        "Continuous loud alarm",
                        Colors.red,
                        Icons.alarm_on,
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: AppTheme.spacingXL),
              
              // * SECTION: Alert Options
              _buildSectionHeader("Alert Options", Icons.notifications_rounded),
              const SizedBox(height: AppTheme.spacingMD),
              
              _buildToggleCard(
                icon: Icons.vibration,
                title: "Vibration",
                subtitle: "Vibrate on alarm",
                value: _vibrateOnAlarm,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _vibrateOnAlarm = value);
                },
              ),
              
              const SizedBox(height: AppTheme.spacingSM),
              
              _buildToggleCard(
                icon: Icons.volume_up_rounded,
                title: "Sound",
                subtitle: "Play alarm sound",
                value: _playSoundOnAlarm,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _playSoundOnAlarm = value);
                },
              ),
              
              const SizedBox(height: AppTheme.spacingSM),
              
              _buildToggleCard(
                icon: Icons.access_time,
                title: "Time backup alarm",
                subtitle: "Also alarm at ${_backupAlarmMinutes} min ETA",
                value: _useTimeBackupAlarm,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _useTimeBackupAlarm = value);
                },
              ),
              
              if (_useTimeBackupAlarm) ...[
                const SizedBox(height: AppTheme.spacingSM),
                _buildSettingCard(
                  icon: Icons.timer,
                  title: "Backup time",
                  subtitle: "Trigger alarm at this ETA",
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Text(
                      "$_backupAlarmMinutes min",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: Slider(
                    value: _backupAlarmMinutes.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: Colors.blue,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _backupAlarmMinutes = value.round());
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: AppTheme.spacingXL),
              
              // * SECTION: Battery Saver
              _buildSectionHeader("Battery Saver", Icons.battery_saver_rounded),
              const SizedBox(height: AppTheme.spacingMD),
              
              _buildToggleCard(
                icon: Icons.eco_rounded,
                title: "Ultra-Low Power Mode",
                subtitle: "Reduce GPS updates for longer commutes",
                value: _ultraLowPowerMode,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _ultraLowPowerMode = value);
                },
                accentColor: Colors.green,
              ),
              
              if (_ultraLowPowerMode) ...[
                const SizedBox(height: AppTheme.spacingSM),
                
                // * Warning
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: AppTheme.spacingSM),
                      Expanded(
                        child: Text(
                          "Low power mode may reduce location accuracy. Best for long, predictable routes.",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingSM),
                
                _buildSettingCard(
                  icon: Icons.gps_fixed,
                  title: "GPS interval",
                  subtitle: "How often to check location",
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Text(
                      "${_lowPowerGpsIntervalSeconds}s",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: Slider(
                    value: _lowPowerGpsIntervalSeconds.toDouble(),
                    min: 15,
                    max: 60,
                    divisions: 3,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _lowPowerGpsIntervalSeconds = value.round());
                    },
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingSM),
                
                _buildToggleCard(
                  icon: Icons.do_not_disturb_on_rounded,
                  title: "Minimize alerts",
                  subtitle: "Reduce notifications when phone is active",
                  value: _minimizeAlertsWhenActive,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    setState(() => _minimizeAlertsWhenActive = value);
                  },
                  accentColor: Colors.green,
                ),
              ],
              
              const SizedBox(height: AppTheme.spacingXXL),
              
              // * Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveAndClose,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                  ),
                  child: const Text("Save Settings"),
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingMD),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: AppTheme.spacingSM),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              trailing,
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          child,
        ],
      ),
    );
  }
  
  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.05) : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: value ? color.withOpacity(0.3) : AppTheme.borderColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? color : AppTheme.textSecondary, size: 20),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStagePreview(
    String stage,
    String timing,
    String description,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$stage • $timing",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

