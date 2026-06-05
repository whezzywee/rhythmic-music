import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonymusic/core/playback/playback_stream_metadata_repository.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;
  late PlaybackStreamMetadataRepository repository;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'playback_stream_metadata_test_',
    );
    Hive.init(hiveDirectory.path);
  });

  setUp(() async {
    repository = PlaybackStreamMetadataRepository();
    await Hive.openBox('SongsUrlCache');
    await Hive.openBox('SongDownloads');
    await Hive.box('SongsUrlCache').clear();
    await Hive.box('SongDownloads').clear();
  });

  tearDown(() async {
    await Hive.box('SongsUrlCache').clear();
    await Hive.box('SongDownloads').clear();
    await Hive.close();
  });

  tearDownAll(() async {
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('reads loudness from cached stream metadata first', () async {
    await Hive.box('SongsUrlCache').put('song1', {
      'highQualityAudio': {'loudnessDb': -8.5},
    });
    await Hive.box('SongDownloads').put('song1', {
      'streamInfo': [
        true,
        {'loudnessDb': -4.0},
      ],
    });

    expect(repository.loudnessDbForSong('song1'), -8.5);
  });

  test('falls back to downloaded song stream metadata', () async {
    await Hive.box('SongDownloads').put('song2', {
      'streamInfo': [
        true,
        {'loudnessDb': -3},
      ],
    });

    expect(repository.loudnessDbForSong('song2'), -3.0);
  });

  test('returns zero for downloaded songs without stream metadata', () async {
    await Hive.box('SongDownloads').put('song3', {
      'streamInfo': null,
    });

    expect(repository.loudnessDbForSong('song3'), 0);
  });

  test('returns null when no metadata exists', () async {
    expect(repository.loudnessDbForSong('missing'), isNull);
  });
}
