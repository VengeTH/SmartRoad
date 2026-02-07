import "package:flutter/material.dart";

import "../core/theme/app_theme.dart";
import "../models/music_app.dart";
import "../services/music_app_launcher_service.dart";

/// * Music App Picker Sheet
/// *
/// * Bottom sheet that shows only installed supported music apps for quick access.
/// * When the user chooses an app, SmartRoad launches it and optionally remembers it as default.
class MusicAppPickerSheet extends StatefulWidget {
  final String title;

  /// * When true, selecting an app always sets it as default.
  final bool forceSetAsDefault;

  /// * Controls the default value of the "Remember as default" toggle.
  final bool rememberAsDefaultByDefault;

  const MusicAppPickerSheet({
    super.key,
    this.title = "Open Music",
    this.forceSetAsDefault = false,
    this.rememberAsDefaultByDefault = true,
  });

  static Future<MusicAppDescriptor?> show(
    BuildContext context, {
    String title = "Open Music",
    bool forceSetAsDefault = false,
    bool rememberAsDefaultByDefault = true,
  }) async {
    return await showModalBottomSheet<MusicAppDescriptor>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MusicAppPickerSheet(
          title: title,
          forceSetAsDefault: forceSetAsDefault,
          rememberAsDefaultByDefault: rememberAsDefaultByDefault,
        );
      },
    );
  }

  @override
  State<MusicAppPickerSheet> createState() => _MusicAppPickerSheetState();
}

class _MusicAppPickerSheetState extends State<MusicAppPickerSheet> {
  final MusicAppLauncherService _launcher = MusicAppLauncherService();

  late Future<List<MusicAppDescriptor>> _appsFuture;
  bool _rememberAsDefault = true;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    _rememberAsDefault = widget.rememberAsDefaultByDefault;
    _appsFuture = _launcher.getInstalledSupportedApps();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxWidth =
        AppTheme.isDesktop(context) ? 520.0 : double.infinity;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.98),
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(
                color: AppTheme.borderColor.withOpacity(0.7),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: "Close",
                        onPressed: _isLaunching
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    "Choose an installed music app to start playback with fewer distractions.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  if (!widget.forceSetAsDefault) ...[
                    _buildRememberToggle(theme),
                    const SizedBox(height: AppTheme.spacingMD),
                  ],
                  FutureBuilder<List<MusicAppDescriptor>>(
                    future: _appsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacingXL,
                            ),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final apps = snapshot.data ?? const <MusicAppDescriptor>[];
                      if (apps.isEmpty) {
                        return _buildEmptyState(theme);
                      }

                      return _buildAppsGrid(theme, apps);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRememberToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withOpacity(0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: AppTheme.borderColor.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star_rounded,
            color: AppTheme.warningColor,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Remember as default",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Tapping the music chip opens this app next time.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _rememberAsDefault,
            onChanged: _isLaunching
                ? null
                : (value) => setState(() => _rememberAsDefault = value),
            activeColor: AppTheme.secondaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAppsGrid(ThemeData theme, List<MusicAppDescriptor> apps) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 340 ? 2 : (width < 480 ? 3 : 4);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppTheme.spacingSM,
            crossAxisSpacing: AppTheme.spacingSM,
            childAspectRatio: 1.05,
          ),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return _MusicAppTile(
              app: app,
              isDisabled: _isLaunching,
              onTap: () => _handleSelect(app),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.borderColor.withOpacity(0.7),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.music_off_rounded,
              color: AppTheme.textSecondary,
              size: 28,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            "No supported music apps found",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Install Spotify, YouTube Music, or another supported app, then try again.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingLG),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLaunching ? null : _launcher.openPlayStoreSearch,
              icon: const Icon(Icons.shop_rounded, size: 18),
              label: const Text("Search Play Store"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSelect(MusicAppDescriptor app) async {
    if (_isLaunching) return;

    setState(() => _isLaunching = true);

    try {
      final didOpen = await _launcher.openMusicApp(app);
      if (!didOpen) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't open ${app.displayName}."),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (widget.forceSetAsDefault || _rememberAsDefault) {
        await _launcher.setDefaultMusicAppId(app.id);
      }

      if (!mounted) return;
      Navigator.of(context).pop(app);
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }
}

class _MusicAppTile extends StatelessWidget {
  final MusicAppDescriptor app;
  final VoidCallback onTap;
  final bool isDisabled;

  const _MusicAppTile({
    required this.app,
    required this.onTap,
    required this.isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant.withOpacity(0.45),
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: AppTheme.borderColor.withOpacity(0.6),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: app.accentColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: app.accentColor.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Icon(
                  app.icon,
                  color: app.accentColor.withOpacity(0.9),
                  size: 24,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                app.displayName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

