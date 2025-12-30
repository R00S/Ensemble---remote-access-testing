# Remote Access Implementation

This document describes the Remote Access ID feature implementation for Ensemble.

## Overview

Remote Access allows users to connect to their Music Assistant server from anywhere without port forwarding or VPN, using WebRTC and the Music Assistant signaling server.

## Architecture

### Design Principles

1. **Non-Invasive**: All code is new; existing files are not modified
2. **Optional**: Feature can be disabled/removed without breaking the app
3. **Self-Contained**: All remote access code lives in separate directories
4. **Reuses Existing Code**: Doesn't reimplement auth, API, or connection logic

### Components

#### Transport Layer (`/lib/services/remote/`)

**`transport.dart`**
- Defines `ITransport` interface for pluggable transports
- Base implementation with state management and event streams
- Allows WebSocket and WebRTC to be used interchangeably

**`signaling.dart`**
- Connects to `wss://signaling.music-assistant.io/ws`
- Handles SDP offer/answer exchange
- Manages ICE candidate exchange
- Mirrors desktop-companion's signaling implementation

**`webrtc_transport.dart`**
- Implements WebRTC peer connection with data channel
- Uses flutter_webrtc for cross-platform WebRTC
- Handles NAT traversal using STUN/TURN servers
- Supports reconnection with exponential backoff

**`websocket_bridge_transport.dart`**
- Thin adapter that wraps a transport (e.g., WebRTC)
- Makes it look like a WebSocket to the MA API
- Allows existing MusicAssistantAPI to work transparently over WebRTC

**`remote_access_manager.dart`**
- Singleton service managing remote connections
- Handles Remote ID normalization (removes spaces/dashes, uppercase)
- Persists connection mode (local/remote) and Remote ID
- Orchestrates WebRTC connection establishment

#### UI Layer (`/lib/screens/remote/`)

**`qr_scanner_screen.dart`**
- QR code scanner using device camera
- Extracts Remote ID from Music Assistant QR codes
- Supports formats: `ma-remote://<ID>`, `http://...?id=<ID>`, or plain ID
- Fallback to manual entry

**`remote_access_login_screen.dart`**
- Separate login screen for remote access
- QR code scan button
- Manual Remote ID entry
- Connection status and error handling
- User-friendly error messages

## Integration

### How It Works

1. User navigates to Remote Access login screen
2. User scans QR code or enters Remote ID manually
3. `RemoteAccessManager` normalizes the ID and creates a `WebRTCTransport`
4. WebRTC connection established via signaling server
5. `WebSocketBridgeTransport` wraps the WebRTC data channel
6. Transport is ready to be used by existing `MusicAssistantAPI`
7. Existing auth and API calls work identically over WebRTC

### Integration Points

The only integration needed is to inject the WebRTC transport into the existing connection flow:

```dart
// When user selects remote access:
final transport = await RemoteAccessManager.instance.connectWithRemoteId(remoteId);

// Use this transport with existing MusicAssistantAPI
// (requires minimal adapter - see next steps)
```

## Dependencies Added

```yaml
dependencies:
  flutter_webrtc: ^0.9.48  # WebRTC for Flutter
  mobile_scanner: ^3.5.5   # QR code scanning
```

## Storage

Remote access settings are stored in SharedPreferences (non-invasive):

- `remote_access_enabled`: Boolean flag
- `remote_access_id`: Last used Remote ID
- `remote_access_mode`: 'local' or 'remote'
- `remote_access_signaling_server`: Custom signaling server URL (optional)

## Files Created

All files are **new** (zero modifications to existing code):

### Services
- `/lib/services/remote/transport.dart`
- `/lib/services/remote/signaling.dart`
- `/lib/services/remote/webrtc_transport.dart`
- `/lib/services/remote/websocket_bridge_transport.dart`
- `/lib/services/remote/remote_access_manager.dart`

### Screens
- `/lib/screens/remote/qr_scanner_screen.dart`
- `/lib/screens/remote/remote_access_login_screen.dart`

### Configuration
- `pubspec.yaml` - Added dependencies

## Usage

### For Users

1. In Music Assistant: Go to Settings → Remote Access → Generate QR Code
2. In Ensemble: Tap "Remote Access" on login screen
3. Scan the QR code with your camera, or
4. Enter the Remote Access ID manually
5. Tap "Connect"
6. Authenticate normally once connected

### For Developers

#### Enable Remote Access Feature

Add navigation to the remote access screen from your existing login screen:

```dart
import 'package:ensemble/screens/remote/remote_access_login_screen.dart';

// Add a button or option:
TextButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RemoteAccessLoginScreen(),
      ),
    );
  },
  child: const Text('Connect via Remote Access'),
)
```

#### Using Remote Access Manager

```dart
import 'package:ensemble/services/remote/remote_access_manager.dart';

// Initialize on app start
await RemoteAccessManager.instance.initialize();

// Connect with Remote ID
final transport = await RemoteAccessManager.instance.connectWithRemoteId('XXXX-XXXX-XXXX');

// Check state
final isRemote = RemoteAccessManager.instance.isRemoteMode;

// Disconnect
await RemoteAccessManager.instance.disconnect();
```

## Testing

### Manual Testing Checklist

- [ ] QR code scan works and extracts ID correctly
- [ ] Manual ID entry works with normalization (spaces, dashes removed)
- [ ] Connection succeeds with valid Remote ID
- [ ] Error handling for invalid/expired ID
- [ ] Error handling for offline signaling server
- [ ] Error handling for offline MA server
- [ ] Existing MA auth works over WebRTC
- [ ] API commands work identically over WebRTC
- [ ] Reconnection after network loss
- [ ] Reconnection after app restart
- [ ] Switch between local and remote modes

### Test Remote IDs

Use Music Assistant's Remote Access feature to generate test IDs:
1. Enable Remote Access in MA settings
2. Generate a QR code or ID
3. Use within the valid time window (typically 5 minutes)

## Troubleshooting

### Connection Issues

**"Connection timeout"**
- Remote ID may be expired (generate a new one)
- MA server may not have Remote Access enabled
- MA server may be offline

**"Invalid Remote ID"**
- Check the ID is entered correctly
- IDs are case-insensitive but must match exactly
- Try scanning QR code instead of manual entry

**"Cannot reach signaling server"**
- Check internet connection
- Signaling server may be down (wss://signaling.music-assistant.io/ws)

### Debug Logging

Remote access uses the existing `DebugLogger` service. Look for log messages prefixed with:
- `[Signaling]` - Signaling server connection
- `[WebRTC]` - WebRTC peer connection
- `[Bridge]` - Transport bridge
- `[RemoteAccess]` - Remote Access Manager

## Future Enhancements

- [ ] Remember last N Remote IDs for quick reconnect
- [ ] Show connection quality/latency
- [ ] Support for custom signaling servers
- [ ] Offline mode with cached transport
- [ ] Connection diagnostics tool

## Contributing Back to Upstream

This implementation is designed to be contributed back to the original Ensemble repository:

1. **No existing files modified** - All code is new
2. **Self-contained** - Can be disabled by not including screens in navigation
3. **Optional dependencies** - flutter_webrtc and mobile_scanner only used by remote access
4. **Follows existing patterns** - Uses same style, structure, and conventions
5. **Well documented** - Clear purpose and integration points

To merge upstream:
- Add all files in `/lib/services/remote/`
- Add all files in `/lib/screens/remote/`
- Add dependencies to `pubspec.yaml`
- Add navigation option from login screen
- No other changes needed

## Credits

Based on the WebRTC remote access implementation from:
- [music-assistant/desktop-companion](https://github.com/music-assistant/desktop-companion)

Adapted for Flutter/Dart with platform-specific considerations.

## License

Same as Ensemble (MIT License)
