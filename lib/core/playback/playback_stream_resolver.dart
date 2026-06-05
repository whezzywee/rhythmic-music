import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '/core/storage/app_preferences_store.dart';
import '/core/storage/hive_app_preferences_store.dart';
import '/models/hm_streaming_data.dart';
import '/services/background_task.dart';
import '/services/stream_service.dart';
import '/services/utils.dart';
import '/utils/helper.dart';
import 'hive_stream_cache_store.dart';
import 'stream_cache_store.dart';

typedef StoragePermissionChecker = Future<bool> Function();

class PlaybackStreamResolver {
  PlaybackStreamResolver({
    required this.cacheDirectoryPath,
    required this.supportDirectoryPath,
    required StoragePermissionChecker storagePermissionChecker,
    StreamCacheStore? streamCacheStore,
    AppPreferencesStore? appPreferences,
  })  : _storagePermissionChecker = storagePermissionChecker,
        _streamCacheStore = streamCacheStore ?? HiveStreamCacheStore(),
        _appPreferences = appPreferences ?? HiveAppPreferencesStore();

  final String cacheDirectoryPath;
  final String supportDirectoryPath;
  final StoragePermissionChecker _storagePermissionChecker;
  final StreamCacheStore _streamCacheStore;
  final AppPreferencesStore _appPreferences;

  Future<HMStreamingData> resolve(
    String songId, {
    bool generateNewUrl = false,
    bool offlineReplacementUrl = false,
  }) async {
    printINFO('Requested id : $songId');

    if (!offlineReplacementUrl && _streamCacheStore.hasCachedSong(songId)) {
      return _resolveCachedSong(songId);
    }

    if (!offlineReplacementUrl && _streamCacheStore.hasDownload(songId)) {
      return _resolveDownloadedSong(
        songId,
        _streamCacheStore.getDownload(songId),
      );
    }

    return _resolveOnlineStream(
      songId,
      generateNewUrl: generateNewUrl,
    );
  }

  HMStreamingData _resolveCachedSong(String songId) {
    printINFO('Got Song from cachedbox ($songId)');
    final cachedData = _streamCacheStore.getCachedSong(songId);
    final streamInfo = cachedData['streamInfo'] as Map<String, dynamic>?;
    Audio? cacheAudioPlaceholder;

    if (streamInfo != null && streamInfo.isNotEmpty) {
      streamInfo[1]['url'] = 'file://$cacheDirectoryPath/cachedSongs/$songId.mp3';
      cacheAudioPlaceholder = Audio.fromJson(streamInfo[1]);
    } else {
      cacheAudioPlaceholder = Audio(
        audioCodec: Codec.mp4a,
        bitrate: 0,
        loudnessDb: 0,
        duration: 0,
        size: 0,
        url: 'file://$cacheDirectoryPath/cachedSongs/$songId.mp3',
        itag: 0,
      );
    }

    return HMStreamingData(
      playable: true,
      statusMSG: 'OK',
      lowQualityAudio: cacheAudioPlaceholder,
      highQualityAudio: cacheAudioPlaceholder,
    );
  }

  Future<HMStreamingData> _resolveDownloadedSong(
    String songId,
    dynamic song,
  ) async {
    final streamInfoJson = song['streamInfo'];
    final path = song['url'];
    final Audio audio;

    if (streamInfoJson != null && streamInfoJson.isNotEmpty) {
      audio = Audio.fromJson(streamInfoJson[1]);
    } else {
      audio = Audio(
        itag: 140,
        audioCodec: Codec.mp4a,
        bitrate: 0,
        duration: 0,
        loudnessDb: 0,
        url: path,
        size: 0,
      );
    }

    final streamInfo = HMStreamingData(
      playable: true,
      statusMSG: 'OK',
      highQualityAudio: audio,
      lowQualityAudio: audio,
    );

    if (path.contains('$supportDirectoryPath/Music')) {
      return streamInfo;
    }

    final status = await _storagePermissionChecker();
    if (status && await File(path).exists()) {
      return streamInfo;
    }

    return resolve(songId, offlineReplacementUrl: true);
  }

  Future<HMStreamingData> _resolveOnlineStream(
    String songId, {
    required bool generateNewUrl,
  }) async {
    final qualityIndex =
        _appPreferences.get('streamingQuality', defaultValue: 1) ?? 1;
    HMStreamingData? streamInfo;

    if (_streamCacheStore.hasStreamUrl(songId) && !generateNewUrl) {
      final streamInfoJson = _streamCacheStore.getStreamUrl(songId);
      if (streamInfoJson is Map &&
          !isExpired(url: (streamInfoJson['lowQualityAudio']['url']))) {
        printINFO('Got cached Url ($songId)');
        streamInfo = HMStreamingData.fromJson(streamInfoJson);
      }
    }

    if (streamInfo == null) {
      final token = RootIsolateToken.instance;
      final streamInfoJson =
          await Isolate.run(() => getStreamInfo(songId, token));
      streamInfo = HMStreamingData.fromJson(streamInfoJson);
      if (streamInfo.playable) {
        await _streamCacheStore.putStreamUrl(songId, streamInfo);
      }
    }

    streamInfo.setQualityIndex(qualityIndex as int);
    return streamInfo;
  }
}
