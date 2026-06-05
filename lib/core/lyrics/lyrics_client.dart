import 'package:dio/dio.dart';

class LyricsRequest {
  const LyricsRequest({
    required this.artistName,
    required this.trackName,
    required this.durationSeconds,
    this.albumName,
  });

  final String? artistName;
  final String trackName;
  final String? albumName;
  final int durationSeconds;
}

class SyncedLyrics {
  const SyncedLyrics({
    required this.synced,
    this.plainLyrics,
  });

  final String synced;
  final String? plainLyrics;

  Map<String, dynamic> toJson() => {
        'synced': synced,
        'plainLyrics': plainLyrics,
      };
}

class LyricsClient {
  LyricsClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<SyncedLyrics?> getSyncedLyrics(LyricsRequest request) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://lrclib.net/api/get',
      queryParameters: {
        'artist_name': request.artistName,
        'track_name': request.trackName,
        'album_name': request.albumName,
        'duration': request.durationSeconds,
      },
    );

    final data = response.data;
    final synced = data?['syncedLyrics'] as String?;
    if (synced == null) return null;

    return SyncedLyrics(
      synced: synced,
      plainLyrics: data?['plainLyrics'] as String?,
    );
  }
}
