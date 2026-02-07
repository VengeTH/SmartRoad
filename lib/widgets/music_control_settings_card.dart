import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../core/theme/app_theme.dart";
import "../models/music_app.dart";
import "../providers/music_control_provider.dart";
import "../services/music_app_launcher_service.dart";
import "music_app_picker_sheet.dart";

/// * Music Control Settings Card
/// Widget to enable/disable music controls and request permissions
class MusicControlSettingsCard extends ConsumerStatefulWidget {
  const MusicControlSettingsCard({super.key});

  @override
  ConsumerState<MusicControlSettingsCard> createState() =>
      _MusicControlSettingsCardState();
}

class _MusicControlSettingsCardState
    extends ConsumerState<MusicControlSettingsCard> {
  bool _isAndroid = true;
  final MusicAppLauncherService _launcher = MusicAppLauncherService();
  Future<String?>? _defaultAppIdFuture;

  @override
  void initState() {
    super.initState();
    _checkPlatform();
    _reloadDefaultMusicApp();
  }

  Future<void> _checkPlatform() async {
    // * Only show this feature on Android
    _isAndroid = Platform.isAndroid;
    if (mounted) setState(() {});
  }

  void _reloadDefaultMusicApp() {
    _defaultAppIdFuture = _launcher.getDefaultMusicAppId();
  }

  Future<void> _pickDefaultMusicApp() async {
    if (!mounted) return;

    final selected = await MusicAppPickerSheet.show(
      context,
      title: "Choose default music app",
      forceSetAsDefault: true,
      rememberAsDefaultByDefault: true,
    );

    if (!mounted) return;
    setState(_reloadDefaultMusicApp);

    if (selected != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Default music app set to ${selected.displayName}"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearDefaultMusicApp() async {
    await _launcher.setDefaultMusicAppId(null);
    if (!mounted) return;

    setState(_reloadDefaultMusicApp);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Default music app cleared"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // * Don't show on non-Android platforms
    if (!_isAndroid) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final musicState = ref.watch(musicControlProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // * Header row with icon and toggle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: AppTheme.secondaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Music Controls",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Control music playback while navigating",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // * Main toggle
                Switch.adaptive(
                  value: musicState.isEnabled,
                  onChanged: (value) {
                    ref.read(musicControlProvider.notifier).setEnabled(value);
                  },
                  activeColor: AppTheme.secondaryColor,
                ),
              ],
            ),
            // * Show permission section if enabled but no permission
            if (musicState.isEnabled) ...[
              const SizedBox(height: AppTheme.spacingMD),
              const Divider(height: 1),
              const SizedBox(height: AppTheme.spacingMD),

              // * Permission status
              if (!musicState.hasPermission) ...[
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(
                      color: AppTheme.warningColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.warningColor,
                        size: 24,
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Permission Required",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Notification access is needed to control other music apps.",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        musicState.isLoading
                            ? null
                            : () {
                              ref
                                  .read(musicControlProvider.notifier)
                                  .requestPermission();
                            },
                    icon:
                        musicState.isLoading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Icon(Icons.settings, size: 18),
                    label: Text(
                      musicState.isLoading
                          ? "Opening Settings..."
                          : "Grant Permission",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingMD,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // * Permission granted - show status
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.successColor,
                        size: 24,
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ready to go!",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Music controls will appear on the map when music is playing.",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // * Currently playing info (if available)
                if (musicState.hasActiveMedia) ...[
                  const SizedBox(height: AppTheme.spacingMD),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Row(
                      children: [
                        // * Thumbnail or music icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.2),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child:
                              musicState.thumbnail != null
                                  ? ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusSM),
                                    child: Image.memory(
                                      musicState.thumbnail!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                  : Icon(
                                    Icons.music_note_rounded,
                                    color: AppTheme.secondaryColor,
                                    size: 28,
                                  ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                musicState.trackTitle ?? "Unknown Track",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                musicState.artistName ?? "Unknown Artist",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // * Playing indicator
                        Icon(
                          musicState.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: AppTheme.secondaryColor,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: AppTheme.spacingMD),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: AppTheme.borderColor.withOpacity(0.6),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(
                          color: AppTheme.secondaryColor.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.open_in_new_rounded,
                        color: AppTheme.secondaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: FutureBuilder<String?>(
                        future: _defaultAppIdFuture,
                        builder: (context, snapshot) {
                          final id = snapshot.data;
                          final app = MusicAppDescriptor.fromId(id);
                          final label = app?.displayName ?? "Not set";

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Default music app",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    FutureBuilder<String?>(
                      future: _defaultAppIdFuture,
                      builder: (context, snapshot) {
                        final hasDefault =
                            MusicAppDescriptor.fromId(snapshot.data) != null;

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasDefault)
                              IconButton(
                                tooltip: "Clear default",
                                onPressed: _clearDefaultMusicApp,
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 20,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            TextButton(
                              onPressed: _pickDefaultMusicApp,
                              child: const Text("Change"),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
