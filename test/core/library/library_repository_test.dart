import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonymusic/core/library/library_repository.dart';
import 'package:harmonymusic/models/album.dart';
import 'package:harmonymusic/models/artist.dart';
import 'package:harmonymusic/models/media_Item_builder.dart';
import 'package:harmonymusic/models/playlist.dart';
import 'package:hive/hive.dart';

import '../../test_support/memory_preferences_store.dart';

void main() {
  late Directory hiveDirectory;
  late LibraryRepository repository;

  const libraryBoxNames = [
    'SongsCache',
    'SongDownloads',
    'LibraryPlaylists',
    'LibraryAlbums',
    'LibraryArtists',
    'LIB_custom',
    'LIB_edit',
  ];

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'library_repository_test_',
    );
    Hive.init(hiveDirectory.path);
  });

  setUp(() async {
    repository = LibraryRepository(
      appPreferences: MemoryPreferencesStore(),
    );

    for (final boxName in libraryBoxNames) {
      await Hive.openBox(boxName);
      await Hive.box(boxName).clear();
    }
  });

  tearDown(() async {
    for (final boxName in libraryBoxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).clear();
      }
    }
    await Hive.close();
  });

  tearDownAll(() async {
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('combines cached and downloaded songs without duplicates', () async {
    await Hive.box('SongsCache').put('song1', _songJson('song1'));
    await Hive.box('SongsCache').put('song2', _songJson('song2'));
    await Hive.box('SongDownloads').put('song1', _songJson('song1'));
    await Hive.box('SongDownloads').put('song3', _songJson('song3'));

    final songs = await repository.librarySongs();

    expect(songs.map((song) => song.id), ['song1', 'song2', 'song3']);
  });

  test('returns default playlists and hides Piped playlists by default',
      () async {
    final local = _playlist('LIB_custom', 'Road Mix');
    final piped = _playlist('PIPED_custom', 'Piped Mix', isPiped: true);
    await Hive.box('LibraryPlaylists').put(local.playlistId, local.toJson());
    await Hive.box('LibraryPlaylists').put(piped.playlistId, piped.toJson());

    final visible = await repository.playlists();
    final visibleIds = visible.map((playlist) => playlist.playlistId);

    expect(visibleIds, containsAll(['LIBRP', 'LIBFAV', 'SongsCache']));
    expect(visibleIds, contains('LIB_custom'));
    expect(visibleIds, isNot(contains('PIPED_custom')));

    final all = await repository.playlists(includePiped: true);
    expect(
        all.map((playlist) => playlist.playlistId), contains('PIPED_custom'));
  });

  test('only local user playlists are editable', () async {
    final editable = _playlist('LIB_custom', 'Road Mix');
    final piped = _playlist('LIB_piped', 'Piped Mix', isPiped: true);
    final cloud = _playlist('VL_cloud', 'Cloud Mix', isCloud: true);
    await Hive.box('LibraryPlaylists')
        .put(editable.playlistId, editable.toJson());
    await Hive.box('LibraryPlaylists').put(piped.playlistId, piped.toJson());
    await Hive.box('LibraryPlaylists').put(cloud.playlistId, cloud.toJson());

    final editableIds = (await repository.editablePlaylists())
        .map((playlist) => playlist.playlistId)
        .toList();

    expect(editableIds, ['LIB_custom']);
  });

  test('adds and removes songs from editable playlists', () async {
    final playlist = _playlist('LIB_edit', 'Edit Mix');
    final song = MediaItemBuilder.fromJson(_songJson('song1'));
    await Hive.box('LibraryPlaylists')
        .put(playlist.playlistId, playlist.toJson());

    await repository.addSongsToPlaylist(
      playlist: playlist,
      songs: [song, song],
    );

    expect((await repository.playlistSongs(playlist)).map((song) => song.id), [
      'song1',
    ]);

    await repository.removeSongFromPlaylist(playlist: playlist, song: song);

    expect(await repository.playlistSongs(playlist), isEmpty);
  });

  test('renames and deletes editable playlists', () async {
    final playlist = _playlist('LIB_edit', 'Edit Mix');
    await Hive.box('LibraryPlaylists')
        .put(playlist.playlistId, playlist.toJson());
    await Hive.box('LIB_edit').put('song1', _songJson('song1'));

    await repository.renamePlaylist(playlist, ' night mix ');

    final renamed = Playlist.fromJson(
      Hive.box('LibraryPlaylists').get(playlist.playlistId),
    );
    expect(renamed.title, 'Night mix');

    await repository.deletePlaylist(renamed);

    expect(Hive.box('LibraryPlaylists').containsKey('LIB_edit'), isFalse);
    expect(Hive.box('LIB_edit').isEmpty, isTrue);
  });

  group('album and artist save/remove', () {
    test('saves and removes an album', () async {
      final album = Album(
        title: 'Test Album',
        browseId: 'ALB_123',
        thumbnailUrl: 'https://example.com/alb.jpg',
        artists: [
          {'name': 'Test Artist'},
        ],
      );

      expect(await repository.isAlbumSaved('ALB_123'), isFalse);
      await repository.saveAlbum(album);
      expect(await repository.isAlbumSaved('ALB_123'), isTrue);
      await repository.removeAlbum('ALB_123');
      expect(await repository.isAlbumSaved('ALB_123'), isFalse);
    });

    test('saves and removes an artist', () async {
      final artist = Artist(
        name: 'Test Artist',
        browseId: 'ART_456',
        thumbnailUrl: 'https://example.com/art.jpg',
      );

      expect(await repository.isArtistSaved('ART_456'), isFalse);
      await repository.saveArtist(artist);
      expect(await repository.isArtistSaved('ART_456'), isTrue);
      await repository.removeArtist('ART_456');
      expect(await repository.isArtistSaved('ART_456'), isFalse);
    });

    test('albums list includes saved album', () async {
      final album = Album(
        title: 'Listed Album',
        browseId: 'ALB_LIST',
        thumbnailUrl: 'https://example.com/alb.jpg',
        artists: [],
      );

      await repository.saveAlbum(album);
      final albums = await repository.albums();
      expect(albums.any((a) => a.browseId == 'ALB_LIST'), isTrue);
    });

    test('artists list includes saved artist', () async {
      final artist = Artist(
        name: 'Listed Artist',
        browseId: 'ART_LIST',
        thumbnailUrl: 'https://example.com/art.jpg',
      );

      await repository.saveArtist(artist);
      final artists = await repository.artists();
      expect(artists.any((a) => a.browseId == 'ART_LIST'), isTrue);
    });
  });
}

Map<String, dynamic> _songJson(String id) {
  return {
    'videoId': id,
    'title': 'Song $id',
    'duration': 180,
    'length': '3:00',
    'album': {
      'id': 'album_$id',
      'name': 'Album $id',
    },
    'artists': [
      {'name': 'Artist $id'},
    ],
    'date': null,
    'thumbnails': [
      {'url': 'https://example.com/$id.jpg'},
    ],
    'url': null,
    'trackDetails': null,
    'year': null,
  };
}

Playlist _playlist(
  String id,
  String title, {
  bool isPiped = false,
  bool isCloud = false,
}) {
  return Playlist(
    title: title,
    playlistId: id,
    thumbnailUrl: Playlist.thumbPlaceholderUrl,
    isPipedPlaylist: isPiped,
    isCloudPlaylist: isCloud,
  );
}
