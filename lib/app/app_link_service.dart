import 'dart:async';

import 'package:app_links/app_links.dart';

enum AppLinkActionType {
  song,
  playlist,
  album,
  artist,
  unsupported,
}

class AppLinkAction {
  const AppLinkAction({
    required this.type,
    required this.uri,
    this.id,
  });

  final AppLinkActionType type;
  final Uri uri;
  final String? id;
}

class AppLinkService {
  AppLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  final _actions = StreamController<AppLinkAction>.broadcast();
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  Stream<AppLinkAction> get actions => _actions.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final initialLink = await _appLinks.getInitialAppLink();
    if (initialLink != null) {
      _emit(initialLink);
    }

    _subscription = _appLinks.uriLinkStream.listen(_emit);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _actions.close();
  }

  void _emit(Uri uri) {
    if (!_actions.isClosed) {
      _actions.add(parse(uri));
    }
  }

  static AppLinkAction parse(Uri uri) {
    if (!_isYoutubeHost(uri.host) || uri.pathSegments.isEmpty) {
      return AppLinkAction(type: AppLinkActionType.unsupported, uri: uri);
    }

    if (uri.pathSegments.first == 'watch') {
      final songId = uri.queryParameters['v'];
      return AppLinkAction(
        type: songId == null
            ? AppLinkActionType.unsupported
            : AppLinkActionType.song,
        id: songId,
        uri: uri,
      );
    }

    if (uri.host == 'youtu.be') {
      final songId = uri.pathSegments.first;
      return AppLinkAction(
        type: songId.isEmpty
            ? AppLinkActionType.unsupported
            : AppLinkActionType.song,
        id: songId,
        uri: uri,
      );
    }

    if (uri.pathSegments.first == 'playlist') {
      final playlistId = uri.queryParameters['list'];
      final type = playlistId?.contains('OLAK5uy') == true
          ? AppLinkActionType.album
          : AppLinkActionType.playlist;
      return AppLinkAction(
        type: playlistId == null ? AppLinkActionType.unsupported : type,
        id: playlistId,
        uri: uri,
      );
    }

    if (uri.pathSegments.first == 'channel' && uri.pathSegments.length > 1) {
      return AppLinkAction(
        type: AppLinkActionType.artist,
        id: uri.pathSegments[1],
        uri: uri,
      );
    }

    return AppLinkAction(type: AppLinkActionType.unsupported, uri: uri);
  }

  static bool _isYoutubeHost(String host) {
    return host == 'youtube.com' ||
        host == 'music.youtube.com' ||
        host == 'youtu.be' ||
        host == 'www.youtube.com' ||
        host == 'm.youtube.com';
  }
}
