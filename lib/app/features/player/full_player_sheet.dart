import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/app/features/player/player_progress.dart';
import '/app/features/queue/queue_sheet.dart';
import '/app/widgets/artwork.dart';
import '/core/core.dart';

class FullPlayerSheet extends StatelessWidget {
  const FullPlayerSheet({super.key, required this.backend});

  final HarmonyBackend backend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;
    final height = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: height * 0.94),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: StreamBuilder<MediaItem?>(
          stream: backend.playback.currentItem,
          builder: (context, itemSnapshot) {
            final song = itemSnapshot.data;
            if (song == null) {
              return const SizedBox(height: 220);
            }

            return StreamBuilder<PlaybackState>(
              stream: backend.playback.state,
              builder: (context, stateSnapshot) {
                final state = stateSnapshot.data;
                final playing = state?.playing ?? false;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            onPressed: Navigator.of(context).pop,
                          ),
                          Expanded(
                            child: Text(
                              'Now playing',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Queue',
                            icon: const Icon(Icons.queue_music_rounded),
                            onPressed: () => _showQueue(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Artwork(uri: song.artUri, size: 420),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        song.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song.artist ?? song.album ?? '',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.muted, fontSize: 16),
                      ),
                      const SizedBox(height: 28),
                      PlayerProgress(backend: backend),
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Previous',
                            iconSize: 34,
                            icon: const Icon(Icons.skip_previous_rounded),
                            onPressed: backend.playback.previous,
                          ),
                          const SizedBox(width: 18),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              fixedSize: const Size(70, 58),
                            ),
                            onPressed: playing
                                ? backend.playback.pause
                                : backend.playback.play,
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 18),
                          IconButton(
                            tooltip: 'Next',
                            iconSize: 34,
                            icon: const Icon(Icons.skip_next_rounded),
                            onPressed: backend.playback.next,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QueueSheet(backend: backend),
    );
  }
}
