import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/theme/app_theme.dart";
import "../../models/commute_state.dart";

/// * Safety Settings Sheet
/// * Bottom sheet for configuring safety alert features
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
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.enabled;
    _thresholdKm = widget.settings.offRouteThresholdKm;
    _autoSmsEnabled = widget.settings.autoSmsEnabled;
    _contacts = List.from(widget.settings.emergencyContacts);
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
                      Row(
                        children: [
                          const Icon(
                            Icons.straighten,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingSM),
                          Text(
                            "Off-route threshold",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
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
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        "Trigger alert if you're this far from your expected route",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Slider(
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
                    ],
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingMD),
                
                // * Auto SMS toggle
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sms_outlined,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Auto-send SMS",
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              "Automatically text contacts after 30s countdown",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _autoSmsEnabled,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          setState(() => _autoSmsEnabled = value);
                        },
                        activeColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
                
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
}

