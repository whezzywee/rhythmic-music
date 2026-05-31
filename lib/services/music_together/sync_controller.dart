import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';

import '../../ui/player/player_controller.dart';
import 'session_host.dart';
import 'session_client.dart';
import 'together_messages.dart';

class SyncController extends GetxController {
  TogetherServer? _sessionHost;
  final SessionClient sessionClient = SessionClient();

  bool _isApplyingRemoteChange = false;

  PlayerController? get _playerController {
    try { return Get.find<PlayerController>(); } catch (_) { return null; }
  }

  AudioHandler? get _audioHandler {
    try { return Get.find<AudioHandler>(); } catch (_) { return null; }
  }

  void startHosting(TogetherServer host) {
    _sessionHost = host;
    _sessionHost!.eventStream.listen(_onServerEvent);
  }

  void stopHosting() {
    _sessionHost = null;
  }

  void startPeering() {
    sessionClient.messageStream.listen(_onRemoteMessage);
  }

  void stopPeering() {
    // handled by sessionClient
  }

  void _onServerEvent(TogetherServerEvent event) {
    if (event is JoinRequestedEvent) {
      // join requested
    } else if (event is ParticipantJoinedEvent) {
      // participant joined
    } else if (event is ParticipantLeftEvent) {
      // participant left
    } else if (event is ControlRequestedEvent) {
      _handleRemoteControl(event.request);
    } else if (event is AddTrackRequestedEvent) {
      // track added
    }
  }

  void _onRemoteMessage(TogetherMessage msg) {
    if (_isApplyingRemoteChange) return;

    switch (msg) {
      case RoomStateMessage(:final state):
        _applyRoomState(state);
        break;
      case ControlRequest():
        _handleRemoteControl(msg);
        break;
      default:
        break;
    }
  }

  void _applyRoomState(TogetherRoomState state) {
    _isApplyingRemoteChange = true;
    final ah = _audioHandler;
    if (ah == null) {
      _isApplyingRemoteChange = false;
      return;
    }

    if (state.isPlaying) {
      ah.play();
    } else {
      ah.pause();
    }

    if (state.positionMs > 0) {
      ah.seek(Duration(milliseconds: state.positionMs));
    }

    _isApplyingRemoteChange = false;
  }

  void _handleRemoteControl(ControlRequest request) {
    _isApplyingRemoteChange = true;
    final ah = _audioHandler;
    if (ah == null) {
      _isApplyingRemoteChange = false;
      return;
    }

    switch (request.action) {
      case ControlActionType.play:
        ah.play();
        break;
      case ControlActionType.pause:
        ah.pause();
        break;
      case ControlActionType.seekTo:
        if (request.positionMs != null) {
          ah.seek(Duration(milliseconds: request.positionMs!));
        }
        break;
      case ControlActionType.skipNext:
        ah.skipToNext();
        break;
      case ControlActionType.skipPrevious:
        ah.skipToPrevious();
        break;
      default:
        break;
    }

    _isApplyingRemoteChange = false;
  }

  /// Broadcast current playback state to all peers.
  void broadcastPlaybackState({
    required String sessionId,
    required String hostId,
    required String trackId,
    required String trackTitle,
    required String trackArtist,
    required int positionMs,
    required bool isPlaying,
    required int durationSec,
  }) {
    if (_sessionHost == null) return;
    _sessionHost!.broadcastRoomState(TogetherRoomState(
      sessionId: sessionId,
      hostId: hostId,
      queue: [
        TogetherTrack(
          id: trackId,
          title: trackTitle,
          artists: [trackArtist],
          durationSec: durationSec,
        ),
      ],
      currentIndex: 0,
      isPlaying: isPlaying,
      positionMs: positionMs,
      sentAtElapsedRealtimeMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  void onClose() {
    _sessionHost = null;
    sessionClient.dispose();
    super.onClose();
  }
}
