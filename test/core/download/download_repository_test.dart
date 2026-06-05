import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonymusic/core/download/download_repository.dart';
import 'package:harmonymusic/core/download/song_download_client.dart';
import 'package:harmonymusic/core/storage/app_preferences_store.dart';
import 'package:harmonymusic/services/music_service.dart';

import '../../test_support/memory_preferences_store.dart';

class _FakeSongDownloadClient extends SongDownloadClient {
  _FakeSongDownloadClient() : super(dio: null);
}

class _FakeMusicServices extends MusicServices {
  _FakeMusicServices() : super(dio: null, appPreferences: MemoryPreferencesStore());
}

MediaItem _dummySong() => MediaItem(id: 'test', title: 'Test', duration: Duration.zero);

void main() {
  group('DownloadRepository', () {
    late MemoryPreferencesStore store;
    late DownloadRepository repository;

    setUp(() {
      store = MemoryPreferencesStore({
        'downloadingFormat': 'm4a',
        'downloadLocationPath': '/tmp/test_downloads',
      });
      repository = DownloadRepository(
        client: _FakeSongDownloadClient(),
        music: _FakeMusicServices(),
        appPreferences: store,
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test('DownloadJobStatus enum has all expected values', () {
      expect(DownloadJobStatus.values, [
        DownloadJobStatus.queued,
        DownloadJobStatus.downloading,
        DownloadJobStatus.completed,
        DownloadJobStatus.failed,
        DownloadJobStatus.cancelled,
      ]);
    });

    test('currentSnapshot starts empty', () {
      expect(repository.currentSnapshot.jobs, isEmpty);
    });

    test('DownloadJobState.copyWith preserves fields', () {
      final state = DownloadJobState(
        song: _dummySong(),
        progress: 50,
        status: DownloadJobStatus.downloading,
        message: 'Downloading...',
      );

      final updated = state.copyWith(progress: 75, status: DownloadJobStatus.completed);
      expect(updated.progress, 75);
      expect(updated.status, DownloadJobStatus.completed);
      expect(updated.message, 'Downloading...');
    });

    test('cancelDownload and retryDownload APIs exist', () {
      expect(repository.cancelDownload, isA<Function>());
      expect(repository.retryDownload, isA<Function>());
    });

    test('DownloadRepositorySnapshot.hasActiveJobs works', () {
      final snapshot = DownloadRepositorySnapshot(jobs: const []);
      expect(snapshot.hasActiveJobs, isFalse);

      final active = DownloadRepositorySnapshot(jobs: [
        DownloadJobState(
          song: _dummySong(),
          progress: 0,
          status: DownloadJobStatus.downloading,
        ),
      ]);
      expect(active.hasActiveJobs, isTrue);
    });
  });
}
