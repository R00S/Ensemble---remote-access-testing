# Fork vs Upstream Comparison

**Date:** 2026-01-12  
**Analysis:** Comparing R00S/Ensemble---remote-access-testing with CollotsSpot/Ensemble

---

## Summary

This fork diverged from the upstream to experiment with **WebRTC Remote Access** features. Meanwhile, the upstream repository continued with production-ready improvements without remote access features.

### Version Comparison

| Repository | Version | Status |
|------------|---------|--------|
| **This Fork** | v2.7.3-beta | Halted at remote access experimentation |
| **Upstream** | v2.8.7-beta | Active development, production-ready |

---

## Key Differences

### What This Fork Has (Not in Upstream)

**WebRTC Remote Access Implementation (Non-Functional)**
- `lib/services/remote/` - Complete WebRTC implementation
  - `remote_access_manager.dart` - Connection manager
  - `signaling.dart` - WebRTC signaling protocol
  - `webrtc_transport.dart` - WebRTC data channel transport
  - `websocket_bridge_transport.dart` - Bridge adapter
- `lib/screens/remote/` - Remote access UI
  - `remote_access_login_screen.dart` - Remote login flow
  - `qr_scanner_screen.dart` - QR code scanning for remote ID
- `flutter_webrtc: ^0.9.48` dependency
- `mobile_scanner: ^3.5.5` dependency

**Status:** ⚠️ **NOT FUNCTIONAL** for audio playback
- MA API connection works through WebRTC
- Sendspin audio streaming fails (cannot establish WebSocket through WebRTC)
- Device shows as "greyed out" in Music Assistant
- Audio playback on device not possible

**Documentation:**
- `docs/REMOTE_ACCESS_*.md` - Extensive research and analysis
- Identified root cause: Sendspin requires separate WebSocket connection that can't be established through WebRTC data channel
- Documented workaround: Use Cloudflared tunnel instead

### What Upstream Has (Not in This Fork)

**From v2.7.4-beta to v2.8.7-beta:**

#### v2.8.7-beta (Latest)
- **Queue Reliability** - Real-time queue sync, error handling with rollback
- **Playlist Enhancements** - Favorite playlists, hero animations, upgraded details screen
- **Search & Library Polish** - Animated filter bars, scroll-back fixes
- **Home Screen** - Favorite podcasts row, fixed row height consistency
- **Localization** - French translation, fixed language fallback
- **Bug Fixes** - Favorite artists showing on startup (#41)

#### v2.8.6-beta
- **Volume Control Redesign** - +/- buttons, precision mode, adaptive colors
- **Queue Panel Improvements** - Tap to skip, clear queue button, haptic feedback
- **Library Screen Redesign** - Unified segmented control, smooth animations
- **Player Animation Polish** - Hero-like curved path animations, 60-120fps
- **Bug Fixes** - Podcast player, home screen reconnection, mini player text

#### v2.8.5-beta
- **Redesigned Queue Panel** - Swipe to delete, instant drag handles, better navigation
- **Volume Precision Mode** - Hold slider for fine-grained control
- **Favorite Playlists & Radio** - New home screen rows

#### v2.8.4-beta
- **Search Scoring Overhaul** - Stopword removal, fuzzy matching, n-gram matching
- **Improved Scoring Tiers** - Better result ranking
- **Bug Fixes** - Radio stream metadata

#### v2.8.3-beta
- **Fix Black Screen Bug** - Material You theme fixed (#37)

#### v2.8.2-beta
- **Fixed Tailscale Authentication** - .ts.net URLs properly recognized (#38)

#### v2.8.1-beta
- **Provider & Player Filter Sync** - Respects MA user profile settings
- **Artist Filter Setting** - Show only album artists option
- **Add to Library from Search** - Direct add from search results
- **Event-Driven Library Sync** - Automatic updates when MA changes
- **Podcast Action Buttons** - Quick actions for episodes

#### v2.8.0-beta
- **Podcast Support** - Full podcast browsing, episodes, high-res artwork
- **Radio Support** - Radio stations in library, global search
- **Library Redesign** - Media type selector, letter scrollbar, improved filters
- **Search Improvements** - Colored type pills, better scoring
- **Mini Player** - Power button, improved layout

#### v2.7.4-beta
- **3-line Mini Player** - Shows track, artist, and player name
- **Volume Swipe Controls** - Swipe on mini player to adjust volume
- **Better Cast+Sendspin Sync** - Fixed sync for dual-capability devices
- **Yellow Border Indicator** - Shows manually synced players

---

## Missing Features (This Fork vs Upstream)

### Major Missing Features
1. **Podcast Support** (v2.8.0) - Complete podcast functionality
2. **Radio Support** (v2.8.0) - Radio stations in library and search
3. **Volume Swipe Controls** (v2.7.4) - Quick volume adjustment
4. **Queue Panel Redesign** (v2.8.5-v2.8.7) - Swipe to delete, tap to skip, clear queue
5. **Library Screen Redesign** (v2.8.6) - Unified media type selector
6. **Volume Control Redesign** (v2.8.6) - New +/- buttons with precision mode
7. **Search Scoring Overhaul** (v2.8.4) - Fuzzy matching, stopword removal
8. **Player Filter Sync** (v2.8.1) - Respects MA user profile
9. **Add to Library from Search** (v2.8.1) - Direct add functionality
10. **Playlist Favorites** (v2.8.7) - Favorite button for playlists

### Bug Fixes Missing
- Material You black screen fix (#37)
- Tailscale authentication fix (#38)
- Favorite artists startup fix (#41)
- Queue reliability improvements (#30)
- Podcast player display fixes
- Mini player text alignment
- And many more stability improvements

### Performance & Polish Missing
- Hero-like curved path animations (60-120fps)
- Event-driven library sync
- Better cache management
- Instant UI updates for favorites
- Letter scrollbar for long lists
- Colored type pills in search
- And many UX improvements

---

## Architectural Insights

### Remote Access Challenge

The fork attempted to implement remote access for audio playback, which proved architecturally challenging:

**Problem:**
- Music Assistant's Sendspin protocol requires a **direct WebSocket connection** for audio streaming
- WebRTC Remote Access only provides a **data channel** for MA API
- Cannot establish Sendspin WebSocket through WebRTC data channel
- Result: Device registers but shows as "unavailable" (greyed out) in MA

**Why Desktop Companion Works:**
- Desktop companion = **remote control only** (no audio playback)
- Only needs MA API through WebRTC
- Doesn't need to register as a player device

**Why Mobile App Fails:**
- Mobile app = **actual player device** (audio playback)
- Needs both MA API (✓ works) AND Sendspin WebSocket (✗ fails)
- Cannot play audio without Sendspin connection

### Recommended Solution

**Upstream Approach (No Remote Access):**
- No WebRTC complexity
- Users can use **Cloudflared tunnel** for remote access
- Cloudflared provides real URL that works with Sendspin
- All features functional, no architectural limitations

**This is the proven, stable approach.**

---

## Recommendation

### Option 1: Align with Upstream (Recommended) ✅

**Remove non-functional remote access code and catch up with upstream improvements:**

1. **Remove WebRTC Implementation**
   - Delete `lib/services/remote/` directory
   - Delete `lib/screens/remote/` directory
   - Remove `flutter_webrtc` and `mobile_scanner` dependencies
   - Remove remote access references from codebase

2. **Update Documentation**
   - Document Cloudflared as recommended remote access method
   - Keep research docs for historical reference
   - Update README to align with upstream

3. **Clean State for Future Improvements**
   - Allows cherry-picking upstream improvements
   - Maintains compatibility with upstream
   - Can merge/rebase upstream changes easily

**Pros:**
- Proven, stable architecture
- Can benefit from upstream improvements
- No non-functional code
- Clear path forward

**Cons:**
- Loses experimental work (but it didn't work anyway)
- Remote access requires external tool (Cloudflared)

### Option 2: Continue Remote Access Development ⚠️

**Attempt to fix WebRTC remote access:**

1. Implement WebSocket proxy over WebRTC data channel
2. Or implement builtin_player API fallback
3. Extensive testing and debugging
4. May still not work due to protocol limitations

**Pros:**
- Could eventually provide native remote access
- Interesting technical challenge

**Cons:**
- Significant development effort
- May be architecturally impossible with current MA server
- Falls behind on all other improvements
- No guarantee of success
- Maintenance burden

---

## Conclusion

The fork halted progress at v2.7.3-beta while attempting non-functional WebRTC remote access. The upstream progressed to v2.8.7-beta with substantial improvements, new features, and bug fixes.

**Recommended Path Forward:**
1. Remove non-functional remote access code
2. Document Cloudflared as remote access solution
3. Align with upstream architecture
4. Provides clean slate for future improvements

This brings the fork back to a stable, maintainable state aligned with the proven upstream approach while preserving research learnings in documentation.
