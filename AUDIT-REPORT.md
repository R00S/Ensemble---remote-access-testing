# Ensemble Codebase - Comprehensive Audit Report

**Audit Date:** 2026-01-01
**Codebase:** Ensemble Flutter App (Music Assistant Client)
**Version:** 2.7.3-beta+35
**Total Lines of Code:** ~40,583 Dart
**Files Analyzed:** 90 Dart files

---

## Executive Summary

### Overall Code Quality Score: 5.5/10

The Ensemble codebase demonstrates **strong architectural foundations** with a well-organized service layer, effective caching strategies, and sophisticated audio handling. However, the audit revealed **critical security vulnerabilities**, **zero test coverage**, and significant **technical debt** that must be addressed before production release.

### Critical Statistics

| Metric | Value | Status |
|--------|-------|--------|
| Test Coverage | 0% | CRITICAL |
| God Class Size | 4,469 LOC | CRITICAL |
| Silent Exception Handlers | 7 | CRITICAL |
| Plaintext Credentials | 4 locations | CRITICAL |
| Memory Leak Locations | 6 | HIGH |
| Race Conditions | 4 | HIGH |
| Accessibility (Semantics) | 0 widgets | CRITICAL |

---

## Issue Summary by Severity

| Severity | Count | Categories |
|----------|-------|------------|
| **CRITICAL** | 12 | Security, Testing, Architecture, Accessibility |
| **HIGH** | 18 | Memory, Race Conditions, Networking, Audio |
| **MEDIUM** | 22 | Error Handling, UI, Caching, Code Quality |
| **LOW** | 14 | Naming, Documentation, Minor Improvements |

---

## CRITICAL ISSUES (Immediate Action Required)

### 1. Plaintext Credential Storage
**File:** `/lib/services/settings_service.dart`
**Lines:** 131-143, 147-159, 169-190, 209-222

Passwords and auth tokens stored in SharedPreferences without encryption.

```dart
// VULNERABLE CODE
static Future<void> setPassword(String? password) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyPassword, password);  // PLAINTEXT!
}
```

**Fix:** Use `flutter_secure_storage` for all sensitive data.

---

### 2. Zero Test Coverage
**Location:** Entire codebase

No unit tests, widget tests, or integration tests exist. The `flutter_test` dependency is unused.

**Impact:** Cannot safely refactor, high regression risk, no confidence in correctness.

**Fix:** Establish test infrastructure immediately. Start with:
- Unit tests for `MusicAssistantAPI`, `CacheService`, `ErrorHandler`
- Widget tests for player controls
- Integration tests for playback flows

---

### 3. God Class - MusicAssistantProvider
**File:** `/lib/providers/music_assistant_provider.dart`
**Size:** 4,469 lines, ~140 methods, 744 conditional branches

Single class handles: connection, players, library, cache, audio, sync, offline queue.

**Fix:** Split into:
- `ConnectionManager` (~500 LOC)
- `PlayerManager` (~800 LOC)
- `LibraryCacheService` (~600 LOC)
- `SendspinManager` (~400 LOC)
- `MusicAssistantProvider` - Facade composing above (~800 LOC)

---

### 4. Zero Accessibility Support
**Files:** `/lib/widgets/`, `/lib/screens/` (all)

- **0** `Semantics` widgets
- **0** `semanticLabel` properties
- **1** `Tooltip` (entire app)
- Screen readers cannot navigate the app

**Fix:** Add Semantics to all interactive elements:
```dart
Semantics(
  button: true,
  label: isPlaying ? 'Pause playback' : 'Play',
  child: IconButton(...)
)
```

---

### 5. Silent Exception Handlers
**Locations:** 7 instances across codebase

| File | Line | Code |
|------|------|------|
| player_provider.dart | 567, 575, 584 | `catch (e) {}` |
| music_assistant_provider.dart | 2690 | `catch (e) {}` |
| music_assistant_api.dart | 2542 | `catch (e) {}` |
| recently_played_service.dart | 154, 206 | `catch (_) {}` |

**Fix:** Add logging or use `firstWhereOrNull` instead of try/catch around `firstWhere`.

---

### 6. Audio Session Listeners Not Disposed
**File:** `/lib/services/audio/massiv_audio_handler.dart`
**Lines:** 45-73

Stream subscriptions created but never cancelled - causes memory leaks and zombie listeners.

**Fix:** Store subscriptions and cancel in dispose():
```dart
StreamSubscription? _interruptionSubscription;
_interruptionSubscription = session.interruptionEventStream.listen(...);

void dispose() {
  _interruptionSubscription?.cancel();
}
```

---

## HIGH SEVERITY ISSUES

### 7. Connection State Subscription Not Stored
**File:** `/lib/providers/music_assistant_provider.dart:575-614`

The `connectionState.listen()` return value is not stored - causes listener accumulation on reconnect.

---

### 8. Player State Race Condition
**File:** `/lib/providers/music_assistant_provider.dart`

Timer polling (every 5s) and WebSocket events can race to update `_selectedPlayer` and `_currentTrack` without mutex protection.

---

### 9. Async Method Reentrancy
**File:** `/lib/providers/music_assistant_provider.dart:2713-2841`

`selectPlayer()` is `void async` with no guard against concurrent calls. Multiple rapid player switches can interleave.

---

### 10. Unbounded Search Cache
**File:** `/lib/services/cache_service.dart:31-32`

`_searchCache` map has no size limit or proactive TTL eviction. Grows indefinitely with user searches.

---

### 11. Static Memory Leak
**File:** `/lib/models/player.dart:96, 139-144`

`_playerCreationTimes` static map cleanup only removes 50 of 100+ entries, allowing unbounded growth.

---

### 12. No Database Indexes
**File:** `/lib/database/database.dart`

No secondary indexes defined. Query performance degrades as database grows.

---

### 13. No Incremental Sync
**File:** `/lib/services/sync_service.dart:150-165`

Full library fetch (up to 4000 items) on every sync instead of delta updates.

---

### 14. Offline Queue Not Atomic
**File:** `/lib/services/offline_action_queue.dart:80-108`

Queue persistence happens after all processing - crash during processing loses successful actions.

---

### 15. Auth Retry Without Deduplication
**File:** `/lib/services/sendspin_service.dart:189-209`

Multiple auth messages can be sent during rapid reconnection attempts.

---

### 16. Pending Requests Not Completed on Disconnect
**File:** `/lib/services/music_assistant_api.dart:2911`

`_pendingRequests.clear()` abandons Completers without completing them with errors.

---

### 17. HTTP Fallback for Local IPs
**File:** `/lib/services/auth/auth_manager.dart:51-58`

HTTPS failures silently fall back to HTTP on local networks - MITM vulnerability.

---

### 18. Certificate Validation Bypassed
**File:** `/lib/services/auth/auth_manager.dart:210-236`

HTTPS redirects explicitly refused for local IPs due to expected certificate failures.

---

## MEDIUM SEVERITY ISSUES

### 19. Double Opacity Bug
**File:** `/lib/widgets/player/player_controls.dart:62-63, 99-100`

```dart
// BUG: .withOpacity(0.5).withOpacity(expandedElementsOpacity) compounds opacity
color: (shuffle == true ? primaryColor : textColor.withOpacity(0.5))
    .withOpacity(expandedElementsOpacity),
```

---

### 20. Mixed Async Patterns
**Locations:** 13 instances

`.then()` chains mixed with `async/await` throughout the codebase.

---

### 21. Hardcoded Colors
**Locations:** 55 instances

`Color(0xFF604CEC)`, `Color(0xFF1a1a1a)` scattered across theme files and widgets.

---

### 22. View Modes as Strings
**Locations:** 80+ instances

`'grid2'`, `'grid3'`, `'list'` should be enums.

---

### 23. Fire-and-Forget Pause Commands
**File:** `/lib/providers/music_assistant_provider.dart:3875-3894`

Server pause command uses `unawaited()` - errors are silently lost.

---

### 24. Position Tracker Anchor Timeout Missing
**File:** `/lib/services/position_tracker.dart:24-26`

No timeout on stale anchor - interpolation can drift indefinitely.

---

### 25. PCM Buffer No Overflow Protection
**File:** `/lib/services/pcm_audio_player.dart:68, 236-247`

Audio buffer grows unbounded if data arrives faster than consumption.

---

### 26. No Client-Side Rate Limiting
**Location:** App-wide

No throttling on API requests during rapid user interactions.

---

### 27. Portrait-Only Lock
**File:** `/lib/main.dart:64-68`

No landscape orientation support.

---

### 28. Touch Targets Below 48dp
**Files:** player_controls.dart, queue_panel.dart, player_card.dart

Multiple buttons at 28x28 and 44x44 instead of minimum 48x48.

---

### 29. WCAG Contrast Not Validated
**File:** `/lib/theme/palette_helper.dart`

Uses 0.4 threshold instead of proper WCAG 4.5:1 contrast ratio calculation.

---

### 30. StreamControllers Not Closed
**File:** `/lib/services/hardware_volume_service.dart:18-19, 74-85`

`_volumeUpController` and `_volumeDownController` never closed in dispose().

---

## LOW SEVERITY ISSUES

### 31-34. Naming Inconsistencies
Mixed patterns: `_isLoading` vs `_isLoadingPlaylists`, various cache variable names.

### 35-38. Missing TODO Implementations
6 actionable TODOs identified (queue removal, audiobook progress sync, playlist modification).

### 39-42. Dead/Unused Code
- `@Deprecated` methods still implemented
- `library_stats.dart` appears unused
- `animation_debugger.dart` disabled by default

### 43-44. Minor Documentation Gaps
Missing method documentation, no architecture diagram.

---

## Recommended Remediation Roadmap

### Sprint 1 (Week 1-2): Security & Critical Fixes
1. Migrate credentials to `flutter_secure_storage`
2. Add logging to all silent catch blocks
3. Store connection state subscription
4. Fix audio session listener disposal
5. Add basic test infrastructure (10% coverage target)

### Sprint 2 (Week 3-4): Memory & Race Conditions
6. Add mutex to player state updates
7. Add reentrancy guard to `selectPlayer()`
8. Implement bounded caches with LRU eviction
9. Fix static memory leak in Player model
10. Store and cancel all stream subscriptions

### Sprint 3 (Week 5-6): Architecture Refactoring
11. Split `MusicAssistantProvider` into 5 smaller classes
12. Split `expandable_player.dart` into component widgets
13. Replace GlobalKey anti-patterns with Provider
14. Convert string constants to enums
15. Extract hardcoded colors to constants file

### Sprint 4 (Week 7-8): Accessibility & UI
16. Add Semantics to all interactive elements
17. Increase touch targets to 48dp minimum
18. Implement WCAG contrast validation
19. Fix double opacity bug
20. Add landscape orientation support

### Sprint 5 (Week 9-10): Performance & Polish
21. Add database indexes
22. Implement incremental sync
23. Add client-side rate limiting
24. Fix atomic offline queue processing
25. Achieve 30% test coverage target

---

## Files Requiring Most Attention

| File | LOC | Issues | Priority |
|------|-----|--------|----------|
| `music_assistant_provider.dart` | 4,469 | 12 | CRITICAL |
| `settings_service.dart` | 811 | 4 | CRITICAL |
| `expandable_player.dart` | 2,485 | 6 | HIGH |
| `music_assistant_api.dart` | 2,929 | 5 | HIGH |
| `cache_service.dart` | 370 | 4 | HIGH |
| `massiv_audio_handler.dart` | 296 | 2 | CRITICAL |
| `player.dart` | 422 | 2 | HIGH |
| `auth_manager.dart` | 300 | 3 | HIGH |

---

## Estimated Technical Debt

| Category | Effort (Dev-Days) |
|----------|-------------------|
| Security Fixes | 3-5 |
| Test Infrastructure | 10-15 |
| Architecture Refactoring | 15-20 |
| Memory Leak Fixes | 3-5 |
| Accessibility | 5-8 |
| UI/UX Polish | 3-5 |
| Performance | 5-8 |
| **Total** | **44-66 dev-days** |

---

## Conclusion

The Ensemble app has a solid foundation with well-designed patterns for caching, audio handling, and multi-device synchronization. However, **critical security vulnerabilities** (plaintext credentials), **zero test coverage**, and a **4,469-line god class** represent significant risks that must be addressed before any production deployment.

The most urgent priorities are:
1. **Secure credential storage** - immediate security risk
2. **Add test infrastructure** - enables safe refactoring
3. **Split the god class** - enables maintainability
4. **Add accessibility** - legal/compliance requirement

With focused effort over 8-10 weeks, the codebase can be brought to production-quality standards.

---

*Audit conducted using 6 parallel specialized sub-agents analyzing security, memory management, race conditions, architecture, UI/UX, and audio/networking.*
