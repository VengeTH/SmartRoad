import "dart:async";
import "dart:typed_data";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../services/music_control_service.dart";
import "../services/app_preferences_service.dart";

/// * Music control state for the provider
class MusicControlState {
  final bool isEnabled;
  final bool hasPermission;
  final bool isPlaying;
  final String? trackTitle;
  final String? artistName;
  final Uint8List? thumbnail;
  final bool isExpanded;
  final bool isLoading;

  const MusicControlState({
    this.isEnabled = false,
    this.hasPermission = false,
    this.isPlaying = false,
    this.trackTitle,
    this.artistName,
    this.thumbnail,
    this.isExpanded = false,
    this.isLoading = false,
  });

  bool get hasActiveMedia => trackTitle != null && trackTitle!.isNotEmpty;

  MusicControlState copyWith({
    bool? isEnabled,
    bool? hasPermission,
    bool? isPlaying,
    String? trackTitle,
    String? artistName,
    Uint8List? thumbnail,
    bool? isExpanded,
    bool? isLoading,
    bool clearTrack = false,
    bool clearArtist = false,
    bool clearThumbnail = false,
  }) {
    return MusicControlState(
      isEnabled: isEnabled ?? this.isEnabled,
      hasPermission: hasPermission ?? this.hasPermission,
      isPlaying: isPlaying ?? this.isPlaying,
      trackTitle: clearTrack ? null : (trackTitle ?? this.trackTitle),
      artistName: clearArtist ? null : (artistName ?? this.artistName),
      thumbnail: clearThumbnail ? null : (thumbnail ?? this.thumbnail),
      isExpanded: isExpanded ?? this.isExpanded,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// * Music control notifier
class MusicControlNotifier extends StateNotifier<MusicControlState> {
  final MusicControlService _service;
  final AppPreferencesService _prefs;
  StreamSubscription<MediaState>? _mediaSubscription;

  MusicControlNotifier(this._service, this._prefs)
      : super(const MusicControlState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // * Load enabled preference
    final isEnabled = await _prefs.getMusicControlEnabled();
    state = state.copyWith(isEnabled: isEnabled);

    if (isEnabled) {
      await _initializeService();
    }
  }

  Future<void> _initializeService() async {
    state = state.copyWith(isLoading: true);

    await _service.initialize();

    state = state.copyWith(
      hasPermission: _service.hasPermission,
      isPlaying: _service.isPlaying,
      trackTitle: _service.currentTrack,
      artistName: _service.currentArtist,
      thumbnail: _service.thumbnail,
      isLoading: false,
    );

    // * Listen for media state changes
    _mediaSubscription?.cancel();
    _mediaSubscription = _service.mediaStateStream.listen((mediaState) {
      state = state.copyWith(
        isPlaying: mediaState.isPlaying,
        trackTitle: mediaState.track,
        artistName: mediaState.artist,
        thumbnail: mediaState.thumbnail,
        clearTrack: mediaState.track == null,
        clearArtist: mediaState.artist == null,
        clearThumbnail: mediaState.thumbnail == null,
      );
    });
  }

  /// * Enable or disable music controls
  Future<void> setEnabled(bool enabled) async {
    await _prefs.setMusicControlEnabled(enabled);
    state = state.copyWith(isEnabled: enabled);

    if (enabled) {
      await _initializeService();
    } else {
      _service.stopPolling();
      _mediaSubscription?.cancel();
      state = state.copyWith(
        isPlaying: false,
        clearTrack: true,
        clearArtist: true,
        clearThumbnail: true,
      );
    }
  }

  /// * Request permission
  Future<void> requestPermission() async {
    state = state.copyWith(isLoading: true);
    await _service.requestPermission();
    
    if (_service.hasPermission) {
      await _initializeService();
    } else {
      state = state.copyWith(
        hasPermission: false,
        isLoading: false,
      );
    }
  }

  /// * Toggle expanded state
  void toggleExpanded() {
    state = state.copyWith(isExpanded: !state.isExpanded);
  }

  /// * Collapse the widget
  void collapse() {
    state = state.copyWith(isExpanded: false);
  }

  /// * Toggle play/pause
  Future<void> togglePlayPause() async {
    await _service.togglePlayPause();
  }

  /// * Skip to next track
  Future<void> nextTrack() async {
    await _service.nextTrack();
  }

  /// * Go to previous track
  Future<void> previousTrack() async {
    await _service.previousTrack();
  }

  /// * Manually refresh media info
  Future<void> refresh() async {
    await _service.refreshMediaInfo();
  }

  @override
  void dispose() {
    _mediaSubscription?.cancel();
    super.dispose();
  }
}

/// * Provider for music control state
final musicControlProvider =
    StateNotifierProvider<MusicControlNotifier, MusicControlState>((ref) {
  return MusicControlNotifier(
    MusicControlService(),
    AppPreferencesService(),
  );
});
