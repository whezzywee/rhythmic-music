import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/music_together/music_together_service.dart';

class HostSessionScreen extends StatelessWidget {
  const HostSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _HostInfoCard(),
          const SizedBox(height: 16),
          _PeerListCard(),
          const SizedBox(height: 16),
          _StopHostingButton(),
        ],
      ),
    );
  }
}

class _HostInfoCard extends StatelessWidget {
  const _HostInfoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.cast, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text('Session Active',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'HOSTING',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Obx(() {
              final service = Get.find<MusicTogetherService>();
              return _InfoRow('Name', service.sessionName.value);
            }),
            Obx(() {
              final service = Get.find<MusicTogetherService>();
              return _InfoRow('Port', service.hostPort.toString());
            }),
            Obx(() {
              final service = Get.find<MusicTogetherService>();
              return _InfoRow(
                  'ID', service.sessionId.value.toUpperCase());
            }),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class _PeerListCard extends StatelessWidget {
  const _PeerListCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, size: 20),
                const SizedBox(width: 8),
                const Text('Connected Peers',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Obx(() {
                  final count =
                      Get.find<MusicTogetherService>().connectedPeers.length;
                  return Text(
                    '$count',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }),
              ],
            ),
            const Divider(height: 16),
            Obx(() {
              final peers =
                  Get.find<MusicTogetherService>().connectedPeers;
              if (peers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Waiting for peers to join...',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: peers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final peer = peers[index];
                  IconData deviceIcon;
                  switch (peer.device) {
                    case 'android':
                      deviceIcon = Icons.phone_android;
                      break;
                    case 'linux':
                      deviceIcon = Icons.computer;
                      break;
                    default:
                      deviceIcon = Icons.laptop_windows;
                  }
                  return ListTile(
                    leading: Icon(deviceIcon),
                    title: Text(peer.name),
                    subtitle: Text(peer.device),
                    dense: true,
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StopHostingButton extends StatelessWidget {
  const _StopHostingButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () =>
            Get.find<MusicTogetherService>().stopHosting(),
        icon: const Icon(Icons.stop),
        label: const Text('Stop Hosting'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
