<div align="center">

# 🎵 Rhythmic Music

**The desktop music app that plays in rhythm with your phone.**

A free, open-source desktop music player for **Windows** and **Linux**.
Built on the foundation of [Harmony Music](https://github.com/anandnet/Harmony-Music) by **anandnet**.
Designed to work alongside [OpenTune](https://github.com/Arturo254/OpenTune) on mobile.

[Download](#download) · [Features](#features) · [Music Together](#-music-together) · [Contributing](#contributing)

</div>

---

## Why Rhythmic Music?

Android has incredible open-source music apps — [OpenTune](https://github.com/Arturo254/OpenTune), [OuterTune](https://github.com/DD3Boh/OuterTune), [RiMusic](https://github.com/fast4x/RiMusic) — but desktop has almost nothing.

**Rhythmic Music** fills that gap. It's a desktop-first music player that streams from YouTube Music, with no ads, no accounts, and no tracking.

And with **Music Together**, you can sync what you're listening to across your desktop and your phone — on the same local network — so your music flows with you.

## Why This Fork Exists

[Harmony Music](https://github.com/anandnet/Harmony-Music) was created by **anandnet** — a beautifully designed, cross-platform music app built with Flutter. It was one of the few open-source music apps that truly cared about the desktop experience.

The original project reached its final release (v1.12.2) in December 2025, when anandnet announced the project's conclusion. We understand — open source is volunteer work, and every project has its season.

But the desktop experience was too good to let go. So Rhythmic Music picks up where Harmony Music left off:

- **Preserving** everything that made the original great
- **Focusing** on desktop (Windows + Linux) — because Android is already covered
- **Adding** Music Together for LAN-based sync with mobile apps like OpenTune
- **Improving** with new features and polish over time

We give full credit to **anandnet** and all original Harmony Music contributors. Their work is the foundation everything here is built on.

> *"He made the rollercoaster and I sat in it. Now I want other people to experience what I experienced."*

If anandnet ever wants to collaborate or take the project back — the door is always open.

---

## Features

### Inherited from Harmony Music
- 🎵 Stream music from YouTube / YouTube Music
- 🔇 No ads, no login required
- 📋 Playlist creation & management
- 🔖 Bookmark songs, artists, albums
- 📥 Song downloading & offline caching
- 🎨 Dynamic themes (album art colors)
- ⏭️ Skip silence
- 🎚️ Equalizer
- 🎤 Synced & plain lyrics
- ⏰ Sleep timer
- 🔊 Streaming quality control
- 📐 Sidebar & bottom navigation toggle
- 🖥️ Desktop-native UI (not a stretched mobile app)

### New in Rhythmic Music
- 🎧 **Music Together** — Sync listening sessions over LAN
- 🖥️ Desktop-focused experience (Windows + Linux)
- 🔧 Updated dependencies & bug fixes
- ✨ More coming soon...

---

## 🎧 Music Together

Listen to the same music at the same time with friends or across your own devices — as long as you're on the same local network.

**How it works:**
1. One device **hosts** a session
2. Other devices **discover** it automatically on the network (via mDNS)
3. Playback syncs in real-time — play, pause, seek, track changes

**No internet server needed.** Everything stays on your local network. Private by design.

Works between:
- 🖥️ Rhythmic Music (desktop) ↔ 🖥️ Rhythmic Music (desktop)
- 🖥️ Rhythmic Music (desktop) ↔ 📱 OpenTune (mobile) *(planned)*

---

## Download

> 🚧 **Coming soon.** Rhythmic Music is currently in development.

Builds will be available for:
- **Windows** — `.exe` installer
- **Linux** — AppImage, `.deb`, `.rpm`

---

## Building from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- For Linux: `mpv` package (`sudo apt install mpv` or equivalent)

### Steps
```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/rhythmic-music.git
cd rhythmic-music

# Get dependencies
flutter pub get

# Run on desktop
flutter run -d windows    # Windows
flutter run -d linux      # Linux
```

---

## Roadmap

| Version | Theme | What's included |
|---------|-------|----------------|
| **v0.1** | "It Lives" | Desktop builds working, dependencies updated, critical bugs fixed, new branding |
| **v0.5** | "The Bridge" | Music Together over LAN, device discovery, desktop ↔ mobile sync |
| **v1.0** | "Daily Driver" | System tray, media keys, keyboard shortcuts, audio normalization, polished UX |
| **v2.0+** | "Future" | macOS support, multiple music sources, advanced Music Together features |

---

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Whether it's bug reports, feature ideas, code, translations, or documentation — every contribution matters.

---

## Credits & Acknowledgments

This project wouldn't exist without the work of others:

| Project | Creator | Contribution |
|---------|---------|-------------|
| [Harmony Music](https://github.com/anandnet/Harmony-Music) | **anandnet** | The foundation — the entire codebase this project is built on |
| [OpenTune](https://github.com/Arturo254/OpenTune) | **Arturo254** | Inspiration for features, polish, and the Music Together concept |
| [InnerTune](https://github.com/z-huang/InnerTune) | **z-huang** | The original that started the open-source YTM ecosystem |
| [ViMusic](https://github.com/vfsfitvnm/ViMusic) | **vfsfitvnm** | UI inspiration for the original Harmony Music |
| [LRCLIB](https://lrclib.net) | — | Synced lyrics provider |
| [sigma67/ytmusicapi](https://github.com/sigma67/ytmusicapi) | **sigma67** | YouTube Music API reference |

---

## License

```
Rhythmic Music is free software licensed under GPL v3.0.

Based on Harmony Music by anandnet, also licensed under GPL v3.0.

- Copied/modified versions of this software cannot be used for non-free or profit purposes.
- You cannot publish copied/modified versions of this app on closed-source app repositories
  like PlayStore/AppStore.
```

## Disclaimer

```
This project is not sponsored, affiliated with, funded, authorized, or endorsed by any
content provider. Any song, content, or trademark used in this app is the intellectual
property of their respective owners.

Rhythmic Music is not responsible for any infringement of copyright or other intellectual
property rights that may result from the use of songs and other content available through
this app.

This software is released "as-is", without any warranty, responsibility, or liability.
```
