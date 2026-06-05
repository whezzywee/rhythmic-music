import '/models/playlist.dart';

typedef LibraryTitleTranslator = String Function(String key);

List<Playlist> defaultLibraryPlaylists({
  LibraryTitleTranslator? translate,
}) {
  String title(String key) => translate?.call(key) ?? key;

  return [
    Playlist(
      title: title('recentlyPlayed'),
      playlistId: 'LIBRP',
      thumbnailUrl: Playlist.thumbPlaceholderUrl,
      isCloudPlaylist: false,
    ),
    Playlist(
      title: title('favorites'),
      playlistId: 'LIBFAV',
      thumbnailUrl: Playlist.thumbPlaceholderUrl,
      isCloudPlaylist: false,
    ),
    Playlist(
      title: title('cachedOrOffline'),
      playlistId: 'SongsCache',
      thumbnailUrl: Playlist.thumbPlaceholderUrl,
      isCloudPlaylist: false,
    ),
    Playlist(
      title: title('downloads'),
      playlistId: 'SongDownloads',
      thumbnailUrl: Playlist.thumbPlaceholderUrl,
      isCloudPlaylist: false,
    ),
  ];
}
