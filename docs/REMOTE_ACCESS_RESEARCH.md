# Remote Access Research - Sendspin Audio Streaming Issue

**Date:** 2026-01-02  
**Status:** Research Complete - Workaround Available  
**Issue:** Remote Access connections work for API but Sendspin audio streaming fails

---

## Problem Summary

When connecting via Remote Access (WebRTC):
- MA API connection works ✓ (through WebRTC data channel)
- Device appears in Music Assistant as "sendspin device (greyed out)"
- Device doesn't show up in app's player list
- Cannot play audio on the device

## Root Cause Analysis

### Critical Discovery

**User observation:** "Phone shows up in MA as sendspin device (greyed out), but doesnt show up in the app"

This reveals:
1. **Sendspin IS registering** - device appears in MA server
2. **Device is unavailable** - shows as "greyed out" 
3. **WebSocket connection fails** - can't establish audio streaming connection

### The Architectural Problem

**Why it fails:**
- Remote Access login uses placeholder URL: `wss://remote.music-assistant.io`
- This URL gets saved as `_serverUrl` in the provider
- When Sendspin tries to connect, it uses this placeholder to build connection URL
- Sendspin attempts: `wss://remote.music-assistant.io/sendspin`
- This URL doesn't route to the actual MA server!

**Code Path:**
```dart
// In remote_access_login_screen.dart:
await provider.connectToServer(
  'wss://remote.music-assistant.io',  // PLACEHOLDER - not real server
  username: username,
  password: password,
);

// Later in _connectViaSendspin():
_sendspinService = SendspinService(_serverUrl!);  // Uses placeholder!
```

### Desktop Companion vs Mobile App

**Key difference:**
- **Desktop Companion**: Remote control only, no audio playback
  - Only needs WebRTC for MA API
  - No player registration required
  
- **Mobile App**: Actual player device
  - Needs WebRTC for MA API ✓
  - Needs separate connection for Sendspin audio streaming ✗
  - Cannot use local network URL (device on different network)

## Constraint

**Cannot use server's local network URL for remote access** - device is on different network, connecting through WebRTC/signaling server only.

---

## Possible Solutions (Analyzed)

### Solution 1: WebSocket Proxy Over WebRTC (85% success probability)

**Approach:**
- Route ALL traffic through single WebRTC data channel
- Implement WebSocket proxy over WebRTC (similar to desktop-companion's HTTP proxy)
- SendspinService connects to local proxy (localhost:8927)
- Local proxy forwards WebSocket frames through WebRTC data channel

**Architecture:**
```
SendspinService → localhost:8927 (local proxy) → WebRTC data channel → MA Server
```

**Implementation Steps:**
1. Create local WebSocket proxy server in app
2. Proxy listens on localhost:8927
3. Proxy forwards all WebSocket traffic through WebRTC data channel
4. SendspinService connects to localhost:8927
5. WebRTC transport handles protocol translation

**Evidence from desktop-companion:**
Desktop companion already implements HTTP proxy over WebRTC:
```typescript
async sendHttpProxyRequest(method, path, headers) {
  const request = {
    type: "http-proxy-request",
    id: requestId,
    method, path, headers
  };
  this.dataChannel.send(JSON.stringify(request));
}
```

**Need to extend to WebSocket:**
```typescript
{
  type: "websocket-proxy-connect",
  path: "/sendspin",
  // Forward WebSocket frames over data channel
}
```

**Pros:**
- Works through NAT/firewalls
- No separate network connection needed
- Consistent with WebRTC architecture
- All traffic secured through single channel

**Cons:**
- Complex implementation
- Requires WebSocket proxy protocol implementation
- May add latency to audio streaming
- Need to verify MA server supports WebSocket proxying

**Key Questions:**
1. Does MA server support WebSocket proxying over WebRTC?
2. Can we run local WebSocket server in Flutter?
3. What's the performance impact on audio streaming?

---

### Solution 2: Force builtin_player API (60% success probability)

**Approach:**
- Skip Sendspin entirely for remote connections
- Use older builtin_player API through WebRTC
- Player registration works through MA API WebSocket (which uses WebRTC)

**Implementation:**
1. Detect remote mode in `_registerLocalPlayer()`
2. Force builtin_player registration even if `_serverUsesSendspin()` returns true
3. Handle audio streaming through MA API WebSocket (WebRTC)

**Code change:**
```dart
Future<void> _registerLocalPlayer() async {
  // Detect remote mode
  final remoteManager = RemoteAccessManager.instance;
  final isRemoteMode = await remoteManager.getSavedMode() == ConnectionMode.remote;
  
  // Force builtin_player for remote connections
  if (isRemoteMode) {
    _logger.log('Remote mode: using builtin_player API instead of Sendspin');
    // Skip Sendspin connection
    // Use builtin_player registration
    await _api!.registerBuiltinPlayer(playerId, name);
    return;
  }
  
  // Normal flow for local connections
  if (_serverUsesSendspin()) {
    // Connect via Sendspin
  }
}
```

**Pros:**
- Much simpler implementation
- builtin_player API goes through MA API (uses WebRTC)
- No separate connection needed
- Proven to work in older MA versions

**Cons:**
- Only works if MA server supports builtin_player
- May not work with MA 2.7.0b20+ (Sendspin-only servers)
- Audio streaming might be less efficient
- Deprecated API - may be removed in future

**Key Questions:**
1. Does builtin_player API work through WebRTC?
2. What MA server versions support it?
3. Is there feature parity with Sendspin?

---

### Solution 3: Remote Control Only (40% - Workaround)

**Approach:**
- Accept that mobile app can't play audio over remote access
- Only works as remote control (like desktop companion)
- Clear limitation but connection works

**Implementation:**
- Skip player registration for remote connections
- Show UI message: "Audio playback not available over Remote Access"
- Allow browsing/controlling other players

**Pros:**
- Simplest implementation
- Makes the app work for browsing/control
- Sets clear user expectations
- No complex networking

**Cons:**
- Users can't play audio on their device
- Defeats primary purpose of mobile player
- Not ideal user experience
- Feature regression

---

### Solution 4: Dual WebRTC + TURN (30% - Complex)

**Approach:**
- Establish second WebRTC peer connection specifically for audio
- Use TURN server to tunnel Sendspin connection
- Two parallel WebRTC connections

**Implementation:**
1. Get TURN credentials from MA server
2. Establish second WebRTC connection for audio
3. Route Sendspin through this second connection
4. Manage lifecycle of both connections

**Pros:**
- Proper separation of concerns
- Optimized for audio quality
- Could support higher bitrates

**Cons:**
- Very complex implementation
- Requires TURN server (costs/resources)
- Double connection overhead
- May not be supported by MA server
- Adds significant latency
- Complex state management

---

## Current Workaround

**Working Solution (as of 2026-01-02):**
User reports that exposing Music Assistant through cloudflared and logging in with URL works.

**Setup:**
- Use cloudflared tunnel to expose MA server
- Login with actual cloudflare URL instead of Remote Access
- Connection works because URL routes to real server
- Sendspin can connect to real server URL

**Pros:**
- Works with current codebase
- No code changes needed
- Full functionality available

**Cons:**
- Requires cloudflared setup/configuration
- More complex for users
- Additional infrastructure dependency

---

## Recommendation

### Immediate (Current State)
- Document cloudflared workaround for users
- Keep Remote Access feature for MA API/browsing

### Short Term (If implementing fix)
**Try Solution 2 first (builtin_player API)**
- Simpler implementation
- Quick to test
- Falls back gracefully if server doesn't support it

### Long Term (If Solution 2 fails)
**Implement Solution 1 (WebSocket Proxy)**
- Architecturally correct
- Future-proof
- Supports all MA server versions
- Better user experience

---

## Technical Details

### Files Involved

**Player Registration:**
- `lib/providers/music_assistant_provider.dart` - `_registerLocalPlayer()`, `_connectViaSendspin()`
- `lib/services/sendspin_service.dart` - WebSocket connection logic

**Remote Access:**
- `lib/services/remote/remote_access_manager.dart` - Connection mode detection
- `lib/services/remote/webrtc_transport.dart` - WebRTC data channel
- `lib/screens/remote/remote_access_login_screen.dart` - Login flow with placeholder URL

**MA API:**
- `lib/services/music_assistant_api.dart` - WebRTC transport adapter

### Key Code Locations

**Placeholder URL usage:**
```dart
// lib/screens/remote/remote_access_login_screen.dart:125
await provider.connectToServer(
  'wss://remote.music-assistant.io',
  username: username,
  password: password,
);
```

**Sendspin URL construction:**
```dart
// lib/providers/music_assistant_provider.dart:1135
_sendspinService = SendspinService(_serverUrl!);
```

**Where fix would go (Solution 2):**
```dart
// lib/providers/music_assistant_provider.dart:1017-1053
Future<void> _registerLocalPlayer() async {
  // Check for remote mode and use builtin_player
}
```

---

## Research Sources

1. **music-assistant/desktop-companion** - HTTP proxy over WebRTC implementation
2. **flutter-webrtc examples** - Mobile WebRTC patterns
3. **music-assistant/server** - Server-side API structure
4. **Current codebase** - Architecture analysis

---

## Future Work

If implementing proper solution:

1. **Investigate MA Server Support**
   - Check if server supports WebSocket proxying over WebRTC
   - Test builtin_player API compatibility
   - Review server version requirements

2. **Prototype Local Proxy**
   - Test if dart:io WebSocket server works on mobile
   - Measure performance/latency impact
   - Security implications of localhost server

3. **Protocol Design**
   - Define WebSocket proxy message format
   - Handle WebSocket handshake over data channel
   - Bidirectional frame forwarding

4. **Testing Strategy**
   - Test with different MA server versions
   - Measure audio streaming latency
   - Verify across iOS/Android
   - Test app lifecycle (backgrounding)

---

## Conclusion

Remote Access works for MA API but requires additional work for audio playback:
- **Root cause identified:** Sendspin can't connect using placeholder URL
- **Workaround available:** Cloudflared tunnel with real URL
- **Proper fix possible:** WebSocket proxy over WebRTC or builtin_player fallback
- **Decision needed:** Invest in proper fix or keep workaround

The architecture difference between desktop-companion (remote control) and mobile app (actual player) creates this complexity. Any proper solution requires either routing Sendspin through WebRTC or using an alternative player API that works through WebRTC.
