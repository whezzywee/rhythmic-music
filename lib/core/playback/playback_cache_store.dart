import 'package:audio_service/audio_service.dart';

/// Abstract store for playback cache — write buffered songs to the
/// local song-cache box so they survive restarts.
abstract class PlaybackCacheStore {
  /// Persist a buffered song, returning the updated [MediaItem]
  /// if it was actually stored, or `null` otherwise.
  Future<MediaItem?> saveBufferedSong({
    required MediaItem song,
    required String cacheDirectoryPath,
    required String? currentSongUrl,
    required Duration? duration,
  });
}
