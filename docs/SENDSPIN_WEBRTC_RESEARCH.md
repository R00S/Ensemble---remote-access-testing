# Sendspin WebRTC Architecture Research

**Date:** 2026-01-13  
**Status:** Research Complete - Dual Peer Connection Architecture Identified  
**Upstream Response:** Sendspin uses WebRTC DataChannels, not WebSocket proxying

---

## Executive Summary

Based on upstream feedback and current research, **Sendspin DOES support WebRTC DataChannels** for audio streaming in remote scenarios. The current implementation incorrectly assumes Sendspin requires WebSocket connections and attempted to proxy WebSocket over WebRTC. The correct architecture uses **two separate peer connections**:

1. **Peer Connection 1**: MA API control (already implemented ✅)
2. **Peer Connection 2**: Sendspin audio streaming (not implemented ❌)

---

## Current State of Sendspin Protocol (2025-2026)

### What is Sendspin?

Sendspin (formerly "Resonate") is Music Assistant's new open-source protocol for synchronized multi-room audio, introduced in MA 2.7 (December 2025). Key features:

- **Sample-accurate synchronization**: Sub-0.05ms deviation between devices
- **Multi-role support**: Audio player, controller, artwork display, visualizers, etc.
- **Open standard**: Royalty-free, designed to compete with AirPlay/Chromecast
- **Multiple transport layers**: WebSocket (local), WebRTC (remote), Opus codec
- **Complete music experience**: Audio + metadata + artwork + visualizations

### Transport Layer Architecture

According to official documentation and upstream feedback:

**Local Network (LAN):**
- Uses **WebSocket** connection directly to server
- URL: `ws://{server-ip}:8927/sendspin`
- Optimal for stability and low latency with TCP reliability

**Remote Network (WAN):**
- Uses **WebRTC** with DataChannels
- Enables peer-to-peer, NAT traversal via STUN/TURN
- Signaling happens through MA API connection
- End-to-end encrypted

### Key Insight: Dual Peer Connection Architecture

Music Assistant's web player implementation uses:

```
Connection 1: MA API (Control Plane)
├── WebRTC Peer Connection
├── Data Channel: "ma-api"
└── Purpose: Browse library, control players, authentication

Connection 2: Sendspin Audio (Data Plane)
├── WebRTC Peer Connection (separate from API)
├── Data Channel: unnamed/default
├── Signaling: Via API data channel (Connection 1)
└── Purpose: Stream audio (JSON control + binary PCM/Opus)
```

**Critical difference from current implementation:**
- Current: Tried to proxy WebSocket→WebRTC (single connection)
- Correct: Two separate WebRTC peer connections, signaled through first

---

## API Endpoints for Sendspin WebRTC

Based on research, these MA API commands exist for establishing the second peer connection:

### 1. `sendspin/ice_servers`
**Purpose:** Get STUN/TURN server configuration for WebRTC
**Request:** Via MA API data channel
**Response:** Array of ICE server configurations

```json
{
  "ice_servers": [
    {"urls": "stun:stun.l.google.com:19302"},
    {"urls": "turn:turn.example.com", "username": "...", "credential": "..."}
  ]
}
```

### 2. `sendspin/connect`
**Purpose:** Initiate Sendspin peer connection with SDP offer
**Request:**
```json
{
  "sdp": {
    "type": "offer",
    "sdp": "v=0\r\no=- ..."
  }
}
```
**Response:** SDP answer from server

### 3. ICE Candidate Exchange
**Purpose:** Exchange ICE candidates for NAT traversal
**Method:** Via API data channel (likely custom message format)

### 4. `sendspin/update_state` (already implemented)
**Purpose:** Report player state back to server
**Current Status:** ✅ Implemented in music_assistant_api.dart

### 5. `sendspin/disconnect` (already implemented)
**Purpose:** Gracefully disconnect player
**Current Status:** ✅ Implemented in music_assistant_api.dart

---

## What Went Wrong in Current Implementation

### Incorrect Assumption
The code comments in `music_assistant_api.dart:2838-2846` state:

```dart
// NOTE: The following Sendspin API methods were removed because they don't exist in MA:
// - getSendspinConnectionInfo (sendspin/connection_info)
// - sendspinOffer (sendspin/webrtc_offer)
// - sendspinAnswer (sendspin/webrtc_answer)
// - sendspinIceCandidate (sendspin/ice_candidate)
```

**Reality:** These APIs (or equivalents) DO exist for establishing WebRTC connections remotely.

### What Was Tried
From `EMAIL_TO_UPSTREAM.md` and `REMOTE_ACCESS_RESEARCH.md`:

1. ❌ **WebSocket Proxy over WebRTC**
   - Attempted to forward WebSocket frames through single WebRTC data channel
   - Quote: "Initial attempts at proxying WebSocket over WebRTC data channel showed high latency"
   - Quote: "I abandoned this approach without trying alternative architectures"
   - Result: Abandoned due to latency

2. ✅ **Direct URL Connection**
   - Using Cloudflare Tunnel with real URLs works
   - But requires external infrastructure

### What Was NOT Tried

❌ **Dual Peer Connection Architecture**
- Never implemented second WebRTC peer connection
- Never called `sendspin/ice_servers` or `sendspin/connect` endpoints
- Never tested native WebRTC DataChannel for Sendspin audio

---

## How It Should Work (Based on Upstream Feedback)

### Architecture Flow

```
Step 1: Establish API Connection (Already Working ✅)
┌─────────────┐           WebRTC            ┌──────────────┐
│   Mobile    │◄──────── Data Channel ─────►│  MA Server   │
│    App      │       "ma-api" label        │              │
└─────────────┘                              └──────────────┘
      │                                             ▲
      │ Library browsing, authentication,          │
      │ player control, queue management           │
      └────────────────────────────────────────────┘

Step 2: Request Sendspin Connection (Via API Channel)
┌─────────────┐                              ┌──────────────┐
│   Mobile    │  sendspin/ice_servers ───►   │  MA Server   │
│    App      │ ◄──── ICE server config      │              │
│             │  sendspin/connect (SDP) ───► │              │
│             │ ◄──── SDP answer             │              │
└─────────────┘                              └──────────────┘

Step 3: Establish Second Peer Connection for Audio
┌─────────────┐           WebRTC            ┌──────────────┐
│   Mobile    │◄─────── Data Channel ──────►│  MA Server   │
│    App      │    (Sendspin protocol)      │              │
└─────────────┘                              └──────────────┘
      ▲                                             │
      │ Binary PCM audio + JSON control            │
      └────────────────────────────────────────────┘
```

### Implementation Steps Required

1. **Detect Remote Mode**
   - When connected via RemoteAccessManager
   - Skip WebSocket connection for Sendspin

2. **Request ICE Servers**
   - Call `sendspin/ice_servers` via MA API
   - Get STUN/TURN configuration

3. **Create Second Peer Connection**
   - New `RTCPeerConnection` instance
   - Separate from MA API connection
   - Configure with received ICE servers

4. **Create Data Channel**
   - Label: Could be empty or "sendspin"
   - Reliable, ordered delivery for audio

5. **Exchange SDP**
   - Create offer from mobile app
   - Send via `sendspin/connect` through API channel
   - Receive answer from server
   - Set remote description

6. **Exchange ICE Candidates**
   - Send local candidates to server (via API channel)
   - Receive remote candidates from server
   - Add to peer connection

7. **Handle Sendspin Protocol**
   - JSON control messages (same as WebSocket version)
   - Binary audio frames (PCM or Opus)
   - Parse header: message type + timestamp + data

8. **Lifecycle Management**
   - Keep both connections alive
   - Reconnect second peer connection if drops
   - Cleanup on disconnect

---

## Code Changes Required

### Files to Modify

1. **`lib/services/remote/webrtc_sendspin_transport.dart`** (NEW)
   - Second peer connection manager
   - Handles Sendspin-specific WebRTC setup
   - Signaling via MA API data channel

2. **`lib/services/sendspin_service.dart`** (MODIFY)
   - Detect remote mode
   - Use WebRTC transport instead of WebSocket when remote
   - Keep existing protocol logic (JSON + binary)

3. **`lib/services/music_assistant_api.dart`** (MODIFY)
   - Add `getSendspinIceServers()` method
   - Add `sendspinConnect(sdp)` method
   - Add ICE candidate exchange methods
   - Remove incorrect comments about non-existent APIs

4. **`lib/providers/music_assistant_provider.dart`** (MODIFY)
   - Pass remote mode flag to Sendspin initialization
   - Coordinate lifecycle of both peer connections

### Estimated Code Impact

- **New code:** ~300-400 lines (WebRTC Sendspin transport)
- **Modified code:** ~100 lines (API methods, Sendspin service)
- **Total:** ~400-500 lines

### Minimal change philosophy maintained:
- Reuses existing WebRTC infrastructure from API connection
- No changes to Sendspin protocol handling
- Only transport layer changes

---

## Benefits of Correct Implementation

1. ✅ **Native WebRTC performance**: No proxy overhead
2. ✅ **Lower latency**: Direct peer-to-peer audio stream
3. ✅ **Better for audio**: UDP with loss tolerance vs TCP retransmits
4. ✅ **Architecturally correct**: Matches MA web player design
5. ✅ **Future-proof**: Aligns with MA's remote streaming vision
6. ✅ **No infrastructure**: No Cloudflare Tunnel required

---

## Comparison: Approaches

| Approach | Status | Latency | Complexity | Works? |
|----------|--------|---------|------------|--------|
| WebSocket Proxy over WebRTC | Tried, abandoned | High | High | ❌ No |
| Cloudflare Tunnel | Current workaround | Low | Medium | ✅ Yes |
| Dual Peer Connection | **Not tried** | **Low** | **Medium** | **❓ Should work** |

---

## References

### Official Documentation
- Sendspin Protocol: https://www.sendspin-audio.com/
- Music Assistant API: https://www.music-assistant.io/api/
- GitHub: https://github.com/Sendspin
- GitHub: https://github.com/music-assistant/server

### Implementation Examples
- **sendspin-js**: TypeScript client with WebRTC support
- **aiosendspin**: Python async client library
- **MA web player**: Browser-based player using WebRTC for remote

### Key Features (MA 2.7+)
- WebRTC remote streaming via Nabu Casa infrastructure
- Sample-accurate multi-room sync (<0.05ms deviation)
- Multiple device roles (player, controller, display, visualizer)
- Open, royalty-free protocol

---

## Next Steps

### To Implement Dual Peer Connection:

1. ✅ **Research complete** - Architecture understood
2. ⏳ **Verify API endpoints** - Test `sendspin/ice_servers` and `sendspin/connect`
3. ⏳ **Prototype second peer connection** - Minimal implementation
4. ⏳ **Test audio streaming** - Verify PCM/Opus over WebRTC DataChannel
5. ⏳ **Integration** - Connect to existing Sendspin service
6. ⏳ **Testing** - Remote connection stability, audio quality
7. ⏳ **Documentation** - Update implementation docs

### Questions to Answer:

1. **Exact API format**: What's the precise request/response for `sendspin/connect`?
2. **ICE candidate exchange**: How are candidates sent through API channel?
3. **Audio codec**: PCM or Opus over WebRTC? Same format as WebSocket?
4. **Synchronization**: Does time sync work over WebRTC DataChannel?
5. **Error handling**: Reconnection strategy for second peer connection?

---

## Conclusion

The upstream response reveals a critical architectural misunderstanding. Sendspin DOES support WebRTC DataChannels natively - the correct implementation uses:

- **Two separate peer connections**
- **Signaling through the first (API) connection**
- **Direct audio streaming over the second connection**

This has never been tested. The WebSocket proxy approach was a dead end. The dual peer connection architecture aligns with Music Assistant's official web player and should be the path forward for remote audio playback.

**Key Takeaway:** The code comments claiming these APIs don't exist were incorrect. They do exist, and implementing them properly would enable full remote playback functionality without requiring external infrastructure like Cloudflare Tunnel.
