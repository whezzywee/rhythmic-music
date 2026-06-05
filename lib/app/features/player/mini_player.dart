import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/app/features/player/full_player_sheet.dart';
import '/app/widgets/artwork.dart';
import '/core/core.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.backend});

  final HarmonyBackend backend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return StreamBuilder<MediaItem?>(
      stream: backend.playback.currentItem,
      builder: (context, itemSnapshot) {
        final song = itemSnapshot.data;
        if (song == null) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<PlaybackState>(
          stream: backend.playback.state,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            final playing = state?.playing ?? false;
            final processing = state?.processingState;

            return Material(
              color: colors.surface,
              child: InkWell(
                onTap: () => _showFullPlayer(context),
                child: Container(
                  height: 82,
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: colors.surfaceHigh),
                    ),
                  ),
                  child: Row(
                    children: [
                      _NowPlayingArtwork(
                        uri: song.artUri,
                        loading: processing == AudioProcessingState.loading ||
                            processing == AudioProcessingState.buffering,
                      ),
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
                            Row(
                              children: [
                                if (processing == AudioProcessingState.loading ||
                                    processing == AudioProcessingState.buffering)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.secondary,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    song.artist ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: colors.muted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Previous',
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: backend.playback.previous,
                      ),
                      FilledButton(
                        onPressed: playing
                            ? backend.playback.pause
                            : backend.playback.play,
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next',
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: backend.playback.next,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFullPlayer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullPlayerSheet(backend: backend),
    );
  }
}

class _NowPlayingArtwork extends StatelessWidget {
  const _NowPlayingArtwork({required this.uri, required this.loading});

  final Uri? uri;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return Stack(
      alignment: Alignment.center,
      children: [
        Artwork(uri: uri, size: 56),
        if (loading)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.background.withOpacity(0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.secondary,
              ),
            ),
          ),
      ],
    );
  }
}
