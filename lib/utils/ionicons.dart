import 'package:flutter/widgets.dart';

/// Local replacement for the ionicons package.
/// IconData became a final class in Dart 3.x, so we use the constructor directly
/// instead of extending it like the original package did.
class Ionicons {
  Ionicons._();

  static const _fontFamily = 'Ionicons';

  /// shuffle
  static const shuffle = IconData(0xee80, fontFamily: _fontFamily);

  /// logo-youtube
  static const logo_youtube = IconData(0xed27, fontFamily: _fontFamily);

  /// play-circle
  static const play_circle = IconData(0xedc9, fontFamily: _fontFamily);
}
