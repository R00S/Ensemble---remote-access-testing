# Prompt for Next Agent: Remote Access Feature Completion

---

## Context

You are taking over development of the Remote Access feature for Ensemble, a Music Assistant mobile client. The previous agent implemented the foundational WebRTC transport layer, UI components, and basic authentication flow. However, two critical issues prevent the feature from being production-ready.

**Repository:** R00S/Ensemble---remote-access-testing  
**Branch:** copilot/add-remote-access-id-login  
**Language:** Dart/Flutter  
**Current Status:** Alpha - Partially functional with known issues

---

## Your Mission

Fix two critical issues that make the Remote Access feature unusable:

### 1. Connection Instability (PRIORITY 1)
**Problem:** WebRTC connection breaks or times out frequently during or after authentication  
**Impact:** Users must disconnect and reconnect repeatedly - feature is unusable

**What to investigate:**
- WebRTC data channel state management in `lib/services/remote/webrtc_transport.dart`
- Missing keep-alive/heartbeat mechanism
- Race conditions in connection establishment flow
- ICE candidate handling issues
- Transport adapter connection lifecycle in `lib/services/music_assistant_api.dart`

**Success criteria:**
- Connection remains stable for 10+ minutes continuously
- Reconnection works automatically on network interruption
- Connection survives app backgrounding/foregrounding

### 2. Missing Player Registration (PRIORITY 2)
**Problem:** App doesn't register as a player when connecting via Remote Access  
**Impact:** Users can only browse library and control other players, cannot play music to their device

**What to investigate:**
- Why `_initializeLocalPlayback()` in `lib/providers/music_assistant_provider.dart` doesn't register player for remote connections
- Compare player registration flow between working IP connection and broken remote connection
- Check if Music Assistant server requires special handling for remote players
- Verify player ID and configuration are correct for remote mode
- Timing - does registration need to happen at a specific point in connection flow?

**Success criteria:**
- App shows up as a built-in player in Music Assistant when connected remotely
- User can play music to their device over Remote Access
- Player state (playing/paused/idle) syncs correctly

---

## Code Architecture

### What's Already Implemented

**Transport Layer** (`lib/services/remote/`):
- ✅ `transport.dart` - ITransport interface
- ✅ `signaling.dart` - WebRTC signaling to `wss://signaling.music-assistant.io/ws`
- ✅ `webrtc_transport.dart` - WebRTC peer connection with data channel
- ✅ `websocket_bridge_transport.dart` - Makes WebRTC look like WebSocket
- ✅ `remote_access_manager.dart` - Manages remote connections

**UI Layer** (`lib/screens/remote/`):
- ✅ `qr_scanner_screen.dart` - QR code scanning with URL parsing
- ✅ `remote_access_login_screen.dart` - Remote ID + username/password entry

**Integration** (minimal changes):
- ✅ `lib/services/music_assistant_api.dart` - Remote mode detection, transport adapter (~137 lines)
- ✅ `lib/providers/music_assistant_provider.dart` - Credential handling, player init call (~15 lines)
- ✅ `lib/services/local_player_service.dart` - isInitialized getter (3 lines)
- ✅ `lib/screens/login_screen.dart` - Navigation button (~60 lines)

**Total changes to existing files:** ~215 lines (minimal, surgical changes)

### What's Working
- WebRTC signaling connection establishes
- Data channel opens successfully
- Transport adapter wraps WebRTC as WebSocketChannel
- UI flow (login → remote access → home)
- Authentication messages flow over WebRTC
- QR code scanning and URL parsing

### What's Broken
- Connection stability (timeouts, disconnects)
- Player registration for remote connections

---

## Development Constraints

### CRITICAL: Minimal Changes Philosophy

The codebase follows a **minimal modification** approach to make the feature upstream-contribution friendly:

**Rules:**
1. **DO NOT** rewrite existing code unless absolutely necessary
2. **DO** keep all new code in separate directories when possible
3. **DO** make surgical, targeted changes to existing files
4. **DO NOT** modify working IP connection flow
5. **DO** maintain compatibility with existing WebSocket flow

**Why:** This makes it easier to contribute the feature upstream to the main Ensemble repository.

### Files You'll Likely Need to Modify

**For Connection Stability:**
- `lib/services/remote/webrtc_transport.dart` - WebRTC state management
- `lib/services/remote/signaling.dart` - Signaling keep-alive
- `lib/services/music_assistant_api.dart` - Transport adapter lifecycle

**For Player Registration:**
- `lib/providers/music_assistant_provider.dart` - Player initialization flow
- `lib/services/local_player_service.dart` - Player registration logic
- Possibly `lib/services/remote/remote_access_manager.dart` - Remote mode flags

---

## Debugging Strategy

### Step 1: Add Comprehensive Logging

Add debug logging to track the full flow:

```dart
// In webrtc_transport.dart
print('[WebRTC] State: ${_state}, Channel: ${_dataChannel?.state}');

// In music_assistant_api.dart  
print('[API] Using remote mode: $isRemoteMode');

// In music_assistant_provider.dart
print('[Provider] Initializing local playback, remote: ${isRemoteConnection}');

// In local_player_service.dart
print('[Player] Registering player, initialized: $_initialized');
```

### Step 2: Compare Working vs Broken

Run the app with verbose logging for both:
1. **Working:** Connect via local IP, note full sequence of events
2. **Broken:** Connect via Remote Access, note where flow diverges

Look for:
- Different timing of player registration calls
- Missing initialization steps
- State changes in WebRTC that aren't handled
- Errors that are silently caught

### Step 3: Monitor Network Traffic

Use network monitoring to verify:
- WebRTC data channel messages are flowing
- No unexpected disconnections at transport level
- Signaling server keep-alive messages (if needed)
- STUN/TURN server connectivity

### Step 4: Test Incrementally

For each fix:
1. Make minimal change
2. Build and test thoroughly
3. Verify change doesn't break IP connection
4. Commit with clear message
5. Document what was fixed and why

---

## Testing Requirements

Before marking as complete, verify:

### Connection Stability Tests
- [ ] Connection stays active for 15+ minutes
- [ ] Survives app backgrounding (30+ seconds)
- [ ] Automatic reconnection works after network drop
- [ ] No timeouts during authentication
- [ ] Works on both WiFi and mobile data

### Player Registration Tests  
- [ ] App appears as player in Music Assistant
- [ ] Can select app as playback target from MA
- [ ] Music plays on device over remote connection
- [ ] Playback controls work (play/pause/skip)
- [ ] Volume control works
- [ ] Queue management works

### Regression Tests
- [ ] Local IP connection still works identically
- [ ] All existing features work over remote connection
- [ ] No new crashes or errors
- [ ] Build succeeds without warnings

---

## Resources

### Reference Implementations
- **Desktop Companion:** https://github.com/music-assistant/desktop-companion
  - Check `src/services/webrtc.ts` for WebRTC handling
  - Check signaling protocol implementation
  - Note: Desktop companion is NOT a player, so player registration won't be there

- **Music Assistant Server Code:** https://github.com/music-assistant/server
  - Check player registration requirements
  - Check remote connection handling

### Documentation
- Current status: `docs/REMOTE_ACCESS_STATUS.md` (read this first!)
- Technical details: `docs/REMOTE_ACCESS_INTEGRATION.md`
- User guide: `docs/REMOTE_ACCESS.md`

### Key Files to Review
1. `lib/services/remote/webrtc_transport.dart` - WebRTC implementation
2. `lib/providers/music_assistant_provider.dart` - Connection flow
3. `lib/services/local_player_service.dart` - Player registration
4. `lib/services/music_assistant_api.dart` - Transport integration

---

## Success Criteria

The feature is complete when:

1. ✅ Users can scan QR code or enter Remote ID
2. ✅ Authentication with username/password succeeds consistently
3. ✅ Connection remains stable for entire session (15+ minutes)
4. ✅ App registers as a player in Music Assistant
5. ✅ Users can play music to their device over remote connection
6. ✅ All existing features work identically to IP connection
7. ✅ No regressions in IP connection flow
8. ✅ Code changes remain minimal and surgical

---

## Getting Started

1. **Read the status document:** `docs/REMOTE_ACCESS_STATUS.md`
2. **Review the current code:**
   - Start with `lib/services/remote/webrtc_transport.dart`
   - Then `lib/providers/music_assistant_provider.dart`
   - Then `lib/services/local_player_service.dart`
3. **Add logging** to understand current behavior
4. **Test the current build** to reproduce issues
5. **Compare with IP connection** to identify differences
6. **Make targeted fixes** following minimal-change philosophy
7. **Test thoroughly** before committing

---

## Notes from Previous Agent

- WebRTC signaling and data channel establishment work correctly
- Transport adapter successfully makes WebRTC look like WebSocket to MA API
- Authentication flow is correct, credentials pass through properly
- UI is complete and functional
- The issues are likely in state management or timing, not in the core architecture
- Desktop companion code is a good reference for WebRTC but won't help with player registration
- Player registration works perfectly for IP connections, so the logic is correct - just not being triggered for remote

---

## Questions to Answer

As you debug, try to answer:

1. **For connection stability:**
   - What WebRTC state is the connection in when it breaks?
   - Are data channel messages still flowing when connection "breaks"?
   - Is it actually disconnecting or just appearing disconnected?
   - Does signaling server require periodic keep-alive?

2. **For player registration:**
   - Is `_initializeLocalPlayback()` being called for remote connections?
   - If yes, why doesn't it register the player?
   - If no, why is it being skipped?
   - What's different about the provider state for IP vs remote?
   - Does MA server see the registration attempt?

Good luck! The foundation is solid - these are targeted fixes, not architectural changes needed.
