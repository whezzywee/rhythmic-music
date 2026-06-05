import 'package:flutter_test/flutter_test.dart';

import 'package:harmonymusic/core/harmony_backend.dart';
import 'package:harmonymusic/main.dart';

void main() {
  test('MyApp accepts an injected backend', () {
    final backend = HarmonyBackend();

    expect(MyApp(backend: backend), isA<MyApp>());
  });
}
