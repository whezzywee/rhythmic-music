import '/models/hm_streaming_data.dart';

/// Abstract store for stream resolution — song download records,
/// cached stream URLs, and stream metadata the [PlaybackStreamResolver]
/// reads during playback.
abstract class StreamCacheStore {
  /// Whether a download record exists for [songId].
  bool hasDownload(String songId);

  /// The full download record for [songId], or `null`.
  dynamic getDownload(String songId);

  /// Whether the play-cache box contains [songId].
  bool hasCachedSong(String songId);

  /// The cache metadata for [songId], or `null`.
  dynamic getCachedSong(String songId);

  /// Whether a cached stream URL record exists for [songId].
  bool hasStreamUrl(String songId);

  /// The cached stream metadata for [songId], or `null`.
  dynamic getStreamUrl(String songId);

  /// Persist a resolved stream result so it can be reused.
  Future<void> putStreamUrl(String songId, HMStreamingData data);
}
