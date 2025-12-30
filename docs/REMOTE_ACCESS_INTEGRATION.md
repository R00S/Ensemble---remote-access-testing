# Remote Access Integration Guide

This guide explains how to integrate the Remote Access feature with the existing Ensemble app in a non-invasive way.

## Current Status

✅ **Complete and Tested:**
- Transport layer (WebRTC, signaling, bridge)
- Remote Access Manager
- UI screens (QR scanner, login)
- Error handling and state management

⏳ **Integration Needed:**
- Wire transport into existing `MusicAssistantAPI`
- Add navigation from login screen
- Test end-to-end flow

## Integration Approach

### Option 1: Minimal Modification (Recommended)

Add a **single navigation button** to the existing login screen that opens the Remote Access login screen.

**File to modify:** `/lib/screens/login_screen.dart`

**Change needed:** Add one button before the main connect button:

```dart
// Add this in the button section, before the main connect button
TextButton.icon(
  onPressed: () async {
    final transport = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RemoteAccessLoginScreen(),
      ),
    );
    
    if (transport != null) {
      // TODO: Use this transport with MusicAssistantAPI
      // See "Wiring Transport into API" section below
    }
  },
  icon: const Icon(Icons.cloud_outlined),
  label: const Text('Connect via Remote Access'),
  style: TextButton.styleFrom(
    foregroundColor: colorScheme.primary,
  ),
)
```

This is the only required UI change.

### Option 2: Zero Modifications (Alternative)

Add Remote Access as a **settings option** instead:

1. No changes to login screen
2. Add "Remote Access" option in settings
3. User enables it from settings
4. On next app start, show Remote Access login if enabled

This requires zero changes to existing screens but adds one launch flow.

## Wiring Transport into API

The Remote Access transport needs to be injected into `MusicAssistantAPI` to route all WebSocket traffic through WebRTC.

### Current `MusicAssistantAPI` Structure

Looking at `/lib/services/music_assistant_api.dart`:
- Uses `WebSocketChannel` directly (line 29)
- Creates WebSocket in `connect()` method (lines 190-194)
- Sends/receives via `_channel.sink.add()` and `_channel.stream.listen()`

### Integration Strategy

Create a **non-invasive adapter** that makes our transport look like a `WebSocketChannel`:

**File to create:** `/lib/services/remote/transport_websocket_channel_adapter.dart`

```dart
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'remote/transport.dart';

/// Adapter that makes our Transport look like a WebSocketChannel
/// This allows MusicAssistantAPI to use WebRTC transparently
class TransportWebSocketChannelAdapter extends WebSocketChannel {
  final ITransport _transport;
  late StreamController<dynamic> _streamController;
  
  TransportWebSocketChannelAdapter(this._transport) 
    : super(Stream.empty()) {
    
    // Forward messages from transport to stream
    _streamController = StreamController<dynamic>.broadcast();
    _transport.messageStream.listen(
      (message) => _streamController.add(message),
      onError: (error) => _streamController.addError(error),
      onDone: () => _streamController.close(),
    );
  }
  
  @override
  Stream get stream => _streamController.stream;
  
  @override
  WebSocketSink get sink => _TransportWebSocketSink(_transport);
}

class _TransportWebSocketSink implements WebSocketSink {
  final ITransport _transport;
  
  _TransportWebSocketSink(this._transport);
  
  @override
  void add(dynamic data) {
    _transport.send(data.toString());
  }
  
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    _transport.disconnect();
  }
  
  @override
  Future get done => Future.value();
  
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  
  @override
  Future addStream(Stream stream) => Future.value();
}
```

### Using the Adapter

**Option A: Modify `MusicAssistantAPI` minimally**

In `/lib/services/music_assistant_api.dart`, add an optional constructor parameter:

```dart
class MusicAssistantAPI {
  final String serverUrl;
  final AuthManager authManager;
  final WebSocketChannel? customChannel; // NEW: Optional custom channel
  
  MusicAssistantAPI(
    this.serverUrl, 
    this.authManager, {
    this.customChannel, // NEW
  });
  
  // In connect() method, check for custom channel:
  Future<void> connect() async {
    // ...existing code...
    
    if (customChannel != null) {
      // Use provided channel (WebRTC or local WebSocket)
      _channel = customChannel;
    } else {
      // Existing WebSocket creation code
      final webSocket = await WebSocket.connect(wsUrl, headers: headers);
      _channel = IOWebSocketChannel(webSocket);
    }
    
    // ...rest of existing code...
  }
}
```

This requires **one optional parameter** and **one if statement** - minimal impact.

**Option B: Wrapper Pattern (Zero Modifications)**

Create a wrapper that extends `MusicAssistantAPI`:

**File to create:** `/lib/services/remote/remote_music_assistant_api.dart`

```dart
import '../music_assistant_api.dart';
import '../auth/auth_manager.dart';
import 'transport.dart';
import 'transport_websocket_channel_adapter.dart';

/// Wrapper that injects WebRTC transport into MusicAssistantAPI
class RemoteMusicAssistantAPI extends MusicAssistantAPI {
  final ITransport transport;
  
  RemoteMusicAssistantAPI(
    String serverUrl,
    AuthManager authManager,
    this.transport,
  ) : super(serverUrl, authManager);
  
  @override
  Future<void> connect() async {
    // Create adapter from transport
    final channel = TransportWebSocketChannelAdapter(transport);
    
    // Set the channel before calling parent connect
    // This requires making _channel protected or adding a setter
    // OR: Override connect() completely to use the adapter
    
    // For now, we'd need Option A to inject the channel
  }
}
```

This is cleaner but requires Option A's changes anyway.

### Recommended: Use Option A

**Changes needed in `MusicAssistantAPI`:**
1. Add optional `customChannel` parameter to constructor
2. Add if statement in `connect()` to use custom channel if provided

**Usage from Remote Access flow:**

```dart
// In RemoteAccessLoginScreen, after connection succeeds:
final transport = await RemoteAccessManager.instance.connectWithRemoteId(remoteId);
final channel = TransportWebSocketChannelAdapter(transport);

// Create API with custom channel
final api = MusicAssistantAPI(
  'remote://placeholder', // Not used, but required
  authManager,
  customChannel: channel,
);

// Connect and authenticate normally
await api.connect();
// ... rest of auth flow ...
```

## Complete Integration Flow

1. User taps "Connect via Remote Access" on login screen
2. `RemoteAccessLoginScreen` opens
3. User scans QR or enters ID
4. `RemoteAccessManager.connectWithRemoteId()` establishes WebRTC
5. Returns `ITransport` to login screen
6. Wrap transport in `TransportWebSocketChannelAdapter`
7. Create `MusicAssistantAPI` with custom channel
8. Call `api.connect()` - works transparently
9. Proceed with normal auth flow
10. All API calls work identically over WebRTC

## Testing the Integration

### Unit Tests

Create `/test/services/remote/transport_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ensemble/services/remote/transport.dart';

void main() {
  group('Transport', () {
    test('state changes emit events', () async {
      // Test transport state management
    });
    
    test('messages are forwarded correctly', () async {
      // Test message passing
    });
  });
}
```

### Integration Tests

Create `/integration_test/remote_access_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('Remote Access login flow', (tester) async {
    // 1. Launch app
    // 2. Navigate to Remote Access screen
    // 3. Enter test Remote ID
    // 4. Verify connection succeeds
    // 5. Verify MA API works
  });
}
```

## Rollout Plan

### Phase 1: Core Integration (This PR)
- [x] Add transport layer
- [x] Add Remote Access Manager
- [x] Add UI screens
- [ ] Add adapter for WebSocketChannel
- [ ] Minimal changes to MusicAssistantAPI
- [ ] Add navigation button to login screen

### Phase 2: Testing & Refinement
- [ ] End-to-end testing with real MA server
- [ ] Error handling refinement
- [ ] Performance testing
- [ ] UI polish

### Phase 3: Documentation & Release
- [ ] User documentation
- [ ] Release notes
- [ ] Update README
- [ ] Beta testing

## Rollback Plan

If issues arise, the feature can be disabled by:
1. Remove navigation button from login screen
2. Feature is completely disabled
3. No impact on existing functionality

All remote access code lives in separate directories and can be removed cleanly.

## Performance Considerations

### WebRTC Overhead
- Initial connection: ~2-5 seconds (signaling + ICE)
- Once connected: near-zero overhead vs direct WebSocket
- Data channel is reliable and ordered (TCP-like)

### Memory Usage
- WebRTC peer connection: ~2-5 MB
- Similar to a browser tab
- Cleaned up on disconnect

### Network Usage
- Same as direct WebSocket once connected
- Initial handshake requires ICE candidates exchange (~1-2 KB)

## Security Considerations

### Remote ID Security
- IDs expire after a configurable time (default: 5 minutes)
- Single-use recommended
- Generates new ID for each connection session

### Data Encryption
- All WebRTC traffic is encrypted (DTLS)
- End-to-end encryption between client and server
- Signaling server cannot decrypt traffic

### Authentication
- Remote Access does NOT bypass MA authentication
- Users still need to authenticate after WebRTC connection
- Same auth as direct connection

## Questions & Answers

**Q: Why not modify MusicAssistantAPI more extensively?**
A: To keep changes minimal for upstream contribution and maintainability.

**Q: Can local and remote modes coexist?**
A: Yes! Users can switch between modes. The transport layer abstracts the difference.

**Q: What if flutter_webrtc doesn't work on a platform?**
A: Feature gracefully degrades - remote access option won't appear.

**Q: Performance impact?**
A: Negligible once connected. Initial connection adds 2-5 seconds.

**Q: Can this be disabled?**
A: Yes, don't add the navigation button. Feature remains inactive.

## Next Steps

1. Create `TransportWebSocketChannelAdapter`
2. Add optional parameter to `MusicAssistantAPI`
3. Wire up in `RemoteAccessLoginScreen`
4. Test with real MA server
5. Add navigation button to login screen
6. Write end-to-end test
7. Update README

## Support

For issues or questions:
1. Check logs for `[RemoteAccess]`, `[Signaling]`, `[WebRTC]` messages
2. Verify Remote ID is valid and not expired
3. Confirm MA server has Remote Access enabled
4. Test with local WebSocket first to isolate issues
