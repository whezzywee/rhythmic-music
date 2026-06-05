import 'package:audio_service/audio_service.dart';

import '/core/storage/app_preferences_store.dart';
import '/core/storage/hive_app_preferences_store.dart';
import 'hive_playback_session_store.dart';
import 'playback_session_store.dart';

// Re-export PlaybackSessionSnapshot for backward compatibility.
export 'playback_session_store.dart' show PlaybackSessionSnapshot;

class PlaybackSessionRepository {
  PlaybackSessionRepository({
    PlaybackSessionStore? sessionStore,
    AppPreferencesStore? appPreferences,
  })  : _sessionStore = sessionStore ??
            HivePlaybackSessionStore(
                appPreferences: appPreferences ?? HiveAppPreferencesStore());

  final PlaybackSessionStore _sessionStore;

  bool get restoreSessionEnabled => _sessionStore.restoreEnabled;

  Future<void> save({
    required List<MediaItem> queue,
    required int currentIndex,
    required int positionMillis,
  }) {
    return _sessionStore.save(
      queue: queue,
      currentIndex: currentIndex,
      positionMillis: positionMillis,
    );
  }

  Future<PlaybackSessionSnapshot?> restoreIfEnabled() {
    return _sessionStore.restore();
  }
}
