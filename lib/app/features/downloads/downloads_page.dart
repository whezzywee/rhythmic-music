import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/app/features/search/song_result_tile.dart';
import '/app/widgets/artwork.dart';
import '/app/widgets/inline_message.dart';
import '/app/widgets/page_header.dart';
import '/app/widgets/shimmer_placeholder.dart';
import '/app/widgets/song_actions_menu.dart';
import '/core/core.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, required this.backend});

  final HarmonyBackend backend;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late Future<List<MediaItem>> _downloadsFuture = _loadDownloads();
  StreamSubscription<DownloadRepositorySnapshot>? _downloadSubscription;
  final Set<String> _refreshedDownloadIds = {};

  @override
  void initState() {
    super.initState();
    _downloadSubscription = widget.backend.downloadRepository.jobs.listen(
      _handleDownloadSnapshot,
    );
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  Future<List<MediaItem>> _loadDownloads() {
    return widget.backend.library.downloadedSongs();
  }

  void _refresh() {
    setState(() => _downloadsFuture = _loadDownloads());
  }

  void _handleDownloadSnapshot(DownloadRepositorySnapshot snapshot) {
    if (!mounted) return;
    for (final job in snapshot.jobs) {
      if (job.status == DownloadJobStatus.completed &&
          _refreshedDownloadIds.add(job.song.id)) {
        _refresh();
        return;
      }
    }
  }

  Future<void> _play(List<MediaItem> songs, int index) {
    return widget.backend.playback.playQueue(songs, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<List<MediaItem>>(
      future: _downloadsFuture,
      builder: (context, snapshot) {
        final songs = snapshot.data ?? const <MediaItem>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Downloads',
                subtitle: '${songs.length} local songs',
                action: IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _refresh,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _DownloadActivity(backend: widget.backend),
            ),
            if (loading)
              const SliverToBoxAdapter(child: ShimmerPlaceholder(rows: 8))
            else if (songs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: InlineMessage(
                                  icon: Icons.download_rounded,
                                  title: 'No downloads yet',
                                  subtitle: 'Downloaded songs will appear here',
                                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: songs.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: colors.surfaceContainerHighest,
                  ),
                  itemBuilder: (context, index) {
                    return SongResultTile(
                      song: songs[index],
                      index: index,
                      onTap: () => _play(songs, index),
                      actions: SongActionsMenu(
                        backend: widget.backend,
                        song: songs[index],
                        onChanged: _refresh,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DownloadActivity extends StatelessWidget {
  const _DownloadActivity({required this.backend});

  final HarmonyBackend backend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return StreamBuilder<DownloadRepositorySnapshot>(
      stream: backend.downloadRepository.jobs,
      initialData: backend.downloadRepository.currentSnapshot,
      builder: (context, snapshot) {
        final jobs = snapshot.data?.jobs ?? const <DownloadJobState>[];
        if (jobs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Activity',
                      style: TextStyle(
                        color: colors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!(snapshot.data?.hasActiveJobs ?? false))
                    IconButton(
                      tooltip: 'Clear finished',
                      icon: const Icon(Icons.clear_all_rounded),
                      onPressed: backend.downloadRepository.clearFinishedJobs,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (final job in jobs) _DownloadJobTile(job: job, backend: backend),
            ],
          ),
        );
      },
    );
  }
}

class _DownloadJobTile extends StatelessWidget {
  const _DownloadJobTile({required this.job, required this.backend});

  final DownloadJobState job;
  final HarmonyBackend backend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;
    final active = job.status == DownloadJobStatus.queued ||
        job.status == DownloadJobStatus.downloading;
    final cancellable = active && job.song.id.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Artwork(uri: job.song.artUri, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: job.progress / 100,
                  minHeight: 5,
                  backgroundColor: colors.surfaceHigh,
                ),
                const SizedBox(height: 5),
                Text(
                  _statusLabel(job),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (cancellable)
            IconButton(
              tooltip: 'Cancel download',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => backend.downloadRepository.cancelDownload(job.song.id),
            )
          else if (job.status == DownloadJobStatus.failed ||
              job.status == DownloadJobStatus.cancelled)
            IconButton(
              tooltip: 'Retry download',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => backend.downloadRepository.retryDownload(job.song),
            )
          else
            SizedBox(
              width: 38,
              child: active
                  ? Text(
                      '${job.progress}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(color: colors.muted),
                    )
                  : Icon(
                      job.status == DownloadJobStatus.completed
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: job.status == DownloadJobStatus.completed
                          ? colors.secondary
                          : Theme.of(context).colorScheme.error,
                    ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(DownloadJobState job) {
    switch (job.status) {
      case DownloadJobStatus.queued:
        return 'Queued';
      case DownloadJobStatus.downloading:
        return 'Downloading';
      case DownloadJobStatus.completed:
        return job.message ?? 'Completed';
      case DownloadJobStatus.failed:
        return job.message ?? 'Failed';
      case DownloadJobStatus.cancelled:
        return 'Cancelled';
    }
  }
}
