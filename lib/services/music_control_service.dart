import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:flutter_media_controller/flutter_media_controller.dart";

/// * Music Control Service
/// * Handles integration with external music apps (Spotify, YouTube Music, etc.)
class MusicControlService {
  static final MusicControlService _instance = MusicControlService._internal();
  factory MusicControlService() => _instance;
  MusicControlService._internal();

  // * Android returns Base64.DEFAULT which can include line breaks/whitespace
  static final RegExp _base64Whitespace = RegExp(r"\s+");

  // * Current media state
  String? _currentTrack;
  String? _currentArtist;
  bool _isPlaying = false;
  Uint8List? _thumbnail;
  String? _thumbnailBase64;
  bool _hasPermission = false;

  // * Polling timer for media updates
  Timer? _pollTimer;
  final Duration _pollInterval = const Duration(seconds: 2);

  // * Stream controller for media state changes
  final _mediaStateController = StreamController<MediaState>.broadcast();
  Stream<MediaState> get mediaStateStream => _mediaStateController.stream;

  // * Getters
  String? get currentTrack => _currentTrack;
  String? get currentArtist => _currentArtist;
  bool get isPlaying => _isPlaying;
  Uint8List? get thumbnail => _thumbnail;
  bool get hasPermission => _hasPermission;
  bool get hasActiveMedia => _currentTrack != null && _currentTrack!.isNotEmpty;

  /// * Normalizes the plugin's "no media" placeholder into `null`
  String? _normalizeTrackTitle(String rawTrack) {
    final track = rawTrack.trim();
    if (track.isEmpty) return null;
    if (track == "No track playing") return null;
    return track;
  }

  /// * Normalizes base64 artwork returned by the plugin (removes whitespace)
  String? _normalizeThumbnailBase64(String rawBase64) {
    final normalized = rawBase64.replaceAll(_base64Whitespace, "").trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  /// * Decodes base64 artwork into bytes for `Image.memory`
  Uint8List? _decodeThumbnailBytes(String? normalizedBase64) {
    if (normalizedBase64 == null) return null;
    try {
      return base64Decode(normalizedBase64);
    } on FormatException {
      return null;
    }
  }

  /// * Request notification listener permission
  /// * This opens system settings where user must enable access
  Future<void> requestPermission() async {
    try {
      await FlutterMediaController.requestPermissions();
      // * Check if permission was granted after request
      await _checkPermission();
    } catch (e) {
      _hasPermission = false;
    }
  }

  /// * Check if notification listener permission is granted
  Future<bool> _checkPermission() async {
    try {
      // * Try to get media info - if it works, we have permission
      await FlutterMediaController.getCurrentMediaInfo();
      _hasPermission = true;
      return true;
    } catch (e) {
      _hasPermission = false;
      return false;
    }
  }

  /// * Initialize the service and start polling for media updates
  Future<void> initialize() async {
    await _checkPermission();
    if (_hasPermission) {
      await refreshMediaInfo();
      _startPolling();
    }
  }

  /// * Start polling for media state changes
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_hasPermission) {
        refreshMediaInfo();
      }
    });
  }

  /// * Stop polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// * Refresh current media information.
  /// * Note: MediaInfo from flutter_media_controller has [thumbnailUrl] (base64 string), not artwork.
  Future<void> refreshMediaInfo() async {
    if (!_hasPermission) return;

    try {
      final mediaInfo = await FlutterMediaController.getCurrentMediaInfo();

      final newTrack = _normalizeTrackTitle(mediaInfo.track);
      final newArtist = newTrack == null ? null : mediaInfo.artist;
      final newIsPlaying = newTrack == null ? false : mediaInfo.isPlaying;

      // * Plugin returns artwork as base64 (despite the field name `thumbnailUrl`)
      final newThumbnailBase64 = newTrack == null
          ? null
          : _normalizeThumbnailBase64(mediaInfo.thumbnailUrl);
      final thumbnailChanged = newThumbnailBase64 != _thumbnailBase64;
      final newThumbnail = thumbnailChanged
          ? _decodeThumbnailBytes(newThumbnailBase64)
          : _thumbnail;

      // * Check if anything changed
      final hasChanged = _currentTrack != newTrack ||
          _currentArtist != newArtist ||
          _isPlaying != newIsPlaying ||
          thumbnailChanged;

      _currentTrack = newTrack;
      _currentArtist = newArtist;
      _isPlaying = newIsPlaying;
      _thumbnail = newThumbnail;
      _thumbnailBase64 = newThumbnailBase64;

      // * Notify listeners if state changed
      if (hasChanged) {
        _mediaStateController.add(MediaState(
          track: _currentTrack,
          artist: _currentArtist,
          isPlaying: _isPlaying,
          thumbnail: _thumbnail,
        ));
      }
    } catch (e) {
      // * Permission might have been revoked
      _hasPermission = false;
      _clearState();
    }
  }

  /// * Toggle play/pause
  Future<void> togglePlayPause() async {
    if (!_hasPermission) return;

    try {
      await FlutterMediaController.togglePlayPause();
      // * Refresh state after action
      await Future.delayed(const Duration(milliseconds: 200));
      await refreshMediaInfo();
    } catch (e) {
      // * Ignore errors
    }
  }

  /// * Skip to next track
  Future<void> nextTrack() async {
    if (!_hasPermission) return;

    try {
      await FlutterMediaController.nextTrack();
      // * Refresh state after action
      await Future.delayed(const Duration(milliseconds: 200));
      await refreshMediaInfo();
    } catch (e) {
      // * Ignore errors
    }
  }

  /// * Go to previous track
  Future<void> previousTrack() async {
    if (!_hasPermission) return;

    try {
      await FlutterMediaController.previousTrack();
      // * Refresh state after action
      await Future.delayed(const Duration(milliseconds: 200));
      await refreshMediaInfo();
    } catch (e) {
      // * Ignore errors
    }
  }

  /// * Clear current state
  void _clearState() {
    _currentTrack = null;
    _currentArtist = null;
    _isPlaying = false;
    _thumbnail = null;
    _thumbnailBase64 = null;
    _mediaStateController.add(MediaState(
      track: null,
      artist: null,
      isPlaying: false,
      thumbnail: null,
    ));
  }

  /// * Dispose resources
  void dispose() {
    stopPolling();
    _mediaStateController.close();
  }
}

/// * Represents current media playback state
class MediaState {
  final String? track;
  final String? artist;
  final bool isPlaying;
  final Uint8List? thumbnail;

  MediaState({
    this.track,
    this.artist,
    this.isPlaying = false,
    this.thumbnail,
  });

  bool get hasActiveMedia => track != null && track!.isNotEmpty;
}
