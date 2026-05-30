import 'dart:math';
import 'package:get/get.dart';

import 'lan_discovery.dart';
import 'session_host.dart';
import 'session_client.dart';
import 'sync_controller.dart';

class MusicTogetherService extends GetxController {
  final LanDiscovery lanDiscovery = LanDiscovery();
  final SyncController syncController = SyncController();
  final SessionHost sessionHost = SessionHost();
  final SessionClient sessionClient = SessionClient();

  final RxString sessionName = ''.obs;
  final RxString sessionId = ''.obs;
  final RxBool isHosting = false.obs;
  final RxBool isPeer = false.obs;
  final RxList<ConnectedPeer> connectedPeers = <ConnectedPeer>[].obs;
  final RxList<DiscoveredSession> discoveredSessions = <DiscoveredSession>[].obs;
  final Rx<ClientState> clientState = ClientState.disconnected.obs;
  final RxDouble currentPositionMs = 0.0.obs;
  final RxDouble currentDurationMs = 0.0.obs;
  final RxString currentTrackTitle = ''.obs;
  final RxString currentTrackArtist = ''.obs;
  final RxBool isPlaying = false.obs;

  @override
  void onInit() {
    super.onInit();
    lanDiscovery.discoveredSessions.listen((sessions) {
      discoveredSessions.value = sessions;
    });

    sessionHost.peerListStream.listen((peers) {
      connectedPeers.value = peers;
    });

    sessionClient.stateStream.listen((state) {
      clientState.value = state;
    });
  }

  int get hostPort => sessionHost.port ?? 0;

  Future<void> startHosting({required String name}) async {
    sessionName.value = name;
    sessionId.value = _generateSessionId();

    final port = 18765;
    await sessionHost.start(port);
    syncController.startHosting();

    await lanDiscovery.startAdvertising(
      sessionName: name,
      hostPort: port,
      sessionId: sessionId.value,
    );

    isHosting.value = true;
  }

  Future<void> stopHosting() async {
    lanDiscovery.stopAdvertising();
    await sessionHost.stop();
    syncController.stopHosting();
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
      peerName: 'Rhythmic Desktop',
      device: 'windows',
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
}
