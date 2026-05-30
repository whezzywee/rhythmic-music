# Music Together — Design Document

## Overview

Music Together lets multiple devices on the same local network (LAN) listen to the same music in real-time sync. One device hosts a session, others discover and join it automatically.

**No internet server required.** Everything stays on your local network.

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│                    LOCAL NETWORK (Wi-Fi)                 │
│                                                         │
│   🖥️ Host (Rhythmic Music)                              │
│   ├── Advertises session via mDNS                       │
│   ├── Runs WebSocket server on local port               │
│   └── Sends playback state to all connected peers       │
│                                                         │
│   📱 Peer 1 (OpenTune)          🖥️ Peer 2 (Rhythmic)    │
│   ├── Discovers session          ├── Discovers session   │
│   ├── Connects via WebSocket     ├── Connects via WS     │
│   └── Syncs playback state       └── Syncs playback      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Architecture

### 1. Device Discovery (mDNS / DNS-SD)

The host advertises a service on the local network using **mDNS** (Multicast DNS), also known as Bonjour/Zeroconf.

- **Service type:** `_rhythmic-music._tcp`
- **Service name:** User-chosen session name (e.g., "Zayed's Room")
- **TXT record:** Contains metadata like app version, host name, session ID

Peers scan for this service type and display discovered sessions in the UI.

**Dart packages to consider:**
- `nsd` — Network Service Discovery (mDNS/DNS-SD) for Flutter
- `bonsoir` — Cross-platform Bonjour/mDNS for Flutter
- `multicast_dns` — Low-level mDNS for Dart

### 2. Connection (WebSocket)

Once a peer selects a session, it connects to the host's WebSocket server.

- Host starts a WebSocket server on a local port (e.g., `ws://192.168.1.x:8765`)
- Peers connect as WebSocket clients
- All communication is bidirectional over the WebSocket connection

**Dart packages:**
- `web_socket_channel` — WebSocket client (standard)
- `shelf_web_socket` or `dart:io HttpServer` — WebSocket server

### 3. Sync Protocol

Messages are JSON-encoded (simple, human-readable, easy to debug).

#### Message Types

```json
// Host → Peers: Playback state update
{
  "type": "playback_state",
  "data": {
    "track_id": "dQw4w9WgXcQ",
    "track_title": "Never Gonna Give You Up",
    "track_artist": "Rick Astley",
    "position_ms": 42000,
    "is_playing": true,
    "timestamp": 1717070000000
  }
}

// Host → Peers: Track changed
{
  "type": "track_change",
  "data": {
    "track_id": "new_track_id",
    "track_title": "Song Name",
    "track_artist": "Artist Name"
  }
}

// Host → Peers: Playback control
{
  "type": "control",
  "action": "pause"    // "play", "pause", "seek"
  "seek_ms": 0         // only for "seek" action
}

// Peer → Host: Join notification
{
  "type": "peer_join",
  "data": {
    "name": "Peer Display Name",
    "device": "windows"  // "linux", "android"
  }
}

// Host → All Peers: Peer list update
{
  "type": "peer_list",
  "data": {
    "peers": [
      {"name": "Phone", "device": "android"},
      {"name": "Laptop", "device": "windows"}
    ]
  }
}
```

### 4. Sync Strategy

**Host is the authority.** The host controls what plays, when it plays, and at what position. Peers follow.

- When the host plays/pauses/seeks/changes track → message sent to all peers
- Peers apply the action to their local player
- **Clock drift compensation:** Messages include a timestamp. Peers calculate the offset and adjust position to stay in sync (±500ms tolerance)
- **Reconnection:** If a peer disconnects, they can rejoin and the host sends current state immediately

### 5. OpenTune Compatibility (Future)

For Rhythmic Music ↔ OpenTune sync to work, both apps need to speak the same protocol.

**Options:**
1. **Rhythmic Music adopts OpenTune's protocol** — Match whatever protobuf/WebSocket format OpenTune uses (from the metroproto/metroserver ecosystem)
2. **Both adopt a shared protocol** — Define a common protocol and propose it to the OpenTune project
3. **Bridge server** — A small local relay that translates between the two formats

> **Recommendation:** Start with option 1 (adopt OpenTune's existing protocol) if the metroproto format is documented well enough. Fall back to option 3 if the protocols are too different.

## Module Structure

```
lib/services/music_together/
├── lan_discovery.dart        # mDNS service advertisement and discovery
├── session_host.dart         # WebSocket server, session management
├── session_client.dart       # WebSocket client, connecting to host
├── sync_controller.dart      # Bridges sync messages ↔ AudioHandler
├── sync_messages.dart        # Message type definitions and serialization
└── music_together_service.dart  # Top-level service (GetX controller)
```

## UI Screens

```
lib/ui/screens/music_together/
├── music_together_screen.dart    # Main screen: host or join
├── host_session_screen.dart      # Hosting view: session name, connected peers
├── join_session_screen.dart      # Join view: discovered sessions list
└── session_overlay.dart          # Mini overlay showing active session status
```

## User Flow

### Hosting
1. User opens Music Together from the menu
2. Taps "Host Session"
3. Enters a session name (or uses default)
4. Session is advertised on the local network
5. Connected peers appear in a list
6. Host plays music normally — playback syncs to all peers

### Joining
1. User opens Music Together from the menu
2. App scans for sessions on the local network
3. Available sessions appear in a list
4. User taps a session to join
5. Playback syncs to the host's current state
6. User sees what's playing, controlled by the host

## Privacy & Security

- **All traffic stays on the local network** — nothing goes to the internet
- **No authentication** (local network trust model, same as Chromecast/AirPlay)
- **No data collection** — no analytics, no tracking
- **Encryption:** Optional TLS for WebSocket (wss://) — nice to have, not essential for LAN
