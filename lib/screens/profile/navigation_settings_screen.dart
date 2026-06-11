import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/theme/app_theme.dart";
import "../../models/navigation_avatar_style.dart";
import "../../models/navigation_settings.dart";
import "../../providers/navigation_settings_provider.dart";

/// * Navigation settings screen (driver-focused map and navigation preferences).
class NavigationSettingsScreen extends ConsumerWidget {
  const NavigationSettingsScreen({super.key});

  static const _highwayKeysInUiOrder = <String>[
    "motorway",
    "trunk",
    "primary",
    "secondary",
    "tertiary",
    "unclassified",
    "residential",
    "service",
    "living_street",
  ];

  String _prettyHighway(String key) {
    return key.replaceAll("_", " ").split(" ").map((w) {
      if (w.isEmpty) return w;
      return "${w[0].toUpperCase()}${w.substring(1)}";
    }).join(" ");
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(navigationSettingsProvider);
    final notifier = ref.read(navigationSettingsProvider.notifier);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigation"),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 800.0 : double.infinity,
          ),
          child: ListView(
            padding: EdgeInsets.all(isDesktop ? AppTheme.spacingXXL : AppTheme.spacingXL),
            children: [
              // * Avatar Section
              _buildSettingsCard(
                context,
                title: "Avatar",
                child: Wrap(
                  spacing: AppTheme.spacingSM,
                  runSpacing: AppTheme.spacingSM,
                  children: NavigationAvatarStyle.values.map((style) {
                    final selected = settings.avatarStyle == style;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(style.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(style.label),
                        ],
                      ),
                      selected: selected,
                      onSelected: (_) async {
                        HapticFeedback.lightImpact();
                        await notifier.setAvatarStyle(style);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              // * Speed & Alerts Section
              _buildSettingsCard(
                context,
                title: "Speed & Alerts",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToggleRow(
                      context,
                      title: "Show speed during navigation",
                      subtitle: "Displays your current speed during navigation.",
                      value: settings.showSpeedHud,
                      onChanged: (value) async {
                        await notifier.setShowSpeedHud(value);
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggleRow(
                      context,
                      title: "Overspeed warnings",
                      subtitle: "Warns when speed exceeds the road limit + tolerance.",
                      value: settings.overspeedWarningsEnabled,
                      onChanged: (value) async {
                        await notifier.setOverspeedWarningsEnabled(value);
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    Text(
                      "Tolerance: ${settings.overspeedToleranceKph} km/h",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Slider(
                      value: settings.overspeedToleranceKph.toDouble(),
                      min: 0,
                      max: 20,
                      divisions: 20,
                      label: "${settings.overspeedToleranceKph} km/h",
                      onChanged: (value) async {
                        await notifier.setOverspeedToleranceKph(value.round());
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                "Tolerance: ${settings.overspeedToleranceKph} km/h",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Slider(
                value: settings.overspeedToleranceKph.toDouble(),
                min: 0,
                max: 20,
                divisions: 20,
                label: "${settings.overspeedToleranceKph} km/h",
                onChanged: (value) async {
                  await notifier.setOverspeedToleranceKph(value.round());
                },
              ),
              const SizedBox(height: AppTheme.spacingXL),
              const Divider(),
              const SizedBox(height: AppTheme.spacingXL),
              Text(
                "Speed Limits",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              SwitchListTile(
                value: settings.useOsmSpeedLimits,
                onChanged: (value) async {
                  await notifier.setUseOsmSpeedLimits(value);
                },
                title: const Text("Use OpenStreetMap speed limits"),
                subtitle: const Text("Reads maxspeed tags when available (best-effort)."),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              OutlinedButton.icon(
                onPressed: () {
                  _showDefaultSpeedLimitsSheet(
                    context: context,
                    settings: settings,
                    notifier: notifier,
                  );
                },
                icon: const Icon(Icons.tune),
                label: const Text("Edit default speed limits"),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              OutlinedButton.icon(
                onPressed: () async {
                  await notifier.clearAllSpeedLimitOverrides();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Cleared all speed limit overrides")),
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text("Clear road overrides"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDefaultSpeedLimitsSheet({
    required BuildContext context,
    required NavigationSettings settings,
    required NavigationSettingsNotifier notifier,
  }) {
    final controllers = <String, TextEditingController>{};
    for (final key in _highwayKeysInUiOrder) {
      final current = settings.defaultSpeedLimitsByHighway[key];
      controllers[key] = TextEditingController(
        text: current != null ? current.toString() : "",
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL),
              ),
              boxShadow: AppTheme.shadowLarge,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Default speed limits",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      "Used when a road has no maxspeed tag. Values are km/h.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    for (final key in _highwayKeysInUiOrder) ...[
                      TextField(
                        controller: controllers[key],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _prettyHighway(key),
                          prefixIcon: const Icon(Icons.speed),
                          suffixText: "km/h",
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                    ],
                    const SizedBox(height: AppTheme.spacingMD),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await notifier.resetDefaultSpeedLimits();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text("Reset defaults"),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              for (final entry in controllers.entries) {
                                final key = entry.key;
                                final raw = entry.value.text.trim();
                                if (raw.isEmpty) continue;
                                final parsed = int.tryParse(raw);
                                if (parsed == null) continue;
                                await notifier.setDefaultSpeedLimitForHighway(key, parsed);
                              }
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text("Save"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  /// * Desktop-style settings card with title and content
  Widget _buildSettingsCard(BuildContext context, {required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          child,
        ],
      ),
    );
  }

  /// * Desktop-style toggle row (replaces SwitchListTile)
  Widget _buildToggleRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSM),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

