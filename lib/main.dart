import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:terminate_restart/terminate_restart.dart';

import '/app/app_branding.dart';
import '/app/app_link_service.dart';
import '/app/app_platform.dart';
import '/app/app_shell.dart';
import '/app/app_theme.dart';
import '/app/app_translations.dart';
import '/core/harmony_backend.dart';
import '/services/audio_handler.dart';
import '/utils/system_tray.dart';
import 'utils/update_check_flag_file.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  _setAppInitPrefs();
  final backend = startApplicationServices();
  final audioHandler = await initAudioService(
    appPreferences: backend.appPreferences,
    translate: AppTranslations.translate,
    branding: const AppBranding(),
  );
  backend.attachAudioHandler(audioHandler);
  if (AppPlatform.isDesktop) {
    DesktopSystemTray(
      audioHandler: audioHandler,
      appPreferences: backend.appPreferences,
    ).start();
  }
  WidgetsBinding.instance.addObserver(LifecycleHandler(audioHandler));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  TerminateRestart.instance.initialize();
  runApp(MyApp(
    backend: backend,
    appLinkService: AppPlatform.isDesktop ? null : AppLinkService(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.backend,
    this.appLinkService,
  });

  final HarmonyBackend backend;
  final AppLinkService? appLinkService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: const AppBranding().appName,
      home: NewAppShell(
        backend: backend,
        appLinkService: appLinkService,
      ),
      theme: NewAppTheme.dark(),
      debugShowCheckedModeBanner: false,
      locale: Locale(AppTranslations.currentLanguageCode),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      builder: (context, child) {
        final mQuery = MediaQuery.of(context);
        final scale =
            mQuery.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.1);
        return Stack(
          children: [
            MediaQuery(
              data: mQuery.copyWith(textScaler: scale),
              child: child!,
            ),
            GestureDetector(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  color: Colors.transparent,
                  height: mQuery.padding.bottom,
                  width: mQuery.size.width,
                ),
              ),
            )
          ],
        );
      },
    );
  }
}

HarmonyBackend startApplicationServices() {
  return HarmonyBackend();
}

initHive() async {
  String applicationDataDirectoryPath;
  if (AppPlatform.isDesktop) {
    applicationDataDirectoryPath =
        "${(await getApplicationSupportDirectory()).path}/db";
  } else {
    applicationDataDirectoryPath =
        (await getApplicationDocumentsDirectory()).path;
  }
  await Hive.initFlutter(applicationDataDirectoryPath);
  await Hive.openBox("SongsCache");
  await Hive.openBox("SongDownloads");
  await Hive.openBox('SongsUrlCache');
  await Hive.openBox("AppPrefs");
}

void _setAppInitPrefs() {
  final appPrefs = Hive.box("AppPrefs");
  if (appPrefs.isEmpty) {
    appPrefs.putAll({
      'themeModeType': 0,
      "cacheSongs": false,
      "skipSilenceEnabled": false,
      'streamingQuality': 1,
      'themePrimaryColor': 4278199603,
      'discoverContentType': "QP",
      'newVersionVisibility': updateCheckFlag,
      "cacheHomeScreenData": true
    });
  }
}

class LifecycleHandler extends WidgetsBindingObserver {
  LifecycleHandler(this._audioHandler);

  final AudioHandler _audioHandler;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else if (state == AppLifecycleState.detached) {
      await _audioHandler.customAction("saveSession");
    }
  }
}
