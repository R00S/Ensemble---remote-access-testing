<div align="center">
  <img src="assets/images/ensemble_logo.png" alt="Ensemble Logo" height="200">

---

  <p><strong>An unofficial mobile client for Music Assistant</strong></p>
  <p>Stream your music library directly to your phone, or control playback on any connected speaker.</p>
</div>

---

## Disclaimer

**Ensemble is an unofficial, community-built mobile client for Music Assistant. It is not affiliated with, endorsed by, or supported by the Music Assistant project or its developers.**

This application was built with AI-assisted development using **Claude Code** and **Gemini CLI**.

---

## Features

### Local Playback
- **Stream to Your Phone** - Play music from your Music Assistant library directly on your mobile device
- **Background Playback** - Music continues playing when the app is minimized
- **Media Notifications** - Control playback from your notification shade with album art display

### Remote Control
- **Multi-Player Support** - Control any speaker or device connected to Music Assistant
- **Device Selector** - Quickly switch between your phone and other players
- **Full Playback Controls** - Play, pause, skip, seek, and adjust volume
- **Queue Management** - View and manage the playback queue

### Home Screen
- **Customizable Rows** - Toggle Recently Played, Discover Artists, and Discover Albums
- **Favorites Rows** - Optional rows for Favorite Albums, Artists, and Tracks
- **Adaptive Layout** - Rows scale properly for different screen sizes and aspect ratios
- **Pull to Refresh** - Refresh content with a simple pull gesture

### Library Browsing
- **Browse Your Collection** - Artists, albums, playlists, and tracks from all your music sources
- **Favorites Filter** - Toggle to show only your favorite items
- **Album Details** - View track listings with artwork
- **Artist Details** - View artist albums and top tracks
- **Playlist Support** - Browse and play your playlists
- **Search** - Find music across your entire library

### Audiobooks
- **Audiobooks Tab** - Browse your audiobook library with grid/list view options
- **Series Support** - View audiobooks organized by series with collage cover art
- **Author Browsing** - Browse audiobooks by author
- **Chapter Navigation** - Jump between chapters with timestamp display
- **Progress Tracking** - Track your listening progress across sessions
- **Continue Listening** - Pick up where you left off
- **Mark as Finished/Unplayed** - Manage your reading progress

### Smart Features
- **Instant App Restore** - App loads instantly with cached library data while syncing in background
- **Auto-Reconnect** - Automatically reconnects when connection is lost
- **Offline Browsing** - Browse your cached library even when disconnected
- **Hero Animations** - Smooth transitions between screens

### Theming
- **Material You** - Dynamic theming based on your device's wallpaper
- **Adaptive Colors** - Album artwork-based color schemes
- **Light/Dark Mode** - System-aware or manual theme selection

## Screenshots

<div align="center">
  <img src="assets/screenshots/1.png?v=2" alt="Connection Screen" width="150">
  <img src="assets/screenshots/2.png?v=2" alt="Home Screen" width="150">
  <img src="assets/screenshots/3.png?v=2" alt="Album Details" width="150">
  <img src="assets/screenshots/4.png?v=2" alt="Now Playing" width="150">
  <img src="assets/screenshots/5.png?v=2" alt="Queue" width="150">
  <img src="assets/screenshots/6.png?v=2" alt="Settings" width="150">
  <img src="assets/screenshots/7.png?v=2" alt="Audiobooks" width="150">
  <img src="assets/screenshots/8.png?v=2" alt="Audiobook Player" width="150">
</div>

## Download

Download the latest release from the [Releases page](https://github.com/R00S/Ensemble---remote-access-testing/releases).

**Note:** This is a development/testing build with **experimental Remote Access features**. The WebRTC Remote Access feature is currently **not functional** for audio playback - use the Cloudflared tunnel workaround instead (see Remote Access section below).

For a stable production build, see the [main Ensemble repository](https://github.com/CollotsSpot/Ensemble/releases).

### Remote Access (Alpha)

Connect to your Music Assistant server from anywhere - no port forwarding or VPN required.

**Status:** ⚠️ Alpha - WebRTC implementation not functional for audio playback

**Current Limitation:**
The WebRTC Remote Access feature currently **does not work** for audio playback. While the MA API connection works, the app cannot register as a player device over WebRTC due to architectural limitations (Sendspin audio streaming requires a separate WebSocket connection that cannot be established through the WebRTC data channel with the current implementation).

**✅ Recommended Workaround: Cloudflared Tunnel**

For remote access, use **Cloudflare Tunnel** to expose your Music Assistant server:

1. Set up [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) to expose your MA server
2. Get your cloudflare tunnel URL (e.g., `https://ma.yourdomain.com`)
3. In the app, tap "Connect via URL" (not "Connect via Remote Access")
4. Enter your cloudflare URL
5. Authenticate with your MA credentials

This provides:
- ✅ Full remote access to your Music Assistant server
- ✅ Audio playback on your phone works
- ✅ All features functional (library, playback, control)
- ✅ Secure connection through Cloudflare

**For developers:** See [Remote Access Research](docs/REMOTE_ACCESS_RESEARCH.md) for technical details and potential future solutions.

## Setup

1. Launch the app
2. Enter your Music Assistant server URL (e.g., `music.example.com` or `192.168.1.100`)
3. Connect to your server
4. Start playing! Music plays on your phone by default, or tap the device icon to choose a different player.

## Authentication

Ensemble supports multiple authentication methods:

| Method | Status |
|--------|--------|
| Music Assistant native auth | Tested |
| No authentication | Tested |
| Authelia | Implemented, not recently tested |
| HTTP Basic Auth | Implemented, not recently tested |

**Note:** Development and testing is done against Music Assistant beta with native authentication enabled.

## Requirements

- Music Assistant server (v2.7.0 beta 20 or later)
- Network connectivity to your Music Assistant server
- Android device (Android 5.0+)
- Audiobookshelf provider configured in Music Assistant (for audiobook features)

## License

MIT License

---

## For Developers

<details>
<summary>Build from Source</summary>

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK

### Build Instructions

1. Clone the repository
```bash
git clone https://github.com/CollotsSpot/Ensemble.git
cd Ensemble
```

2. Install dependencies
```bash
flutter pub get
```

3. Generate launcher icons
```bash
flutter pub run flutter_launcher_icons
```

4. Build APK
```bash
flutter build apk --release
```

The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`

</details>

<details>
<summary>Technologies Used</summary>

- **Flutter** - Cross-platform mobile framework
- **audio_service** - Background playback and media notifications
- **web_socket_channel** - WebSocket communication with Music Assistant
- **provider** - State management
- **cached_network_image** - Image caching
- **shared_preferences** - Local settings storage

</details>
