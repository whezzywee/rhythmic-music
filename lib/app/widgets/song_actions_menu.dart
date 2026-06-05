import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/core/core.dart';
import '/models/playlist.dart';

enum _SongAction {
  playNext,
  addToQueue,
  addToPlaylist,
  download,
  removeFromPlaylist,
}

class SongActionsMenu extends StatelessWidget {
  const SongActionsMenu({
    super.key,
    required this.backend,
    required this.song,
    this.sourcePlaylist,
    this.onChanged,
  });

  final HarmonyBackend backend;
  final MediaItem song;
  final Playlist? sourcePlaylist;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final canRemove = sourcePlaylist != null &&
        backend.library.canEditPlaylist(sourcePlaylist!);

    return PopupMenuButton<_SongAction>(
      tooltip: 'Song actions',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _SongAction.playNext,
          child: _ActionLabel(
            icon: Icons.playlist_play_rounded,
            label: 'Play next',
          ),
        ),
        const PopupMenuItem(
          value: _SongAction.addToQueue,
          child: _ActionLabel(
            icon: Icons.add_to_queue_rounded,
            label: 'Add to queue',
          ),
        ),
        const PopupMenuItem(
          value: _SongAction.addToPlaylist,
          child: _ActionLabel(
            icon: Icons.playlist_add_rounded,
            label: 'Add to playlist',
          ),
        ),
        const PopupMenuItem(
          value: _SongAction.download,
          child: _ActionLabel(
            icon: Icons.download_rounded,
            label: 'Download',
          ),
        ),
        if (canRemove)
          const PopupMenuItem(
            value: _SongAction.removeFromPlaylist,
            child: _ActionLabel(
              icon: Icons.remove_circle_outline_rounded,
              label: 'Remove from playlist',
            ),
          ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, _SongAction action) async {
    switch (action) {
      case _SongAction.playNext:
        await backend.playback.playNext(song);
        if (!context.mounted) return;
        _showMessage(context, 'Added to play next');
        break;
      case _SongAction.addToQueue:
        await backend.playback.addToQueue(song);
        if (!context.mounted) return;
        _showMessage(context, 'Added to queue');
        break;
      case _SongAction.addToPlaylist:
        await _showAddToPlaylistSheet(context);
        break;
      case _SongAction.download:
        await _download(context);
        break;
      case _SongAction.removeFromPlaylist:
        final playlist = sourcePlaylist;
        if (playlist == null) return;
        await backend.library.removeSongFromPlaylist(
          playlist: playlist,
          song: song,
        );
        if (!context.mounted) return;
        onChanged?.call();
        _showMessage(context, 'Removed from playlist');
        break;
    }
  }

  Future<void> _showAddToPlaylistSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddToPlaylistSheet(
        backend: backend,
        songs: [song],
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    _showMessage(context, 'Downloading ${song.title}');
    final result = await backend.downloadRepository.downloadSong(song);
    if (!context.mounted) return;
    _showMessage(
      context,
      result.playable ? 'Downloaded ${song.title}' : result.statusMessage,
    );
    onChanged?.call();
  }

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _AddToPlaylistSheet extends StatefulWidget {
  const _AddToPlaylistSheet({
    required this.backend,
    required this.songs,
    this.onChanged,
  });

  final HarmonyBackend backend;
  final List<MediaItem> songs;
  final VoidCallback? onChanged;

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  final TextEditingController _controller = TextEditingController();
  late final Future<List<Playlist>> _playlistsFuture = _loadPlaylists();
  bool _creating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<Playlist>> _loadPlaylists() {
    return widget.backend.library.editablePlaylists();
  }

  Future<void> _createPlaylist() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _creating) return;

    setState(() => _creating = true);
    final playlist = await widget.backend.library.createPlaylist(title);
    await widget.backend.library.addSongsToPlaylist(
      playlist: playlist,
      songs: widget.songs,
    );
    widget.onChanged?.call();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to ${playlist.title}')),
      );
    }
  }

  Future<void> _addToPlaylist(Playlist playlist) async {
    await widget.backend.library.addSongsToPlaylist(
      playlist: playlist,
      songs: widget.songs,
    );
    widget.onChanged?.call();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to ${playlist.title}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;
    final height = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: height * 0.74),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to playlist',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: Navigator.of(context).pop,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _createPlaylist(),
                      decoration: const InputDecoration(
                        hintText: 'New playlist name',
                        prefixIcon: Icon(Icons.queue_music_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _creating ? null : _createPlaylist,
                    child: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: FutureBuilder<List<Playlist>>(
                  future: _playlistsFuture,
                  builder: (context, snapshot) {
                    final playlists = snapshot.data ?? const <Playlist>[];
                    final loading =
                        snapshot.connectionState == ConnectionState.waiting;
                    if (loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (playlists.isEmpty) {
                      return Center(
                        child: Text(
                          'Create a playlist to add this song',
                          style: TextStyle(color: colors.muted),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: playlists.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: colors.surfaceHigh),
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.queue_music_rounded),
                          title: Text(
                            playlist.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            playlist.description ?? 'Playlist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.muted),
                          ),
                          onTap: () => _addToPlaylist(playlist),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({
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
