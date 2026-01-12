# Repository Comparison: Fork vs Upstream

**Date:** January 12, 2026  
**Fork:** R00S/Ensemble---remote-access-testing  
**Upstream:** CollotsSpot/Ensemble

---

## Version Status

| Repository | Version | Status |
|------------|---------|--------|
| Fork | v2.7.3-beta | Remote access testing build (experimental) |
| Upstream | v2.8.7-beta+45 | Production build with recent improvements |

**Divergence:** Fork is approximately 40+ commits behind upstream

---

## Unique Features in Fork

### 1. WebRTC Remote Access (Experimental)
**Status:** ⚠️ Alpha - Not functional for audio playback

**Implementation:**
- ~320 lines of code in separate directories
- WebRTC transport layer for MA API communication
- QR code scanner for Remote Access IDs
- Dependencies: `flutter_webrtc: ^0.9.48`, `mobile_scanner: ^3.5.5`

**What Works:**
- ✅ API communication over WebRTC
- ✅ Control remote players
- ✅ Browse library remotely
- ✅ Queue management

**What Doesn't Work:**
- ❌ Local audio playback on phone over WebRTC
- ❌ Register as player device
- ❌ Sendspin audio streaming

**Root Cause:**
Sendspin requires direct WebSocket connection for PCM audio streaming. WebRTC data channels cannot efficiently proxy WebSocket connections for real-time audio.

**Recommended Solution:**
Use Cloudflare Tunnel or similar reverse proxy instead of WebRTC.

**Files Added:**
```
lib/services/remote/
  - signaling.dart
  - remote_access_manager.dart
  - transport.dart
  - websocket_bridge_transport.dart
  - webrtc_transport.dart
lib/screens/remote/
  - remote_access_login_screen.dart
  - qr_scanner_screen.dart
docs/
  - REMOTE_ACCESS.md
  - REMOTE_ACCESS_FIXES.md
  - REMOTE_ACCESS_INTEGRATION.md
  - REMOTE_ACCESS_RESEARCH.md
  - REMOTE_ACCESS_STATUS.md
  - REMOTE_ACCESS_SUMMARY.md
```

---

## Features in Upstream (Not in Fork)

### Recent Improvements (Since Fork Divergence)

#### UI/UX Enhancements
1. **Animated sliding highlight** on search filter bar
2. **Hero animations** for playlist displays across all screens
3. **Favorite podcasts row** on home screen
4. **Welcome screen** with guided onboarding
5. **Multi-room grouping** - Long-press player to sync
6. **Volume precision mode** - Hold slider for fine-grained control
7. **Power control** - Turn players on/off from mini player
8. **Swipe to delete** tracks from queue
9. **Instant drag handles** for queue reordering
10. **Letter scrollbar** for fast navigation in long lists

#### Bug Fixes
1. **Queue sync issues** fixed (issue #30)
2. **Favorite artists** not showing on startup fixed (issue #41)
3. **Podcast player** - correct podcast name and text overlap fixed
4. **Language fallback** to English fixed

#### New Features
1. **French translation** support
2. **Radio stations** with list/grid view
3. **Podcast episodes** with descriptions and publish dates
4. **High-resolution artwork** via iTunes for podcasts
5. **Skip controls** for podcast playback
6. **Long-press quick actions** on search results

#### Performance & Code Quality
1. **Material 3 compliance** - Replaced deprecated `colorScheme.background` with `colorScheme.surface`
2. **Image cache optimization** - Added `memCacheWidth`/`memCacheHeight` for scroll performance
3. **Queue animation isolation** - Prevents full player rebuilds
4. **Home screen row conformity** fixes

#### Dependencies
1. **flutter_secure_storage: ^9.2.2** - Added for secure credential storage

---

## Dependency Comparison

### Fork Only
- `flutter_webrtc: ^0.9.48` - WebRTC for remote access
- `mobile_scanner: ^3.5.5` - QR code scanning

### Upstream Only
- `flutter_secure_storage: ^9.2.2` - Secure storage for credentials

### Common Dependencies
All other dependencies are identical between fork and upstream.

---

## Commit Activity Comparison

| Repository | Recent Commits (Dec 2025 - Jan 2026) | Focus Areas |
|------------|--------------------------------------|-------------|
| Fork | 2 commits | Remote access experimentation |
| Upstream | 40+ commits | UI polish, bug fixes, features, translations |

---

## File Count Comparison

| Repository | Dart Files |
|------------|-----------|
| Fork | 97 |
| Upstream | 104 |

**Difference:** Upstream has 7 more Dart files, likely from new features (welcome screen, podcast enhancements, etc.)

---

## Documentation Comparison

### Fork Documentation (13 files)
- Extensive remote access documentation (6 files)
- Implementation plans and summaries
- License attribution
- Release notes
- SEARCH-IMPROVEMENTS.md

### Upstream Documentation (1 file)
- AUDIOBOOKS_IMPLEMENTATION_PLAN.md
- AUDIT_SUMMARY.md
- AUDIT_REPORT.md
- AUDIT_PROMPT.md

**Note:** Upstream has audit documentation showing professional code review process.

---

## Feature Parity Analysis

### Features Fork Lacks (Present in Upstream)

**High Priority:**
- Queue sync fixes (issue #30) - Important bug fix
- Favorite artists startup fix (issue #41) - Important bug fix
- Language fallback and French translation
- Material 3 API compliance (deprecated API fixes)

**Medium Priority:**
- Animated UI transitions (search filters, playlists)
- Favorite podcasts row
- Podcast player fixes
- Radio station improvements
- Welcome screen for new users
- Multi-room grouping UI
- Volume precision mode
- Power control from mini player

**Low Priority (Polish):**
- Various home screen layout tweaks
- Library type bar redesign
- Swipe gestures for media type switching
- Long-press quick actions

### Features Upstream Lacks (Present in Fork)

**Experimental:**
- WebRTC remote access (non-functional for audio playback)
- QR code scanner for Remote Access IDs
- Extensive remote access documentation

**Status:** These features are experimental and not recommended for production use due to fundamental limitations.

---

## Recommendations

### For Fork Maintainer

**Priority 1: Merge Upstream Improvements**
1. Update to v2.8.7-beta+45
2. Integrate queue sync fixes (issue #30)
3. Integrate favorite artists fix (issue #41)
4. Update deprecated Material 3 APIs
5. Add French translation support

**Priority 2: Remote Access Strategy**
1. Document Cloudflare Tunnel as recommended solution
2. Keep WebRTC implementation as reference/research
3. Update README to clearly state WebRTC limitations
4. Consider removing WebRTC code if not planning to support "remote control only" mode

**Priority 3: Feature Integration**
1. Animated UI transitions
2. Welcome screen
3. Podcast improvements
4. Multi-room grouping

### For Upstream Developer

**Information to Consider:**
1. Remote access requests can be directed to reverse proxy solutions (Cloudflare Tunnel)
2. WebRTC approach is not viable for mobile player devices due to Sendspin architecture
3. Fork's remote access research is available as reference if needed

**No Action Required:**
The fork is experimental and doesn't contain production-ready features for upstream integration.

---

## Conclusion

**Fork Status:**
- Experimental remote access implementation (non-functional for core use case)
- Behind upstream by ~40 commits
- Missing important bug fixes and features
- Good documentation of remote access research

**Upstream Status:**
- Active development with regular improvements
- Strong focus on UI polish and user experience
- Professional code quality (audit process, Material 3 compliance)
- Growing feature set (podcasts, radio, translations)

**Value Exchange:**
- Fork → Upstream: Remote access research and documentation (what doesn't work and why)
- Upstream → Fork: Bug fixes, features, UI improvements, code quality enhancements

**Recommendation:**
Fork should prioritize merging upstream improvements. Remote access feature should be documented as "not recommended" with clear guidance toward reverse proxy solutions.
