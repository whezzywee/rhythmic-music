import 'package:flutter_test/flutter_test.dart';
import 'package:harmonymusic/core/playback/playback_session_store.dart';

import '../../test_support/memory_preferences_store.dart';
import 'package:harmonymusic/core/playback/hive_playback_session_store.dart';

void main() {
  group('PlaybackSessionStore (memory defaults)', () {
    test('restoreEnabled returns false by default', () {
      final store = HivePlaybackSessionStore(
        appPreferences: MemoryPreferencesStore(),
      );

      expect(store.restoreEnabled, isFalse);
    });

    test('restoreEnabled returns true when preference is set', () {
      final store = HivePlaybackSessionStore(
        appPreferences: MemoryPreferencesStore({
          'restrorePlaybackSession': true,
        }),
      );

      expect(store.restoreEnabled, isTrue);
    });

    test('restore returns null when disabled', () async {
      final store = HivePlaybackSessionStore(
        appPreferences: MemoryPreferencesStore(),
      );

      final snapshot = await store.restore();
      expect(snapshot, isNull);
    });

    test('PlaybackSessionSnapshot computes position Duration', () {
      const snapshot = PlaybackSessionSnapshot(
        queue: [],
        index: 0,
        positionMillis: 5000,
      );

      expect(snapshot.position, const Duration(seconds: 5));
    });
  });
}
