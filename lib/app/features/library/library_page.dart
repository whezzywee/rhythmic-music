import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/features/details/media_collection_detail_page.dart';
import '/app/features/search/content_result_tile.dart';
import '/app/features/search/song_result_tile.dart';
import '/app/widgets/inline_message.dart';
import '/app/widgets/page_header.dart';
import '/app/widgets/shimmer_placeholder.dart';
import '/app/widgets/song_actions_menu.dart';
import '/core/core.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/playlist.dart';

enum LibraryTab {
  songs(label: 'Songs', icon: Icons.library_music_rounded),
  albums(label: 'Albums', icon: Icons.album_rounded),
  artists(label: 'Artists', icon: Icons.person_rounded),
  playlists(label: 'Playlists', icon: Icons.queue_music_rounded),
  downloads(label: 'Downloads', icon: Icons.download_rounded);

  const LibraryTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.backend});

  final HarmonyBackend backend;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryTab _activeTab = LibraryTab.songs;
  MediaCollectionDetail? _detail;
  late Future<_LibrarySnapshot> _snapshotFuture = _loadSnapshot();

  Future<_LibrarySnapshot> _loadSnapshot() async {
    final songsFuture = widget.backend.library.librarySongs();
    final albumsFuture = widget.backend.library.albums();
    final artistsFuture = widget.backend.library.artists();
    final playlistsFuture = widget.backend.library.playlists();
    final downloadsFuture = widget.backend.library.downloadedSongs();

    return _LibrarySnapshot(
      songs: await songsFuture,
      albums: await albumsFuture,
      artists: await artistsFuture,
      playlists: await playlistsFuture,
      downloads: await downloadsFuture,
    );
  }

  void _refresh() {
    setState(() {
      _detail = null;
      _snapshotFuture = _loadSnapshot();
    });
  }

  void _openAlbum(Album album) {
    setState(() {
      _detail = MediaCollectionDetail.album(
        backend: widget.backend,
        album: album,
      );
    });
  }

  void _openArtist(Artist artist) {
    setState(() {
      _detail = MediaCollectionDetail.artist(
        backend: widget.backend,
        artist: artist,
      );
    });
  }

  void _openPlaylist(Playlist playlist) {
    setState(() {
      _detail = MediaCollectionDetail.playlist(
        backend: widget.backend,
        playlist: playlist,
      );
    });
  }

  Future<void> _play(List<MediaItem> songs, int index) {
    return widget.backend.playback.playQueue(songs, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail != null) {
      return MediaCollectionDetailPage(
        detail: detail,
        backend: widget.backend,
        onBack: () => setState(() => _detail = null),
        onChanged: _refresh,
      );
    }

    return FutureBuilder<_LibrarySnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _LibrarySnapshot.empty();
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Library',
                subtitle: _subtitle(data),
                action: IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _refresh,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _LibraryTabs(
                activeTab: _activeTab,
                onChanged: (tab) => setState(() => _activeTab = tab),
              ),
            ),
            if (loading)
              const SliverToBoxAdapter(child: ShimmerPlaceholder(rows: 8))
            else
              _buildTabContent(context, data),
          ],
        );
      },
    );
  }

  Widget _buildTabContent(BuildContext context, _LibrarySnapshot data) {
    switch (_activeTab) {
      case LibraryTab.songs:
        return _SongList(
          backend: widget.backend,
          songs: data.songs,
          emptyIcon: Icons.library_music_rounded,
          emptyTitle: 'No saved songs yet',
          onPlay: _play,
          onChanged: _refresh,
        );
      case LibraryTab.albums:
        return _AlbumList(
          albums: data.albums,
          onOpen: _openAlbum,
        );
      case LibraryTab.artists:
        return _ArtistList(
          artists: data.artists,
          onOpen: _openArtist,
          onRadio: _playArtistRadio,
        );
      case LibraryTab.playlists:
        return _PlaylistList(
          playlists: data.playlists,
          onOpen: _openPlaylist,
        );
      case LibraryTab.downloads:
        return _SongList(
          backend: widget.backend,
          songs: data.downloads,
          emptyIcon: Icons.download_rounded,
          emptyTitle: 'No downloads yet',
          onPlay: _play,
          onChanged: _refresh,
        );
    }
  }

  Future<void> _playArtistRadio(Artist artist) async {
    if (artist.radioId == null) return;
    final result = await widget.backend.music.getWatchPlaylist(
      playlistId: artist.radioId,
      radio: true,
    );
    final songs = List<MediaItem>.from(result['tracks'] ?? const []);
    if (songs.isNotEmpty) {
      await widget.backend.playback.playQueue(songs);
    }
  }

  String _subtitle(_LibrarySnapshot data) {
    return [
      '${data.songs.length} songs',
      '${data.albums.length} albums',
      '${data.artists.length} artists',
    ].join('  ');
  }
}

class _LibrarySnapshot {
  const _LibrarySnapshot({
    required this.songs,
    required this.albums,
    required this.artists,
    required this.playlists,
    required this.downloads,
  });

  const _LibrarySnapshot.empty()
      : songs = const [],
        albums = const [],
        artists = const [],
        playlists = const [],
        downloads = const [];

  final List<MediaItem> songs;
  final List<Album> albums;
  final List<Artist> artists;
  final List<Playlist> playlists;
  final List<MediaItem> downloads;
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs({
    required this.activeTab,
    required this.onChanged,
  });

  final LibraryTab activeTab;
  final ValueChanged<LibraryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: SegmentedButton<LibraryTab>(
        showSelectedIcon: false,
        segments: LibraryTab.values
            .map(
              (tab) => ButtonSegment(
                value: tab,
                icon: Icon(tab.icon),
                label: Text(tab.label),
              ),
            )
            .toList(),
        selected: {activeTab},
        onSelectionChanged: (selected) => onChanged(selected.first),
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  const _SongList({
    required this.backend,
    required this.songs,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.onPlay,
    required this.onChanged,
  });

  final HarmonyBackend backend;
  final List<MediaItem> songs;
  final IconData emptyIcon;
  final String emptyTitle;
  final Future<void> Function(List<MediaItem> songs, int index) onPlay;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (songs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: InlineMessage(
          icon: emptyIcon,
          title: emptyTitle,
        ),
      );
    }

    return SliverPadding(
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
            onTap: () => onPlay(songs, index),
            actions: SongActionsMenu(
              backend: backend,
              song: songs[index],
              onChanged: onChanged,
            ),
          );
        },
      ),
    );
  }
}

class _AlbumList extends StatelessWidget {
  const _AlbumList({
    required this.albums,
    required this.onOpen,
  });

  final List<Album> albums;
  final ValueChanged<Album> onOpen;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: InlineMessage(
          icon: Icons.album_rounded,
          title: 'No saved albums yet',
          subtitle: 'Albums you save will appear here',
        ),
      );
    }

    return _ContentList(
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return ContentResultTile(
          title: album.title,
          subtitle: album.description ?? _artistNames(album.artists),
          thumbnailUrl: album.thumbnailUrl,
          icon: Icons.album_rounded,
          onTap: () => onOpen(album),
        );
      },
    );
  }
}

class _ArtistList extends StatelessWidget {
  const _ArtistList({
    required this.artists,
    required this.onOpen,
    required this.onRadio,
  });

  final List<Artist> artists;
  final ValueChanged<Artist> onOpen;
  final ValueChanged<Artist> onRadio;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: InlineMessage(
          icon: Icons.person_rounded,
          title: 'No saved artists yet',
          subtitle: 'Artists you save will appear here',
        ),
      );
    }

    return _ContentList(
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ContentResultTile(
          title: artist.name,
          subtitle: artist.subscribers ?? 'Artist',
          thumbnailUrl: artist.thumbnailUrl,
          icon: Icons.person_rounded,
          onTap: () => onOpen(artist),
          trailing: IconButton(
            tooltip: 'Artist radio',
            icon: const Icon(Icons.sensors_rounded),
            onPressed: artist.radioId == null ? null : () => onRadio(artist),
          ),
        );
      },
    );
  }
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList({
    required this.playlists,
    required this.onOpen,
  });

  final List<Playlist> playlists;
  final ValueChanged<Playlist> onOpen;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: InlineMessage(
          icon: Icons.queue_music_rounded,
          title: 'No playlists yet',
          subtitle: 'Create a playlist to get started',
        ),
      );
    }

    return _ContentList(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return ContentResultTile(
          title: playlist.title,
          subtitle: playlist.description ?? 'Playlist',
          thumbnailUrl: playlist.thumbnailUrl,
          icon: Icons.queue_music_rounded,
          onTap: () => onOpen(playlist),
        );
      },
    );
  }
}

class _ContentList extends StatelessWidget {
  const _ContentList({
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      sliver: SliverList.separated(
        itemCount: itemCount,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: colors.surfaceContainerHighest,
        ),
        itemBuilder: itemBuilder,
      ),
    );
  }
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
