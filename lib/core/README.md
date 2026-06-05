# Harmony Core

This folder is the UI-independent backend boundary for Harmony Music.

New UI code should depend on `HarmonyBackend` or the plain clients exported by
`core.dart`, not on widgets, screen controllers, or GetX-only services.

## Current Modules

- `HarmonyBackend`: single composition root for music metadata, playback,
  library, downloads, lyrics, optional integrations, HTTP, and preference
  storage.
- `MusicServices`: YouTube Music metadata/search/playlist client. This is now a
  plain Dart class with injectable HTTP and preference storage.
- `PipedServices`: optional legacy Piped account and playlist client. It stays
  isolated from the main UI path and should only be surfaced deliberately.
- `LyricsClient`: plain LRCLIB client without local cache or UI concerns.
- `SongDownloadClient`: plain song download client that resolves streams,
  downloads audio, writes tags, and reports progress through a callback.
- `PlaybackService`: UI-independent playback facade over `AudioHandler` for
  queue control, transport controls, shuffle/repeat, volume, and playback state.
- `PlaybackEventType` / `PlaybackEventKey`: shared custom playback event names
  for frontend adapters.
- `PlaybackStreamResolver`: stream URL/cache/download resolver used by playback.
  It contains the stream resolution algorithm while UI/platform playback remains
  in `AudioHandler`.
- `PlaybackSessionRepository`: saves and restores previous playback sessions.
- `PlaybackCacheRepository`: writes buffered playback metadata to the song cache.
- `AppPreferencesStore`: storage interface used by backend clients.
- `HiveAppPreferencesStore`: Hive-backed implementation for the existing app.

## Optional Integrations

Piped is not a YouTube login and is not required for search, playback,
downloads, local library, or local playlists. Treat it as a legacy/advanced
playlist-sync integration:

- Do not add Piped login or account controls to the default frontend.
- Do not require Piped for any core playback or library workflow.
- Keep Piped playlist handling explicit, for example
  `LibraryRepository.pipedPlaylists()` or `playlist.isPipedPlaylist` branches.
- Preserve the backend client so existing imported Piped playlists can still be
  handled if a future advanced settings screen chooses to expose them.

## Refactor Rule

Backend modules should not import:

- `package:flutter/material.dart`
- `package:get/get.dart`
- files under `lib/ui/`
- snackbars, dialogs, routes, widgets, or screen controllers

When backend work needs to tell the UI about something, return a result object,
throw a domain error, or expose a stream/state object. The UI decides how to show
that state.

## Next Extraction Targets

- Move remaining raw Hive preference reads out of `services/audio_handler.dart`.
- Replace `GetPlatform` usage in backend adapters with an injectable platform
  abstraction if/when the app moves fully away from GetX.
- Move download queue orchestration out of `services/downloader.dart` into a
  downloader repository that reports progress through streams instead of
  snackbars.
- Replace direct `MediaItem` usage in metadata parsing with app-owned DTOs, then
  map DTOs to `MediaItem` only at the audio playback boundary.
