/// Centralised branding values used by the app shell, audio service,
/// and desktop media-kit integration.
///
/// Change these values in a single place when rebranding the app.
class AppBranding {
  const AppBranding({
    this.appName = 'Rhythmic Music',
    this.notificationChannelId = 'com.mycompany.myapp.audio',
    this.notificationChannelName = 'Rhythmic Music',
    this.mediaKitTitle = 'Rhythmic Music',
  });

  /// Display name shown in the Flutter title bar and OS app switcher.
  final String appName;

  /// Android notification channel ID (must be unique per app).
  final String notificationChannelId;

  /// Human-readable notification channel name shown in Android settings.
  final String notificationChannelName;

  /// Title reported by the media-kit desktop backend (Windows/Linux).
  final String mediaKitTitle;
}
