import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';

import '/core/storage/app_preferences_store.dart';
import '/models/media_Item_builder.dart';
import '/utils/helper.dart';
import 'playback_session_store.dart';

class HivePlaybackSessionStore implements PlaybackSessionStore {
  HivePlaybackSessionStore({required AppPreferencesStore appPreferences})
      : _appPreferences = appPreferences;

  static const _sessionBoxName = 'prevSessionData';
  static const _restorePlaybackSessionKey = 'restrorePlaybackSession';

  final AppPreferencesStore _appPreferences;

  @override
  bool get restoreEnabled =>
      _appPreferences.get(_restorePlaybackSessionKey) ?? false;

  @override
  Future<void> save({
    required List<MediaItem> queue,
    required int currentIndex,
    required int positionMillis,
  }) async {
    if (!restoreEnabled || queue.isEmpty) return;

    final queueData = queue.map((e) => MediaItemBuilder.toJson(e)).toList();
    final prevSessionData = await Hive.openBox(_sessionBoxName);
    await prevSessionData.clear();
    await prevSessionData.putAll({
      'queue': queueData,
      'position': positionMillis,
      'index': currentIndex,
    });
    await prevSessionData.close();
    printINFO('Saved session data');
  }

  @override
  Future<PlaybackSessionSnapshot?> restore() async {
    if (!restoreEnabled) return null;

    final prevSessionData = await Hive.openBox(_sessionBoxName);
    if (prevSessionData.keys.isEmpty) {
      await prevSessionData.close();
      return null;
    }

    final queue = (prevSessionData.get('queue') as List)
        .map((e) => MediaItemBuilder.fromJson(e))
        .toList();
    final index = prevSessionData.get('index') as int;
    final position = prevSessionData.get('position') as int;
    await prevSessionData.close();

    return PlaybackSessionSnapshot(
      queue: queue,
      index: index,
      positionMillis: position,
    );
  }
}
