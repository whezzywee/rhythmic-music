import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '/app/app_platform.dart';
import '/core/storage/app_preferences_store.dart';

class DesktopSystemTray with TrayListener {
  DesktopSystemTray({
    required AudioHandler audioHandler,
    required AppPreferencesStore appPreferences,
  })  : _audioHandler = audioHandler,
        _appPreferences = appPreferences;

  final AudioHandler _audioHandler;
  final AppPreferencesStore _appPreferences;
  WindowListener? _listener;

  void start() {
    trayManager.addListener(this);
    Future.delayed(const Duration(seconds: 2), () => initSystemTray());
  }

  Future<void> initSystemTray() async {
    String path = AppPlatform.isWindows
        ? 'assets/icons/icon.ico'
        : 'assets/icons/icon.png';

    await windowManager.ensureInitialized();

    await trayManager.setIcon(path);

    // create context menu
    final Menu menu = Menu(items: [
      MenuItem(
        label: 'Show/Hide',
        onClick: (menuItem) async => await windowManager.isVisible()
            ? await windowManager.hide()
            : await windowManager.show(),
      ),
      MenuItem.separator(),
      MenuItem(
        label: 'Prev',
        onClick: (menuItem) async {
          if (_hasQueue) {
            await _audioHandler.skipToPrevious();
          }
        },
      ),
      MenuItem(
        label: 'Play/Pause',
        onClick: (menuItem) async => _togglePlayback(),
      ),
      MenuItem(
        label: 'Next',
        onClick: (menuItem) async {
          if (_hasQueue) {
            await _audioHandler.skipToNext();
          }
        },
      ),
      MenuItem.separator(),
      MenuItem(
        label: 'Quit',
        onClick: (menuItem) async {
          await _audioHandler.customAction("saveSession");
          exit(0);
        },
      ),
    ]);

    // set context menu
    await trayManager.setContextMenu(menu);

    await windowManager.setPreventClose(true);
    final listener = CloseWindowListener(
      audioHandler: _audioHandler,
      appPreferences: _appPreferences,
    );
    _listener = listener;
    windowManager.addListener(listener);
  }

  bool get _hasQueue => _audioHandler.queue.value.isNotEmpty;

  Future<void> _togglePlayback() async {
    if (!_hasQueue) return;
    if (_audioHandler.playbackState.value.playing) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  void dispose() {
    trayManager.removeListener(this);
    final listener = _listener;
    if (listener != null) {
      windowManager.removeListener(listener);
    }
  }

  @override
  void onTrayIconMouseDown() {
    if (AppPlatform.isWindows) {
      windowManager.show();
    } else {
      trayManager.popUpContextMenu();
    }

    super.onTrayIconMouseDown();
  }

  @override
  void onTrayIconRightMouseDown() {
    if (AppPlatform.isWindows) {
      trayManager.popUpContextMenu();
    } else {
      windowManager.show();
    }

    super.onTrayIconRightMouseDown();
  }
}

class CloseWindowListener extends WindowListener {
  CloseWindowListener({
    required AudioHandler audioHandler,
    required AppPreferencesStore appPreferences,
  })  : _audioHandler = audioHandler,
        _appPreferences = appPreferences;

  final AudioHandler _audioHandler;
  final AppPreferencesStore _appPreferences;

  @override
  Future<void> onWindowClose() async {
    final backgroundPlayEnabled =
        _appPreferences.get('backgroundPlayEnabled', defaultValue: true) ==
            true;
    if (backgroundPlayEnabled && _audioHandler.playbackState.value.playing) {
      await windowManager.hide();
    } else {
      await _audioHandler.customAction("saveSession");
      exit(0);
    }
  }
}
