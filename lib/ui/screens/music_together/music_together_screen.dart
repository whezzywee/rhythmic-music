import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/music_together/music_together_service.dart';
import 'host_session_screen.dart';
import 'join_session_screen.dart';
import 'session_overlay.dart';

class MusicTogetherScreen extends StatelessWidget {
  const MusicTogetherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Together'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const _HeaderSection(),
          const Expanded(child: _SessionView()),
          if (_sessionActive()) const _OverlaySection(),
        ],
      ),
    );
  }

  bool _sessionActive() {
    final service = Get.find<MusicTogetherService>();
    return service.isHosting.value || service.isPeer.value;
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.group,
            size: 48,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 12),
          Obx(() {
            final service = Get.find<MusicTogetherService>();
            if (service.isHosting.value) {
              return Text(
                'Hosting: ${service.sessionName.value}',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              );
            } else if (service.isPeer.value) {
              return Text(
                'Connected to session',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              );
            }
            return Text(
              'Listen Together',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            );
          }),
          const SizedBox(height: 4),
          Text(
            'Sync music on the same local network',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MusicTogetherService>(
      builder: (controller) {
        if (controller.isHosting.value) {
          return const HostSessionScreen();
        } else if (controller.isPeer.value) {
          return const _PeerView();
        }
        return const _MainMenu();
      },
    );
  }
}

class _MainMenu extends StatefulWidget {
  const _MainMenu();

  @override
  State<_MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<_MainMenu> {
  @override
  void initState() {
    super.initState();
    final service = Get.find<MusicTogetherService>();
    service.startDiscovery();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _MenuCard(
            icon: Icons.cast,
            title: 'Host a Session',
            subtitle: 'Play music and let others join',
            onTap: () => _showHostDialog(context),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            icon: Icons.connect_without_contact,
            title: 'Join a Session',
            subtitle: 'Listen along with someone else',
            onTap: () => _showJoinSheet(context),
          ),
        ],
      ),
    );
  }

  void _showHostDialog(BuildContext context) {
    final nameController = TextEditingController(text: 'Rhythmic Session');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Host a Session'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Session Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Get.find<MusicTogetherService>()
                  .startHosting(name: nameController.text.trim());
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    Get.find<MusicTogetherService>().stopDiscovery();
    super.dispose();
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeerView extends StatelessWidget {
  const _PeerView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.headphones, size: 48),
            const SizedBox(height: 16),
            Obx(() {
              final service = Get.find<MusicTogetherService>();
              return Text(
                'Listening on: ${service.sessionName.value}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Playback is synced with the host',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Get.find<MusicTogetherService>().leaveSession(),
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Leave Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlaySection extends StatelessWidget {
  const _OverlaySection();

  @override
  Widget build(BuildContext context) {
    return const SessionOverlay();
  }
}

void _showJoinSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const JoinSessionSheet(),
  );
}
