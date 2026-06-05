import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';

import '/models/media_Item_builder.dart';
import '/core/storage/app_preferences_store.dart';
import 'playback_cache_store.dart';

class HivePlaybackCacheStore implements PlaybackCacheStore {
  HivePlaybackCacheStore({required AppPreferencesStore appPreferences})
      : _appPreferences = appPreferences;

  final AppPreferencesStore _appPreferences;

  @override
  Future<MediaItem?> saveBufferedSong({
    required MediaItem song,
    required String cacheDirectoryPath,
    required String? currentSongUrl,
    required Duration? duration,
  }) async {
    final songsCacheBox = Hive.box('SongsCache');
    final cacheFile = File('$cacheDirectoryPath/cachedSongs/${song.id}.mp3');

    if (songsCacheBox.containsKey(song.id) || !await cacheFile.exists()) {
      return null;
    }

    song.extras!['url'] = currentSongUrl;
    song.extras!['date'] = DateTime.now().millisecondsSinceEpoch;

    final dbStreamData = Hive.box('SongsUrlCache').get(song.id);
    final jsonData = MediaItemBuilder.toJson(song);
    jsonData['duration'] = duration?.inSeconds;
    jsonData['streamInfo'] = dbStreamData != null
        ? [
            true,
            dbStreamData[
                _appPreferences.get('streamingQuality') == 0
                    ? 'lowQualityAudio'
                    : 'highQualityAudio']
          ]
        : null;

    await songsCacheBox.put(song.id, jsonData);
    return song;
  }
}
