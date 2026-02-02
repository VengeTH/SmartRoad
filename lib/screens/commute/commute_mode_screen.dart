import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";

import "../../core/theme/app_theme.dart";
import "../../models/commute_state.dart";
import "../../providers/commute_provider.dart";
import "../../widgets/commute/countdown_ring_widget.dart";
import "../../widgets/commute/commute_empty_state.dart";
import "../../widgets/commute/lagpas_alert_overlay.dart";
import "../../widgets/commute/safety_alert_overlay.dart";
import "../../widgets/commute/safety_settings_sheet.dart";
import "../../widgets/commute/arrival_celebration.dart";

/// * Commute Mode Screen
/// * A simple, beautiful UI for commuters with destination alarm
class CommuteModeScreen extends ConsumerStatefulWidget {
  const CommuteModeScreen({super.key});

  @override
  ConsumerState<CommuteModeScreen> createState() => _CommuteModeScreenState();
}

class _CommuteModeScreenState extends ConsumerState<CommuteModeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  
  // * Sample recent destinations for demo
  final List<Map<String, dynamic>> _recentDestinations = [
    {
      "name": "SM Mall of Asia",
      "lat": 14.5351,
      "lng": 120.9840,
    },
    {
      "name": "Ayala Malls Manila Bay",
      "lat": 14.5307,
      "lng": 120.9795,
    },
    {
      "name": "Robinsons Ermita",
      "lat": 14.5766,
      "lng": 120.9867,
    },
  ];
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  bool _showLagpasAlert = false;
  bool _showSafetyAlert = false;
  bool _showArrivalCelebration = false;
  bool _showEmptyState = true;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final commuteState = ref.watch(commuteProvider);
    
    // * Show lagpas alert overlay when user passes destination
    if (commuteState.status == CommuteStatus.passed && !_showLagpasAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showLagpasAlert = true);
      });
    }
    
    // * Show safety alert overlay when off-route detected
    if (commuteState.status == CommuteStatus.danger && !_showSafetyAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showSafetyAlert = true);
      });
    }
    
    // * Show arrival celebration
    if (commuteState.status == CommuteStatus.arrived && !_showArrivalCelebration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showArrivalCelebration = true);
      });
    }
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // * Main content
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: commuteState.isActive
                  ? _buildActiveCommuteView(commuteState)
                  : _buildIdleView(commuteState),
            ),
          ),
          
          // * Lagpas alert overlay
          if (_showLagpasAlert)
            LagpasAlertOverlay(
              destinationName: commuteState.destinationName ?? "your stop",
              onDismiss: () {
                setState(() => _showLagpasAlert = false);
                ref.read(commuteProvider.notifier).dismissAlarm();
                ref.read(commuteProvider.notifier).stopCommute();
              },
            ),
          
          // * Safety alert overlay
          if (_showSafetyAlert)
            SafetyAlertOverlay(
              destinationName: commuteState.destinationName ?? "Unknown",
              offRouteDistance: commuteState.offRouteDistanceKm ?? 0.0,
              onImSafe: () {
                setState(() => _showSafetyAlert = false);
                ref.read(commuteProvider.notifier).dismissSafetyAlert();
              },
              onSendAlert: () {
                setState(() => _showSafetyAlert = false);
                ref.read(commuteProvider.notifier).sendSafetyAlert();
              },
            ),
          
          // * Arrival celebration
          if (_showArrivalCelebration)
            ArrivalCelebration(
              destinationName: commuteState.destinationName ?? "your destination",
              onDismiss: () {
                setState(() => _showArrivalCelebration = false);
                ref.read(commuteProvider.notifier).stopCommute();
              },
            ),
        ],
      ),
    );
  }
  
  /// * Build idle state view (set destination)
  Widget _buildIdleView(CommuteState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.spacingMD),
          
          // * Header
          _buildHeader(),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          // * Destination input
          _buildDestinationInput(),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          // * Recent destinations or empty state
          if (_recentDestinations.isNotEmpty) ...[
            _buildSectionHeader("Recent Destinations", Icons.history),
            const SizedBox(height: AppTheme.spacingMD),
            ..._recentDestinations.map((dest) => _buildRecentDestinationTile(dest)),
          ] else
            CommuteEmptyState(
              onSearchTap: () {
                _destinationFocusNode.requestFocus();
              },
            ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          // * Settings section
          _buildSettingsSection(state),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // * Safety settings
          _buildSafetySettingsCard(state),
          
          const SizedBox(height: AppTheme.spacingXXL),
        ],
      ),
    );
  }
  
  /// * Build header
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Commute Mode",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                "Never miss your stop again",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// * Build destination input
  Widget _buildDestinationInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _destinationController,
        focusNode: _destinationFocusNode,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: "Where are you going?",
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.6),
          ),
          prefixIcon: const Icon(
            Icons.place_rounded,
            color: AppTheme.primaryColor,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search_rounded, color: AppTheme.secondaryColor),
            onPressed: () {
              // * TODO: Implement location search
              HapticFeedback.lightImpact();
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppTheme.spacingLG),
        ),
      ),
    );
  }
  
  /// * Build section header
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: AppTheme.spacingSM),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
  
  /// * Build recent destination tile
  Widget _buildRecentDestinationTile(Map<String, dynamic> destination) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startCommuteWithDestination(destination),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: AppTheme.borderColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSM),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Text(
                    destination["name"] as String,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSM,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: const Text(
                    "GO",
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// * Build settings section
  Widget _buildSettingsSection(CommuteState state) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingXS),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                "Alarm Settings",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingLG),
          
          // * Alarm distance slider
          _buildSettingItem(
            icon: Icons.straighten_rounded,
            title: "Distance Alarm",
            description: "Alert when this close to destination",
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingSM,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Text(
                _formatDistance(state.settings.alarmDistanceMeters),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          Slider(
            value: state.settings.alarmDistanceMeters.toDouble(),
            min: 200,
            max: 1000,
            divisions: 8,
            activeColor: AppTheme.primaryColor,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              ref.read(commuteProvider.notifier).setAlarmDistance(value.round());
            },
          ),
          
          const Divider(color: AppTheme.borderColor, height: AppTheme.spacingLG),
          
          // * Time backup toggle
          _buildSettingItem(
            icon: Icons.timer_rounded,
            title: "Time Backup Alarm",
            description: "Also alert ${state.settings.backupAlarmMinutes} min before arrival (ETA based)",
            trailing: Switch.adaptive(
              value: state.settings.useTimeBackupAlarm,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                ref.read(commuteProvider.notifier).setUseTimeBackupAlarm(value);
              },
              activeColor: AppTheme.primaryColor,
            ),
          ),
          
          // * Time backup slider (if enabled)
          if (state.settings.useTimeBackupAlarm) ...[
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              children: [
                Text(
                  "1 min",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: state.settings.backupAlarmMinutes.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      ref.read(commuteProvider.notifier).setBackupAlarmMinutes(value.round());
                    },
                  ),
                ),
                Text(
                  "10 min",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          
          const Divider(color: AppTheme.borderColor, height: AppTheme.spacingLG),
          
          // * Vibration toggle
          _buildSettingItem(
            icon: Icons.vibration_rounded,
            title: "Vibration",
            description: "Vibrate when alarm triggers",
            trailing: Switch.adaptive(
              value: state.settings.vibrateOnAlarm,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                ref.read(commuteProvider.notifier).setVibrateOnAlarm(value);
              },
              activeColor: AppTheme.primaryColor,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingSM),
          
          // * Sound toggle
          _buildSettingItem(
            icon: Icons.volume_up_rounded,
            title: "Sound",
            description: "Play alarm sound",
            trailing: Switch.adaptive(
              value: state.settings.playSoundOnAlarm,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                ref.read(commuteProvider.notifier).setPlaySoundOnAlarm(value);
              },
              activeColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  /// * Build safety settings card
  Widget _buildSafetySettingsCard(CommuteState state) {
    final safetyEnabled = state.settings.safetySettings.enabled;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSafetySettings(state),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          decoration: BoxDecoration(
            color: safetyEnabled 
                ? Colors.orange.withOpacity(0.1) 
                : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: safetyEnabled 
                  ? Colors.orange.withOpacity(0.3) 
                  : AppTheme.borderColor.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: safetyEnabled 
                      ? Colors.orange.withOpacity(0.2) 
                      : AppTheme.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  safetyEnabled ? Icons.shield : Icons.shield_outlined,
                  color: safetyEnabled ? Colors.orange : AppTheme.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Safety Alert",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (safetyEnabled) ...[
                          const SizedBox(width: AppTheme.spacingSM),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingSM,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            ),
                            child: const Text(
                              "ON",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      safetyEnabled
                          ? "Alert contacts if you go off-route"
                          : "Tap to set up emergency contacts",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// * Build setting item
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String description,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
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
        trailing,
      ],
    );
  }
  
  /// * Format distance with proper units
  String _formatDistance(int meters) {
    if (meters < 1000) {
      return "$meters m";
    } else {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
  }
  
  /// * Open safety settings sheet
  void _openSafetySettings(CommuteState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SafetySettingsSheet(
          settings: state.settings.safetySettings,
          onSave: (newSettings) {
            ref.read(commuteProvider.notifier).updateSafetySettings(newSettings);
          },
        ),
      ),
    );
  }
  
  /// * Build active commute view
  Widget _buildActiveCommuteView(CommuteState state) {
    final isApproaching = state.status == CommuteStatus.approaching;
    final isDanger = state.status == CommuteStatus.danger;
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacingMD),
          
          // * Header with destination name
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLG,
              vertical: AppTheme.spacingMD,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.place_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Flexible(
                  child: Text(
                    state.destinationName ?? "Unknown",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // * Countdown ring with progress
          ScaleTransition(
            scale: isApproaching || isDanger
                ? _pulseAnimation
                : const AlwaysStoppedAnimation(1.0),
            child: CountdownRingWidget(
              progress: state.progressPercentage,
              status: state.status,
              distance: state.formattedDistance,
              eta: state.formattedEta,
            ),
          ),
          
          const Spacer(),
          
          // * Status badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLG,
              vertical: AppTheme.spacingMD,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(state.status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(
                color: _getStatusColor(state.status).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(state.status),
                  size: 18,
                  color: _getStatusColor(state.status),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Text(
                  state.statusText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _getStatusColor(state.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXXL),
          
          // * Bottom buttons
          Row(
            children: [
              // * Dismiss alarm button (if approaching)
              if (isApproaching && !state.alarmDismissed)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(commuteProvider.notifier).dismissAlarm();
                    },
                    icon: const Icon(Icons.notifications_off_rounded),
                    label: const Text("Dismiss"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.warningColor,
                      side: BorderSide(color: AppTheme.warningColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                    ),
                  ),
                ),
              
              if (isApproaching && !state.alarmDismissed)
                const SizedBox(width: AppTheme.spacingMD),
              
              // * Stop button
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _stopCommute(),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text("Stop"),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingLG),
        ],
      ),
    );
  }
  
  // * Get status color
  Color _getStatusColor(CommuteStatus status) {
    switch (status) {
      case CommuteStatus.idle:
        return AppTheme.textSecondary;
      case CommuteStatus.active:
        return AppTheme.primaryColor;
      case CommuteStatus.approaching:
        return AppTheme.warningColor;
      case CommuteStatus.arrived:
        return AppTheme.successColor;
      case CommuteStatus.passed:
        return AppTheme.errorColor;
      case CommuteStatus.danger:
        return AppTheme.errorColor;
    }
  }

  // * Get status icon
  IconData _getStatusIcon(CommuteStatus status) {
    switch (status) {
      case CommuteStatus.idle:
        return Icons.place_outlined;
      case CommuteStatus.active:
        return Icons.directions_bus_rounded;
      case CommuteStatus.approaching:
        return Icons.notifications_active_rounded;
      case CommuteStatus.arrived:
        return Icons.check_circle_rounded;
      case CommuteStatus.passed:
        return Icons.warning_rounded;
      case CommuteStatus.danger:
        return Icons.emergency_rounded;
    }
  }
  
  /// * Start commute with selected destination
  Future<void> _startCommuteWithDestination(Map<String, dynamic> destination) async {
    HapticFeedback.mediumImpact();
    
    final name = destination["name"] as String;
    final lat = destination["lat"] as double;
    final lng = destination["lng"] as double;
    
    final success = await ref.read(commuteProvider.notifier).startCommute(
      destination: LatLng(lat, lng),
      destinationName: name,
    );
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not start commute. Please check location permissions."),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
  
  /// * Stop commute
  Future<void> _stopCommute() async {
    HapticFeedback.mediumImpact();
    await ref.read(commuteProvider.notifier).stopCommute();
  }
}

