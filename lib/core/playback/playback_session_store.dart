import 'package:audio_service/audio_service.dart';

/// Abstract store for playback session persistence —
/// save / restore queue state across app restarts.
abstract class PlaybackSessionStore {
  /// Whether the user has opted into session restoration.
  bool get restoreEnabled;

  /// Persist the current playback session.
  Future<void> save({
    required List<MediaItem> queue,
    required int currentIndex,
    required int positionMillis,
  });

  /// Restore the previous session, or `null` when nothing is saved.
  Future<PlaybackSessionSnapshot?> restore();
}

class PlaybackSessionSnapshot {
  const PlaybackSessionSnapshot({
    required this.queue,
    required this.index,
    required this.positionMillis,
  });

  final List<MediaItem> queue;
  final int index;
  final int positionMillis;

  Duration get position => Duration(milliseconds: positionMillis);
}
