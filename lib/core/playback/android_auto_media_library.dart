import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';

import '/core/library/library_defaults.dart';
import '/models/album.dart';
import '/models/media_Item_builder.dart';
import '/models/playlist.dart';

typedef PlaybackLabelTranslator = String Function(String key);

class AndroidAutoMediaLibrary {
  AndroidAutoMediaLibrary({
    PlaybackLabelTranslator? translate,
  }) : _translate = translate ?? ((key) => key);

  static const albumsRootId = 'albums';
  static const songsRootId = 'songs';
  static const favoritesRootId = 'LIBFAV';
  static const playlistsRootId = 'playlists';

  final PlaybackLabelTranslator _translate;

  Future<List<MediaItem>> getByRootId(String id) async {
    switch (id) {
      case AudioService.browsableRootId:
        return Future.value(getRoot());
      case songsRootId:
        return getLibSongs('SongDownloads');
      case favoritesRootId:
        return getLibSongs('LIBFAV');
      case albumsRootId:
        return getAlbums();
      case playlistsRootId:
        return getPlaylists();
      case AudioService.recentRootId:
        return getLibSongs('LIBRP');
      default:
        return getLibSongs(id);
    }
  }

  List<MediaItem> getRoot() {
    return [
      MediaItem(
        id: songsRootId,
        title: _translate('songs'),
        playable: false,
      ),
      MediaItem(
        id: favoritesRootId,
        title: _translate('favorites'),
        playable: false,
      ),
      MediaItem(
        id: albumsRootId,
        title: _translate('albums'),
        playable: false,
      ),
      MediaItem(
        id: playlistsRootId,
        title: _translate('playlists'),
        playable: false,
      ),
    ];
  }

  Future<List<MediaItem>> getAlbums() async {
    final box = await Hive.openBox('LibraryAlbums');
    final albums =
        box.values.map((item) => Album.fromJson(item).toMediaItem()).toList();
    await box.close();
    return albums;
  }

  Future<List<MediaItem>> getPlaylists() async {
    final box = await Hive.openBox('LibraryPlaylists');
    final playlists = [
      ...defaultLibraryPlaylists(translate: _translate)
          .map((playlist) => playlist.toMediaItem()),
      ...(box.values
          .map((item) => Playlist.fromJson(item).toMediaItem())
          .toList())
    ];
    await box.close();
    return playlists;
  }

  Future<List<MediaItem>> getLibSongs(String libId) async {
    Box<dynamic> box;
    try {
      box = await Hive.openBox(libId);
    } catch (e) {
      box = await Hive.openBox(libId);
    }
    final songs = box.values.toList().map((item) {
      final song = MediaItemBuilder.fromJson(item);
      return MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        artUri: song.artUri,
        extras: {'libraryId': libId},
        playable: true,
      );
    }).toList();

    if (!libId.contains('SongDownloads')) {
      await box.close();
    }

    if (libId == 'LIBRP') {
      return songs.reversed.toList();
    }

    return songs;
  }
}
