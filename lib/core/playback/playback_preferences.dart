import '/core/storage/app_preferences_store.dart';

class PlaybackPreferences {
  const PlaybackPreferences(this._appPreferences);

  final AppPreferencesStore _appPreferences;

  bool get skipSilenceEnabled => _bool('skipSilenceEnabled');

  bool get loopModeEnabled => _bool('isLoopModeEnabled');

  bool get shuffleModeEnabled => _bool('isShuffleModeEnabled');

  bool get queueLoopModeEnabled => _bool('queueLoopModeEnabled');

  bool get loudnessNormalizationEnabled =>
      _bool('loudnessNormalizationEnabled');

  bool get cacheSongs => _bool('cacheSongs');

  bool get stopPlaybackOnSwipeAway => _bool('stopPlyabackOnSwipeAway');

  bool _bool(String key, {bool defaultValue = false}) {
    return _appPreferences.get(key, defaultValue: defaultValue) == true;
  }
}
