import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';

import '/core/library/library_defaults.dart';
import '/core/storage/app_preferences_store.dart';
import '/models/album.dart';
import '/models/artist.dart';
import '/models/media_Item_builder.dart';
import '/models/playlist.dart';

class LibraryRepository {
  const LibraryRepository({required AppPreferencesStore appPreferences})
      : _appPreferences = appPreferences;

  final AppPreferencesStore _appPreferences;

  Future<List<MediaItem>> librarySongs() async {
    final songs = <MediaItem>[];
    songs.addAll(await cachedSongs());
    songs.addAll(await downloadedSongs());
    return _dedupeSongs(songs);
  }

  Future<List<MediaItem>> cachedSongs() {
    return _songsFromBox('SongsCache');
  }

  Future<List<MediaItem>> downloadedSongs() {
    return _songsFromBox('SongDownloads');
  }

  // ── Albums ──

  Future<List<Album>> albums() async {
    final box = await _box('LibraryAlbums');
    return box.values
        .map<Album?>((item) => _albumFromJson(item))
        .whereType<Album>()
        .toList();
  }

  Future<bool> isAlbumSaved(String browseId) async {
    final box = await _box('LibraryAlbums');
    return box.containsKey(browseId);
  }

  Future<void> saveAlbum(Album album) async {
    final box = await _box('LibraryAlbums');
    await box.put(album.browseId, album.toJson());
  }

  Future<void> removeAlbum(String browseId) async {
    final box = await _box('LibraryAlbums');
    await box.delete(browseId);
  }

  // ── Artists ──

  Future<List<Artist>> artists() async {
    final box = await _box('LibraryArtists');
    return box.values
        .map<Artist?>((item) => _artistFromJson(item))
        .whereType<Artist>()
        .toList();
  }

  Future<bool> isArtistSaved(String browseId) async {
    final box = await _box('LibraryArtists');
    return box.containsKey(browseId);
  }

  Future<void> saveArtist(Artist artist) async {
    final box = await _box('LibraryArtists');
    await box.put(artist.browseId, artist.toJson());
  }

  Future<void> removeArtist(String browseId) async {
    final box = await _box('LibraryArtists');
    await box.delete(browseId);
  }

  // ── Playlists ──

  Future<List<Playlist>> playlists({bool includePiped = false}) async {
    final box = await _box('LibraryPlaylists');
    final localPlaylists = box.values
        .map<Playlist?>((item) => _playlistFromJson(item))
        .whereType<Playlist>()
        .where((playlist) => includePiped || !playlist.isPipedPlaylist)
        .toList();

    return [
      ...defaultLibraryPlaylists(),
      ...localPlaylists,
    ];
  }

  Future<List<Playlist>> editablePlaylists() async {
    final playlists = await this.playlists();
    return playlists.where((playlist) => canEditPlaylist(playlist)).toList();
  }

  Future<List<Playlist>> pipedPlaylists() async {
    final box = await _box('LibraryPlaylists');
    return box.values
        .map<Playlist?>((item) => _playlistFromJson(item))
        .whereType<Playlist>()
        .where((playlist) => playlist.isPipedPlaylist)
        .toList();
  }

  bool canEditPlaylist(Playlist playlist) {
    return !playlist.isPipedPlaylist &&
        !playlist.isCloudPlaylist &&
        playlist.playlistId.startsWith('LIB') &&
        playlist.playlistId != 'LIBRP' &&
        playlist.playlistId != 'LIBFAV';
  }

  Future<Playlist> createPlaylist(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Playlist title is required.');
    }

    final playlist = Playlist(
      title: _titleCase(trimmed),
      playlistId: 'LIB${DateTime.now().millisecondsSinceEpoch}',
      thumbnailUrl: Playlist.thumbPlaceholderUrl,
      description: 'Library Playlist',
      isCloudPlaylist: false,
    );
    final box = await _box('LibraryPlaylists');
    await box.put(playlist.playlistId, playlist.toJson());
    await _box(playlist.playlistId);
    return playlist;
  }

  Future<void> renamePlaylist(Playlist playlist, String title) async {
    if (!canEditPlaylist(playlist)) return;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final updated = playlist.copyWith(title: _titleCase(trimmed));
    final box = await _box('LibraryPlaylists');
    await box.put(updated.playlistId, updated.toJson());
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    if (!canEditPlaylist(playlist)) return;
    final playlistsBox = await _box('LibraryPlaylists');
    await playlistsBox.delete(playlist.playlistId);

    final songsBox = await _box(playlist.playlistId);
    await songsBox.clear();
  }

  Future<void> addSongsToPlaylist({
    required Playlist playlist,
    required List<MediaItem> songs,
  }) async {
    if (!canEditPlaylist(playlist) || songs.isEmpty) return;

    final box = await _box(playlist.playlistId);
    final existingIds = box.values
        .map<MediaItem?>((item) => _mediaItemFromJson(item))
        .whereType<MediaItem>()
        .map((song) => song.id)
        .toSet();
    for (final song in songs) {
      if (existingIds.add(song.id)) {
        await box.add(MediaItemBuilder.toJson(song));
      }
    }
  }

  Future<void> removeSongFromPlaylist({
    required Playlist playlist,
    required MediaItem song,
  }) async {
    if (!canEditPlaylist(playlist)) return;
    final box = await _box(playlist.playlistId);
    dynamic keyToDelete;
    for (final key in box.keys) {
      final item = _mediaItemFromJson(box.get(key));
      if (item?.id == song.id) {
        keyToDelete = key;
        break;
      }
    }
    if (keyToDelete != null) {
      await box.delete(keyToDelete);
    }
  }

  Future<List<MediaItem>> playlistSongs(Playlist playlist) async {
    switch (playlist.playlistId) {
      case 'SongsCache':
        return cachedSongs();
      case 'SongDownloads':
        return downloadedSongs();
      default:
        return _songsFromBox(playlist.playlistId);
    }
  }

  bool get pipedLoggedIn {
    final piped = _appPreferences.get('piped');
    return piped is Map && piped['isLoggedIn'] == true;
  }

  Future<Box> _box(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box(name);
    }
    return Hive.openBox(name);
  }

  Future<List<MediaItem>> _songsFromBox(String boxName) async {
    final box = await _box(boxName);
    return box.values
        .map<MediaItem?>((item) => _mediaItemFromJson(item))
        .whereType<MediaItem>()
        .toList();
  }

  MediaItem? _mediaItemFromJson(dynamic item) {
    try {
      return MediaItemBuilder.fromJson(item);
    } catch (_) {
      return null;
    }
  }

  Playlist? _playlistFromJson(dynamic item) {
    try {
      return Playlist.fromJson(item);
    } catch (_) {
      return null;
    }
  }

  Album? _albumFromJson(dynamic item) {
    try {
      return Album.fromJson(item);
    } catch (_) {
      return null;
    }
  }

  Artist? _artistFromJson(dynamic item) {
    try {
      return Artist.fromJson(item);
    } catch (_) {
      return null;
    }
  }

  List<MediaItem> _dedupeSongs(List<MediaItem> songs) {
    final seen = <String>{};
    return [
      for (final song in songs)
        if (seen.add(song.id)) song,
    ];
  }

  String _titleCase(String title) {
    if (title.isEmpty) return title;
    return '${title[0].toUpperCase()}${title.substring(1)}';
  }
}
