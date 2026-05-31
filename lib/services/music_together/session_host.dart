import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'together_messages.dart';

class TogetherServer {
  HttpServer? _server;
  final String sessionId;
  final String sessionKey;
  final String hostDisplayName;
  TogetherRoomSettings _settings;
  final Map<String, _Client> _clients = {};
  final _random = Random();
  List<TogetherParticipant> _lastParticipants = [];

  String _generateId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .replaceRange(12, 13, '4')
        .replaceRange(20, 21, '');
  }

  final _eventController =
      StreamController<TogetherServerEvent>.broadcast();
  Stream<TogetherServerEvent> get eventStream => _eventController.stream;

  TogetherServer({
    required this.sessionId,
    required this.sessionKey,
    required this.hostDisplayName,
    TogetherRoomSettings? initialSettings,
  }) : _settings = initialSettings ?? const TogetherRoomSettings();

  List<TogetherParticipant> get participants => _lastParticipants;
  TogetherRoomSettings get settings => _settings;
  int? get port => _server?.port;
  bool get isRunning => _server != null;

  Future<void> start(int port) async {
    final handler = webSocketHandler((WebSocketChannel channel) {
      _handleClient(channel);
    });

    final cascade = Cascade()
        .add(handler)
        .add((Request request) => Response.notFound(''));

    _server = await io.serve(
      const Pipeline().addHandler(cascade.handler),
      InternetAddress.anyIPv4,
      port,
    );
  }

  void updateSettings(TogetherRoomSettings newSettings) {
    _settings = newSettings;
    _rebuildAndBroadcast();
  }

  void approveParticipant(String participantId, bool approved) {
    final client = _clients[participantId];
    if (client == null || !client.pending) return;

    if (!approved) {
      _sendToClient(client,
          JoinDecision(sessionId: sessionId, participantId: participantId, approved: false));
      _closeClient(client, 'Not approved');
      _clients.remove(participantId);
      _eventController.add(TogetherServerEvent.participantLeft(
          participantId, 'Not approved'));
      return;
    }

    client.pending = false;
    _sendToClient(client,
        JoinDecision(sessionId: sessionId, participantId: participantId, approved: true));
    _eventController.add(TogetherServerEvent.participantJoined(
      TogetherParticipant(
          id: participantId,
          name: client.name,
          isHost: false,
          isPending: false,
          isConnected: true),
    ));
  }

  void broadcastRoomState(TogetherRoomState state) {
    final host = TogetherParticipant(
      id: state.hostId,
      name: hostDisplayName,
      isHost: true,
      isPending: false,
      isConnected: true,
    );

    final participantList = <TogetherParticipant>[host];
    participantList.addAll(
      _clients.values
          .toList()
          .sortedBy((c) => c.name.toLowerCase())
          .map((c) => TogetherParticipant(
                id: c.participantId,
                name: c.name,
                isHost: false,
                isPending: c.pending,
                isConnected: true,
              )),
    );
    _lastParticipants = participantList;

    for (final client in Map.from(_clients).values) {
      final safeState = client.pending
          ? TogetherRoomState(
              sessionId: state.sessionId,
              hostId: state.hostId,
              queue: [],
              queueHash: '',
              currentIndex: 0,
              isPlaying: false,
              positionMs: 0,
              participants: participantList,
              settings: _settings,
            )
          : state.copyWith(
              participants: participantList,
              settings: _settings,
            );

      _sendToClient(client, RoomStateMessage(state: safeState));
    }
  }

  void _handleClient(WebSocketChannel channel) {
    final stream = channel.stream.asBroadcastStream();
    _Client? client;

    // Wait for handshake via a single-subscription listener.
    late StreamSubscription<dynamic> handshakeSub;
    handshakeSub = stream.listen(
      (raw) {
        try {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          final msg = TogetherMessage.fromJson(json);
          if (msg is! ClientHello) {
            _sendRaw(channel,
                ServerError(sessionId: null, message: 'Handshake required')
                    .encode());
            channel.sink.close();
            return;
          }

          if (msg.protocolVersion != togetherProtocolVersion) {
            _sendRaw(channel,
                ServerError(sessionId: msg.sessionId, message: 'Unsupported protocol')
                    .encode());
            channel.sink.close();
            return;
          }

          if (msg.sessionId != sessionId || msg.sessionKey != sessionKey) {
            _sendRaw(channel,
                ServerError(sessionId: msg.sessionId, message: 'Invalid session')
                    .encode());
            channel.sink.close();
            return;
          }

          final participantId = _generateId();
          final isPending = _settings.requireHostApprovalToJoin;
          final name = msg.displayName.trim().isEmpty ? 'Guest' : msg.displayName.trim();

          client = _Client(
            participantId: participantId,
            clientId: msg.clientId,
            name: name,
            channel: channel,
            pending: isPending,
          );
          _clients[participantId] = client!;

          _sendToClient(client!,
              ServerWelcome(
                protocolVersion: togetherProtocolVersion,
                sessionId: sessionId,
                participantId: participantId,
                role: ServerRole.guest,
                isPending: isPending,
                settings: _settings,
              ));

          final participant = TogetherParticipant(
            id: participantId,
            name: name,
            isHost: false,
            isPending: isPending,
            isConnected: true,
          );

          _eventController.add(isPending
              ? TogetherServerEvent.joinRequested(participant)
              : TogetherServerEvent.participantJoined(participant));

          // Cancel handshake listener and start normal message listener.
          handshakeSub.cancel();
          stream.listen(
            (raw2) => _handleMessage(client!, raw2),
            onDone: () => _removeClient(client!),
            onError: (_) => _removeClient(client!),
          );
        } catch (_) {
          _sendRaw(channel,
              ServerError(sessionId: null, message: 'Invalid handshake')
                  .encode());
          channel.sink.close();
        }
      },
      onDone: () {
        if (client != null) _removeClient(client!);
      },
      onError: (_) {
        if (client != null) _removeClient(client!);
      },
    );
  }

  void _handleMessage(_Client client, dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final msg = TogetherMessage.fromJson(json);

      switch (msg) {
        case HeartbeatPing():
          _sendToClient(client,
              HeartbeatPong(
                sessionId: sessionId,
                pingId: msg.pingId,
                clientElapsedRealtimeMs: msg.clientElapsedRealtimeMs,
                serverElapsedRealtimeMs: DateTime.now().millisecondsSinceEpoch,
              ));
          break;

        case ControlRequest():
          if (!client.pending) {
            _eventController.add(TogetherServerEvent.controlRequested(msg));
          }
          break;

        case AddTrackRequest():
          if (!client.pending) {
            _eventController.add(TogetherServerEvent.addTrackRequested(msg));
          }
          break;

        case ClientLeave():
          if (msg.participantId == client.participantId) {
            _removeClient(client);
          }
          break;

        default:
          break;
      }
    } catch (_) {}
  }

  void _removeClient(_Client client) {
    _clients.remove(client.participantId);
    _eventController
        .add(TogetherServerEvent.participantLeft(client.participantId, 'Disconnected'));
    _closeClient(client, 'Disconnected');
  }

  void _sendToClient(_Client client, TogetherMessage message) {
    try {
      client.channel.sink.add(message.encode());
    } catch (_) {}
  }

  void _sendRaw(WebSocketChannel channel, String data) {
    try {
      channel.sink.add(data);
    } catch (_) {}
  }

  void _closeClient(_Client client, String reason) {
    try {
      client.channel.sink.close();
    } catch (_) {}
  }

  void _rebuildAndBroadcast() {
    // Placeholder — room state is broadcast externally via broadcastRoomState().
  }

  Future<void> stop() async {
    final clients = Map.from(_clients);
    _clients.clear();
    for (final c in clients.values) {
      _closeClient(c, 'Session ended');
    }
    await _server?.close(force: true);
    _server = null;
  }
}

class _Client {
  final String participantId;
  final String clientId;
  final String name;
  final WebSocketChannel channel;
  bool pending;

  _Client({
    required this.participantId,
    required this.clientId,
    required this.name,
    required this.channel,
    required this.pending,
  });
}

sealed class TogetherServerEvent {
  factory TogetherServerEvent.joinRequested(TogetherParticipant p) =
      JoinRequestedEvent;
  factory TogetherServerEvent.participantJoined(TogetherParticipant p) =
      ParticipantJoinedEvent;
  factory TogetherServerEvent.participantLeft(String id, String? reason) =
      ParticipantLeftEvent;
  factory TogetherServerEvent.controlRequested(ControlRequest r) =
      ControlRequestedEvent;
  factory TogetherServerEvent.addTrackRequested(AddTrackRequest r) =
      AddTrackRequestedEvent;
}

class JoinRequestedEvent implements TogetherServerEvent {
  final TogetherParticipant participant;
  JoinRequestedEvent(this.participant);
}

class ParticipantJoinedEvent implements TogetherServerEvent {
  final TogetherParticipant participant;
  ParticipantJoinedEvent(this.participant);
}

class ParticipantLeftEvent implements TogetherServerEvent {
  final String participantId;
  final String? reason;
  ParticipantLeftEvent(this.participantId, this.reason);
}

class ControlRequestedEvent implements TogetherServerEvent {
  final ControlRequest request;
  ControlRequestedEvent(this.request);
}

class AddTrackRequestedEvent implements TogetherServerEvent {
  final AddTrackRequest request;
  AddTrackRequestedEvent(this.request);
}

extension _ListSort<T> on List<T> {
  List<T> sortedBy(Comparable<Object> Function(T) toComparable) {
    final copy = List<T>.from(this);
    copy.sort((a, b) => toComparable(a).compareTo(toComparable(b)));
    return copy;
  }
}
