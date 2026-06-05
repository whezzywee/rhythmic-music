import 'package:hive/hive.dart';

class PlaybackStreamMetadataRepository {
  double? loudnessDbForSong(String songId) {
    final cachedLoudness = _cachedUrlLoudnessDb(songId);
    if (cachedLoudness != null) return cachedLoudness;
    return _downloadedSongLoudnessDb(songId);
  }

  double? _cachedUrlLoudnessDb(String songId) {
    final songsUrlCacheBox = Hive.box('SongsUrlCache');
    if (!songsUrlCacheBox.containsKey(songId)) return null;

    final songJson = songsUrlCacheBox.get(songId);
    if (songJson is! Map) return null;
    final highQualityAudio = songJson['highQualityAudio'];
    if (highQualityAudio is! Map) return null;
    return _toDouble(highQualityAudio['loudnessDb']);
  }

  double? _downloadedSongLoudnessDb(String songId) {
    final songDownloadsBox = Hive.box('SongDownloads');
    if (!songDownloadsBox.containsKey(songId)) return null;

    final songJson = songDownloadsBox.get(songId);
    if (songJson is! Map) return null;
    final streamInfo = songJson['streamInfo'];
    if (streamInfo is! List || streamInfo.length < 2) return 0;
    final audioJson = streamInfo[1];
    if (audioJson is! Map) return 0;
    return _toDouble(audioJson['loudnessDb']) ?? 0;
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }
}
