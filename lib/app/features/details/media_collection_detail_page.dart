import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/app_theme.dart';
import '/app/features/search/song_result_tile.dart';
import '/app/widgets/inline_message.dart';
import '/app/widgets/page_header.dart';
import '/app/widgets/song_actions_menu.dart';
import '/core/core.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/playlist.dart';

class MediaCollectionDetail {
  const MediaCollectionDetail({
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.songsFuture,
    this.sourcePlaylist,
    this.sourceAlbum,
    this.sourceArtist,
    this.emptyTitle = 'No songs found',
    this.downloadTooltip = 'Download collection',
  });

  factory MediaCollectionDetail.album({
    required HarmonyBackend backend,
    required Album album,
  }) {
    return MediaCollectionDetail(
      title: album.title,
      subtitle: album.description ?? _artistNames(album.artists),
      thumbnailUrl: album.thumbnailUrl,
      songsFuture: loadAlbumSongs(backend, album),
      sourceAlbum: album,
      downloadTooltip: 'Download album',
    );
  }

  factory MediaCollectionDetail.playlist({
    required HarmonyBackend backend,
    required Playlist playlist,
    Future<List<MediaItem>>? songsFuture,
  }) {
    return MediaCollectionDetail(
      title: playlist.title,
      subtitle: playlist.description ?? 'Playlist',
      thumbnailUrl: playlist.thumbnailUrl,
      sourcePlaylist: playlist,
      songsFuture: songsFuture ?? loadPlaylistSongs(backend, playlist),
      emptyTitle: 'This playlist is empty',
      downloadTooltip: 'Download playlist',
    );
  }

  factory MediaCollectionDetail.artist({
    required HarmonyBackend backend,
    required Artist artist,
  }) {
    return MediaCollectionDetail(
      title: artist.name,
      subtitle: artist.subscribers ?? 'Artist',
      thumbnailUrl: artist.thumbnailUrl,
      songsFuture: loadArtistSongs(backend, artist),
      sourceArtist: artist,
      emptyTitle: 'No top songs found',
      downloadTooltip: 'Download top songs',
    );
  }

  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final Future<List<MediaItem>> songsFuture;
  final Playlist? sourcePlaylist;
  final Album? sourceAlbum;
  final Artist? sourceArtist;
  final String emptyTitle;
  final String downloadTooltip;
}

class MediaCollectionDetailPage extends StatefulWidget {
  const MediaCollectionDetailPage({
    super.key,
    required this.detail,
    required this.backend,
    required this.onBack,
    this.onChanged,
  });

  final MediaCollectionDetail detail;
  final HarmonyBackend backend;
  final VoidCallback onBack;
  final VoidCallback? onChanged;

  @override
  State<MediaCollectionDetailPage> createState() =>
      _MediaCollectionDetailPageState();
}

class _MediaCollectionDetailPageState extends State<MediaCollectionDetailPage> {
  bool? _albumSaved;
  bool? _artistSaved;

  @override
  void initState() {
    super.initState();
    _checkSavedState();
  }

  Future<void> _checkSavedState() async {
    final album = widget.detail.sourceAlbum;
    if (album != null) {
      final saved = await widget.backend.library.isAlbumSaved(album.browseId);
      if (mounted) setState(() => _albumSaved = saved);
    }
    final artist = widget.detail.sourceArtist;
    if (artist != null) {
      final saved = await widget.backend.library.isArtistSaved(artist.browseId);
      if (mounted) setState(() => _artistSaved = saved);
    }
  }

  Future<void> _toggleAlbumSave() async {
    final album = widget.detail.sourceAlbum;
    if (album == null || _albumSaved == null) return;
    if (_albumSaved!) {
      await widget.backend.library.removeAlbum(album.browseId);
      if (mounted) setState(() => _albumSaved = false);
    } else {
      await widget.backend.library.saveAlbum(album);
      if (mounted) setState(() => _albumSaved = true);
    }
    widget.onChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_albumSaved! ? 'Album saved' : 'Album removed'),
        ),
      );
    }
  }

  Future<void> _toggleArtistSave() async {
    final artist = widget.detail.sourceArtist;
    if (artist == null || _artistSaved == null) return;
    if (_artistSaved!) {
      await widget.backend.library.removeArtist(artist.browseId);
      if (mounted) setState(() => _artistSaved = false);
    } else {
      await widget.backend.library.saveArtist(artist);
      if (mounted) setState(() => _artistSaved = true);
    }
    widget.onChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_artistSaved! ? 'Artist saved' : 'Artist removed'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;

    return FutureBuilder<List<MediaItem>>(
      future: widget.detail.songsFuture,
      builder: (context, snapshot) {
        final songs = snapshot.data ?? const <MediaItem>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: widget.detail.title,
                subtitle: loading
                    ? widget.detail.subtitle
                    : '${songs.length} songs',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.detail.sourceAlbum != null)
                      IconButton(
                        tooltip:
                            _albumSaved == true ? 'Remove album' : 'Save album',
                        icon: Icon(_albumSaved == true
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded),
                        onPressed: _albumSaved == null
                            ? null
                            : _toggleAlbumSave,
                      ),
                    if (widget.detail.sourceArtist != null)
                      IconButton(
                        tooltip: _artistSaved == true
                            ? 'Remove artist'
                            : 'Save artist',
                        icon: Icon(_artistSaved == true
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded),
                        onPressed: _artistSaved == null
                            ? null
                            : _toggleArtistSave,
                      ),
                    IconButton(
                      tooltip: 'Play all',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed:
                          songs.isEmpty ? null : () => _playSongs(songs, 0),
                    ),
                    IconButton(
                      tooltip: widget.detail.downloadTooltip,
                      icon: const Icon(Icons.download_rounded),
                      onPressed: songs.isEmpty
                          ? null
                          : () => _downloadAll(context, songs),
                    ),
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: widget.onBack,
                    ),
                  ],
                ),
              ),
            ),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (songs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: InlineMessage(
                  icon: Icons.music_note_rounded,
                  title: widget.detail.emptyTitle,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: songs.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: colors.surfaceHigh,
                  ),
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return SongResultTile(
                      song: song,
                      index: index,
                      onTap: () => _playSongs(songs, index),
                      actions: SongActionsMenu(
                        backend: widget.backend,
                        song: song,
                        sourcePlaylist: widget.detail.sourcePlaylist,
                        onChanged: widget.onChanged,
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

  Future<void> _playSongs(List<MediaItem> songs, int index) {
    return widget.backend.playback.playQueue(songs, startIndex: index);
  }

  Future<void> _downloadAll(BuildContext context, List<MediaItem> songs) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${songs.length} songs')),
    );
    final results = await widget.backend.downloadRepository.downloadSongs(songs);
    if (!context.mounted) return;
    final completed = results.where((result) => result.playable).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Downloaded $completed of ${songs.length} songs')),
    );
    widget.onChanged?.call();
  }
}

Future<List<MediaItem>> loadAlbumSongs(
  HarmonyBackend backend,
  Album album,
) async {
  final result = await backend.music.getPlaylistOrAlbumSongs(
    albumId: album.browseId,
  );
  return List<MediaItem>.from(result['tracks'] ?? const []);
}

Future<List<MediaItem>> loadPlaylistSongs(
  HarmonyBackend backend,
  Playlist playlist,
) async {
  if (playlist.isPipedPlaylist) {
    return backend.piped.getPlaylistSongs(playlist.playlistId);
  }
  if (playlist.isCloudPlaylist && !playlist.playlistId.startsWith('LIB')) {
    final result = await backend.music.getPlaylistOrAlbumSongs(
      playlistId: playlist.playlistId,
    );
    return List<MediaItem>.from(result['tracks'] ?? const []);
  }
  return backend.library.playlistSongs(playlist);
}

Future<List<MediaItem>> loadArtistSongs(
  HarmonyBackend backend,
  Artist artist,
) async {
  final artistData = await backend.music.getArtist(artist.browseId);
  final topSongs = artistData['Top songs'] ?? artistData['Songs'];
  if (topSongs is Map && topSongs['content'] is List) {
    return List<MediaItem>.from(topSongs['content']);
  }
  if (topSongs is Map && topSongs.containsKey('params')) {
    final result = await backend.music.getArtistRealtedContent(
      Map<String, dynamic>.from(topSongs),
      'Songs',
    );
    return List<MediaItem>.from(result['results'] ?? const []);
  }
  return const [];
}

String _artistNames(List<Map<dynamic, dynamic>>? artists) {
  final names = artists
      ?.map((artist) => artist['name']?.toString())
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .toList();
  if (names == null || names.isEmpty) return 'Album';
  return names.join(', ');
}
