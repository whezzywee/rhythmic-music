import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/utils/get_localization.dart';

/// Thin wrapper around the auto-generated GetX [Languages] map
/// so the rest of the app never imports `package:get/get.dart`
/// for translation lookups.
class AppTranslations {
  AppTranslations._();

  static final Languages _languages = Languages();

  /// The current language code stored in Hive.
  static String get currentLanguageCode =>
      Hive.box('AppPrefs').get('currentAppLanguageCode', defaultValue: 'en');

  /// Translate [key] using the auto-generated GetX map
  /// without depending on `GetMaterialApp` being in the widget tree.
  static String translate(String key) {
    return _languages.keys[currentLanguageCode]?[key] ?? key;
  }
}
