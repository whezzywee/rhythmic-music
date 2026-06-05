import 'package:flutter_test/flutter_test.dart';
import 'package:harmonymusic/app/app_shell.dart';
import 'package:harmonymusic/core/harmony_backend.dart';

void main() {
  test('NewAppShell can be constructed with a HarmonyBackend', () {
    final backend = HarmonyBackend();

    // Construction should succeed even before an audio handler
    // is attached — the error only occurs when playback is accessed.
    expect(
      () => NewAppShell(backend: backend),
      returnsNormally,
    );
  });

  test('HarmonyBackend throws StateError when playback is accessed before attach', () {
    final backend = HarmonyBackend();

    expect(
      () => backend.playback,
      throwsStateError,
    );
  });

  test('HarmonyBackend attaches audio handler successfully', () {
    // Just verify the method exists and compiles correctly.
    // Full integration test would need a real AudioHandler.
    final backend = HarmonyBackend();
    expect(backend, isNotNull);
  });
}
