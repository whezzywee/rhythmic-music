import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
// ignore: depend_on_referenced_packages
import 'package:rxdart/rxdart.dart';

import '/app/app_branding.dart';
import '/app/app_platform.dart';
import '/core/playback/android_auto_media_library.dart';
import '/core/playback/playback_events.dart';
import '/core/playback/playback_cache_repository.dart';
import '/core/playback/playback_preferences.dart';
import '/core/playback/playback_queue_manager.dart';
import '/core/playback/playback_session_repository.dart';
import '/core/playback/playback_stream_metadata_repository.dart';
import '/core/playback/playback_stream_resolver.dart';
import '/core/storage/app_preferences_store.dart';
import '/core/storage/hive_app_preferences_store.dart';
import '/services/equalizer.dart';
import '/models/hm_streaming_data.dart';
import '/services/permission_service.dart';
import '../utils/helper.dart';
// ignore: unused_import, implementation_imports, depend_on_referenced_packages
import "package:media_kit/src/player/platform_player.dart" show MPVLogLevel;

Future<AudioHandler> initAudioService(
    {AppPreferencesStore? appPreferences,
    PlaybackLabelTranslator? translate,
    PlaybackCacheRepository? cacheRepository,
    PlaybackSessionRepository? sessionRepository,
    PlaybackStreamMetadataRepository? streamMetadataRepository,
    AndroidAutoMediaLibrary? mediaLibrary,
    AppBranding? branding}) async {
  final appBranding = branding ?? const AppBranding();
  final playbackPreferences = PlaybackPreferences(
    appPreferences ?? HiveAppPreferencesStore(),
  );
  return await AudioService.init(
    builder: () => MyAudioHandler(
      preferences: playbackPreferences,
      translate: translate,
      cacheRepository: cacheRepository,
      sessionRepository: sessionRepository,
      streamMetadataRepository: streamMetadataRepository,
      mediaLibrary: mediaLibrary,
      branding: appBranding,
    ),
    config: AudioServiceConfig(
      androidNotificationIcon: 'mipmap/ic_launcher_monochrome',
      androidNotificationChannelId: appBranding.notificationChannelId,
      androidNotificationChannelName: appBranding.notificationChannelName,
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler {
  MyAudioHandler({
    required PlaybackPreferences preferences,
    AppBranding? branding,
    PlaybackLabelTranslator? translate,
    PlaybackCacheRepository? cacheRepository,
    PlaybackSessionRepository? sessionRepository,
    PlaybackStreamMetadataRepository? streamMetadataRepository,
    AndroidAutoMediaLibrary? mediaLibrary,
  })  : _preferences = preferences,
        _branding = branding ?? const AppBranding(),
        _cacheRepository = cacheRepository ?? PlaybackCacheRepository(),
        _sessionRepository = sessionRepository ?? PlaybackSessionRepository(),
        _streamMetadataRepository =
            streamMetadataRepository ?? PlaybackStreamMetadataRepository(),
        _mediaLibrary =
            mediaLibrary ?? AndroidAutoMediaLibrary(translate: translate),
        _queueManager = PlaybackQueueManager(
          shuffleEnabled: preferences.shuffleModeEnabled,
          loopModeEnabled: preferences.loopModeEnabled,
          queueLoopModeEnabled: preferences.queueLoopModeEnabled,
        ) {
    if (AppPlatform.isWindows || AppPlatform.isLinux) {
      JustAudioMediaKit.title = _branding.mediaKitTitle;
      JustAudioMediaKit.protocolWhitelist = const ['http', 'https', 'file'];
    }
    _player = AudioPlayer(
        audioLoadConfiguration: const AudioLoadConfiguration(
            androidLoadControl: AndroidLoadControl(
      minBufferDuration: Duration(seconds: 50),
      maxBufferDuration: Duration(seconds: 120),
      bufferForPlaybackDuration: Duration(milliseconds: 50),
      bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
    )));
    _createCacheDir();
    _addEmptyList();
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToPlaybackForNextSong();
    _listenForSequenceStateChanges();
    _player.setSkipSilenceEnabled(_preferences.skipSilenceEnabled);
    loudnessNormalizationEnabled = _preferences.loudnessNormalizationEnabled;
    _listenForDurationChanges();
    _syncQueueToAudioService();
    if (AppPlatform.isAndroid) {
      _listenSessionIdStream();
    }
  }

  final PlaybackPreferences _preferences;
  final AppBranding _branding;
  // ignore: prefer_typing_uninitialized_variables
  late final _cacheDir;
  late final String _supportDir;
  late AudioPlayer _player;
  final AndroidAutoMediaLibrary _mediaLibrary;
  late String? currentSongUrl;
  bool isPlayingUsingLockCachingSource = false;
  bool loudnessNormalizationEnabled = false;
  bool isSongLoading = true;

  final _playList =
      ConcatenatingAudioSource(children: [], useLazyPreparation: false);
  final PlaybackQueueManager _queueManager;
  final PlaybackCacheRepository _cacheRepository;
  final PlaybackSessionRepository _sessionRepository;
  final PlaybackStreamMetadataRepository _streamMetadataRepository;

  PlaybackStreamResolver get _streamResolver => PlaybackStreamResolver(
        cacheDirectoryPath: _cacheDir,
        supportDirectoryPath: _supportDir,
        storagePermissionChecker: PermissionService.getExtStoragePermission,
      );

  Future<void> _createCacheDir() async {
    _cacheDir = (await getTemporaryDirectory()).path;
    _supportDir = (await getApplicationSupportDirectory()).path;
    if (!Directory("$_cacheDir/cachedSongs/").existsSync()) {
      Directory("$_cacheDir/cachedSongs/").createSync(recursive: true);
    }
  }

  void _addEmptyList() {
    try {
      _player.setAudioSource(_playList);
    } catch (r) {
      printERROR(r.toString());
    }
  }

  void _listenSessionIdStream() {
    _player.androidAudioSessionIdStream.listen((int? id) {
      if (id != null) {
        EqualizerService.initAudioEffect(id);
      }
    });
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: isSongLoading
            ? AudioProcessingState.loading
            : const {
                ProcessingState.idle: AudioProcessingState.idle,
                ProcessingState.loading: AudioProcessingState.loading,
                ProcessingState.buffering: AudioProcessingState.buffering,
                ProcessingState.ready: AudioProcessingState.ready,
                ProcessingState.completed: AudioProcessingState.completed,
              }[_player.processingState]!,
        repeatMode: const {
          LoopMode.off: AudioServiceRepeatMode.none,
          LoopMode.one: AudioServiceRepeatMode.one,
          LoopMode.all: AudioServiceRepeatMode.all,
        }[_player.loopMode]!,
        shuffleMode: (_queueManager.shuffleEnabled)
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _queueManager.currentIndex,
      ));

      //print("set ${playbackState.value.queueIndex},${event.currentIndex}");
    }, onError: (Object e, StackTrace st) async {
      if (e is PlayerException) {
        printERROR('Error code: ${e.code}');
        printERROR('Error message: ${e.message}');
      } else {
        printERROR('An error occurred: $e');
        Duration curPos = _player.position;
        await _player.stop();

        if (isPlayingUsingLockCachingSource &&
            e.toString().contains("Connection closed while receiving data")) {
          await _player.seek(curPos, index: 0);
          await _player.play();
          return;
        }

        //Workaround when 403 error encountered
        // customAction("playByIndex", {'index': currentIndex, 'newUrl': true})
        //     .whenComplete(() async {
        //   await _player.stop();
        //   if (currentSongUrl == null) {
        //     networkErrorPause = true;
        //   } else {
        //     _player.play();
        //   }
        // });
        customAction("playByIndex", {'index': _queueManager.currentIndex, 'newUrl': true});
        await _player.seek(curPos, index: 0);
      }
    });
  }

  void _listenToPlaybackForNextSong() {
    final playerDurationOffset = AppPlatform.isWindows
        ? 200
        : AppPlatform.isLinux
            ? 700
            : 0;
    _player.positionStream.listen((value) async {
      if (_player.duration != null && _player.duration?.inSeconds != 0) {
        if (value.inMilliseconds >=
            (_player.duration!.inMilliseconds - playerDurationOffset)) {
          await _triggerNext();
        }
      }
    });
  }

  Future<void> _triggerNext() async {
    if (_queueManager.loopModeEnabled) {
      await _player.seek(Duration.zero);
      if (!_player.playing) {
        _player.play();
      }
      return;
    }
    skipToNext();
  }

  void _listenForSequenceStateChanges() {
    _player.sequenceStateStream.listen((SequenceState? sequenceState) {
      final sequence = sequenceState?.effectiveSequence;
      if (sequence == null || sequence.isEmpty) return;
    });
  }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) async {
      if (_queueManager.currentIndex == null ||
          _queueManager.isEmpty ||
          duration == null) return;
      final currentSong = _queueManager.currentItem;
      if (currentSong?.duration == null || _queueManager.currentIndex == 0) {
        final newMediaItem = currentSong!.copyWith(duration: duration);
        mediaItem.add(newMediaItem);
      }
    });
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    _queueManager.addAll(mediaItems);
    _syncQueueToAudioService();
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _queueManager.replaceQueue(queue);
    _syncQueueToAudioService();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _queueManager.addOne(mediaItem);
    _syncQueueToAudioService();
  }

  AudioSource _createAudioSource(MediaItem mediaItem) {
    final url = mediaItem.extras!['url'] as String;
    if (url.contains('/cache') ||
        (_preferences.cacheSongs && url.contains("http"))) {
      printINFO("Playing Using LockCaching");
      isPlayingUsingLockCachingSource = true;
      // ignore: experimental_member_use
      return LockCachingAudioSource(
        Uri.parse(url),
        cacheFile: File("$_cacheDir/cachedSongs/${mediaItem.id}.mp3"),
        tag: mediaItem,
      );
    }

    printINFO("Playing Using AudioSource.uri");
    isPlayingUsingLockCachingSource = false;
    return AudioSource.uri(
      Uri.tryParse(url)!,
      tag: mediaItem,
    );
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<void> removeQueueItem(MediaItem mediaItem_) async {
    _queueManager.remove(mediaItem_);
    _syncQueueToAudioService();
  }

  @override
  Future<void> play() async {
    if (currentSongUrl == null ||
        (AppPlatform.isDesktop &&
            (_player.duration == null ||
                _player.duration?.inMilliseconds == 0))) {
      await customAction("playByIndex", {'index': _queueManager.currentIndex});
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queueManager.length) return;
    await customAction("playByIndex", {'index': index});
  }

  @override
  Future<void> skipToNext() async {
    final index = _queueManager.nextIndex();
    if (index != _queueManager.currentIndex) {
      if (_player.position != Duration.zero) _player.seek(Duration.zero);
      await customAction("playByIndex", {'index': index});
    } else {
      _player.seek(Duration.zero);
      _player.pause();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inMilliseconds > 5000) {
      _player.seek(Duration.zero);
      return;
    }
    _player.seek(Duration.zero);
    final index = _queueManager.previousIndex(_player.position);
    if (index != _queueManager.currentIndex) {
      await customAction("playByIndex", {'index': index});
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _queueManager.loopModeEnabled = repeatMode != AudioServiceRepeatMode.none;
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      _queueManager.shuffleEnabled = false;
    } else {
      _queueManager.shuffleEnabled = true;
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'dispose':
        await _player.dispose();
        super.stop();
        break;

      case 'playByIndex':
        final songIndex = extras!['index'];
        _queueManager.jumpToIndex(songIndex);
        final isNewUrlReq = extras['newUrl'] ?? false;
        final currentSong = _queueManager.currentItem!;
        final futureStreamInfo =
            checkNGetUrl(currentSong.id, generateNewUrl: isNewUrlReq);
        final bool restoreSession = extras['restoreSession'] ?? false;
        isSongLoading = true;
        playbackState.add(playbackState.value
            .copyWith(processingState: AudioProcessingState.loading));
        if (_playList.children.isNotEmpty) {
          await _playList.clear();
        }

        mediaItem.add(currentSong);
        final streamInfo = await futureStreamInfo;
        if (songIndex != _queueManager.currentIndex) {
          return;
        } else if (!streamInfo.playable) {
          currentSongUrl = null;
          isSongLoading = false;
          _emitPlaybackError(streamInfo.statusMSG);
          playbackState.add(playbackState.value.copyWith(
              processingState: AudioProcessingState.error,
              errorCode: 404,
              errorMessage: streamInfo.statusMSG));
          return;
        }
        currentSongUrl = currentSong.extras!['url'] = streamInfo.audio!.url;
        playbackState.add(
            playbackState.value.copyWith(queueIndex: _queueManager.currentIndex));
        await _playList.add(_createAudioSource(currentSong));

        isSongLoading = false;
        if (loudnessNormalizationEnabled && AppPlatform.isAndroid) {
          _normalizeVolume(streamInfo.audio!.loudnessDb);
        }

        if (restoreSession) {
          if (!AppPlatform.isDesktop) {
            final position = extras['position'];
            await _player.load();
            await _player.seek(
              Duration(
                milliseconds: position,
              ),
            );
            await _player.seek(
              Duration(
                milliseconds: position,
              ),
            );
          }
        } else {
          await _player.play();
        }
        break;

      case 'checkWithCacheDb':
        if (isPlayingUsingLockCachingSource) {
          final song = extras!['mediaItem'] as MediaItem;
          final cachedSong = await _cacheRepository.saveBufferedSong(
            song: song,
            cacheDirectoryPath: _cacheDir,
            currentSongUrl: currentSongUrl,
            duration: _player.duration,
          );
          if (cachedSong != null) {
            _emitSongCached(cachedSong);
          }
        }
        break;

      case 'setSourceNPlay':
        final currMed = (extras!['mediaItem'] as MediaItem);
        final futureStreamInfo = checkNGetUrl(currMed.id);
        isSongLoading = true;
        await _playList.clear();
        _queueManager.replaceQueue([currMed]);
        _syncQueueToAudioService();
        mediaItem.add(currMed);
        final streamInfo = (await futureStreamInfo);
        if (!streamInfo.playable) {
          currentSongUrl = null;
          isSongLoading = false;
          _emitPlaybackError(streamInfo.statusMSG);
          playbackState.add(playbackState.value
              .copyWith(processingState: AudioProcessingState.error));
          return;
        }
        currentSongUrl = currMed.extras!['url'] = streamInfo.audio!.url;

        await _playList.add(_createAudioSource(currMed));
        isSongLoading = false;

        // Normalize audio
        if (loudnessNormalizationEnabled && AppPlatform.isAndroid) {
          _normalizeVolume(streamInfo.audio!.loudnessDb);
        }

        await _player.play();
        break;

      case 'toggleSkipSilence':
        final enable = (extras!['enable'] as bool);
        await _player.setSkipSilenceEnabled(enable);
        break;

      case 'toggleLoudnessNormalization':
        loudnessNormalizationEnabled = (extras!['enable'] as bool);
        if (!loudnessNormalizationEnabled) {
          _player.setVolume(1.0);
          return;
        }

        if (loudnessNormalizationEnabled) {
          try {
            final currentSongId = _queueManager.currentItem!.id;
            final loudnessDb =
                _streamMetadataRepository.loudnessDbForSong(currentSongId);
            if (loudnessDb != null) {
              _normalizeVolume(loudnessDb);
            }
          } catch (e) {
            printERROR(e);
          }
        }
        break;

      case 'shuffleQueue':
        _queueManager.shuffleCurrentQueue();
        _syncQueueToAudioService();
        break;

      case 'reorderQueue':
        final oldIndex = extras!['oldIndex'];
        int newIndex = extras['newIndex'];
        _queueManager.reorder(oldIndex, newIndex);
        _syncQueueToAudioService();
        break;

      case 'addPlayNextItem':
        final song = extras!['mediaItem'] as MediaItem;
        _queueManager.insertAfterCurrent(song);
        _syncQueueToAudioService();
        break;

      case 'openEqualizer':
        EqualizerService.openEqualizer(_player.androidAudioSessionId!);
        break;

      case 'saveSession':
        await saveSessionData();
        break;

      case 'setVolume':
        _player.setVolume(extras!['value'] / 100);
        break;

      case 'shuffleCmd':
        final songIndex = extras!['index'];
        _queueManager.jumpToIndex(songIndex);
        _queueManager.shuffleEnabled = true;
        break;

      case 'upadateMediaItemInAudioService':
        //added to update media item from player controller
        final songIndex = extras!['index'];
        _queueManager.jumpToIndex(songIndex);
        mediaItem.add(_queueManager.currentItem);
        break;

      case 'toggleQueueLoopMode':
        _queueManager.queueLoopModeEnabled = extras!['enable'];
        break;

      case 'clearQueue':
        _queueManager.clearExceptCurrent();
        _syncQueueToAudioService();
        break;
      default:
        break;
    }
  }

  void _emitPlaybackError(String message) {
    customEvent.add({
      PlaybackEventKey.eventType: PlaybackEventType.playbackError,
      PlaybackEventKey.message: message,
    });
  }

  void _emitSongCached(MediaItem song) {
    customEvent.add({
      PlaybackEventKey.eventType: PlaybackEventType.songCached,
      PlaybackEventKey.mediaItem: song,
    });
  }

  Future<void> _requestHomeCacheRefresh() async {
    final completion = Completer<void>();
    customEvent.add({
      PlaybackEventKey.eventType: PlaybackEventType.homeCacheRequested,
      PlaybackEventKey.completion: completion,
    });

    await completion.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
  }

  void _normalizeVolume(double currentLoudnessDb) {
    double loudnessDifference = -5 - currentLoudnessDb;

    // Converted loudness difference to a volume multiplier
    // We use a factor to convert dB difference to a linear scale
    // 10^(difference / 20) converts dB difference to a linear volume factor
    final volumeAdjustment = pow(10.0, loudnessDifference / 20.0);
    printINFO(
        "loudness:$currentLoudnessDb Normalized volume: $volumeAdjustment");
    _player.setVolume(volumeAdjustment.toDouble().clamp(0, 1.0));
  }

  void _syncQueueToAudioService() {
    queue.add(_queueManager.queue);
    mediaItem.add(_queueManager.currentItem);
  }

  Future<void> saveSessionData() async {
    await _sessionRepository.save(
      queue: _queueManager.queue,
      currentIndex: _queueManager.currentIndex ?? 0,
      positionMillis: _player.position.inMilliseconds,
    );
  }

  /// Android Auto
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    return _mediaLibrary.getByRootId(parentMediaId);
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    return Stream.fromFuture(
            _mediaLibrary.getByRootId(parentMediaId).then((items) => items))
        .map((_) => <String, dynamic>{})
        .shareValue();
  }

  // only for Android Auto
  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    customEvent.add({
      PlaybackEventKey.eventType: PlaybackEventType.playFromMediaId,
      PlaybackEventKey.songId: mediaId,
      PlaybackEventKey.libraryId: extras![PlaybackEventKey.libraryId],
    });
  }

  @override
  Future<void> onTaskRemoved() async {
    if (_preferences.stopPlaybackOnSwipeAway) {
      await _requestHomeCacheRefresh();
      await saveSessionData();
      await stop();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

// Work around used [useNewInstanceOfExplode = false] to Fix Connection closed before full header was received issue
  Future<HMStreamingData> checkNGetUrl(String songId,
      {bool generateNewUrl = false, bool offlineReplacementUrl = false}) async {
    return _streamResolver.resolve(
      songId,
      generateNewUrl: generateNewUrl,
      offlineReplacementUrl: offlineReplacementUrl,
    );
  }
}

class UrlError extends Error {
  String message() => 'Unable to fetch url';
}
