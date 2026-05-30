import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'sync_messages.dart';

enum ClientState { disconnected, connecting, connected }

class SessionClient {
  WebSocketChannel? _channel;
  final _stateController = StreamController<ClientState>.broadcast();
  final _messageController = StreamController<SyncMessage>.broadcast();
  StreamSubscription? _subscription;

  ClientState _state = ClientState.disconnected;

  Stream<ClientState> get stateStream => _stateController.stream;
  Stream<SyncMessage> get messageStream => _messageController.stream;
  ClientState get state => _state;
  bool get isConnected => _state == ClientState.connected;

  Future<void> connect({
    required String hostAddress,
    required int hostPort,
    required String peerName,
    required String device,
  }) async {
    if (_state != ClientState.disconnected) return;

    _setState(ClientState.connecting);

    try {
      final uri = Uri.parse('ws://$hostAddress:$hostPort');
      _channel = WebSocketChannel.connect(uri);

      await _channel!.ready;

      _setState(ClientState.connected);

      _channel!.sink.add(SyncMessage.peerJoin(
        name: peerName,
        device: device,
      ).toJson());

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final message = SyncMessage.fromJson(data as String);
            _messageController.add(message);
          } catch (_) {}
        },
        onError: (_) => disconnect(),
        onDone: () => disconnect(),
      );
    } catch (e) {
      _setState(ClientState.disconnected);
      rethrow;
    }
  }

  void sendMessage(SyncMessage message) {
    if (_state == ClientState.connected && _channel != null) {
      try {
        _channel!.sink.add(message.toJson());
      } catch (_) {
        disconnect();
      }
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
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
