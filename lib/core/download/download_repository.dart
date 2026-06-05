import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '/core/download/song_download_client.dart';
import '/core/storage/app_preferences_store.dart';
import '/services/music_service.dart';

class DownloadJobProgress {
  const DownloadJobProgress({
    required this.song,
    required this.progress,
  });

  final MediaItem song;
  final int progress;
}

enum DownloadJobStatus {
  queued,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadJobState {
  const DownloadJobState({
    required this.song,
    required this.progress,
    required this.status,
    this.message,
  });

  final MediaItem song;
  final int progress;
  final DownloadJobStatus status;
  final String? message;

  DownloadJobState copyWith({
    int? progress,
    DownloadJobStatus? status,
    String? message,
  }) {
    return DownloadJobState(
      song: song,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}

class DownloadRepositorySnapshot {
  const DownloadRepositorySnapshot({required this.jobs});

  final List<DownloadJobState> jobs;

  bool get hasActiveJobs {
    return jobs.any(
      (job) =>
          job.status == DownloadJobStatus.queued ||
          job.status == DownloadJobStatus.downloading,
    );
  }
}

class DownloadRepository {
  DownloadRepository({
    required SongDownloadClient client,
    required MusicServices music,
    required AppPreferencesStore appPreferences,
  })  : _client = client,
        _music = music,
        _appPreferences = appPreferences;

  final SongDownloadClient _client;
  final MusicServices _music;
  final AppPreferencesStore _appPreferences;
  final Map<String, DownloadJobState> _jobs = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final StreamController<DownloadRepositorySnapshot> _jobController =
      StreamController<DownloadRepositorySnapshot>.broadcast();

  Stream<DownloadRepositorySnapshot> get jobs => _jobController.stream;

  DownloadRepositorySnapshot get currentSnapshot {
    return DownloadRepositorySnapshot(jobs: _jobs.values.toList());
  }

  /// Cancel an active or queued download.
  void cancelDownload(String songId) {
    _cancelTokens[songId]?.cancel();
    _cancelTokens.remove(songId);

    final job = _jobs[songId];
    if (job != null &&
        (job.status == DownloadJobStatus.queued ||
            job.status == DownloadJobStatus.downloading)) {
      _updateJob(
        job.song,
        progress: job.progress,
        status: DownloadJobStatus.cancelled,
        message: 'Cancelled',
      );
    }
  }

  /// Retry a previously failed or cancelled download.
  Future<SongDownloadResult> retryDownload(
    MediaItem song, {
    void Function(DownloadJobProgress progress)? onProgress,
  }) {
    _jobs.remove(song.id);
    _cancelTokens.remove(song.id);
    return downloadSong(song, onProgress: onProgress);
  }

  Future<SongDownloadResult> downloadSong(
    MediaItem song, {
    void Function(DownloadJobProgress progress)? onProgress,
  }) async {
    _updateJob(
      song,
      progress: 0,
      status: DownloadJobStatus.queued,
      message: null,
    );

    final downloadsBox = await _box('SongDownloads');
    if (downloadsBox.containsKey(song.id)) {
      _updateJob(
        song,
        progress: 100,
        status: DownloadJobStatus.completed,
        message: 'Already downloaded',
      );
      return SongDownloadResult(
        playable: true,
        statusMessage: 'Already downloaded',
        songJson: Map<String, dynamic>.from(downloadsBox.get(song.id)),
      );
    }

    final cancelToken = CancelToken();
    _cancelTokens[song.id] = cancelToken;

    late final SongDownloadResult result;
    try {
      final downloadDirectoryPath = await _downloadDirectoryPath();
      final supportDirectoryPath = await _supportDirectoryPath();
      result = await _client.download(
        SongDownloadRequest(
          song: song,
          downloadDirectoryPath: downloadDirectoryPath,
          downloadFormat: _downloadFormat(),
          supportDirectoryPath: supportDirectoryPath,
          resolveYear: (song) => _music.getSongYear(song.id),
          cancelToken: cancelToken,
          onProgress: (progress) {
            _updateJob(
              song,
              progress: progress,
              status: DownloadJobStatus.downloading,
              message: null,
            );
            onProgress?.call(
              DownloadJobProgress(song: song, progress: progress),
            );
          },
        ),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _updateJob(
          song,
          progress: _jobs[song.id]?.progress ?? 0,
          status: DownloadJobStatus.cancelled,
          message: 'Cancelled',
        );
        return const SongDownloadResult(
          playable: false,
          statusMessage: 'Cancelled',
        );
      }
      _updateJob(
        song,
        progress: 0,
        status: DownloadJobStatus.failed,
        message: 'Download failed',
      );
      return const SongDownloadResult(
        playable: false,
        statusMessage: 'Download failed',
      );
    } catch (_) {
      _updateJob(
        song,
        progress: 0,
        status: DownloadJobStatus.failed,
        message: 'Download failed',
      );
      return const SongDownloadResult(
        playable: false,
        statusMessage: 'Download failed',
      );
    } finally {
      _cancelTokens.remove(song.id);
    }

    if (result.playable && result.songJson != null) {
      await downloadsBox.put(song.id, result.songJson);
      _updateJob(
        song,
        progress: 100,
        status: DownloadJobStatus.completed,
        message: result.statusMessage,
      );
    } else {
      _updateJob(
        song,
        progress: 0,
        status: DownloadJobStatus.failed,
        message: result.statusMessage,
      );
    }
    return result;
  }

  Future<List<SongDownloadResult>> downloadSongs(
    List<MediaItem> songs, {
    void Function(DownloadJobProgress progress)? onProgress,
  }) async {
    final results = <SongDownloadResult>[];
    for (final song in songs) {
      results.add(
        await downloadSong(
          song,
          onProgress: onProgress,
        ),
      );
    }
    return results;
  }

  String _downloadFormat() {
    return _appPreferences.get('downloadingFormat', defaultValue: 'm4a');
  }

  Future<String> _downloadDirectoryPath() async {
    final configured = _appPreferences.get('downloadLocationPath');
    final path = configured is String && configured.trim().isNotEmpty
        ? configured
        : '${await _supportDirectoryPath()}/Music';
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return path;
  }

  Future<String> _supportDirectoryPath() async {
    return (await getApplicationSupportDirectory()).path;
  }

  Future<Box> _box(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box(name);
    }
    return Hive.openBox(name);
  }

  void clearFinishedJobs() {
    _jobs.removeWhere(
      (key, job) =>
          job.status == DownloadJobStatus.completed ||
          job.status == DownloadJobStatus.failed ||
          job.status == DownloadJobStatus.cancelled,
    );
    _emitJobs();
  }

  void dispose() {
    _jobController.close();
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _cancelTokens.clear();
  }

  void _updateJob(
    MediaItem song, {
    required int progress,
    required DownloadJobStatus status,
    required String? message,
  }) {
    _jobs[song.id] = DownloadJobState(
      song: song,
      progress: progress.clamp(0, 100),
      status: status,
      message: message,
    );
    _emitJobs();
  }

  void _emitJobs() {
    if (_jobController.isClosed) return;
    _jobController.add(currentSnapshot);
  }
}
