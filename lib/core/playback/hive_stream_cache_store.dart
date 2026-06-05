import 'package:hive/hive.dart';

import '/models/hm_streaming_data.dart';
import 'stream_cache_store.dart';

class HiveStreamCacheStore implements StreamCacheStore {
  HiveStreamCacheStore();

  Box get _downloads => Hive.box('SongDownloads');
  Box get _songsCache => Hive.box('SongsCache');
  Box get _urlCache => Hive.box('SongsUrlCache');

  @override
  bool hasDownload(String songId) => _downloads.containsKey(songId);

  @override
  dynamic getDownload(String songId) => _downloads.get(songId);

  @override
  bool hasCachedSong(String songId) => _songsCache.containsKey(songId);

  @override
  dynamic getCachedSong(String songId) => _songsCache.get(songId);

  @override
  bool hasStreamUrl(String songId) => _urlCache.containsKey(songId);

  @override
  dynamic getStreamUrl(String songId) => _urlCache.get(songId);

  @override
  Future<void> putStreamUrl(String songId, HMStreamingData data) async {
    await _urlCache.put(songId, data.toJson());
  }
}
