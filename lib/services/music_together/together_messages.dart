import 'dart:convert';

/// Protocol version matching OpenTune's TogetherProtocolVersion.
const int togetherProtocolVersion = 1;

// ─── Enums ───────────────────────────────────────────────────────────────────

enum ServerRole { host, guest }

enum AddTrackMode { playNext, addToQueue }

enum ControlActionType {
  play,
  pause,
  seekTo,
  skipNext,
  skipPrevious,
  seekToIndex,
  seekToTrack,
  setRepeatMode,
  setShuffleEnabled,
}

// ─── Models ──────────────────────────────────────────────────────────────────

class TogetherTrack {
  final String id;
  final String title;
  final List<String> artists;
  final int durationSec;
  final String? thumbnailUrl;

  const TogetherTrack({
    required this.id,
    required this.title,
    this.artists = const [],
    this.durationSec = -1,
    this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artists': artists,
        'durationSec': durationSec,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      };

  factory TogetherTrack.fromJson(Map<String, dynamic> json) => TogetherTrack(
        id: json['id'] as String,
        title: json['title'] as String,
        artists: (json['artists'] as List<dynamic>?)?.cast<String>() ?? [],
        durationSec: json['durationSec'] as int? ?? -1,
        thumbnailUrl: json['thumbnailUrl'] as String?,
      );
}

class TogetherParticipant {
  final String id;
  final String name;
  final bool isHost;
  final bool isPending;
  final bool isConnected;

  const TogetherParticipant({
    required this.id,
    required this.name,
    this.isHost = false,
    this.isPending = false,
    this.isConnected = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isHost': isHost,
        'isPending': isPending,
        'isConnected': isConnected,
      };

  factory TogetherParticipant.fromJson(Map<String, dynamic> json) =>
      TogetherParticipant(
        id: json['id'] as String,
        name: json['name'] as String,
        isHost: json['isHost'] as bool? ?? false,
        isPending: json['isPending'] as bool? ?? false,
        isConnected: json['isConnected'] as bool? ?? true,
      );
}

class TogetherRoomSettings {
  final bool allowGuestsToAddTracks;
  final bool allowGuestsToControlPlayback;
  final bool requireHostApprovalToJoin;

  const TogetherRoomSettings({
    this.allowGuestsToAddTracks = true,
    this.allowGuestsToControlPlayback = false,
    this.requireHostApprovalToJoin = false,
  });

  Map<String, dynamic> toJson() => {
        'allowGuestsToAddTracks': allowGuestsToAddTracks,
        'allowGuestsToControlPlayback': allowGuestsToControlPlayback,
        'requireHostApprovalToJoin': requireHostApprovalToJoin,
      };

  factory TogetherRoomSettings.fromJson(Map<String, dynamic> json) =>
      TogetherRoomSettings(
        allowGuestsToAddTracks:
            json['allowGuestsToAddTracks'] as bool? ?? true,
        allowGuestsToControlPlayback:
            json['allowGuestsToControlPlayback'] as bool? ?? false,
        requireHostApprovalToJoin:
            json['requireHostApprovalToJoin'] as bool? ?? false,
      );
}

class TogetherRoomState {
  final String sessionId;
  final String hostId;
  final List<TogetherParticipant> participants;
  final TogetherRoomSettings settings;
  final List<TogetherTrack> queue;
  final String queueHash;
  final int currentIndex;
  final bool isPlaying;
  final int positionMs;
  final int repeatMode;
  final bool shuffleEnabled;
  final int sentAtElapsedRealtimeMs;

  const TogetherRoomState({
    required this.sessionId,
    required this.hostId,
    this.participants = const [],
    this.settings = const TogetherRoomSettings(),
    this.queue = const [],
    this.queueHash = '',
    this.currentIndex = 0,
    this.isPlaying = false,
    this.positionMs = 0,
    this.repeatMode = 0,
    this.shuffleEnabled = false,
    this.sentAtElapsedRealtimeMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'hostId': hostId,
        'participants': participants.map((p) => p.toJson()).toList(),
        'settings': settings.toJson(),
        'queue': queue.map((t) => t.toJson()).toList(),
        'queueHash': queueHash,
        'currentIndex': currentIndex,
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'repeatMode': repeatMode,
        'shuffleEnabled': shuffleEnabled,
        'sentAtElapsedRealtimeMs': sentAtElapsedRealtimeMs,
      };

  factory TogetherRoomState.fromJson(Map<String, dynamic> json) =>
      TogetherRoomState(
        sessionId: json['sessionId'] as String,
        hostId: json['hostId'] as String,
        participants: (json['participants'] as List<dynamic>?)
                ?.map((p) =>
                    TogetherParticipant.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
        settings: json['settings'] != null
            ? TogetherRoomSettings.fromJson(
                json['settings'] as Map<String, dynamic>)
            : const TogetherRoomSettings(),
        queue: (json['queue'] as List<dynamic>?)
                ?.map(
                    (t) => TogetherTrack.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        queueHash: json['queueHash'] as String? ?? '',
        currentIndex: json['currentIndex'] as int? ?? 0,
        isPlaying: json['isPlaying'] as bool? ?? false,
        positionMs: json['positionMs'] as int? ?? 0,
        repeatMode: json['repeatMode'] as int? ?? 0,
        shuffleEnabled: json['shuffleEnabled'] as bool? ?? false,
        sentAtElapsedRealtimeMs:
            json['sentAtElapsedRealtimeMs'] as int? ?? 0,
      );

  TogetherRoomState copyWith({
    String? sessionId,
    String? hostId,
    List<TogetherParticipant>? participants,
    TogetherRoomSettings? settings,
    List<TogetherTrack>? queue,
    String? queueHash,
    int? currentIndex,
    bool? isPlaying,
    int? positionMs,
    int? repeatMode,
    bool? shuffleEnabled,
    int? sentAtElapsedRealtimeMs,
  }) =>
      TogetherRoomState(
        sessionId: sessionId ?? this.sessionId,
        hostId: hostId ?? this.hostId,
        participants: participants ?? this.participants,
        settings: settings ?? this.settings,
        queue: queue ?? this.queue,
        queueHash: queueHash ?? this.queueHash,
        currentIndex: currentIndex ?? this.currentIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        positionMs: positionMs ?? this.positionMs,
        repeatMode: repeatMode ?? this.repeatMode,
        shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
        sentAtElapsedRealtimeMs:
            sentAtElapsedRealtimeMs ?? this.sentAtElapsedRealtimeMs,
      );
}

// ─── Messages ────────────────────────────────────────────────────────────────

/// Base class matching OpenTune's sealed interface TogetherMessage.
/// Each message serialises with a @type discriminator field to match
/// kotlinx.serialization's @SerialName behaviour.
sealed class TogetherMessage {
  Map<String, dynamic> toJson();

  static TogetherMessage fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'client_hello':
        return ClientHello.fromJson(json);
      case 'server_welcome':
        return ServerWelcome.fromJson(json);
      case 'server_error':
        return ServerError.fromJson(json);
      case 'room_state':
        return RoomStateMessage.fromJson(json);
      case 'control_request':
        return ControlRequest.fromJson(json);
      case 'add_track_request':
        return AddTrackRequest.fromJson(json);
      case 'join_decision':
        return JoinDecision.fromJson(json);
      case 'join_request':
        return JoinRequest.fromJson(json);
      case 'participant_joined':
        return ParticipantJoined.fromJson(json);
      case 'participant_left':
        return ParticipantLeft.fromJson(json);
      case 'heartbeat_ping':
        return HeartbeatPing.fromJson(json);
      case 'heartbeat_pong':
        return HeartbeatPong.fromJson(json);
      case 'client_leave':
        return ClientLeave.fromJson(json);
      case 'kick':
        return KickParticipant.fromJson(json);
      case 'ban':
        return BanParticipant.fromJson(json);
      default:
        throw FormatException('Unknown message type: $type');
    }
  }

  String encode() => jsonEncode(toJson());
}

class ClientHello extends TogetherMessage {
  final int protocolVersion;
  final String sessionId;
  final String sessionKey;
  final String clientId;
  final String displayName;

  ClientHello({
    required this.protocolVersion,
    required this.sessionId,
    required this.sessionKey,
    required this.clientId,
    required this.displayName,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'client_hello',
        'protocolVersion': protocolVersion,
        'sessionId': sessionId,
        'sessionKey': sessionKey,
        'clientId': clientId,
        'displayName': displayName,
      };

  static ClientHello fromJson(Map<String, dynamic> json) => ClientHello(
        protocolVersion: json['protocolVersion'] as int,
        sessionId: json['sessionId'] as String,
        sessionKey: json['sessionKey'] as String,
        clientId: json['clientId'] as String,
        displayName: json['displayName'] as String,
      );
}

class ServerWelcome extends TogetherMessage {
  final int protocolVersion;
  final String sessionId;
  final String participantId;
  final ServerRole role;
  final bool isPending;
  final TogetherRoomSettings settings;

  ServerWelcome({
    required this.protocolVersion,
    required this.sessionId,
    required this.participantId,
    required this.role,
    required this.isPending,
    required this.settings,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'server_welcome',
        'protocolVersion': protocolVersion,
        'sessionId': sessionId,
        'participantId': participantId,
        'role': role.name,
        'isPending': isPending,
        'settings': settings.toJson(),
      };

  static ServerWelcome fromJson(Map<String, dynamic> json) => ServerWelcome(
        protocolVersion: json['protocolVersion'] as int,
        sessionId: json['sessionId'] as String,
        participantId: json['participantId'] as String,
        role: ServerRole.values.firstWhere((e) => e.name == json['role']),
        isPending: json['isPending'] as bool,
        settings: TogetherRoomSettings.fromJson(
            json['settings'] as Map<String, dynamic>),
      );
}

class ServerError extends TogetherMessage {
  final String? sessionId;
  final String message;
  final String? code;

  ServerError({this.sessionId, required this.message, this.code});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'server_error',
        if (sessionId != null) 'sessionId': sessionId,
        'message': message,
        if (code != null) 'code': code,
      };

  static ServerError fromJson(Map<String, dynamic> json) => ServerError(
        sessionId: json['sessionId'] as String?,
        message: json['message'] as String,
        code: json['code'] as String?,
      );
}

class RoomStateMessage extends TogetherMessage {
  final TogetherRoomState state;

  RoomStateMessage({required this.state});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'room_state',
        ...state.toJson(),
      };

  static RoomStateMessage fromJson(Map<String, dynamic> json) =>
      RoomStateMessage(state: TogetherRoomState.fromJson(json));
}

class ControlRequest extends TogetherMessage {
  final String sessionId;
  final String participantId;
  final ControlActionType action;
  final int? positionMs;
  final int? index;
  final String? trackId;
  final int? repeatMode;
  final bool? shuffleEnabled;

  ControlRequest({
    required this.sessionId,
    required this.participantId,
    required this.action,
    this.positionMs,
    this.index,
    this.trackId,
    this.repeatMode,
    this.shuffleEnabled,
  });

  @override
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'type': 'control_request',
      'sessionId': sessionId,
      'participantId': participantId,
      'action': action.name,
    };
    if (positionMs != null && action == ControlActionType.seekTo) {
      m['positionMs'] = positionMs;
    }
    if (index != null) m['index'] = index;
    if (trackId != null) m['trackId'] = trackId;
    if (repeatMode != null) m['repeatMode'] = repeatMode;
    if (shuffleEnabled != null) m['shuffleEnabled'] = shuffleEnabled;
    return m;
  }

  static ControlRequest fromJson(Map<String, dynamic> json) => ControlRequest(
        sessionId: json['sessionId'] as String,
        participantId: json['participantId'] as String,
        action:
            ControlActionType.values.firstWhere((e) => e.name == json['action']),
        positionMs: json['positionMs'] as int?,
        index: json['index'] as int?,
        trackId: json['trackId'] as String?,
        repeatMode: json['repeatMode'] as int?,
        shuffleEnabled: json['shuffleEnabled'] as bool?,
      );
}

class AddTrackRequest extends TogetherMessage {
  final String sessionId;
  final String participantId;
  final TogetherTrack track;
  final AddTrackMode mode;

  AddTrackRequest({
    required this.sessionId,
    required this.participantId,
    required this.track,
    required this.mode,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'add_track_request',
        'sessionId': sessionId,
        'participantId': participantId,
        'track': track.toJson(),
        'mode': mode.name,
      };

  static AddTrackRequest fromJson(Map<String, dynamic> json) =>
      AddTrackRequest(
        sessionId: json['sessionId'] as String,
        participantId: json['participantId'] as String,
        track: TogetherTrack.fromJson(json['track'] as Map<String, dynamic>),
        mode:
            AddTrackMode.values.firstWhere((e) => e.name == json['mode']),
      );
}

class JoinDecision extends TogetherMessage {
  final String sessionId;
  final String participantId;
  final bool approved;

  JoinDecision({
    required this.sessionId,
    required this.participantId,
    required this.approved,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'join_decision',
        'sessionId': sessionId,
        'participantId': participantId,
        'approved': approved,
      };

  static JoinDecision fromJson(Map<String, dynamic> json) => JoinDecision(
        sessionId: json['sessionId'] as String,
        participantId: json['participantId'] as String,
        approved: json['approved'] as bool,
      );
}

class JoinRequest extends TogetherMessage {
  final String sessionId;
  final TogetherParticipant participant;

  JoinRequest({required this.sessionId, required this.participant});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'join_request',
        'sessionId': sessionId,
        'participant': participant.toJson(),
      };

  static JoinRequest fromJson(Map<String, dynamic> json) => JoinRequest(
        sessionId: json['sessionId'] as String,
        participant: TogetherParticipant.fromJson(
            json['participant'] as Map<String, dynamic>),
      );
}

class ParticipantJoined extends TogetherMessage {
  final String sessionId;
  final TogetherParticipant participant;

  ParticipantJoined({required this.sessionId, required this.participant});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'participant_joined',
        'sessionId': sessionId,
        'participant': participant.toJson(),
      };

  static ParticipantJoined fromJson(Map<String, dynamic> json) =>
      ParticipantJoined(
        sessionId: json['sessionId'] as String,
        participant: TogetherParticipant.fromJson(
            json['participant'] as Map<String, dynamic>),
      );
}

class ParticipantLeft extends TogetherMessage {
  final String sessionId;
  final String participantId;
  final String? reason;

  ParticipantLeft({
    required this.sessionId,
    required this.participantId,
    this.reason,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'participant_left',
        'sessionId': sessionId,
        'participantId': participantId,
        if (reason != null) 'reason': reason,
      };

  static ParticipantLeft fromJson(Map<String, dynamic> json) =>
      ParticipantLeft(
        sessionId: json['sessionId'] as String,
        participantId: json['participantId'] as String,
        reason: json['reason'] as String?,
      );
}

class HeartbeatPing extends TogetherMessage {
  final String sessionId;
  final int pingId;
  final int clientElapsedRealtimeMs;

  HeartbeatPing({
    required this.sessionId,
    required this.pingId,
    required this.clientElapsedRealtimeMs,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'heartbeat_ping',
        'sessionId': sessionId,
        'pingId': pingId,
        'clientElapsedRealtimeMs': clientElapsedRealtimeMs,
      };

  static HeartbeatPing fromJson(Map<String, dynamic> json) => HeartbeatPing(
        sessionId: json['sessionId'] as String,
        pingId: json['pingId'] as int,
        clientElapsedRealtimeMs: json['clientElapsedRealtimeMs'] as int,
      );
}

class HeartbeatPong extends TogetherMessage {
  final String sessionId;
  final int pingId;
  final int clientElapsedRealtimeMs;
  final int serverElapsedRealtimeMs;

  HeartbeatPong({
    required this.sessionId,
    required this.pingId,
    required this.clientElapsedRealtimeMs,
    required this.serverElapsedRealtimeMs,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'heartbeat_pong',
        'sessionId': sessionId,
        'pingId': pingId,
        'clientElapsedRealtimeMs': clientElapsedRealtimeMs,
        'serverElapsedRealtimeMs': serverElapsedRealtimeMs,
      };

  static HeartbeatPong fromJson(Map<String, dynamic> json) => HeartbeatPong(
        sessionId: json['sessionId'] as String,
        pingId: json['pingId'] as int,
        clientElapsedRealtimeMs: json['clientElapsedRealtimeMs'] as int,
        serverElapsedRealtimeMs: json['serverElapsedRealtimeMs'] as int,
      );
}

class ClientLeave extends TogetherMessage {
  final String sessionId;
  final String participantId;

  ClientLeave({required this.sessionId, required this.participantId});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'client_leave',
        'sessionId': sessionId,
        'participantId': participantId,
      };

  static ClientLeave fromJson(Map<String, dynamic> json) => ClientLeave(
        sessionId: json['sessionId'] as String,
        participantId: json['participantId'] as String,
      );
}

class KickParticipant extends TogetherMessage {
  final String sessionId;
  final String participantId;
  final String? reason;

  KickParticipant({
    required this.sessionId,
    required this.participantId,
    this.reason,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'kick',
        'sessionId': sessionId,
        'participantId': participantId,
        if (reason != null) 'reason': reason,
      };

  static KickParticipant fromJson(Map<String, dynamic> json) =>
      KickParticipant(
        sessionId: json['sessionId'] as String,
        participantId: json['participantId'] as String,
        reason: json['reason'] as String?,
      );
}

class BanParticipant extends TogetherMessage {
  final String sessionId;
  final String participantId;
  final String? reason;

  BanParticipant({
    required this.sessionId,
    required this.participantId,
    this.reason,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ban',
        'sessionId': sessionId,
        'participantId': participantId,
        if (reason != null) 'reason': reason,
      };

  static BanParticipant fromJson(Map<String, dynamic> json) =>
      BanParticipant(
        sessionId: json['sessionId'] as String,
        participantId: json['participantId'] as String,
        reason: json['reason'] as String?,
      );
}
