import 'package:flutter_test/flutter_test.dart';
import 'package:harmonymusic/app/app_link_service.dart';

void main() {
  group('AppLinkService.parse', () {
    test('parses YouTube Music watch links as songs', () {
      final action = AppLinkService.parse(
        Uri.parse('https://music.youtube.com/watch?v=song123&si=abc'),
      );

      expect(action.type, AppLinkActionType.song);
      expect(action.id, 'song123');
    });

    test('parses youtu.be short links as songs', () {
      final action = AppLinkService.parse(
        Uri.parse('https://youtu.be/song456'),
      );

      expect(action.type, AppLinkActionType.song);
      expect(action.id, 'song456');
    });

    test('parses playlist links as playlists', () {
      final action = AppLinkService.parse(
        Uri.parse('https://www.youtube.com/playlist?list=PL123'),
      );

      expect(action.type, AppLinkActionType.playlist);
      expect(action.id, 'PL123');
    });

    test('parses album playlist links as albums', () {
      final action = AppLinkService.parse(
        Uri.parse('https://music.youtube.com/playlist?list=OLAK5uy_album'),
      );

      expect(action.type, AppLinkActionType.album);
      expect(action.id, 'OLAK5uy_album');
    });

    test('parses channel links as artists', () {
      final action = AppLinkService.parse(
        Uri.parse('https://youtube.com/channel/UC123'),
      );

      expect(action.type, AppLinkActionType.artist);
      expect(action.id, 'UC123');
    });

    test('rejects unsupported hosts', () {
      final action = AppLinkService.parse(
        Uri.parse('https://example.com/watch?v=song123'),
      );

      expect(action.type, AppLinkActionType.unsupported);
      expect(action.id, isNull);
    });

    test('rejects watch links without a video id', () {
      final action = AppLinkService.parse(
        Uri.parse('https://youtube.com/watch?si=abc'),
      );

      expect(action.type, AppLinkActionType.unsupported);
      expect(action.id, isNull);
    });
  });
}
