# Ensemble Codebase Intensive Audit Prompt

## Overview

You are tasked with conducting an intensive, comprehensive audit of the **Ensemble** Flutter application - a Music Assistant client for Android with multi-device synchronization, local playback, and Sendspin raw audio streaming capabilities.

**Codebase Statistics:**
- 90 Dart files, ~40,583 lines of code
- 18 screens, 27 services, 6 providers
- Architecture: Provider pattern with ChangeNotifier
- Audio: just_audio + flutter_pcm_sound + audio_service
- Networking: WebSocket (JSON-RPC) + HTTP + Sendspin binary protocol

---

## Audit Scope

Perform a thorough audit covering ALL of the following areas. For each issue found, provide:
1. **File path and line number(s)**
2. **Severity**: CRITICAL / HIGH / MEDIUM / LOW
3. **Description** of the issue
4. **Impact** if left unfixed
5. **Recommended fix** with code example where applicable

---

## SECTION 1: SECURITY AUDIT

### 1.1 Credential Storage (CRITICAL PRIORITY)
Audit `/lib/services/settings_service.dart` for:
- [ ] Plaintext password storage in SharedPreferences (lines 209-222)
- [ ] Auth tokens stored without encryption
- [ ] Serialized credentials in JSON format (lines 169-190)

**Expected Finding:** Credentials stored insecurely. Recommend flutter_secure_storage.

### 1.2 Certificate Validation
Audit `/lib/services/auth/auth_manager.dart` for:
- [ ] HTTPS redirect handling for local IPs
- [ ] Certificate validation disabled scenarios
- [ ] MITM vulnerability exposure

### 1.3 Authentication Strategies
Audit all files in `/lib/services/auth/`:
- [ ] `basic_auth_strategy.dart` - Base64 encoding (not encryption)
- [ ] `authelia_strategy.dart` - Session cookie handling, timing attack (line 159)
- [ ] `ma_auth_strategy.dart` - Token refresh mechanism
- [ ] `no_auth_strategy.dart` - Public server exposure

### 1.4 Input Validation
Audit `/lib/services/music_assistant_api.dart`:
- [ ] URI construction without validation (lines 1346-1360)
- [ ] Provider/itemId injection risks
- [ ] WebSocket message validation

### 1.5 Information Disclosure
- [ ] Debug logs exposing sensitive data (check all `_logger.log()` calls)
- [ ] Server version exposure via `server_info`
- [ ] Error messages leaking technical details

---

## SECTION 2: MEMORY MANAGEMENT AUDIT

### 2.1 Static Memory Leaks
Audit `/lib/models/player.dart`:
- [ ] `_playerCreationTimes` static map (lines 96-144) - grows unbounded
- [ ] Cleanup only removes 50 of 100+ entries

### 2.2 Unbounded Caches
Audit `/lib/services/cache_service.dart`:
- [ ] `_albumTracksCache` - no size limit
- [ ] `_artistAlbumsCache` - no TTL expiration
- [ ] `_searchCache` - never evicted
- [ ] `_playerTrackCache` - only cleared on disconnect

### 2.3 Stream/Timer Cleanup
Audit `/lib/providers/music_assistant_provider.dart`:
- [ ] `_playerStateTimer` disposal (line 4435-4445)
- [ ] `_notificationPositionTimer` multiple creation paths (lines 2925-2940)
- [ ] `_localPlayerEventSubscription` cleanup
- [ ] `_playerUpdatedEventSubscription` cleanup
- [ ] `_playerAddedEventSubscription` cleanup

Audit `/lib/services/hardware_volume_service.dart`:
- [ ] `_volumeUpController` never closed (lines 74-85)
- [ ] `_volumeDownController` never closed

### 2.4 Stream Subscription Leaks
Audit `/lib/providers/music_assistant_provider.dart`:
- [ ] `_api!.connectionState.listen()` - subscription not stored
- [ ] Old subscriptions not cancelled before new API instance

---

## SECTION 3: RACE CONDITION AUDIT

### 3.1 Player State Dual Updates
Audit `/lib/providers/music_assistant_provider.dart`:
- [ ] Timer polling (every 5s) vs WebSocket events racing
- [ ] `_updatePlayerState()` called from both paths
- [ ] No mutex/lock protection

### 3.2 Async Method Reentrancy
Audit `selectPlayer()` method:
- [ ] `async` method without guard against concurrent calls
- [ ] `_selectedPlayer` modified before and after `await`
- [ ] State could change during await

### 3.3 Fire-and-Forget Operations
Search for `unawaited(` and `() async {` patterns:
- [ ] `_persistPlaybackState()` - database save not awaited
- [ ] Pause operations fire-and-forget (lines 3876-3894)
- [ ] Preload operations (line 2707)

### 3.4 PCM Player State Machine
Audit `/lib/services/pcm_audio_player.dart`:
- [ ] 9-state machine with complex transitions (lines 32-37)
- [ ] Auto-recovery race condition (lines 215-229)
- [ ] Feed loop during pause transition (lines 174-179)

---

## SECTION 4: ERROR HANDLING AUDIT

### 4.1 Silent Exception Handlers (CRITICAL)
Find all instances of:
```dart
} catch (e) {}
} catch (_) {}
```

Known locations:
- [ ] `music_assistant_provider.dart` (multiple)
- [ ] `player_provider.dart` (3 instances)
- [ ] `recently_played_service.dart`

### 4.2 Missing Error Recovery
- [ ] No exponential backoff on connection retry
- [ ] No retry logic for failed API calls
- [ ] WebSocket timeout handling (30 seconds - too long?)

### 4.3 Null Safety Violations
Find all `!` (null assertion) operators:
- [ ] `search_screen.dart` (20+ instances)
- [ ] `models/media_item.dart`
- [ ] `models/player.dart`
- [ ] `item.mediaItem! as Artist` patterns

---

## SECTION 5: ARCHITECTURAL ISSUES

### 5.1 God Class
Audit `/lib/providers/music_assistant_provider.dart`:
- [ ] 4,469 lines - violates Single Responsibility
- [ ] 386 conditional branches
- [ ] Mixing: connection, players, library, sync, audio, position tracking

**Recommend splitting into:**
- ConnectionProvider (~500 LOC)
- PlayerManager (~800 LOC)
- LibraryProvider (~1000 LOC)
- LocalPlaybackManager (~600 LOC)

### 5.2 Oversized Widget Files
- [ ] `expandable_player.dart` - 2,485 lines (should be <500)
- [ ] `global_player_overlay.dart` - 737 lines
- [ ] `new_library_screen.dart` - 2,521 lines

### 5.3 Global Key Anti-Pattern
Audit `/lib/widgets/global_player_overlay.dart`:
- [ ] `globalPlayerKey` for state access
- [ ] `_overlayStateKey` for overlay state
- [ ] Should use Provider/context instead

### 5.4 Primitive Obsession
- [ ] View modes as strings ('grid2', 'grid3', 'list')
- [ ] Media types as strings ('track', 'album', 'artist')
- [ ] Should be strongly-typed enums

---

## SECTION 6: CODE QUALITY ISSUES

### 6.1 Testing (CRITICAL)
- [ ] **ZERO test files exist** - confirm this
- [ ] No unit tests, widget tests, or integration tests
- [ ] flutter_test dependency exists but unused

### 6.2 Hardcoded Values
Find and document all:
- [ ] Color hex codes (50+ instances of `Color(0xFF...`)
- [ ] Duration values not using `Timings` constants
- [ ] Magic numbers (16, 4, 5, 100, 50)
- [ ] String literals for media types

### 6.3 Mixed Async Patterns
- [ ] `.then()` chains alongside async/await
- [ ] `.whenComplete()` usage
- [ ] Consolidate to async/await

### 6.4 Dead Code
- [ ] `@Deprecated` methods still implemented
- [ ] `animation_debugger.dart` - dev-only?
- [ ] Unused imports

### 6.5 TODO Comments
Document all actionable TODOs:
- [ ] `queue_screen.dart:214` - queue item removal
- [ ] `audiobook_detail_screen.dart:261,312` - progress sync
- [ ] `music_assistant_provider.dart:793,799` - playlist modification

---

## SECTION 7: UI/UX AUDIT

### 7.1 Accessibility (CRITICAL)
Audit for missing:
- [ ] `Semantics` widgets on interactive elements
- [ ] `Tooltip` on icon buttons
- [ ] Screen reader support
- [ ] Touch target sizes (minimum 48dp)
- [ ] Color contrast validation (WCAG AA)

### 7.2 Performance Issues
Audit `/lib/widgets/expandable_player.dart`:
- [ ] No `RepaintBoundary` wrappers
- [ ] 55+ `setState()` calls
- [ ] 3 AnimationControllers with multiple listeners
- [ ] Title height cache invalidation (lines 118+)

### 7.3 Double Opacity Bug
Audit `/lib/widgets/player/player_controls.dart`:
```dart
color: (shuffle == true ? primaryColor : textColor.withOpacity(0.5))
    .withOpacity(expandedElementsOpacity),
```
- [ ] Double `.withOpacity()` application

### 7.4 Missing Features
- [ ] No landscape orientation support
- [ ] No tablet layout optimization
- [ ] No loading skeleton animations
- [ ] No haptic feedback (except one location)

---

## SECTION 8: AUDIO PLAYBACK AUDIT

### 8.1 Position Interpolation
Audit `/lib/services/position_tracker.dart`:
- [ ] No timeout on anchor updates - unbounded drift possible
- [ ] Duration interpolation can exceed track duration
- [ ] Stale timestamp handling (>30 seconds)

### 8.2 Sendspin Protocol
Audit `/lib/services/sendspin_service.dart`:
- [ ] Proxy auth retry without deduplication (lines 188-209)
- [ ] WebSocket binary frame parsing
- [ ] Clock synchronization accuracy

### 8.3 Audio Resource Cleanup
Audit `/lib/services/audio/massiv_audio_handler.dart`:
- [ ] Audio session interrupt listeners not disposed
- [ ] Audio focus not explicitly released

### 8.4 Mixed Playback Modes
- [ ] just_audio initialized but unused during Sendspin
- [ ] Resource allocation for unused player
- [ ] Potential audio focus conflicts

---

## SECTION 9: NETWORKING AUDIT

### 9.1 WebSocket Lifecycle
Audit `/lib/services/music_assistant_api.dart`:
- [ ] Heartbeat interval (30s) - appropriate?
- [ ] Reconnection logic and timing
- [ ] Pending request cleanup on disconnect

### 9.2 Caching Strategy
- [ ] No incremental/delta sync (full library every 5 minutes)
- [ ] Cache staleness not communicated to UI
- [ ] No query result pagination (fetches up to 5000 items)

### 9.3 Rate Limiting
- [ ] No client-side rate limiting
- [ ] Search requests not throttled
- [ ] Could overload server

### 9.4 Offline Support
Audit `/lib/services/offline_action_queue.dart`:
- [ ] Queue execution not atomic (lines 118-130)
- [ ] Action could execute twice on crash
- [ ] Queue stored unencrypted

---

## SECTION 10: DATABASE AUDIT

### 10.1 Schema Review
Audit `/lib/database/database.dart`:
- [ ] Table indexes for query performance
- [ ] Foreign key constraints
- [ ] Migration strategy

### 10.2 Query Patterns
- [ ] N+1 query prevention
- [ ] Transaction usage for atomic operations
- [ ] Connection pooling

### 10.3 Data Consistency
- [ ] Tier 1 (DB) vs Tier 2 (API sync) race conditions
- [ ] User modifications during background sync
- [ ] Conflict resolution strategy

---

## Deliverables

After completing the audit, provide:

### 1. Executive Summary
- Overall code quality score (1-10)
- Top 5 critical issues requiring immediate attention
- Estimated technical debt in developer-hours

### 2. Issue Tracker
Create a prioritized list of all issues found:
| ID | Severity | Category | File:Line | Description | Effort |
|----|----------|----------|-----------|-------------|--------|

### 3. Recommended Roadmap
Sprint-based plan to address findings:
- Sprint 1 (Immediate): Security fixes, silent exception handlers
- Sprint 2-3: God class decomposition, test infrastructure
- Sprint 4-6: Memory leak fixes, accessibility
- Long-term: Performance optimization, monitoring

### 4. Code Examples
For each CRITICAL and HIGH severity issue, provide:
- Current problematic code
- Recommended refactored code
- Migration steps

---

## Files to Prioritize

Start your audit with these critical files:

1. `/lib/providers/music_assistant_provider.dart` (4,469 LOC) - God class
2. `/lib/services/settings_service.dart` - Credential storage
3. `/lib/services/music_assistant_api.dart` (2,929 LOC) - Networking
4. `/lib/widgets/expandable_player.dart` (2,485 LOC) - UI complexity
5. `/lib/services/auth/` directory - Security
6. `/lib/models/player.dart` - Memory leaks
7. `/lib/services/cache_service.dart` - Unbounded caches
8. `/lib/services/position_tracker.dart` - Audio sync issues

---

## Known Critical Issues (Pre-Identified)

These issues have been identified and MUST be verified and documented:

1. **CRITICAL: Plaintext credential storage** - SharedPreferences without encryption
2. **CRITICAL: Zero test coverage** - No unit, widget, or integration tests
3. **CRITICAL: 4,469 line god class** - MusicAssistantProvider violates SRP
4. **CRITICAL: Silent exception handlers** - `catch (e) {}` patterns
5. **HIGH: Static memory leak** - `_playerCreationTimes` unbounded growth
6. **HIGH: Race conditions** - Player state polling vs events
7. **HIGH: No accessibility** - Missing Semantics, screen reader support
8. **HIGH: Certificate validation disabled** - MITM vulnerability for local IPs
9. **MEDIUM: Double opacity bug** - `.withOpacity().withOpacity()` in player controls
10. **MEDIUM: Position tracker drift** - No timeout on anchor updates

---

## Audit Execution Notes

- Use `Grep` tool to search for patterns across the codebase
- Use `Read` tool to examine specific file sections
- Document line numbers for all findings
- Provide code snippets for context
- Cross-reference related issues across files
- Verify pre-identified issues exist and document their exact locations

**Total estimated audit time: 4-6 hours for thorough coverage**
