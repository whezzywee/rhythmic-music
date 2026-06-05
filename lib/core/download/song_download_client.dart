import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:audiotags/audiotags.dart';
import 'package:dio/dio.dart';

import '/models/media_Item_builder.dart';
import '/services/stream_service.dart';

typedef DownloadProgressCallback = void Function(int progressPercent);
typedef SongYearResolver = Future<String?> Function(MediaItem song);

class SongDownloadRequest {
  const SongDownloadRequest({
    required this.song,
    required this.downloadDirectoryPath,
    required this.downloadFormat,
    this.supportDirectoryPath,
    this.resolveYear,
    this.cancelToken,
    this.onProgress,
  });

  final MediaItem song;
  final String downloadDirectoryPath;
  final String downloadFormat;
  final String? supportDirectoryPath;
  final SongYearResolver? resolveYear;
  final CancelToken? cancelToken;
  final DownloadProgressCallback? onProgress;
}

class SongDownloadResult {
  const SongDownloadResult({
    required this.playable,
    required this.statusMessage,
    this.filePath,
    this.songJson,
    this.streamInfoJson,
  });

  final bool playable;
  final String statusMessage;
  final String? filePath;
  final Map<String, dynamic>? songJson;
  final Map<String, dynamic>? streamInfoJson;
}

class SongDownloadClient {
  SongDownloadClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<SongDownloadResult> download(SongDownloadRequest request) async {
    final song = request.song;
    final playerResponse = await StreamProvider.fetch(song.id);

    if (!playerResponse.playable) {
      return SongDownloadResult(
        playable: false,
        statusMessage: playerResponse.statusMSG,
      );
    }

    final requiredAudioStream = request.downloadFormat == 'opus'
        ? playerResponse.highestBitrateOpusAudio!
        : playerResponse.highestBitrateMp4aAudio!;

    final filePath = _buildFilePath(
      song: song,
      directoryPath: request.downloadDirectoryPath,
      audio: requiredAudioStream,
    );

    await _downloadAudioFile(
      audio: requiredAudioStream,
      filePath: filePath,
      cancelToken: request.cancelToken,
      onProgress: request.onProgress,
    );

    final year = await _resolveYear(song, request.resolveYear);
    await _downloadThumbnail(song, request.supportDirectoryPath);

    song.extras?['url'] = filePath;
    final songJson = MediaItemBuilder.toJson(song);
    final streamInfoJson = requiredAudioStream.toJson();
    streamInfoJson['url'] = filePath;
    songJson['streamInfo'] = [true, streamInfoJson];

    await _writeTags(
      song: song,
      filePath: filePath,
      year: year,
    );

    return SongDownloadResult(
      playable: true,
      statusMessage: 'OK',
      filePath: filePath,
      songJson: songJson,
      streamInfoJson: streamInfoJson,
    );
  }

  String _buildFilePath({
    required MediaItem song,
    required String directoryPath,
    required Audio audio,
  }) {
    final actualFormat = audio.audioCodec.name.contains('mp') ? 'm4a' : 'opus';
    final invalidChar =
        RegExp(r'Container.|\/|\\|\"|\<|\>|\*|\?|\:|\!|\[|\]|\||\%');
    final songTitle = '${song.title.trim()} (${song.artist?.trim()})'
        .replaceAll(invalidChar, '');
    return '$directoryPath/$songTitle.$actualFormat';
  }

  Future<void> _downloadAudioFile({
    required Audio audio,
    required String filePath,
    CancelToken? cancelToken,
    required DownloadProgressCallback? onProgress,
  }) async {
    final totalBytes = audio.size;
    await _dio.download(
      audio.url,
      filePath,
      cancelToken: cancelToken,
      options: Options(headers: {'Range': 'bytes=0-$totalBytes'}),
      onReceiveProgress: (count, total) {
        if (total <= 0) return;
        onProgress?.call(((count / total) * 100).toInt());
      },
    );
  }

  Future<String?> _resolveYear(
    MediaItem song,
    SongYearResolver? resolveYear,
  ) async {
    if (song.extras?['year'] != null) {
      return song.extras?['year'].toString();
    }
    if (song.album == null || resolveYear == null) {
      return null;
    }
    try {
      return await resolveYear(song);
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadThumbnail(
    MediaItem song,
    String? supportDirectoryPath,
  ) async {
    if (supportDirectoryPath == null || song.artUri == null) return;
    try {
      final thumbnailDirectory = Directory('$supportDirectoryPath/thumbnails');
      if (!await thumbnailDirectory.exists()) {
        await thumbnailDirectory.create(recursive: true);
      }
      final thumbnailPath = '${thumbnailDirectory.path}/${song.id}.png';
      await _dio.downloadUri(song.artUri!, thumbnailPath);
    } catch (_) {}
  }

  Future<void> _writeTags({
    required MediaItem song,
    required String filePath,
    required String? year,
  }) async {
    final trackDetails = (song.extras?['trackDetails'])?.split('/');
    final trackNumber = int.tryParse(trackDetails?[0] ?? '');
    final totalTracks = int.tryParse(trackDetails?[1] ?? '');

    try {
      final imageUrl = song.artUri?.toString();
      final imageBytes = imageUrl == null ? null : await _fetchImage(imageUrl);
      final tag = Tag(
        title: song.title,
        trackArtist: song.artist,
        album: song.album,
        year: int.tryParse(year ?? ''),
        trackNumber: trackNumber,
        trackTotal: totalTracks,
        albumArtist: song.artist,
        genre: song.genre,
        pictures: imageBytes == null
            ? []
            : [
                Picture(
                  bytes: imageBytes,
                  mimeType: MimeType.png,
                  pictureType: PictureType.coverFront,
                )
              ],
      );

      await AudioTags.write(filePath, tag);
    } catch (_) {}
  }

  Future<Uint8List> _fetchImage(String imageUrl) async {
    final response = await _dio.get<List<int>>(
      imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? []);
  }
}
