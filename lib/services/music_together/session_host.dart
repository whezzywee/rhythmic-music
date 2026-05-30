import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'sync_messages.dart';

class ConnectedPeer {
  final WebSocketChannel channel;
  final String name;
  final String device;
  final DateTime connectedAt;

  ConnectedPeer({
    required this.channel,
    required this.name,
    required this.device,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'device': device,
      };
}

class SessionHost {
  HttpServer? _server;
  final List<ConnectedPeer> _peers = [];
  final _peerListController = StreamController<List<ConnectedPeer>>.broadcast();
  final _messageController = StreamController<SyncMessage>.broadcast();

  Stream<List<ConnectedPeer>> get peerListStream => _peerListController.stream;
  Stream<SyncMessage> get messageStream => _messageController.stream;
  List<ConnectedPeer> get peers => List.unmodifiable(_peers);

  int? get port => _server?.port;
  bool get isRunning => _server != null;

  Future<void> start(int port) async {
    final handler = webSocketHandler((WebSocketChannel webSocket) {
      _handleConnection(webSocket);
    });

    final cascade = Cascade()
        .add(handler)
        .add((Request request) => Response.notFound('Not a WebSocket endpoint'));

    _server = await io.serve(
      const Pipeline().addHandler(cascade.handler),
      InternetAddress.anyIPv4,
      port,
    );
  }

  void _handleConnection(WebSocketChannel channel) {
    late ConnectedPeer peer;

    channel.stream.listen(
      (data) {
        try {
          final message = SyncMessage.fromJson(data as String);

          switch (message.type) {
            case SyncMessageType.peerJoin:
              peer = ConnectedPeer(
                channel: channel,
                name: message.data['name'] as String,
                device: message.data['device'] as String,
              );
              _peers.add(peer);
              _broadcastPeerList();
              break;
            case SyncMessageType.peerLeave:
              _peers.removeWhere((p) => p.channel == channel);
              _broadcastPeerList();
              break;
            default:
              _messageController.add(message);
          }
        } catch (_) {}
      },
      onDone: () {
        _peers.removeWhere((p) => p.channel == channel);
        _broadcastPeerList();
      },
      onError: (_) {
        _peers.removeWhere((p) => p.channel == channel);
        _broadcastPeerList();
      },
    );
  }

  void broadcast(SyncMessage message) {
    final json = message.toJson();
    for (final peer in List.from(_peers)) {
      try {
        peer.channel.sink.add(json);
      } catch (_) {
        _peers.remove(peer);
      }
    }
    _broadcastPeerList();
  }

  void broadcastPlaybackState({
    required String trackId,
    required String trackTitle,
    required String trackArtist,
    required int positionMs,
    required bool isPlaying,
  }) {
    broadcast(SyncMessage.playbackState(
      trackId: trackId,
      trackTitle: trackTitle,
      trackArtist: trackArtist,
      positionMs: positionMs,
      isPlaying: isPlaying,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void broadcastTrackChange({
    required String trackId,
    required String trackTitle,
    required String trackArtist,
  }) {
    broadcast(SyncMessage.trackChange(
      trackId: trackId,
      trackTitle: trackTitle,
      trackArtist: trackArtist,
    ));
  }

  void broadcastControl(String action, {int? seekMs}) {
    broadcast(SyncMessage.control(action, seekMs: seekMs));
  }

  void _broadcastPeerList() {
    final peerData = _peers.map((p) => p.toJson()).toList();
    broadcast(SyncMessage.peerList(peerData));
    _peerListController.add(List.from(_peers));
  }

  Future<void> stop() async {
    final peers = List.from(_peers);
    _peers.clear();
    for (final peer in peers) {
      try {
        peer.channel.sink.close();
      } catch (_) {}
    }
    await _server?.close(force: true);
    _server = null;
  }
}
