import 'package:flutter_test/flutter_test.dart';
import 'package:harmonymusic/core/playback/playback_preferences.dart';

import '../../test_support/memory_preferences_store.dart';

void main() {
  group('PlaybackPreferences', () {
    test('returns false defaults for playback flags', () {
      final preferences = PlaybackPreferences(MemoryPreferencesStore());

      expect(preferences.skipSilenceEnabled, isFalse);
      expect(preferences.loopModeEnabled, isFalse);
      expect(preferences.shuffleModeEnabled, isFalse);
      expect(preferences.queueLoopModeEnabled, isFalse);
      expect(preferences.loudnessNormalizationEnabled, isFalse);
      expect(preferences.cacheSongs, isFalse);
      expect(preferences.stopPlaybackOnSwipeAway, isFalse);
    });

    test('reads legacy preference keys', () {
      final store = MemoryPreferencesStore({
        'skipSilenceEnabled': true,
        'isLoopModeEnabled': true,
        'isShuffleModeEnabled': true,
        'queueLoopModeEnabled': true,
        'loudnessNormalizationEnabled': true,
        'cacheSongs': true,
        'stopPlyabackOnSwipeAway': true,
      });

      final preferences = PlaybackPreferences(store);

      expect(preferences.skipSilenceEnabled, isTrue);
      expect(preferences.loopModeEnabled, isTrue);
      expect(preferences.shuffleModeEnabled, isTrue);
      expect(preferences.queueLoopModeEnabled, isTrue);
      expect(preferences.loudnessNormalizationEnabled, isTrue);
      expect(preferences.cacheSongs, isTrue);
      expect(preferences.stopPlaybackOnSwipeAway, isTrue);
    });

    test('ignores truthy non-bool values', () {
      final store = MemoryPreferencesStore({
        'skipSilenceEnabled': 'true',
      });

      final preferences = PlaybackPreferences(store);

      expect(preferences.skipSilenceEnabled, isFalse);
    });
  });
}
