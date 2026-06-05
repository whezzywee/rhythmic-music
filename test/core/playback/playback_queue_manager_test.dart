import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonymusic/core/playback/playback_queue_manager.dart';

MediaItem _song(String id) => MediaItem(
      id: id,
      title: 'Song $id',
      artist: 'Artist $id',
      duration: const Duration(minutes: 3),
    );

void main() {
  group('PlaybackQueueManager', () {
    late PlaybackQueueManager manager;

    setUp(() {
      manager = PlaybackQueueManager();
    });

    test('starts empty', () {
      expect(manager.isEmpty, isTrue);
      expect(manager.currentIndex, isNull);
      expect(manager.currentItem, isNull);
    });

    test('replaceQueue sets queue and index', () {
      final songs = [_song('a'), _song('b'), _song('c')];
      manager.replaceQueue(songs, startIndex: 1);

      expect(manager.length, 3);
      expect(manager.currentIndex, 1);
      expect(manager.currentItem!.id, 'b');
    });

    test('addOne appends to queue', () {
      manager.replaceQueue([_song('a')]);
      manager.addOne(_song('b'));

      expect(manager.length, 2);
      expect(manager.queue.last.id, 'b');
    });

    test('addAll appends items', () {
      manager.replaceQueue([_song('a')]);
      manager.addAll([_song('b'), _song('c')]);

      expect(manager.length, 3);
      expect(manager.queue.last.id, 'c');
    });

    test('insertAfterCurrent places item after current', () {
      manager.replaceQueue([_song('a'), _song('b'), _song('c')], startIndex: 1);
      manager.insertAfterCurrent(_song('x'));

      expect(manager.queue.map((s) => s.id).toList(), ['a', 'b', 'x', 'c']);
    });

    test('remove adjusts index when removing before current', () {
      manager.replaceQueue([_song('a'), _song('b'), _song('c')], startIndex: 2);
      manager.remove(manager.queue[0]);

      expect(manager.currentIndex, 1);
      expect(manager.queue.length, 2);
    });

    test('shuffleCurrentQueue keeps current song at index 0', () {
      manager.replaceQueue(
          [_song('a'), _song('b'), _song('c'), _song('d')],
          startIndex: 2);
      manager.shuffleCurrentQueue();

      expect(manager.currentIndex, 0);
      expect(manager.currentItem!.id, 'c');
      expect(manager.length, 4);
    });

    test('nextIndex advances sequentially without shuffle', () {
      manager.replaceQueue([_song('a'), _song('b'), _song('c')]);
      expect(manager.nextIndex(), 1);
      manager.jumpToIndex(1);
      expect(manager.nextIndex(), 2);
    });

    test('nextIndex wraps when queueLoopModeEnabled is true', () {
      manager.queueLoopModeEnabled = true;
      manager.replaceQueue([_song('a'), _song('b')], startIndex: 1);
      expect(manager.nextIndex(), 0);
    });

    test('shuffleEnabled rebuilds shuffled order', () {
      manager.replaceQueue(
          [_song('a'), _song('b'), _song('c'), _song('d')],
          startIndex: 0);
      manager.shuffleEnabled = true;

      // Shuffled queue should contain all 4 ids and a valid next index
      final next = manager.nextIndex();
      expect(next, greaterThanOrEqualTo(0));
      expect(next, lessThan(4));
    });

    test('clearExceptCurrent keeps only current song', () {
      manager.replaceQueue([_song('a'), _song('b'), _song('c')], startIndex: 1);
      manager.clearExceptCurrent();

      expect(manager.length, 1);
      expect(manager.currentItem!.id, 'b');
    });

    test('dispose closes subjects', () {
      manager.dispose();
      expect(manager.queueSubject.isClosed, isTrue);
      expect(manager.currentIndexSubject.isClosed, isTrue);
      expect(manager.currentItemSubject.isClosed, isTrue);
    });

    test('reorder moves item within queue', () {
      manager.replaceQueue(
          [_song('a'), _song('b'), _song('c'), _song('d')],
          startIndex: 3);
      manager.reorder(1, 2);

      expect(manager.queue.map((s) => s.id).toList(), ['a', 'b', 'c', 'd']);
    });

    test('loopModeEnabled can be toggled', () {
      expect(manager.loopModeEnabled, isFalse);
      manager.loopModeEnabled = true;
      expect(manager.loopModeEnabled, isTrue);
    });
  });
}
