import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '/core/storage/app_preferences_store.dart';
import '/services/music_service.dart';
import '/services/piped_service.dart';

enum DownloadFormat {
  m4a('m4a'),
  opus('opus');

  const DownloadFormat(this.value);

  final String value;

  static DownloadFormat fromValue(String? value) {
    return DownloadFormat.values.firstWhere(
      (format) => format.value == value,
      orElse: () => DownloadFormat.m4a,
    );
  }
}

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.skipSilenceEnabled,
    required this.loudnessNormalizationEnabled,
    required this.cacheSongs,
    required this.restorePlaybackSession,
    required this.backgroundPlayEnabled,
    required this.cacheHomeScreenData,
    required this.streamingQuality,
    required this.downloadFormat,
    required this.downloadLocationPath,
    required this.appLanguageCode,
    required this.contentLanguageCode,
  });

  final bool skipSilenceEnabled;
  final bool loudnessNormalizationEnabled;
  final bool cacheSongs;
  final bool restorePlaybackSession;
  final bool backgroundPlayEnabled;
  final bool cacheHomeScreenData;
  final AudioQuality streamingQuality;
  final DownloadFormat downloadFormat;
  final String downloadLocationPath;
  final String appLanguageCode;
  final String contentLanguageCode;
}

class SettingsRepository {
  SettingsRepository({
    required AppPreferencesStore appPreferences,
    required PipedServices piped,
    required MusicServices music,
  })  : _appPreferences = appPreferences,
        _piped = piped,
        _music = music;

  final AppPreferencesStore _appPreferences;
  final PipedServices _piped;
  final MusicServices _music;

  Future<SettingsSnapshot> load() async {
    final downloadLocationPath = await getDownloadLocationPath();
    final streamingIndex = _appPreferences.get(
      'streamingQuality',
      defaultValue: AudioQuality.High.index,
    );

    return SettingsSnapshot(
      skipSilenceEnabled: _bool('skipSilenceEnabled'),
      loudnessNormalizationEnabled: _bool('loudnessNormalizationEnabled'),
      cacheSongs: _bool('cacheSongs'),
      restorePlaybackSession: _bool('restrorePlaybackSession'),
      backgroundPlayEnabled: _bool('backgroundPlayEnabled', defaultValue: true),
      cacheHomeScreenData: _bool('cacheHomeScreenData', defaultValue: true),
      streamingQuality: AudioQuality.values[_intInRange(
        streamingIndex,
        AudioQuality.values.length,
        fallback: AudioQuality.High.index,
      )],
      downloadFormat: DownloadFormat.fromValue(
        _appPreferences.get('downloadingFormat', defaultValue: 'm4a'),
      ),
      downloadLocationPath: downloadLocationPath,
      appLanguageCode:
          _appPreferences.get('currentAppLanguageCode', defaultValue: 'en'),
      contentLanguageCode:
          _appPreferences.get('contentLanguage', defaultValue: 'en'),
    );
  }

  Future<void> setBool(String key, bool value) {
    return _appPreferences.put(key, value);
  }

  Future<void> setStreamingQuality(AudioQuality value) {
    return _appPreferences.put('streamingQuality', value.index);
  }

  Future<void> setDownloadFormat(DownloadFormat value) {
    return _appPreferences.put('downloadingFormat', value.value);
  }

  Future<void> setAppLanguageCode(String value) {
    return _appPreferences.put('currentAppLanguageCode', value);
  }

  Future<void> setContentLanguageCode(String value) async {
    _music.hlCode = value;
    await _appPreferences.put('contentLanguage', value);
  }

  Future<String?> pickDownloadLocation() async {
    final pickedFolderPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select downloads folder',
    );
    if (pickedFolderPath == null || pickedFolderPath == '/') {
      return null;
    }
    await setDownloadLocationPath(pickedFolderPath);
    return pickedFolderPath;
  }

  Future<void> resetDownloadLocation() async {
    await setDownloadLocationPath(await defaultDownloadLocationPath());
  }

  Future<void> setDownloadLocationPath(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await _appPreferences.put('downloadLocationPath', path);
  }

  Future<String> getDownloadLocationPath() async {
    final configured = _appPreferences.get('downloadLocationPath');
    if (configured is String && configured.trim().isNotEmpty) {
      return configured;
    }
    final defaultPath = await defaultDownloadLocationPath();
    await setDownloadLocationPath(defaultPath);
    return defaultPath;
  }

  Future<String> defaultDownloadLocationPath() async {
    final supportDir = (await getApplicationSupportDirectory()).path;
    return '$supportDir/Music';
  }

  void logoutPiped() {
    _piped.logout();
  }

  bool _bool(String key, {bool defaultValue = false}) {
    return _appPreferences.get(key, defaultValue: defaultValue) == true;
  }

  int _intInRange(dynamic value, int length, {required int fallback}) {
    final intValue = value is int ? value : fallback;
    if (intValue < 0 || intValue >= length) return fallback;
    return intValue;
  }
}
