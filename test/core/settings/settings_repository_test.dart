import 'package:flutter_test/flutter_test.dart';
import 'package:harmonymusic/core/settings/settings_repository.dart';
import 'package:harmonymusic/core/storage/app_preferences_store.dart';
import 'package:harmonymusic/services/music_service.dart';
import 'package:harmonymusic/services/piped_service.dart';

import '../../test_support/memory_preferences_store.dart';

class _FakePipedServices extends PipedServices {
  _FakePipedServices() : super(dio: null, appPreferences: MemoryPreferencesStore());
  @override
  void logout() {}
}

class _FakeMusicServices extends MusicServices {
  _FakeMusicServices() : super(dio: null, appPreferences: MemoryPreferencesStore());
}

void main() {
  group('SettingsRepository', () {
    late MemoryPreferencesStore store;
    late SettingsRepository repository;

    setUp(() {
      store = MemoryPreferencesStore({
        'streamingQuality': 1,
        'downloadingFormat': 'm4a',
        'currentAppLanguageCode': 'en',
        'contentLanguage': 'en',
      });
      repository = SettingsRepository(
        appPreferences: store,
        piped: _FakePipedServices(),
        music: _FakeMusicServices(),
      );
    });

    test('setBool persists a boolean preference', () async {
      await repository.setBool('skipSilenceEnabled', true);
      expect(store.get('skipSilenceEnabled'), isTrue);
    });

    test('setStreamingQuality persists the index', () async {
      await repository.setStreamingQuality(AudioQuality.Low);
      expect(store.get('streamingQuality'), AudioQuality.Low.index);
    });

    test('setDownloadFormat persists the value', () async {
      await repository.setDownloadFormat(DownloadFormat.opus);
      expect(store.get('downloadingFormat'), 'opus');
    });

    test('setAppLanguageCode persists the code', () async {
      await repository.setAppLanguageCode('fr');
      expect(store.get('currentAppLanguageCode'), 'fr');
    });

    test('setContentLanguageCode updates store', () async {
      await repository.setContentLanguageCode('de');
      expect(store.get('contentLanguage'), 'de');
    });

    test('logoutPiped delegates to the piped service', () {
      repository.logoutPiped();
    });
  });
}
