import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/music_together/music_together_service.dart';

class JoinSessionSheet extends StatelessWidget {
  const JoinSessionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Available Sessions',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      final service = Get.find<MusicTogetherService>();
                      service.stopDiscovery();
                      service.startDiscovery();
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Obx(() {
                final sessions =
                    Get.find<MusicTogetherService>().discoveredSessions;
                if (sessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No sessions found on the network',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Make sure devices are on the same WiFi',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note,
                          color: Colors.green),
                      title: Text(session.sessionName),
                      subtitle: Text(session.hostAddress),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16),
                      onTap: () {
                        Navigator.pop(context);
                        Get.find<MusicTogetherService>()
                            .joinSession(session);
                      },
                    );
                  },
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
