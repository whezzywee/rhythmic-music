import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';

/// Stateful queue manager that tracks the playlist, current position,
/// shuffle ordering, and loop/repeat modes so [BaseAudioHandler]
/// implementations can delegate queue bookkeeping.
class PlaybackQueueManager {
  PlaybackQueueManager({
    bool shuffleEnabled = false,
    bool loopModeEnabled = false,
    bool queueLoopModeEnabled = false,
  })  : _shuffleEnabled = shuffleEnabled,
        _loopModeEnabled = loopModeEnabled,
        _queueLoopModeEnabled = queueLoopModeEnabled;

  // ── public state streams ──
  final BehaviorSubject<List<MediaItem>> queueSubject =
      BehaviorSubject.seeded([]);
  final BehaviorSubject<int?> currentIndexSubject =
      BehaviorSubject.seeded(null);
  final BehaviorSubject<MediaItem?> currentItemSubject =
      BehaviorSubject.seeded(null);

  List<MediaItem> get queue => List.unmodifiable(queueSubject.value);
  int? get currentIndex => currentIndexSubject.value;
  MediaItem? get currentItem => currentItemSubject.value;
  bool get isEmpty => queueSubject.value.isEmpty;
  bool get isNotEmpty => queueSubject.value.isNotEmpty;
  int get length => queueSubject.value.length;

  // ── shuffle ──
  bool _shuffleEnabled;
  final List<String> _shuffledIds = [];
  int _shuffleCursor = -1;

  bool get shuffleEnabled => _shuffleEnabled;

  set shuffleEnabled(bool value) {
    if (value == _shuffleEnabled) return;
    _shuffleEnabled = value;
    if (value) {
      _rebuildShuffledQueue();
    } else {
      _shuffledIds.clear();
      _shuffleCursor = -1;
    }
  }

  // ── loop ──
  bool _loopModeEnabled;
  bool _queueLoopModeEnabled;

  bool get loopModeEnabled => _loopModeEnabled;

  set loopModeEnabled(bool value) => _loopModeEnabled = value;

  bool get queueLoopModeEnabled => _queueLoopModeEnabled;

  set queueLoopModeEnabled(bool value) => _queueLoopModeEnabled = value;

  // ── queue mutation ──

  /// Replace the entire queue and start at [startIndex].
  void replaceQueue(List<MediaItem> items, {int startIndex = 0}) {
    final mutable = List<MediaItem>.from(items);
    queueSubject.add(mutable);
    _setIndex(startIndex.clamp(0, mutable.length - 1));
  }

  /// Append items to the end of the queue.
  void addAll(List<MediaItem> items) {
    if (items.isEmpty) return;
    final mutable = List<MediaItem>.from(queueSubject.value)..addAll(items);
    queueSubject.add(mutable);
    if (_shuffleEnabled) {
      _shuffledIds.addAll(items.map((item) => item.id));
    }
  }

  /// Append a single item to the end of the queue.
  void addOne(MediaItem item) {
    final mutable = List<MediaItem>.from(queueSubject.value)..add(item);
    queueSubject.add(mutable);
    if (_shuffleEnabled) {
      _shuffledIds.add(item.id);
    }
  }

  /// Insert [item] immediately after the current song.
  void insertAfterCurrent(MediaItem item) {
    final ci = currentIndex;
    if (ci == null) {
      addOne(item);
      return;
    }
    final mutable = List<MediaItem>.from(queueSubject.value);
    mutable.insert(ci + 1, item);
    queueSubject.add(mutable);
    if (_shuffleEnabled) {
      _shuffledIds.insert(_shuffleCursor + 1, item.id);
    }
  }

  /// Remove [item] from the queue. Adjusts current index if needed.
  void remove(MediaItem item) {
    final mutable = List<MediaItem>.from(queueSubject.value);
    final idx = mutable.indexOf(item);
    if (idx < 0) return;

    mutable.removeAt(idx);
    queueSubject.add(mutable);

    if (_shuffleEnabled) {
      _shuffledIds.remove(item.id);
    }

    final ci = currentIndex;
    if (ci != null) {
      if (ci > idx) {
        _setIndex(ci - 1);
      } else if (ci == idx) {
        _setIndex(mutable.isEmpty ? null : idx.clamp(0, mutable.length - 1));
      } else {
        // ci < idx — current item unchanged, but we still publish
        currentItemSubject.add(currentItem);
      }
    }
  }

  /// Clear everything except the currently-playing item.
  void clearExceptCurrent() {
    final ci = currentIndex;
    if (ci == null || queueSubject.value.isEmpty) {
      queueSubject.add([]);
      _shuffledIds.clear();
      _shuffleCursor = -1;
      _setIndex(null);
      return;
    }
    final current = queueSubject.value[ci];
    queueSubject.add([current]);
    _setIndex(0);
    if (_shuffleEnabled) {
      _shuffledIds
        ..clear()
        ..add(current.id);
      _shuffleCursor = 0;
    }
  }

  /// Shuffle the entire queue while keeping the current song at position 0.
  void shuffleCurrentQueue() {
    final ci = currentIndex;
    if (ci == null || queueSubject.value.isEmpty) return;

    final mutable = List<MediaItem>.from(queueSubject.value);
    final current = mutable.removeAt(ci);
    mutable.shuffle();
    mutable.insert(0, current);

    queueSubject.add(mutable);
    _setIndex(0);
    currentItemSubject.add(current);

    if (_shuffleEnabled) {
      _shuffledIds
        ..clear()
        ..addAll(mutable.map((item) => item.id));
      _shuffleCursor = 0;
    }
  }

  /// Reorder item from [oldIndex] to [newIndex].
  void reorder(int oldIndex, int newIndex) {
    final mutable = List<MediaItem>.from(queueSubject.value);
    if (oldIndex < 0 ||
        oldIndex >= mutable.length ||
        newIndex < 0 ||
        newIndex >= mutable.length) return;

    final item = mutable.removeAt(oldIndex);
    final adjustedNew = oldIndex < newIndex ? newIndex - 1 : newIndex;
    mutable.insert(adjustedNew, item);

    queueSubject.add(mutable);

    final ci = currentIndex;
    if (ci != null) {
      final newCi = mutable.indexOf(queueSubject.value[ci]); // use old item
      _setIndex(newCi >= 0 ? newCi : ci);
    }
  }

  /// Jump to [index] in the physical queue.
  void jumpToIndex(int index) {
    if (queueSubject.value.isEmpty) return;
    _setIndex(index.clamp(0, queueSubject.value.length - 1));
  }

  // ── navigation helpers ──

  /// Next song index according to current repeat / shuffle rules.
  int nextIndex() {
    if (queueSubject.value.isEmpty) return 0;

    if (_shuffleEnabled && _shuffledIds.isNotEmpty) {
      if (_shuffleCursor + 1 >= _shuffledIds.length) {
        _rebuildShuffledQueue();
        _shuffleCursor = 0;
      } else {
        _shuffleCursor++;
      }
      final id = _shuffledIds[_shuffleCursor];
      final idx = queueSubject.value.indexWhere((item) => item.id == id);
      return idx >= 0 ? idx : _nextSequentialIndex();
    }

    return _nextSequentialIndex();
  }

  /// Previous song index according to current rules.
  int previousIndex(Duration currentPosition) {
    if (queueSubject.value.isEmpty) return 0;

    if (_shuffleEnabled && _shuffledIds.isNotEmpty) {
      if (_shuffleCursor - 1 < 0) {
        _rebuildShuffledQueue();
        _shuffleCursor = _shuffledIds.length - 1;
      } else {
        _shuffleCursor--;
      }
      final id = _shuffledIds[_shuffleCursor];
      final idx = queueSubject.value.indexWhere((item) => item.id == id);
      return idx >= 0 ? idx : _prevSequentialIndex();
    }

    return _prevSequentialIndex();
  }

  // ── internal ──

  int _nextSequentialIndex() {
    final ci = currentIndex ?? 0;
    if (queueSubject.value.length > ci + 1) return ci + 1;
    if (_queueLoopModeEnabled) return 0;
    return ci;
  }

  int _prevSequentialIndex() {
    final ci = currentIndex ?? 0;
    if (ci - 1 >= 0) return ci - 1;
    return ci;
  }

  void _rebuildShuffledQueue() {
    _shuffledIds
      ..clear()
      ..addAll(queueSubject.value.map((item) => item.id));
    _shuffledIds.shuffle(Random());
    _shuffleCursor = 0;
  }

  void _setIndex(int? index) {
    currentIndexSubject.add(index);
    if (index != null && index < queueSubject.value.length) {
      currentItemSubject.add(queueSubject.value[index]);
    } else {
      currentItemSubject.add(null);
    }
  }

  void dispose() {
    queueSubject.close();
    currentIndexSubject.close();
    currentItemSubject.close();
  }
}
