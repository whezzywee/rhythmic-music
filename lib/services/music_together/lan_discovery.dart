import 'dart:async';
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:convert';
import 'package:get/get.dart';

class DiscoveredSession {
  final String sessionName;
  final String hostAddress;
  final int hostPort;
  final String sessionId;
  final String sessionKey;
  final DateTime lastSeen;

  DiscoveredSession({
    required this.sessionName,
    required this.hostAddress,
    required this.hostPort,
    required this.sessionId,
    required this.sessionKey,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  String get wsUrl => 'ws://$hostAddress:$hostPort';

  Map<String, dynamic> toJson() => {
        'sessionName': sessionName,
        'hostAddress': hostAddress,
        'hostPort': hostPort,
        'sessionId': sessionId,
      };
}

const int _discoveryPort = 54321;
const int _broadcastPort = 54322;
const Duration _broadcastInterval = Duration(seconds: 3);
const String _magicPrefix = 'RHYTHMIC_DISCOVERY';

class LanDiscovery {
  RawDatagramSocket? _listener;
  Timer? _broadcastTimer;
  RawDatagramSocket? _broadcastSocket;
  final _sessions = <String, DiscoveredSession>{};
  Timer? _cleanupTimer;

  final RxList<DiscoveredSession> discoveredSessions = <DiscoveredSession>[].obs;

  Future<void> startDiscovery() async {
    try {
      _listener = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
      );
      _listener!.readEventsEnabled = true;
      _listener!.listen((event) {
        if (event == RawSocketEvent.read) {
          _handleBroadcast(_listener!);
        }
      });
      _listener!.broadcastEnabled = true;

      _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _cleanupSessions();
      });
    } catch (e) {
      // ignore: avoid_print
      print('LanDiscovery: Failed to start discovery: $e');
    }
  }

  Future<String?> getLocalAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _handleBroadcast(RawDatagramSocket socket) {
    try {
      final datagram = socket.receive();
      if (datagram == null) return;

      final message = utf8.decode(datagram.data);
      if (!message.startsWith(_magicPrefix)) return;

      final jsonStr = message.substring(_magicPrefix.length);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final session = DiscoveredSession(
        sessionName: data['session_name'] as String,
        hostAddress: data['host_address'] as String,
        hostPort: data['host_port'] as int,
        sessionId: data['session_id'] as String,
        sessionKey: data['session_key'] as String? ?? '',
        lastSeen: DateTime.now(),
      );

      final key = session.sessionId;
      if (_sessions.containsKey(key)) {
        _sessions[key]!.lastSeen;
        _sessions[key] = session;
      } else {
        _sessions[key] = session;
      }

      _updateObservedList();
    } catch (_) {}
  }

  void _updateObservedList() {
    discoveredSessions.value = _sessions.values.toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
  }

  void _cleanupSessions() {
    final now = DateTime.now();
    _sessions.removeWhere((key, session) {
      return now.difference(session.lastSeen).inSeconds > 10;
    });
    if (_sessions.length != discoveredSessions.length) {
      _updateObservedList();
    }
  }

  Future<void> startAdvertising({
    required String sessionName,
    required int hostPort,
    required String sessionId,
    String sessionKey = '',
  }) async {
    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _broadcastPort,
      );
      _broadcastSocket!.broadcastEnabled = true;

      final localAddr = await getLocalAddress();
      if (localAddr == null) {
        print('LanDiscovery: No local address found for advertising');
        return;
      }

      final discoveryMessage = jsonEncode({
        'session_name': sessionName,
        'host_address': localAddr,
        'host_port': hostPort,
        'session_id': sessionId,
        'session_key': sessionKey,
      });

      final packet = utf8.encode('$_magicPrefix$discoveryMessage');

      _broadcastTimer = Timer.periodic(_broadcastInterval, (_) {
        try {
          _broadcastSocket?.send(
            packet,
            InternetAddress('255.255.255.255'),
            _discoveryPort,
          );
        } catch (_) {}
      });
    } catch (e) {
      // ignore: avoid_print
      print('LanDiscovery: Failed to start advertising: $e');
    }
  }

  void stopAdvertising() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  void stopDiscovery() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _listener?.close();
    _listener = null;
    _sessions.clear();
    discoveredSessions.clear();
  }

  void dispose() {
    stopAdvertising();
    stopDiscovery();
  }
}
