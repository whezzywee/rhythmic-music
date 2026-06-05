import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '/app/app_link_service.dart';
import '/app/app_theme.dart';
import '/app/features/discover/discover_page.dart';
import '/app/features/downloads/downloads_page.dart';
import '/app/features/library/library_page.dart';
import '/app/features/player/mini_player.dart';
import '/app/features/playlists/playlists_page.dart';
import '/app/features/search/search_page.dart';
import '/app/features/settings/settings_page.dart';
import '/core/core.dart';

class NewAppShell extends StatefulWidget {
  const NewAppShell({
    super.key,
    required this.backend,
    this.appLinkService,
  });

  final HarmonyBackend backend;
  final AppLinkService? appLinkService;

  @override
  State<NewAppShell> createState() => _NewAppShellState();
}

class _NewAppShellState extends State<NewAppShell> {
  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<AppLinkAction>? _appLinkSubscription;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _eventSubscription =
        widget.backend.playback.events.listen(_handlePlaybackEvent);
    final appLinkService = widget.appLinkService;
    if (appLinkService != null) {
      _appLinkSubscription = appLinkService.actions.listen(_handleAppLink);
      appLinkService.start();
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _appLinkSubscription?.cancel();
    widget.appLinkService?.dispose();
    super.dispose();
  }

  void _handlePlaybackEvent(dynamic event) {
    if (!mounted || event is! Map) return;
    if (event[PlaybackEventKey.eventType] == PlaybackEventType.playbackError) {
      final message =
          event[PlaybackEventKey.message]?.toString() ?? 'Playback error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message == 'networkError' ? 'Network error' : message),
        ),
      );
    }
  }

  Future<void> _handleAppLink(AppLinkAction action) async {
    if (!mounted) return;
    switch (action.type) {
      case AppLinkActionType.song:
        await _playLinkedSong(action);
        break;
      case AppLinkActionType.playlist:
        await _playLinkedPlaylist(action);
        break;
      case AppLinkActionType.album:
        await _playLinkedAlbum(action);
        break;
      case AppLinkActionType.artist:
        await _playLinkedArtist(action);
        break;
      case AppLinkActionType.unsupported:
        _showMessage('This link is not a playable YouTube Music link');
        break;
    }
  }

  Future<void> _playLinkedSong(AppLinkAction action) async {
    final songId = action.id;
    if (songId == null) return;
    _showMessage('Opening song');
    final result = await widget.backend.music.getSongWithId(songId);
    if (!mounted) return;
    if (result[0] == true) {
      await widget.backend.playback.playQueue(List.from(result[1]));
    } else {
      _showMessage('This YouTube link is not a music track');
    }
  }

  Future<void> _playLinkedPlaylist(AppLinkAction action) async {
    final playlistId = action.id;
    if (playlistId == null) return;
    _showMessage('Opening playlist');
    final result = await widget.backend.music.getPlaylistOrAlbumSongs(
      playlistId: playlistId,
    );
    if (!mounted) return;
    await _playLinkedTracks(result['tracks']);
  }

  Future<void> _playLinkedAlbum(AppLinkAction action) async {
    final albumId = action.id;
    if (albumId == null) return;
    _showMessage('Opening album');
    final result = await widget.backend.music.getPlaylistOrAlbumSongs(
      albumId: albumId,
    );
    if (!mounted) return;
    await _playLinkedTracks(result['tracks']);
  }

  Future<void> _playLinkedArtist(AppLinkAction action) async {
    final artistId = action.id;
    if (artistId == null) return;
    _showMessage('Opening artist');
    final artistData = await widget.backend.music.getArtist(artistId);
    if (!mounted) return;
    final topSongs = artistData['Top songs'] ?? artistData['Songs'];
    List<MediaItem> tracks;
    if (topSongs is Map && topSongs['content'] is List) {
      tracks = List<MediaItem>.from(topSongs['content']);
    } else {
      tracks = const [];
    }
    if (tracks.isEmpty) {
      _showMessage('No content found for this artist');
      return;
    }
    await widget.backend.playback.playQueue(tracks);
  }

  Future<void> _playLinkedTracks(dynamic tracks) async {
    final songs = List<MediaItem>.from(tracks ?? const <MediaItem>[]);
    if (songs.isEmpty) {
      _showMessage('No playable songs found for this link');
      return;
    }
    await widget.backend.playback.playQueue(songs);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NewAppColors>()!;
    final wide = MediaQuery.sizeOf(context).width >= 820;
    final pages = [
      DiscoverPage(backend: widget.backend),
      SearchPage(backend: widget.backend),
      LibraryPage(backend: widget.backend),
      PlaylistsPage(backend: widget.backend),
      DownloadsPage(backend: widget.backend),
      SettingsPage(backend: widget.backend),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      backgroundColor: colors.background,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectTab,
                      labelType: NavigationRailLabelType.all,
                      destinations: _destinations
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(item.selectedIcon),
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
            if (!wide)
              NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _selectTab,
                destinations: _destinations
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: item.label,
                      ),
                    )
                    .toList(),
              ),
            MiniPlayer(backend: widget.backend),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }
}

const _destinations = [
  _ShellDestination(
    label: 'Discover',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore_rounded,
  ),
  _ShellDestination(
    label: 'Search',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search_rounded,
  ),
  _ShellDestination(
    label: 'Library',
    icon: Icons.library_music_outlined,
    selectedIcon: Icons.library_music_rounded,
  ),
  _ShellDestination(
    label: 'Playlists',
    icon: Icons.queue_music_outlined,
    selectedIcon: Icons.queue_music_rounded,
  ),
  _ShellDestination(
    label: 'Downloads',
    icon: Icons.download_outlined,
    selectedIcon: Icons.download_rounded,
  ),
  _ShellDestination(
    label: 'Settings',
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune_rounded,
  ),
];

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
