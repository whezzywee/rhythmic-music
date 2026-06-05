import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/app/features/details/media_collection_detail_page.dart';
import '/app/widgets/artwork.dart';
import '/app/widgets/inline_message.dart';
import '/app/widgets/page_header.dart';
import '/app/widgets/shimmer_placeholder.dart';
import '/core/core.dart';
import '/models/playlist.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key, required this.backend});

  final HarmonyBackend backend;

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  late Future<List<Playlist>> _playlistsFuture = _loadPlaylists();
  Playlist? _selectedPlaylist;
  Future<List<MediaItem>>? _songsFuture;

  Future<List<Playlist>> _loadPlaylists() {
    return widget.backend.library.playlists();
  }

  void _refresh() {
    setState(() => _playlistsFuture = _loadPlaylists());
  }

  void _refreshSelectedPlaylist() {
    final playlist = _selectedPlaylist;
    if (playlist == null) return;
    setState(() => _songsFuture = loadPlaylistSongs(widget.backend, playlist));
  }

  void _openPlaylist(Playlist playlist) {
    setState(() {
      _selectedPlaylist = playlist;
      _songsFuture = loadPlaylistSongs(widget.backend, playlist);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedPlaylist != null && _songsFuture != null) {
      return MediaCollectionDetailPage(
        detail: MediaCollectionDetail.playlist(
          backend: widget.backend,
          playlist: _selectedPlaylist!,
          songsFuture: _songsFuture!,
        ),
        backend: widget.backend,
        onBack: () => setState(() {
          _selectedPlaylist = null;
          _songsFuture = null;
          _playlistsFuture = _loadPlaylists();
        }),
        onChanged: _refreshSelectedPlaylist,
      );
    }

    return FutureBuilder<List<Playlist>>(
      future: _playlistsFuture,
      builder: (context, snapshot) {
        final playlists = snapshot.data ?? const <Playlist>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Playlists',
                subtitle: '${playlists.length} collections',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Create playlist',
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => _createPlaylist(context),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
            ),
            if (loading)
              const SliverToBoxAdapter(child: ShimmerPlaceholder(rows: 8))
            else if (playlists.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: InlineMessage(
                  icon: Icons.queue_music_rounded,
                  title: 'No playlists yet',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: playlists.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _PlaylistTile(
                      playlist: playlists[index],
                      onTap: () => _openPlaylist(playlists[index]),
                      onRename: widget.backend.library
                              .canEditPlaylist(playlists[index])
                          ? () => _renamePlaylist(context, playlists[index])
                          : null,
                      onDelete: widget.backend.library
                              .canEditPlaylist(playlists[index])
                          ? () => _deletePlaylist(context, playlists[index])
                          : null,
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final title = await _askForPlaylistTitle(context, title: 'Create playlist');
    if (title == null || title.trim().isEmpty) return;
    await widget.backend.library.createPlaylist(title);
    _refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist created')),
      );
    }
  }

  Future<void> _renamePlaylist(BuildContext context, Playlist playlist) async {
    final title = await _askForPlaylistTitle(
      context,
      title: 'Rename playlist',
      initialValue: playlist.title,
    );
    if (title == null || title.trim().isEmpty) return;
    await widget.backend.library.renamePlaylist(playlist, title);
    _refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist renamed')),
      );
    }
  }

  Future<void> _deletePlaylist(BuildContext context, Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete playlist'),
        content: Text('Delete "${playlist.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.backend.library.deletePlaylist(playlist);
    _refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist deleted')),
      );
    }
  }

  Future<String?> _askForPlaylistTitle(
    BuildContext context, {
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            prefixIcon: Icon(Icons.queue_music_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              Artwork(uri: Uri.tryParse(playlist.thumbnailUrl), size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playlist.description ?? 'Playlist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (onRename != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: 'Playlist actions',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'rename') onRename?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: _PlaylistActionLabel(
                        icon: Icons.edit_rounded,
                        label: 'Rename',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: _PlaylistActionLabel(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                      ),
                    ),
                  ],
                )
              else
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistActionLabel extends StatelessWidget {
  const _PlaylistActionLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
