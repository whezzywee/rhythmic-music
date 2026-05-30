// Music Together Service
// 
// This module implements LAN-based synchronized music listening sessions.
// See docs/MUSIC_TOGETHER.md for the full design document.
//
// Architecture:
// - lan_discovery.dart     → mDNS/DNS-SD device discovery
// - session_host.dart      → WebSocket server for hosting sessions
// - session_client.dart    → WebSocket client for joining sessions
// - sync_controller.dart   → Bridges sync messages ↔ AudioHandler
// - sync_messages.dart     → Message type definitions
// - music_together_service.dart → Top-level GetX controller
//
// TODO: Implement this module (see roadmap v0.5 "The Bridge")
