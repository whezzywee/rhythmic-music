import 'package:harmonymusic/core/storage/app_preferences_store.dart';

class MemoryPreferencesStore implements AppPreferencesStore {
  MemoryPreferencesStore([Map<String, dynamic>? values])
      : _values = values ?? {};

  final Map<String, dynamic> _values;

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  dynamic get(String key, {dynamic defaultValue}) {
    return _values.containsKey(key) ? _values[key] : defaultValue;
  }

  @override
  Future<void> put(String key, dynamic value) async {
    _values[key] = value;
  }
}
