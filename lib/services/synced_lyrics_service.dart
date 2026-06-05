import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:harmonymusic/utils/helper.dart';
import 'package:hive/hive.dart';

import '/core/lyrics/lyrics_client.dart';

class SyncedLyricsService {
  static final LyricsClient _lyricsClient = LyricsClient();

  static Future<Map<String, dynamic>?> getSyncedLyrics(
      MediaItem song, int durInSec) async {
    final lyricsBox = await Hive.openBox("lyrics");
    // check if lyrics available in local database
    if (lyricsBox.containsKey(song.id)) {
      return Map<String, dynamic>.from(await lyricsBox.get(song.id));
    }

    final dur = song.duration?.inSeconds ?? durInSec;
    try {
      final response = await _lyricsClient.getSyncedLyrics(
        LyricsRequest(
          artistName: song.artist,
          trackName: song.title,
          albumName: song.album,
          durationSeconds: dur,
        ),
      );
      if (response != null) {
        printINFO("Synced Available");
        final lyricsData = response.toJson();
        await lyricsBox.put(song.id, lyricsData);
        return lyricsData;
      }
    } on DioException catch (e) {
      printERROR(e.response);
    } finally {
      await lyricsBox.close();
    }
    return null;
  }
}
