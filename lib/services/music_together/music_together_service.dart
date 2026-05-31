import 'dart:math';
import 'package:get/get.dart';

import 'lan_discovery.dart';
import 'session_host.dart';
import 'session_client.dart';
import 'sync_controller.dart';
import 'together_messages.dart';

class MusicTogetherService extends GetxController {
  final LanDiscovery lanDiscovery = LanDiscovery();
  final SyncController syncController = SyncController();
  late TogetherServer _sessionHost;
  final SessionClient sessionClient = SessionClient();

  final RxString sessionName = ''.obs;
  final RxString sessionId = ''.obs;
  final RxString sessionKey = ''.obs;
  final RxString hostParticipantId = ''.obs;
  final RxBool isHosting = false.obs;
  final RxBool isPeer = false.obs;
  final RxList<TogetherParticipant> connectedPeers =
      <TogetherParticipant>[].obs;
  final RxList<DiscoveredSession> discoveredSessions =
      <DiscoveredSession>[].obs;
  final Rx<ClientState> clientState = ClientState.disconnected.obs;

  @override
  void onInit() {
    super.onInit();
    lanDiscovery.discoveredSessions.listen((sessions) {
      discoveredSessions.value = sessions;
    });

    sessionClient.stateStream.listen((state) {
      clientState.value = state;
    });
  }

  int get hostPort => _sessionHost.port ?? 0;

  Future<void> startHosting({required String name}) async {
    sessionName.value = name;
    sessionId.value = _generateSessionId();
    sessionKey.value = _generateSessionKey();
    hostParticipantId.value = _generateSessionId();

    _sessionHost = TogetherServer(
      sessionId: sessionId.value,
      sessionKey: sessionKey.value,
      hostDisplayName: name,
    );

    final port = 18765;
    await _sessionHost.start(port);

    syncController.startHosting(_sessionHost);

    await lanDiscovery.startAdvertising(
      sessionName: name,
      hostPort: port,
      sessionId: sessionId.value,
      sessionKey: sessionKey.value,
    );

    isHosting.value = true;
  }

  Future<void> stopHosting() async {
    lanDiscovery.stopAdvertising();
    syncController.stopHosting();
    await _sessionHost.stop();
    isHosting.value = false;
    connectedPeers.clear();
  }

  Future<void> startDiscovery() async {
    await lanDiscovery.startDiscovery();
  }

  void stopDiscovery() {
    lanDiscovery.stopDiscovery();
  }

  Future<void> joinSession(DiscoveredSession session) async {
    await sessionClient.connect(
      hostAddress: session.hostAddress,
      hostPort: session.hostPort,
      sessionId: session.sessionId,
      sessionKey: session.sessionKey,
      displayName: 'Rhythmic Desktop',
    );

    syncController.startPeering();
    isPeer.value = true;
  }

  Future<void> leaveSession() async {
    sessionClient.disconnect();
    syncController.stopPeering();
    isPeer.value = false;
  }

  @override
  void onClose() {
    stopHosting();
    leaveSession();
    lanDiscovery.dispose();
    super.onClose();
  }

  String _generateSessionId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _generateSessionKey() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
