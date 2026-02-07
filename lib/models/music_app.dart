import "package:flutter/material.dart";

/// * Supported music apps for SmartRoad's music app picker.
/// *
/// * Note:
/// * - SmartRoad only shows apps that are installed on the device.
/// * - On Android, we launch apps by package name for reliability.
class MusicAppDescriptor {
  /// * Stable id stored in local preferences (e.g., "spotify").
  final String id;

  /// * Human-friendly label shown in the picker/settings.
  final String displayName;

  /// * Android package used to detect and launch the app.
  final String androidPackageName;

  /// * Icon used when official logos are unavailable.
  final IconData icon;

  /// * Accent color used subtly in the picker UI.
  final Color accentColor;

  /// * Play Store URL used as a fallback when the app is not installed.
  final String playStoreUrl;

  const MusicAppDescriptor({
    required this.id,
    required this.displayName,
    required this.androidPackageName,
    required this.icon,
    required this.accentColor,
    required this.playStoreUrl,
  });

  Uri get playStoreUri => Uri.parse(playStoreUrl);

  /// * Curated list of apps commonly used for driving.
  /// * Keep this list small to avoid Android package visibility issues.
  static const List<MusicAppDescriptor> supported = [
    MusicAppDescriptor(
      id: "spotify",
      displayName: "Spotify",
      androidPackageName: "com.spotify.music",
      icon: Icons.graphic_eq_rounded,
      accentColor: Color(0xFF1DB954),
      playStoreUrl:
          "https://play.google.com/store/apps/details?id=com.spotify.music",
    ),
    MusicAppDescriptor(
      id: "youtube_music",
      displayName: "YouTube Music",
      androidPackageName: "com.google.android.apps.youtube.music",
      icon: Icons.play_circle_fill_rounded,
      accentColor: Color(0xFFFF0033),
      playStoreUrl:
          "https://play.google.com/store/apps/details?id=com.google.android.apps.youtube.music",
    ),
    MusicAppDescriptor(
      id: "youtube",
      displayName: "YouTube",
      androidPackageName: "com.google.android.youtube",
      icon: Icons.ondemand_video_rounded,
      accentColor: Color(0xFFFF0000),
      playStoreUrl:
          "https://play.google.com/store/apps/details?id=com.google.android.youtube",
    ),
    MusicAppDescriptor(
      id: "apple_music",
      displayName: "Apple Music",
      androidPackageName: "com.apple.android.music",
      icon: Icons.library_music_rounded,
      accentColor: Color(0xFFFF2D55),
      playStoreUrl:
          "https://play.google.com/store/apps/details?id=com.apple.android.music",
    ),
    MusicAppDescriptor(
      id: "soundcloud",
      displayName: "SoundCloud",
      androidPackageName: "com.soundcloud.android",
      icon: Icons.cloud_rounded,
      accentColor: Color(0xFFFF5500),
      playStoreUrl:
          "https://play.google.com/store/apps/details?id=com.soundcloud.android",
    ),
    MusicAppDescriptor(
      id: "deezer",
      displayName: "Deezer",
      androidPackageName: "deezer.android.app",
      icon: Icons.multitrack_audio_rounded,
      accentColor: Color(0xFF00C7F2),
      playStoreUrl:
          "https://play.google.com/store/apps/details?id=deezer.android.app",
    ),
    MusicAppDescriptor(
      id: "amazon_music",
      displayName: "Amazon Music",
      androidPackageName: "com.amazon.mp3",
      icon: Icons.shopping_bag_rounded,
      accentColor: Color(0xFF00A8E1),
      playStoreUrl:
          "https://play.google.com/store/apps/details?id=com.amazon.mp3",
    ),
    MusicAppDescriptor(
      id: "samsung_music",
      displayName: "Samsung Music",
      androidPackageName: "com.samsung.android.app.music",
      icon: Icons.queue_music_rounded,
      accentColor: Color(0xFF2D8CFF),
      playStoreUrl:
          "https://play.google.com/store/apps/details?id=com.samsung.android.app.music",
    ),
    MusicAppDescriptor(
      id: "vlc",
      displayName: "VLC",
      androidPackageName: "org.videolan.vlc",
      icon: Icons.play_circle_outline_rounded,
      accentColor: Color(0xFFFF8800),
      playStoreUrl:
          "https://play.google.com/store/apps/details?id=org.videolan.vlc",
    ),
  ];

  static MusicAppDescriptor? fromId(String? id) {
    final normalized = id?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;

    for (final app in supported) {
      if (app.id == normalized) return app;
    }
    return null;
  }
}

