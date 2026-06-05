import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';

import '/core/download/download_repository.dart';
import '/core/download/song_download_client.dart';
import '/core/lyrics/lyrics_client.dart';
import '/core/library/library_repository.dart';
import '/core/playback/playback_service.dart';
import '/core/settings/settings_repository.dart';
import '/core/storage/app_preferences_store.dart';
import '/core/storage/hive_app_preferences_store.dart';
import '/services/music_service.dart';
import '/services/piped_service.dart';

class HarmonyBackend {
  HarmonyBackend({
    Dio? dio,
    AppPreferencesStore? appPreferences,
    MusicServices? music,
    PipedServices? piped,
    LibraryRepository? library,
    DownloadRepository? downloadRepository,
    SettingsRepository? settings,
    LyricsClient? lyrics,
    SongDownloadClient? downloads,
    PlaybackService? playback,
  })  : appPreferences = appPreferences ?? HiveAppPreferencesStore(),
        _dio = dio ?? Dio(),
        _music = music,
        _piped = piped,
        _library = library,
        _downloadRepository = downloadRepository,
        _settings = settings,
        _lyrics = lyrics,
        _downloads = downloads,
        _playback = playback;

  final Dio _dio;
  final MusicServices? _music;
  final PipedServices? _piped;
  final LibraryRepository? _library;
  final DownloadRepository? _downloadRepository;
  final SettingsRepository? _settings;
  final LyricsClient? _lyrics;
  final SongDownloadClient? _downloads;
  PlaybackService? _playback;
  final AppPreferencesStore appPreferences;

  late final MusicServices music = _music ??
      MusicServices(
        dio: _dio,
        appPreferences: appPreferences,
      );

  late final PipedServices piped = _piped ??
      PipedServices(
        dio: _dio,
        appPreferences: appPreferences,
      );

  late final LibraryRepository library =
      _library ?? LibraryRepository(appPreferences: appPreferences);

  late final LyricsClient lyrics = _lyrics ?? LyricsClient(dio: _dio);

  late final SongDownloadClient downloads =
      _downloads ?? SongDownloadClient(dio: _dio);

  late final DownloadRepository downloadRepository = _downloadRepository ??
      DownloadRepository(
        client: downloads,
        music: music,
        appPreferences: appPreferences,
      );

  late final SettingsRepository settings = _settings ??
      SettingsRepository(
        appPreferences: appPreferences,
        piped: piped,
        music: music,
      );

  PlaybackService get playback {
    final playback = _playback;
    if (playback == null) {
      throw StateError('Playback has not been attached to HarmonyBackend.');
    }
    return playback;
  }

  void attachAudioHandler(AudioHandler audioHandler) {
    _playback = PlaybackService(audioHandler);
  }

  void dispose() {
    downloadRepository.dispose();
    if (_music == null) {
      music.onClose();
    } else {
      _dio.close();
    }
  }
}
