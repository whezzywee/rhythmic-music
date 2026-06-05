import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/app/widgets/artwork.dart';
import '/app/widgets/inline_message.dart';
import '/core/core.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key, required this.backend});

  final HarmonyBackend backend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;
    final height = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: height * 0.82),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: StreamBuilder<List<MediaItem>>(
          stream: backend.playback.queue,
          builder: (context, queueSnapshot) {
            final queue = queueSnapshot.data ?? const <MediaItem>[];

            return StreamBuilder<PlaybackState>(
              stream: backend.playback.state,
              builder: (context, stateSnapshot) {
                final state = stateSnapshot.data;
                final currentIndex = state?.queueIndex ?? -1;
                final shuffleEnabled =
                    state?.shuffleMode == AudioServiceShuffleMode.all;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            onPressed: Navigator.of(context).pop,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Up next',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  '${queue.length} songs',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colors.muted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Shuffle queue',
                            icon: const Icon(Icons.shuffle_rounded),
                            onPressed: queue.length < 2
                                ? null
                                : backend.playback.shuffleCurrentQueue,
                          ),
                          IconButton(
                            tooltip: 'Clear queue',
                            icon: const Icon(Icons.delete_sweep_rounded),
                            onPressed: queue.length < 2
                                ? null
                                : backend.playback.clearQueue,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.surfaceHigh),
                    Expanded(
                      child: queue.isEmpty
                          ? const InlineMessage(
                              icon: Icons.queue_music_rounded,
                              title: 'Queue is empty',
                            )
                          : ReorderableListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 10, 14, 24),
                              itemCount: queue.length,
                              onReorder: (oldIndex, newIndex) {
                                if (shuffleEnabled) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Turn off shuffle before reordering',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final backendNewIndex = oldIndex < newIndex
                                    ? newIndex + 1
                                    : newIndex;
                                backend.playback.moveQueueItem(
                                  oldIndex: oldIndex,
                                  newIndex: backendNewIndex,
                                );
                              },
                              itemBuilder: (context, index) {
                                final song = queue[index];
                                return QueueTile(
                                  key: ValueKey('$index-${song.id}'),
                                  song: song,
                                  index: index,
                                  active: index == currentIndex,
                                  onTap: () =>
                                      backend.playback.playIndex(index),
                                  onRemove: index == currentIndex
                                      ? null
                                      : () => backend.playback
                                          .removeFromQueue(song),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class QueueTile extends StatelessWidget {
  const QueueTile({
    super.key,
    required this.song,
    required this.index,
    required this.active,
    required this.onTap,
    required this.onRemove,
  });

  final MediaItem song;
  final int index;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return Material(
      color: active ? colors.surfaceHigh : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: active
                    ? Icon(Icons.equalizer_rounded, color: colors.secondary)
                    : Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.muted),
                      ),
              ),
              Artwork(uri: song.artUri, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist ?? song.album ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
                onPressed: onRemove,
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.drag_handle_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
