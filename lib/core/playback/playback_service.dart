import 'package:audio_service/audio_service.dart';

class PlaybackProgress {
  const PlaybackProgress({
    required this.current,
    required this.buffered,
    required this.total,
  });

  final Duration current;
  final Duration buffered;
  final Duration total;
}

class PlaybackService {
  PlaybackService(this._audioHandler);

  final AudioHandler _audioHandler;

  Stream<List<MediaItem>> get queue => _audioHandler.queue;
  Stream<MediaItem?> get currentItem => _audioHandler.mediaItem;
  Stream<PlaybackState> get state => _audioHandler.playbackState;
  Stream<dynamic> get events => _audioHandler.customEvent;
  Stream<PlaybackProgress> get progress async* {
    MediaItem? currentItem = _audioHandler.mediaItem.valueOrNull;
    yield _progressFromState(_audioHandler.playbackState.value, currentItem);

    await for (final state in _audioHandler.playbackState) {
      currentItem = _audioHandler.mediaItem.valueOrNull ?? currentItem;
      yield _progressFromState(state, currentItem);
    }
  }

  PlaybackProgress _progressFromState(PlaybackState state, MediaItem? item) {
    return PlaybackProgress(
      current: state.position,
      buffered: state.bufferedPosition,
      total: item?.duration ?? Duration.zero,
    );
  }

  Future<void> play() => _audioHandler.play();

  Future<void> pause() => _audioHandler.pause();

  Future<void> stop() => _audioHandler.stop();

  Future<void> seek(Duration position) => _audioHandler.seek(position);

  Future<void> next() => _audioHandler.skipToNext();

  Future<void> previous() => _audioHandler.skipToPrevious();

  Future<void> playIndex(int index, {bool refreshStreamUrl = false}) {
    return _audioHandler.customAction('playByIndex', {
      'index': index,
      if (refreshStreamUrl) 'newUrl': true,
    });
  }

  Future<void> playSong(MediaItem song) {
    return _audioHandler.customAction('setSourceNPlay', {'mediaItem': song});
  }

  Future<void> playQueue(
    List<MediaItem> songs, {
    int startIndex = 0,
    bool refreshStreamUrl = false,
  }) async {
    if (songs.isEmpty) return;
    await _audioHandler.updateQueue(songs);
    await playIndex(startIndex, refreshStreamUrl: refreshStreamUrl);
  }

  Future<void> addToQueue(MediaItem song) {
    return _audioHandler.addQueueItem(song);
  }

  Future<void> addAllToQueue(List<MediaItem> songs) {
    return _audioHandler.addQueueItems(songs);
  }

  Future<void> playNext(MediaItem song) {
    return _audioHandler.customAction('addPlayNextItem', {'mediaItem': song});
  }

  Future<void> removeFromQueue(MediaItem song) {
    return _audioHandler.removeQueueItem(song);
  }

  Future<void> moveQueueItem({
    required int oldIndex,
    required int newIndex,
  }) {
    return _audioHandler.customAction('reorderQueue', {
      'oldIndex': oldIndex,
      'newIndex': newIndex,
    });
  }

  Future<void> clearQueue() {
    return _audioHandler.customAction('clearQueue');
  }

  Future<void> shuffleCurrentQueue() {
    return _audioHandler.customAction('shuffleQueue');
  }

  Future<void> setShuffleEnabled(bool enabled) {
    return _audioHandler.setShuffleMode(
      enabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
  }

  Future<void> setSongRepeatEnabled(bool enabled) {
    return _audioHandler.setRepeatMode(
      enabled ? AudioServiceRepeatMode.one : AudioServiceRepeatMode.none,
    );
  }

  Future<void> setQueueLoopEnabled(bool enabled) {
    return _audioHandler.customAction(
      'toggleQueueLoopMode',
      {'enable': enabled},
    );
  }

  Future<void> setVolume(double percent) {
    return _audioHandler.customAction('setVolume', {'value': percent});
  }

  Future<void> setSkipSilenceEnabled(bool enabled) {
    return _audioHandler.customAction('toggleSkipSilence', {'enable': enabled});
  }

  Future<void> setLoudnessNormalizationEnabled(bool enabled) {
    return _audioHandler.customAction(
      'toggleLoudnessNormalization',
      {'enable': enabled},
    );
  }

  Future<void> saveSession() {
    return _audioHandler.customAction('saveSession');
  }
}
