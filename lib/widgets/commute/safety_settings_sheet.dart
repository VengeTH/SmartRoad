import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/theme/app_theme.dart";
import "../../models/commute_state.dart";
import "../../services/emergency_sms_service.dart";

/// * Safety Settings Sheet
/// * Bottom sheet for configuring safety alert features
/// * V2: Added grace period, sustained detection, night mode, cooldown settings
class SafetySettingsSheet extends StatefulWidget {
  final SafetySettings settings;
  final Function(SafetySettings) onSave;

  const SafetySettingsSheet({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<SafetySettingsSheet> createState() => _SafetySettingsSheetState();
}

class _SafetySettingsSheetState extends State<SafetySettingsSheet> {
  late bool _enabled;
  late double _thresholdKm;
  late bool _autoSmsEnabled;
  late List<EmergencyContact> _contacts;
  
  // * V2: New settings
  late int _gracePeriodSeconds;
  late int _sustainedOffRouteSeconds;
  late bool _useTimeOfDaySensitivity;
  late int _nightModeStartHour;
  late int _nightModeEndHour;
  late double _nightModeThresholdMultiplier;
  late int _alertCooldownMinutes;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.enabled;
    _thresholdKm = widget.settings.offRouteThresholdKm;
    _autoSmsEnabled = widget.settings.autoSmsEnabled;
    _contacts = List.from(widget.settings.emergencyContacts);
    
    // * V2: New settings
    _gracePeriodSeconds = widget.settings.gracePeriodSeconds;
    _sustainedOffRouteSeconds = widget.settings.sustainedOffRouteSeconds;
    _useTimeOfDaySensitivity = widget.settings.useTimeOfDaySensitivity;
    _nightModeStartHour = widget.settings.nightModeStartHour;
    _nightModeEndHour = widget.settings.nightModeEndHour;
    _nightModeThresholdMultiplier = widget.settings.nightModeThresholdMultiplier;
    _alertCooldownMinutes = widget.settings.alertCooldownMinutes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    final newSettings = SafetySettings(
      enabled: _enabled,
      emergencyContacts: _contacts,
      offRouteThresholdKm: _thresholdKm,
      autoSmsEnabled: _autoSmsEnabled,
      gracePeriodSeconds: _gracePeriodSeconds,
      sustainedOffRouteSeconds: _sustainedOffRouteSeconds,
      useTimeOfDaySensitivity: _useTimeOfDaySensitivity,
      nightModeStartHour: _nightModeStartHour,
      nightModeEndHour: _nightModeEndHour,
      nightModeThresholdMultiplier: _nightModeThresholdMultiplier,
      alertCooldownMinutes: _alertCooldownMinutes,
    );
    widget.onSave(newSettings);
    Navigator.of(context).pop();
  }

  void _addContact() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppTheme.spacingLG,
          right: AppTheme.spacingLG,
          top: AppTheme.spacingLG,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLG,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add Emergency Contact",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Contact Name",
                hintText: "e.g., Mom, Dad, Partner",
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingMD),
            
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Phone Number",
                hintText: "+63 9XX XXX XXXX",
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingLG),
            
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_nameController.text.trim().isNotEmpty &&
                      _phoneController.text.trim().isNotEmpty) {
                    setState(() {
                      _contacts.add(EmergencyContact(
                        name: _nameController.text.trim(),
                        phoneNumber: _phoneController.text.trim(),
                      ));
                    });
                    _nameController.clear();
                    _phoneController.clear();
                    Navigator.pop(context);
                  }
                },
                child: const Text("Add Contact"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }
  
  void _showMessagePreview() {
    final smsService = EmergencySmsService();
    final preview = smsService.previewEmergencyMessage(
      destinationName: "Work",
      areaName: "Quezon City",
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: const Row(
          children: [
            Icon(Icons.sms_outlined, color: Colors.orange),
            SizedBox(width: AppTheme.spacingSM),
            Text(
              "Message Preview",
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              preview,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
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
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Safety Alert",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          "Get notified if you go off-route",
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
              
              // * Enable toggle
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: _enabled ? Colors.orange.withOpacity(0.1) : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: _enabled ? Colors.orange.withOpacity(0.3) : AppTheme.borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _enabled ? Icons.shield : Icons.shield_outlined,
                      color: _enabled ? Colors.orange : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Enable Safety Alert",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            "Alert when you stray from your route",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _enabled,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        setState(() => _enabled = value);
                      },
                      activeColor: Colors.orange,
                    ),
                  ],
                ),
              ),
              
              if (_enabled) ...[
                const SizedBox(height: AppTheme.spacingLG),
                
                // * Threshold slider
                _buildSettingCard(
                  icon: Icons.straighten,
                  title: "Off-route threshold",
                  subtitle: "Trigger alert if you're this far from route",
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Text(
                      "${_thresholdKm.toStringAsFixed(1)} km",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: Slider(
                    value: _thresholdKm,
                    min: 1.0,
                    max: 5.0,
                    divisions: 8,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _thresholdKm = value);
                    },
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Grace period slider
                _buildSettingCard(
                  icon: Icons.timer_outlined,
                  title: "Grace period",
                  subtitle: "Time to cancel before alert is sent",
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
                      "$_gracePeriodSeconds sec",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: Slider(
                    value: _gracePeriodSeconds.toDouble(),
                    min: 15,
                    max: 90,
                    divisions: 5,
                    activeColor: Colors.blue,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _gracePeriodSeconds = value.round());
                    },
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Sustained detection slider
                _buildSettingCard(
                  icon: Icons.access_time,
                  title: "Sustained detection",
                  subtitle: "How long off-route before triggering",
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
                      "${(_sustainedOffRouteSeconds / 60).toStringAsFixed(0)} min",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: Slider(
                    value: _sustainedOffRouteSeconds.toDouble(),
                    min: 60,
                    max: 300,
                    divisions: 4,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _sustainedOffRouteSeconds = value.round());
                    },
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Auto SMS toggle
                _buildToggleCard(
                  icon: Icons.sms_outlined,
                  title: "Auto-send SMS",
                  subtitle: "Automatically text contacts after countdown",
                  value: _autoSmsEnabled,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    setState(() => _autoSmsEnabled = value);
                  },
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Time of day sensitivity
                _buildToggleCard(
                  icon: Icons.nightlight_round,
                  title: "Night mode sensitivity",
                  subtitle: "Stricter detection at night (${_nightModeStartHour}:00 - ${_nightModeEndHour}:00)",
                  value: _useTimeOfDaySensitivity,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    setState(() => _useTimeOfDaySensitivity = value);
                  },
                ),
                
                const SizedBox(height: AppTheme.spacingLG),
                
                // * Advanced settings toggle
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showAdvanced = !_showAdvanced);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune, color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: AppTheme.spacingMD),
                        Text(
                          "Advanced Settings",
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _showAdvanced ? Icons.expand_less : Icons.expand_more,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (_showAdvanced) ...[
                  const SizedBox(height: AppTheme.spacingMD),
                  
                  // * Alert cooldown
                  _buildSettingCard(
                    icon: Icons.hourglass_empty,
                    title: "Alert cooldown",
                    subtitle: "Prevent repeat alerts",
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSM,
                        vertical: AppTheme.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Text(
                        "$_alertCooldownMinutes min",
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.purple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    child: Slider(
                      value: _alertCooldownMinutes.toDouble(),
                      min: 5,
                      max: 30,
                      divisions: 5,
                      activeColor: Colors.purple,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _alertCooldownMinutes = value.round());
                      },
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingMD),
                  
                  // * Night mode threshold
                  if (_useTimeOfDaySensitivity)
                    _buildSettingCard(
                      icon: Icons.percent,
                      title: "Night threshold",
                      subtitle: "How much stricter at night",
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSM,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        ),
                        child: Text(
                          "${(_nightModeThresholdMultiplier * 100).round()}%",
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.indigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: Slider(
                        value: _nightModeThresholdMultiplier,
                        min: 0.5,
                        max: 1.0,
                        divisions: 5,
                        activeColor: Colors.indigo,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _nightModeThresholdMultiplier = value);
                        },
                      ),
                    ),
                  
                  const SizedBox(height: AppTheme.spacingMD),
                  
                  // * Preview message button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showMessagePreview,
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text("Preview Alert Message"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: AppTheme.spacingLG),
                
                // * Emergency contacts
                Row(
                  children: [
                    Text(
                      "Emergency Contacts",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addContact,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Add"),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacingSM),
                
                if (_contacts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingLG),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: AppTheme.borderColor.withOpacity(0.5),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: Text(
                            "Add at least one emergency contact to receive safety alerts",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...List.generate(_contacts.length, (index) {
                    final contact = _contacts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            child: Text(
                              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : "?",
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contact.name,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  contact.phoneNumber,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeContact(index),
                            icon: const Icon(Icons.remove_circle_outline),
                            color: AppTheme.errorColor,
                          ),
                        ],
                      ),
                    );
                  }),
              ],
              
              const SizedBox(height: AppTheme.spacingXL),
              
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
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
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
            activeColor: Colors.orange,
          ),
        ],
      ),
    );
  }
}

