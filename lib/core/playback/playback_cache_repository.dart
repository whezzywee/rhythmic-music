import 'package:audio_service/audio_service.dart';

import '/core/storage/app_preferences_store.dart';
import '/core/storage/hive_app_preferences_store.dart';
import 'hive_playback_cache_store.dart';
import 'playback_cache_store.dart';

class PlaybackCacheRepository {
  PlaybackCacheRepository({
    PlaybackCacheStore? cacheStore,
    AppPreferencesStore? appPreferences,
  })  : _cacheStore =
            cacheStore ?? HivePlaybackCacheStore(appPreferences: appPreferences ?? HiveAppPreferencesStore());

  final PlaybackCacheStore _cacheStore;

  Future<MediaItem?> saveBufferedSong({
    required MediaItem song,
    required String cacheDirectoryPath,
    required String? currentSongUrl,
    required Duration? duration,
  }) {
    return _cacheStore.saveBufferedSong(
      song: song,
      cacheDirectoryPath: cacheDirectoryPath,
      currentSongUrl: currentSongUrl,
      duration: duration,
    );
  }
}
