import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/features/details/media_collection_detail_page.dart';
import '/app/features/search/content_result_tile.dart';
import '/app/features/search/search_header.dart';
import '/app/features/search/song_result_tile.dart';
import '/app/widgets/inline_message.dart';
import '/app/widgets/shimmer_placeholder.dart';
import '/app/widgets/song_actions_menu.dart';
import '/core/core.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/playlist.dart';

enum SearchFilter {
  songs(label: 'Songs', filter: 'songs'),
  albums(label: 'Albums', filter: 'albums'),
  playlists(label: 'Playlists', filter: 'playlists'),
  artists(label: 'Artists', filter: 'artists');

  const SearchFilter({required this.label, required this.filter});

  final String label;
  final String filter;
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.backend});

  final HarmonyBackend backend;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Map<SearchFilter, List<dynamic>> _results = {};
  final Map<SearchFilter, String> _loadedQueryByFilter = {};

  bool _loading = false;
  String? _error;
  String _query = '';
  SearchFilter _activeFilter = SearchFilter.songs;
  MediaCollectionDetail? _detail;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _query = query;
      _detail = null;
    });

    try {
      final result = await widget.backend.music.search(
        query,
        filter: _activeFilter.filter,
        limit: _activeFilter == SearchFilter.songs ? 30 : 20,
      );
      final items = _itemsForFilter(result, _activeFilter);
      if (!mounted) return;
      setState(() {
        _results[_activeFilter] = items;
        _loadedQueryByFilter[_activeFilter] = query;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<dynamic> _itemsForFilter(
    Map<String, dynamic> result,
    SearchFilter filter,
  ) {
    switch (filter) {
      case SearchFilter.songs:
        return List<MediaItem>.from(result['Songs'] ?? const []);
      case SearchFilter.albums:
        return List<Album>.from(result['Albums'] ?? const []);
      case SearchFilter.playlists:
        return [
          ...List<Playlist>.from(result['Playlists'] ?? const []),
          ...List<Playlist>.from(result['Featured playlists'] ?? const []),
          ...List<Playlist>.from(result['Community playlists'] ?? const []),
        ];
      case SearchFilter.artists:
        return List<Artist>.from(result['Artists'] ?? const []);
    }
  }

  Future<void> _selectFilter(SearchFilter filter) async {
    if (_activeFilter == filter) return;
    setState(() {
      _activeFilter = filter;
      _detail = null;
      _error = null;
    });

    if (_query.isNotEmpty && _loadedQueryByFilter[filter] != _query) {
      await _search(_query);
    }
  }

  Future<void> _playSongs(List<MediaItem> songs, int index) async {
    await widget.backend.playback.playQueue(songs, startIndex: index);
  }

  void _openAlbum(Album album) {
    setState(() {
      _detail = MediaCollectionDetail.album(
        backend: widget.backend,
        album: album,
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

  void _openArtist(Artist artist) {
    setState(() {
      _detail = MediaCollectionDetail.artist(
        backend: widget.backend,
        artist: artist,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail != null) {
      return MediaCollectionDetailPage(
        detail: detail,
        backend: widget.backend,
        onBack: () => setState(() => _detail = null),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final items = _results[_activeFilter] ?? const [];

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: SearchHeader(
            controller: _searchController,
            focusNode: _searchFocus,
            loading: _loading,
            onSubmit: _search,
          ),
        ),
        SliverToBoxAdapter(
          child: _SearchFilters(
            activeFilter: _activeFilter,
            onChanged: _selectFilter,
          ),
        ),
        if (_error != null)
          SliverToBoxAdapter(
            child: InlineMessage(
              icon: Icons.wifi_off_rounded,
              title: _error!,
              onRetry: _query.isNotEmpty ? () => _search(_query) : null,
            ),
          )
        else if (_loading)
          const SliverToBoxAdapter(child: ShimmerPlaceholder(rows: 10))
        else if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptySearchState(query: _query),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            sliver: SliverList.separated(
              itemBuilder: (context, index) {
                return _buildResultTile(items, index);
              },
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: colors.surfaceContainerHighest,
              ),
              itemCount: items.length,
            ),
          ),
      ],
    );
  }

  Widget _buildResultTile(List<dynamic> items, int index) {
    final item = items[index];
    switch (_activeFilter) {
      case SearchFilter.songs:
        final songs = items.cast<MediaItem>();
        final song = songs[index];
        return SongResultTile(
          song: song,
          index: index,
          onTap: () => _playSongs(songs, index),
          actions: SongActionsMenu(
            backend: widget.backend,
            song: song,
          ),
        );
      case SearchFilter.albums:
        final album = item as Album;
        return ContentResultTile(
          title: album.title,
          subtitle: album.description ?? _artistNames(album.artists),
          thumbnailUrl: album.thumbnailUrl,
          icon: Icons.album_rounded,
          onTap: () => _openAlbum(album),
        );
      case SearchFilter.playlists:
        final playlist = item as Playlist;
        return ContentResultTile(
          title: playlist.title,
          subtitle: playlist.description ?? 'Playlist',
          thumbnailUrl: playlist.thumbnailUrl,
          icon: Icons.queue_music_rounded,
          onTap: () => _openPlaylist(playlist),
        );
      case SearchFilter.artists:
        final artist = item as Artist;
        return ContentResultTile(
          title: artist.name,
          subtitle: artist.subscribers ?? 'Artist',
          thumbnailUrl: artist.thumbnailUrl,
          icon: Icons.person_rounded,
          onTap: () => _openArtist(artist),
          trailing: IconButton(
            tooltip: 'Artist radio',
            icon: const Icon(Icons.sensors_rounded),
            onPressed: artist.radioId == null
                ? null
                : () async {
                    final result = await widget.backend.music.getWatchPlaylist(
                      playlistId: artist.radioId,
                      radio: true,
                    );
                    final songs = List<MediaItem>.from(
                      result['tracks'] ?? const [],
                    );
                    if (songs.isNotEmpty) {
                      await widget.backend.playback.playQueue(songs);
                    }
                  },
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
}

class _SearchFilters extends StatelessWidget {
  const _SearchFilters({
    required this.activeFilter,
    required this.onChanged,
  });

  final SearchFilter activeFilter;
  final ValueChanged<SearchFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: SegmentedButton<SearchFilter>(
        showSelectedIcon: false,
        segments: SearchFilter.values
            .map(
              (filter) => ButtonSegment(
                value: filter,
                label: Text(filter.label),
              ),
            )
            .toList(),
        selected: {activeFilter},
        onSelectionChanged: (selected) => onChanged(selected.first),
      ),
    );
  }
}
