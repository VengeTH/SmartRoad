import "dart:ui";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../core/theme/app_theme.dart";
import "../models/music_app.dart";
import "../providers/music_control_provider.dart";
import "../services/music_app_launcher_service.dart";
import "music_app_picker_sheet.dart";

/// * Music Control Widget
/// * A minimal, non-intrusive floating mini-player for controlling external music apps
/// * Quick-access music integration (open/control music without leaving the map)
class MusicControlWidget extends ConsumerStatefulWidget {
  const MusicControlWidget({super.key});

  @override
  ConsumerState<MusicControlWidget> createState() => _MusicControlWidgetState();
}

class _MusicControlWidgetState extends ConsumerState<MusicControlWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isOpeningMusicApp = false;
  late Future<String?> _defaultMusicAppIdFuture;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.animationNormal,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInQuart,
    );
    _defaultMusicAppIdFuture = MusicAppLauncherService().getDefaultMusicAppId();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicControlProvider);

    // * Don't show if disabled or no permission
    if (!state.isEnabled || !state.hasPermission) {
      return const SizedBox.shrink();
    }

    // * Sync animation state with provider
    if (state.isExpanded && !_animationController.isCompleted) {
      _animationController.forward();
    } else if (!state.isExpanded && _animationController.value > 0) {
      _animationController.reverse();
    }

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return state.isExpanded
            ? _buildExpandedPlayer(state)
            : _buildCollapsedPlayer(state);
      },
    );
  }

  Future<void> _handleMusicChipTap(MusicControlState state) async {
    if (state.hasActiveMedia) {
      ref.read(musicControlProvider.notifier).toggleExpanded();
      return;
    }

    await _openMusicApp();
  }

  Future<void> _openMusicApp({bool forcePicker = false}) async {
    if (_isOpeningMusicApp) return;
    setState(() => _isOpeningMusicApp = true);

    try {
      HapticFeedback.selectionClick();
      final launcher = MusicAppLauncherService();

      if (!forcePicker) {
        final defaultApp = await launcher.getDefaultInstalledMusicApp();
        if (defaultApp != null) {
          final didOpen = await launcher.openMusicApp(defaultApp);
          if (didOpen) return;
        }
      }

      if (!mounted) return;
      await MusicAppPickerSheet.show(context);
      if (mounted) {
        setState(() {
          _defaultMusicAppIdFuture = launcher.getDefaultMusicAppId();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningMusicApp = false);
      }
    }
  }

  /// * Collapsed state - compact pill-shaped widget
  Widget _buildCollapsedPlayer(MusicControlState state) {
    final hasMedia = state.hasActiveMedia;

    return GestureDetector(
      onTap: _isOpeningMusicApp ? null : () => _handleMusicChipTap(state),
      onLongPress: _isOpeningMusicApp ? null : () => _openMusicApp(forcePicker: true),
      child: AnimatedContainer(
        duration: AppTheme.animationFast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: AppTheme.borderColor.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // * Music icon or thumbnail
                _buildMiniThumbnail(state),
                const SizedBox(width: 10),

                // * Track info (truncated)
                if (hasMedia)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      state.trackTitle ?? "No music",
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: FutureBuilder<String?>(
                      future: _defaultMusicAppIdFuture,
                      builder: (context, snapshot) {
                        final app = MusicAppDescriptor.fromId(snapshot.data);
                        final label = app == null
                            ? "No music playing"
                            : "Open ${app.displayName}";
                        final icon = app == null
                            ? Icons.apps_rounded
                            : Icons.open_in_new_rounded;

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              icon,
                              color: AppTheme.textTertiary,
                              size: 18,
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                if (hasMedia) ...[
                  const SizedBox(width: 8),

                  // * Compact controls
                  _buildCompactControls(state),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// * Mini thumbnail or music icon
  Widget _buildMiniThumbnail(MusicControlState state) {
    if (state.thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          state.thumbnail!,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildMusicIcon(small: true),
        ),
      );
    }
    return _buildMusicIcon(small: true);
  }

  /// * Music icon
  Widget _buildMusicIcon({bool small = false}) {
    final size = small ? 28.0 : 48.0;
    final iconSize = small ? 16.0 : 24.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.8),
            AppTheme.secondaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(small ? 6 : 10),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }

  /// * Compact control buttons for collapsed state
  Widget _buildCompactControls(MusicControlState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // * Previous
        _buildCompactButton(
          icon: Icons.skip_previous_rounded,
          onTap: () => ref.read(musicControlProvider.notifier).previousTrack(),
        ),

        // * Play/Pause
        _buildCompactButton(
          icon: state.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onTap: () => ref.read(musicControlProvider.notifier).togglePlayPause(),
          isPrimary: true,
        ),

        // * Next
        _buildCompactButton(
          icon: Icons.skip_next_rounded,
          onTap: () => ref.read(musicControlProvider.notifier).nextTrack(),
        ),
      ],
    );
  }

  /// * Compact button
  Widget _buildCompactButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: isPrimary
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Icon(
          icon,
          color: isPrimary ? Colors.white : AppTheme.textSecondary,
          size: isPrimary ? 20 : 22,
        ),
      ),
    );
  }

  /// * Expanded state - full mini-player
  Widget _buildExpandedPlayer(MusicControlState state) {
    return GestureDetector(
      onTap: () {
        // * Collapse when tapping outside controls
        ref.read(musicControlProvider.notifier).collapse();
      },
      child: AnimatedContainer(
        duration: AppTheme.animationNormal,
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.98),
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(
            color: AppTheme.borderColor.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.1),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // * Album art
                    _buildExpandedThumbnail(state),
                    const SizedBox(width: 16),

                    // * Track info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.trackTitle ?? "Unknown Track",
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.artistName ?? "Unknown Artist",
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // * Close button
                    GestureDetector(
                      onTap: () {
                        ref.read(musicControlProvider.notifier).collapse();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // * Large controls
                _buildExpandedControls(state),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isOpeningMusicApp ? null : () => _openMusicApp(),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text("Open music app"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// * Expanded thumbnail
  Widget _buildExpandedThumbnail(MusicControlState state) {
    if (state.thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          state.thumbnail!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildMusicIcon(),
        ),
      );
    }
    return _buildMusicIcon();
  }

  /// * Expanded control buttons
  Widget _buildExpandedControls(MusicControlState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // * Previous
        _buildExpandedButton(
          icon: Icons.skip_previous_rounded,
          onTap: () => ref.read(musicControlProvider.notifier).previousTrack(),
        ),

        const SizedBox(width: 16),

        // * Play/Pause (primary)
        _buildExpandedButton(
          icon: state.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onTap: () => ref.read(musicControlProvider.notifier).togglePlayPause(),
          isPrimary: true,
        ),

        const SizedBox(width: 16),

        // * Next
        _buildExpandedButton(
          icon: Icons.skip_next_rounded,
          onTap: () => ref.read(musicControlProvider.notifier).nextTrack(),
        ),
      ],
    );
  }

  /// * Expanded control button
  Widget _buildExpandedButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final size = isPrimary ? 52.0 : 44.0;
    final iconSize = isPrimary ? 28.0 : 24.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : AppTheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(isPrimary ? 16 : 12),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.white : AppTheme.textSecondary,
          size: iconSize,
        ),
      ),
    );
  }
}
