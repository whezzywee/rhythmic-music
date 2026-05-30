import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';

import '../../ui/player/player_controller.dart';
import 'session_host.dart';
import 'session_client.dart';
import 'sync_messages.dart';

enum MusicTogetherRole { none, host, peer }

class SyncController extends GetxController {
  final SessionHost sessionHost = SessionHost();
  final SessionClient sessionClient = SessionClient();

  MusicTogetherRole role = MusicTogetherRole.none;

  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _mediaItemSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _hostMessageSubscription;
  StreamSubscription? _clientMessageSubscription;

  bool _isApplyingRemoteChange = false;
  String? _lastTrackId;

  PlayerController? get _playerController {
    try {
      return Get.find<PlayerController>();
    } catch (_) {
      return null;
    }
  }

  AudioHandler? get _audioHandler {
    try {
      return Get.find<AudioHandler>();
    } catch (_) {
      return null;
    }
  }

  void startHosting() {
    role = MusicTogetherRole.host;
    _listenForLocalChanges();
  }

  void stopHosting() {
    role = MusicTogetherRole.none;
    _playbackStateSubscription?.cancel();
    _playbackStateSubscription = null;
    _mediaItemSubscription?.cancel();
    _mediaItemSubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _hostMessageSubscription?.cancel();
    _hostMessageSubscription = null;
  }

  void startPeering() {
    role = MusicTogetherRole.peer;
    _listenForRemoteChanges();
  }

  void stopPeering() {
    role = MusicTogetherRole.none;
    _clientMessageSubscription?.cancel();
    _clientMessageSubscription = null;
  }

  void _listenForLocalChanges() {
    final ah = _audioHandler;
    if (ah == null) return;

    _mediaItemSubscription = ah.mediaItem.listen((item) {
      if (item == null || _isApplyingRemoteChange) return;

      final currentTrackId = item.id;
      if (currentTrackId != _lastTrackId) {
        _lastTrackId = currentTrackId;
        sessionHost.broadcastTrackChange(
          trackId: currentTrackId,
          trackTitle: item.title,
          trackArtist: item.artist ?? '',
        );
      }
    });

    _playbackStateSubscription = ah.playbackState.listen((state) {
      if (_isApplyingRemoteChange) return;

      final pc = _playerController;
      final item = pc?.currentSong.value;
      if (item == null) return;

      sessionHost.broadcastPlaybackState(
        trackId: item.id,
        trackTitle: item.title,
        trackArtist: item.artist ?? '',
        positionMs: state.updatePosition.inMilliseconds,
        isPlaying: state.playing,
      );
    });

    _positionSubscription = Stream.periodic(const Duration(seconds: 2)).listen((_) {
      if (_isApplyingRemoteChange) return;

      final pc = _playerController;
      if (pc == null) return;
      final item = pc.currentSong.value;
      if (item == null) return;

      sessionHost.broadcastPlaybackState(
        trackId: item.id,
        trackTitle: item.title,
        trackArtist: item.artist ?? '',
        positionMs: pc.progressBarStatus.value.current.inMilliseconds,
        isPlaying: pc.buttonState.value == PlayButtonState.playing,
      );
    });

    _hostMessageSubscription = sessionHost.messageStream.listen((message) {
      if (role != MusicTogetherRole.host) return;
      _handleIncomingMessage(message, fromHost: true);
    });
  }

  void _listenForRemoteChanges() {
    _clientMessageSubscription = sessionClient.messageStream.listen((message) {
      if (role != MusicTogetherRole.peer) return;
      _handleIncomingMessage(message, fromHost: false);
    });
  }

  void _handleIncomingMessage(SyncMessage message, {required bool fromHost}) {
    if (_isApplyingRemoteChange) return;

    _isApplyingRemoteChange = true;
    final ah = _audioHandler;
    if (ah == null) {
      _isApplyingRemoteChange = false;
      return;
    }

    switch (message.type) {
      case SyncMessageType.trackChange:
        _handleRemoteTrackChange(message, ah);
        break;

      case SyncMessageType.control:
        _handleRemoteControl(message, ah);
        break;

      case SyncMessageType.playbackState:
        _handleRemotePlaybackState(message, ah);
        break;

      default:
        break;
    }

    _isApplyingRemoteChange = false;
  }

  void _handleRemoteTrackChange(SyncMessage message, AudioHandler ah) {
    final trackId = message.data['track_id'] as String?;
    if (trackId == null || trackId == _lastTrackId) {
      _isApplyingRemoteChange = false;
      return;
    }

    _lastTrackId = trackId;
    final pc = _playerController;
    if (pc == null) return;

    final queue = pc.currentQueue;
    final index = queue.indexWhere((item) => item.id == trackId);
    if (index >= 0) {
      ah.skipToQueueItem(index);
    }
  }

  void _handleRemoteControl(SyncMessage message, AudioHandler ah) {
    final action = message.data['action'] as String?;
    if (action == null) {
      _isApplyingRemoteChange = false;
      return;
    }

    switch (action) {
      case 'play':
        ah.play();
        break;
      case 'pause':
        ah.pause();
        break;
      case 'seek':
        final seekMs = message.data['seek_ms'] as int?;
        if (seekMs != null) {
          ah.seek(Duration(milliseconds: seekMs));
        }
        break;
    }
  }

  void _handleRemotePlaybackState(SyncMessage message, AudioHandler ah) {
    final isPlaying = message.data['is_playing'] as bool?;
    final trackId = message.data['track_id'] as String?;
    final positionMs = message.data['position_ms'] as int?;

    if (trackId != null && trackId != _lastTrackId) {
      _lastTrackId = trackId;
      final pc = _playerController;
      if (pc != null) {
        final queue = pc.currentQueue;
        final index = queue.indexWhere((item) => item.id == trackId);
        if (index >= 0) {
          ah.skipToQueueItem(index);
        }
      }
    }

    if (isPlaying != null) {
      if (isPlaying) {
        ah.play();
      } else {
        ah.pause();
      }
    }

    if (positionMs != null && positionMs > 0 && isPlaying != true) {
      ah.seek(Duration(milliseconds: positionMs));
    }
  }

  Future<void> disconnect() async {
    stopHosting();
    stopPeering();
    sessionClient.disconnect();
    await sessionHost.stop();
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
}
