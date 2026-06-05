abstract class AppPreferencesStore {
  dynamic get(String key, {dynamic defaultValue});
  bool containsKey(String key);
  Future<void> put(String key, dynamic value);
}
