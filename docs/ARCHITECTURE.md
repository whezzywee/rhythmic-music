# Rhythmic Music — Architecture Overview

This document gives a high-level tour of the codebase so new contributors can orient themselves quickly.

## Tech Stack

| Component | Technology |
|---|---|
| **Framework** | Flutter (Dart) |
| **Platforms** | Windows, Linux (desktop-only) |
| **Audio (Android/fallback)** | `just_audio` |
| **Audio (Desktop)** | `media_kit` (wraps libmpv) via `just_audio_media_kit` |
| **Local Database** | Hive (NoSQL, file-based) |
| **State Management** | GetX (`get` package) |
| **YouTube Integration** | `youtube_explode_dart` (stream URLs) + custom YouTube Music API (`music_service.dart`) |
| **Lyrics** | LRCLIB (synced lyrics), custom parser |
| **Theming** | `palette_generator` (album art color extraction) |
| **Window Management** | `window_manager` (desktop window control) |
| **System Tray** | `tray_manager` |
| **Media Keys (Windows)** | `smtc_windows` (System Media Transport Controls) |
| **Media Keys (Linux)** | `audio_service_mpris` (MPRIS D-Bus interface) |

## Project Structure

```
rhythmic-music/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── base_class/                  # Base classes and abstractions
│   ├── mixins/                      # Dart mixins for shared behavior
│   ├── models/                      # Data models (Song, Playlist, Album, Artist, etc.)
│   ├── native_bindings/             # Platform-specific native code bindings
│   ├── services/                    # Core business logic
│   │   ├── audio_handler.dart       # Audio playback management (queue, controls, state)
│   │   ├── music_service.dart       # YouTube Music API integration (search, browse, etc.)
│   │   ├── nav_parser.dart          # YouTube Music response parsing
│   │   ├── stream_service.dart      # Stream URL resolution
│   │   ├── synced_lyrics_service.dart  # Synced lyrics fetching
│   │   ├── piped_service.dart       # Piped proxy integration
│   │   ├── downloader.dart          # Song download management
│   │   ├── equalizer.dart           # Audio equalizer
│   │   ├── windows_audio_service.dart  # Windows SMTC integration
│   │   └── ...
│   ├── ui/                          # User interface layer
│   │   ├── home.dart                # Main home screen
│   │   ├── navigator.dart           # App navigation
│   │   ├── player/                  # Player UI (mini-player, full-screen)
│   │   ├── screens/                 # App screens (search, library, settings, etc.)
│   │   ├── widgets/                 # Reusable UI components
│   │   └── utils/                   # UI helpers and utilities
│   └── utils/                       # General utilities
├── assets/                          # Static assets (icons, etc.)
├── localization/                    # Translation files
├── windows/                         # Windows platform runner
├── linux/                           # Linux platform runner
├── android/                         # Android platform runner (inherited, not primary focus)
├── docs/                            # Project documentation
└── pubspec.yaml                     # Flutter package configuration
```

## Key Architectural Patterns

### State Management (GetX)
The app uses **GetX** for state management, dependency injection, and routing. Controllers are in various places — look for classes extending `GetxController`.

### Audio Pipeline
```
User Action
  → AudioHandler (queue management, playback control)
    → just_audio / media_kit (actual audio playback)
      → StreamService (resolves YouTube stream URLs)
        → youtube_explode_dart (extracts playable URLs)
```

### YouTube Music Integration
```
User searches/browses
  → MusicService (constructs YouTube Music API requests)
    → NavParser (parses YouTube Music API responses into models)
      → Returns: Song, Album, Artist, Playlist models
```

### Desktop-Specific Code
- **Windows:** `windows_audio_service.dart` (SMTC media keys), `smtc_windows` package
- **Linux:** `audio_service_mpris` package (MPRIS media keys), requires `mpv` for playback
- **Window Management:** `window_manager` for window size, position, minimize-to-tray
- **System Tray:** `tray_manager` for tray icon and menu

## Where to Add New Features

| Feature | Where to add it |
|---|---|
| New API endpoint | `lib/services/music_service.dart` + `lib/services/nav_parser.dart` |
| New screen | `lib/ui/screens/` (new file) + register route in `navigator.dart` |
| New widget | `lib/ui/widgets/` |
| New data model | `lib/models/` |
| Music Together | `lib/services/music_together/` (new directory) |
| Platform-specific | `lib/services/` + platform runner (`windows/`, `linux/`) |

## Music Together (Planned)

See [MUSIC_TOGETHER.md](MUSIC_TOGETHER.md) for the design of the LAN-based sync feature.

The Music Together module will be added as:
```
lib/services/music_together/
├── lan_discovery.dart       # mDNS/DNS-SD device discovery
├── session_host.dart        # WebSocket server for hosting sessions
├── session_client.dart      # WebSocket client for joining sessions
├── sync_controller.dart     # Translates sync messages to player actions
└── models.dart              # Session, Peer, SyncMessage models
```
