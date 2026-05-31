import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'together_messages.dart';

enum ClientState { disconnected, connecting, connected }

class SessionClient {
  WebSocketChannel? _channel;
  final _stateController = StreamController<ClientState>.broadcast();
  final _messageController =
      StreamController<TogetherMessage>.broadcast();
  StreamSubscription? _subscription;

  ClientState _state = ClientState.disconnected;
  String? _sessionId;
  String? _participantId;
  ServerRole _role = ServerRole.guest;

  Stream<ClientState> get stateStream => _stateController.stream;
  Stream<TogetherMessage> get messageStream => _messageController.stream;
  ClientState get state => _state;
  String? get sessionId => _sessionId;
  String? get participantId => _participantId;
  bool get isConnected => _state == ClientState.connected;

  Future<void> connect({
    required String hostAddress,
    required int hostPort,
    required String sessionId,
    required String sessionKey,
    required String displayName,
  }) async {
    if (_state != ClientState.disconnected) return;

    _setState(ClientState.connecting);

    try {
      final uri = Uri.parse('ws://$hostAddress:$hostPort');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      // Send OpenTune ClientHello handshake.
      final hello = ClientHello(
        protocolVersion: togetherProtocolVersion,
        sessionId: sessionId,
        sessionKey: sessionKey,
        clientId: DateTime.now().microsecondsSinceEpoch.toString(),
        displayName: displayName,
      );
      _channel!.sink.add(hello.encode());

      // Wait for ServerWelcome.
      final completer = Completer<ServerWelcome>();
      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final json =
                Map<String, dynamic>.from(data as Map<dynamic, dynamic>);
            final msg = TogetherMessage.fromJson(json);

            if (msg is ServerWelcome) {
              _sessionId = msg.sessionId;
              _participantId = msg.participantId;
              _role = msg.role;
              _setState(ClientState.connected);
              if (!completer.isCompleted) completer.complete(msg);
            }

            _messageController.add(msg);
          } catch (_) {}
        },
        onError: (_) => disconnect(),
        onDone: () => disconnect(),
      );

      // Wait up to 5 seconds for ServerWelcome.
      await completer.future.timeout(const Duration(seconds: 5));
    } catch (e) {
      _setState(ClientState.disconnected);
      rethrow;
    }
  }

  void sendMessage(TogetherMessage message) {
    if (_state == ClientState.connected && _channel != null) {
      try {
        _channel!.sink.add(message.encode());
      } catch (_) {
        disconnect();
      }
    }
  }

  void disconnect() {
    if (_sessionId != null && _participantId != null) {
      try {
        _channel?.sink
            .add(ClientLeave(sessionId: _sessionId!, participantId: _participantId!)
                .encode());
      } catch (_) {}
    }

    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _sessionId = null;
    _participantId = null;
    _setState(ClientState.disconnected);
  }

  void _setState(ClientState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _messageController.close();
  }
}
