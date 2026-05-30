import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/music_together/music_together_service.dart';

class SessionOverlay extends StatelessWidget {
  const SessionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha(25),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).primaryColor.withAlpha(80),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Obx(() {
            final service = Get.find<MusicTogetherService>();
            final isHost = service.isHosting.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isHost ? Icons.cast : Icons.headphones,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  isHost ? 'Hosting session' : 'Synced with host',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            );
          }),
          Obx(() {
            final count =
                Get.find<MusicTogetherService>().connectedPeers.length;
            if (count > 0) {
              return Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$count peer${count != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}
