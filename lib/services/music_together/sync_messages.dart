import 'dart:convert';

enum SyncMessageType {
  playbackState,
  trackChange,
  control,
  peerJoin,
  peerLeave,
  peerList,
  sessionInfo,
  discovery,
}

class SyncMessage {
  final SyncMessageType type;
  final Map<String, dynamic> data;

  const SyncMessage({required this.type, required this.data});

  String toJson() => jsonEncode({
        'type': type.name,
        'data': data,
      });

  factory SyncMessage.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return SyncMessage(
      type: SyncMessageType.values.firstWhere((e) => e.name == map['type']),
      data: Map<String, dynamic>.from(map['data'] as Map),
    );
  }

  factory SyncMessage.playbackState({
    required String trackId,
    required String trackTitle,
    required String trackArtist,
    required int positionMs,
    required bool isPlaying,
    required int timestamp,
  }) {
    return SyncMessage(
      type: SyncMessageType.playbackState,
      data: {
        'track_id': trackId,
        'track_title': trackTitle,
        'track_artist': trackArtist,
        'position_ms': positionMs,
        'is_playing': isPlaying,
        'timestamp': timestamp,
      },
    );
  }

  factory SyncMessage.trackChange({
    required String trackId,
    required String trackTitle,
    required String trackArtist,
  }) {
    return SyncMessage(
      type: SyncMessageType.trackChange,
      data: {
        'track_id': trackId,
        'track_title': trackTitle,
        'track_artist': trackArtist,
      },
    );
  }

  factory SyncMessage.control(String action, {int? seekMs}) {
    return SyncMessage(
      type: SyncMessageType.control,
      data: {
        'action': action,
        if (seekMs != null) 'seek_ms': seekMs,
      },
    );
  }

  factory SyncMessage.peerJoin({
    required String name,
    required String device,
  }) {
    return SyncMessage(
      type: SyncMessageType.peerJoin,
      data: {
        'name': name,
        'device': device,
      },
    );
  }

  factory SyncMessage.peerLeave({
    required String name,
  }) {
    return SyncMessage(
      type: SyncMessageType.peerLeave,
      data: {
        'name': name,
      },
    );
  }

  factory SyncMessage.peerList(List<Map<String, dynamic>> peers) {
    return SyncMessage(
      type: SyncMessageType.peerList,
      data: {'peers': peers},
    );
  }

  factory SyncMessage.discovery({
    required String sessionName,
    required String hostAddress,
    required int hostPort,
    required String sessionId,
  }) {
    return SyncMessage(
      type: SyncMessageType.discovery,
      data: {
        'session_name': sessionName,
        'host_address': hostAddress,
        'host_port': hostPort,
        'session_id': sessionId,
      },
    );
  }
}
