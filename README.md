<div align="center">

# Rhythmic Music

</div>

<img src="https://github.com/anandnet/Harmony-Music/blob/main/cover.png" width="1200" >

# Rhythmic Music
A cross-platform music streaming app built with Flutter (Android, Windows, Linux). Streams music from YouTube/YouTube Music without login or advertisements.

## Architecture

The app has been refactored into a clean separation of concerns:

```
lib/
├── app/           # UI shell, pages, widgets, branding, translations
│   ├── features/  # Page modules (discover, search, library, playlists, downloads, player, settings)
│   └── widgets/   # Reusable UI primitives (Artwork, ShimmerPlaceholder, SongActionsMenu, etc.)
├── core/          # UI-independent backend boundary
│   ├── download/  # DownloadRepository, SongDownloadClient (with cancel/retry support)
│   ├── library/   # LibraryRepository (songs, albums, artists, playlists, save/remove)
│   ├── lyrics/    # LyricsClient
│   ├── playback/  # PlaybackService, PlaybackQueueManager, PlaybackStreamResolver, session/cache stores
│   ├── settings/  # SettingsRepository
│   └── storage/   # AppPreferencesStore (abstract) + HiveAppPreferencesStore
├── models/        # Data models (Album, Artist, Playlist, MediaItem, etc.)
├── services/      # YouTube Music, Piped, audio handler, stream resolver
└── main.dart      # Entry point (MaterialApp)
```

- **New startup path**: `MaterialApp` → `NewAppShell` → feature pages (no GetX dependency in the shell)
- **Backend boundary**: `HarmonyBackend` composes all services; UI never touches Hive or GetX directly
- **Queue management**: `PlaybackQueueManager` handles shuffle, loop, queue reordering independently of the audio handler

## Features
* Play songs from YouTube/YouTube Music
* Song caching while streaming
* Radio feature support
* Background playback
* Playlist creation, rename, delete
* Artist & Album bookmark with save/remove
* Import songs, playlists, albums, artists via sharing from YouTube/YouTube Music
* Streaming quality control
* Song downloading with cancel/retry support
* Multi-language support
* Skip silence
* Dynamic theme (dark)
* Adaptive navigation (bottom bar on narrow screens, side rail on wide)
* Equalizer support (Android)
* Android Auto support
* Synced & plain lyrics support
* Sleep timer
* No advertisements
* No login required
* Piped playlist integration (optional)

## Download
Please choose one source for Android APK. Cross-build APK sources cannot update each other.

<a href="https://github.com/anandnet/Harmony-Music/releases/latest"><img src ="https://github.com/anandnet/Harmony-Music/blob/main/don_github.png" width = "250"></a> <a href= "https://f-droid.org/packages/com.anandnet.harmonymusic"><img src = "https://github.com/anandnet/Harmony-Music/blob/main/down_fdroid.png" width = '250'></a></a>

## Development

```bash
flutter pub get        # Install dependencies
flutter analyze        # Lint
flutter test           # Run tests
flutter build apk      # Android
flutter build windows  # Windows
flutter build linux    # Linux
```

### Major Packages
* `just_audio: ^0.9.46` — audio player for Android
* `media_kit` via `just_audio_media_kit` — audio player for Linux & Windows
* `audio_service: ^0.18.17` — background playback & platform audio services
* `hive: ^2.2.3` / `hive_flutter: ^1.1.0` — offline storage
* `youtube_explode_dart` (custom fork) — YouTube Music metadata & streaming
* `dio: ^5.7.0` — HTTP client
* `shimmer: ^3.0.0` — loading placeholders

### Testing
Tests live in `test/` and follow the core module structure:
```
test/
├── app/       # AppLinkService, shell smoke tests
├── core/      # Library, playback, settings, download repository tests
└── test_support/  # MemoryPreferencesStore for unit tests
```

## Translation
<a href="https://hosted.weblate.org/engage/harmony-music/">
<img src="https://hosted.weblate.org/widget/harmony-music/project-translations/multi-auto.svg" alt="Translation status" />
</a>

Help translate at <a href="https://hosted.weblate.org/projects/harmony-music/project-translations/">Weblate</a>.

## Troubleshooting
* If you experience notification control issues or playback stops due to system optimization, enable "Ignore battery optimization" in settings.

## Branding
To rebrand the app, update the defaults in `lib/app/app_branding.dart`:
```dart
const AppBranding(
  appName: 'Rhythmic Music',
  notificationChannelId: 'com.mycompany.myapp.audio',
  notificationChannelName: 'Rhythmic Music',
  mediaKitTitle: 'Rhythmic Music',
);
```

## License
```
Rhythmic Music is free software licensed under GPL v3.0 with the following conditions:

- Copied/modified versions cannot be used for non-free or profit purposes.
- Copied/modified versions cannot be published on closed-source app repositories
  like Play Store or App Store.
```

## Disclaimer
```
This project was created for learning purposes.
It is not sponsored, affiliated with, funded, authorized, or endorsed by any content provider.
All songs, content, and trademarks are the intellectual property of their respective owners.
Rhythmic Music is not responsible for any copyright or intellectual property infringement
that may result from use of content available through this app.

This software is released "as-is" without any warranty, responsibility, or liability.
```

## Credits
* <a href="https://docs.flutter.dev/">Flutter documentation</a>
* <a href="https://suragch.medium.com/">Suragch</a>'s articles on Just Audio & state management
* <a href="https://github.com/sigma67">sigma67</a>'s unofficial YouTube Music API
* UI inspired by <a href="https://github.com/vfsfitvnm">vfsfitvnm</a>'s ViMusic
* Synced lyrics provided by <a href="https://lrclib.net">LRCLIB</a>
* <a href="https://piped.video">Piped</a> for playlists
