import 'package:hive/hive.dart';

import 'app_preferences_store.dart';

class HiveAppPreferencesStore implements AppPreferencesStore {
  HiveAppPreferencesStore({this.boxName = 'AppPrefs'});

  final String boxName;

  Box get _box => Hive.box(boxName);

  @override
  dynamic get(String key, {dynamic defaultValue}) {
    return _box.get(key, defaultValue: defaultValue);
  }

  @override
  bool containsKey(String key) {
    return _box.containsKey(key);
  }

  @override
  Future<void> put(String key, dynamic value) async {
    await _box.put(key, value);
  }
}
