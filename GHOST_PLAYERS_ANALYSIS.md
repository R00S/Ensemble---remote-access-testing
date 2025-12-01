# Ghost Players Analysis & Fixes

## Overview

This document captures the deep analysis and fixes applied to solve the "ghost player" problem in the Ensemble app - where multiple duplicate player entries accumulate in Music Assistant.

## The Problem

When using the app, ghost players (unavailable duplicate entries like "Chris' Phone") kept accumulating in Music Assistant. The player list would show:
- Chris' Phone (ensemble_xxx) - Available: false
- Chris' Phone (ensemble_yyy) - Available: false
- Chris' Phone (ensemble_zzz) - Available: false
- Chris' Phone (ensemble_current) - Available: true

New ghost players were created on each app launch/reconnect.

---

## Root Cause #1: Legacy ID Check Triggering New UUID Generation

**Location**: `lib/services/music_assistant_api.dart`, line 85

**The Bug**:
```dart
// OLD CODE - BROKEN
if (clientId == null || await DeviceIdService.isUsingLegacyId()) {
    clientId = await DeviceIdService.migrateToDeviceId();
}
```

Even when a valid `clientId` existed, the `isUsingLegacyId()` check could return `true` and trigger migration, which generated a **brand new UUID** every time.

**The Fix**:
```dart
// NEW CODE - FIXED
if (clientId == null) {
    clientId = await DeviceIdService.migrateToDeviceId();
}
```

Only generate a new ID if `clientId` is truly `null`.

**Commit**: `6320bb6` - "fix: prevent ghost player accumulation - ROOT CAUSE FIX"

---

## Root Cause #2: Not Reusing Existing builtin_player_id

**Location**: `lib/services/device_id_service.dart`, `getOrCreateDevicePlayerId()`

**The Bug**:
The function checked `local_player_id` first, but if that was null, it would generate a NEW ID even if `builtin_player_id` already contained a valid `ensemble_*` ID.

```dart
// OLD CODE - BROKEN
final existingId = prefs.getString(_keyLocalPlayerId);
if (existingId != null && existingId.startsWith('ensemble_')) {
    return existingId;
}
// Would fall through and generate NEW UUID even if builtin_player_id existed!
```

**The Fix**:
```dart
// NEW CODE - FIXED
// Check local_player_id first
final existingId = prefs.getString(_keyLocalPlayerId);
if (existingId != null && existingId.startsWith('ensemble_')) {
    return existingId;
}

// Check builtin_player_id (may exist without local_player_id)
final legacyBuiltinId = prefs.getString(_legacyKeyBuiltinPlayerId);
if (legacyBuiltinId != null && legacyBuiltinId.startsWith('ensemble_')) {
    // Reuse it and sync to local_player_id
    await prefs.setString(_keyLocalPlayerId, legacyBuiltinId);
    return legacyBuiltinId;
}

// Only generate new ID if we truly have nothing
```

**Commit**: `2fca436` - "fix: reuse existing builtin_player_id instead of generating new one"

---

## Root Cause #3: No Connection Guard

**Location**: `lib/services/music_assistant_api.dart`, `connect()`

**The Bug**:
Multiple simultaneous connection attempts could each generate new IDs.

**The Fix**:
Added a `Completer<void>? _connectionInProgress` guard so concurrent callers wait for the same connection instead of starting new ones.

```dart
if (_connectionInProgress != null) {
    return _connectionInProgress!.future;
}
_connectionInProgress = Completer<void>();
```

**Commit**: `6320bb6` - "fix: prevent ghost player accumulation - ROOT CAUSE FIX"

---

## Why Ghost Players Can't Be Deleted

### Key Finding: Builtin Players Have No Persistent Config

Music Assistant's `builtin_player` provider is **session-based**. Players only exist in memory while connected - they have no persistent configuration file.

**API Behavior**:
- `players/remove` - Removes from runtime player manager, but player reappears if client reconnects
- `builtin_player/unregister` - Disconnects the player session
- `config/players/remove` - Returns error "Player configuration does not exist" for builtin players

**From MA Documentation**:
> "Deleted players which become or are still available will get rediscovered and will return to the list on MA restart or player provider reload."

### Cleanup Attempts That Don't Work Permanently

We tried multiple approaches:
1. `players/remove` - Server returns success but players persist
2. `builtin_player/unregister` - Only disconnects, doesn't delete
3. `config/players/remove` - Fails because no config exists for builtin players

**Conclusion**: Ghost players from `builtin_player` provider can only be "unregistered" temporarily. The only permanent solution is **not creating new ghosts in the first place**.

---

## Storage Keys Used

| Key | Purpose | Service |
|-----|---------|---------|
| `local_player_id` | Primary player ID storage | DeviceIdService |
| `builtin_player_id` | Legacy/compatibility key | SettingsService |
| `device_player_id` | Old legacy key (deprecated) | DeviceIdService |

Both `local_player_id` and `builtin_player_id` should contain the same value after fixes are applied.

---

## ID Format Evolution

1. **Original**: `massiv_<hardware_hash>` - Based on device fingerprint (caused same ID on same-model phones)
2. **Current**: `ensemble_<uuid>` - Random UUID per installation (unique per app install)

---

## Commits in Chronological Order

1. `c772555` - "fix: use UUID for unique player identification per installation"
2. `468f815` - "Auto-cleanup ghost players on connect using builtin_player/unregister"
3. `1711132` - "Hide unavailable ghost players from player selector"
4. `6b47f40` - "Add ghost player prevention and cleanup"
5. `d262707` - "Add deep ghost player cleanup using config API"
6. `c1f52d5` - "fix: detect ghost players by ensemble_ prefix, not just builtin_player provider"
7. `da3750b` - "fix: use player list instead of config API for ghost detection"
8. `6320bb6` - "fix: prevent ghost player accumulation - ROOT CAUSE FIX"
9. `2fca436` - "fix: reuse existing builtin_player_id instead of generating new one"

---

## Current State (After Fixes)

### What's Fixed
- ✅ New player IDs no longer generated on each reconnect
- ✅ Existing `builtin_player_id` is reused if `local_player_id` is missing
- ✅ Connection guard prevents duplicate ID generation from concurrent connects
- ✅ Unavailable ghost players are hidden from the player selector UI

### What's Not Possible
- ❌ Permanently deleting existing ghost players from MA server (by design)
- ❌ Config-level removal (builtin players have no config)

### Existing Ghosts
Old ghost players will remain on the MA server but:
- They're hidden from the app's player selector (filtered by `available` status)
- They may disappear after MA server restart
- They don't affect functionality

---

## Testing Checklist

- [ ] Fresh install generates ONE player ID and reuses it across app restarts
- [ ] Killing and reopening app doesn't create new ghost
- [ ] Network disconnect/reconnect doesn't create new ghost
- [ ] Check logs for "Using existing" vs "Generated new" messages
- [ ] Player list shows only available players (ghosts hidden)

---

## Related Issue: Cross-Device Playback

A separate but related issue was that playing on one phone would trigger playback on another phone.

**Root Cause**: App processed ALL `builtin_player` events without checking if the event was for its own player.

**Fix**: Filter events by `player_id` in `_handleLocalPlayerEvent()`:
```dart
if (eventPlayerId != null && myPlayerId != null && eventPlayerId != myPlayerId) {
    _logger.log('🚫 Ignoring event for different player');
    return;
}
```

**Commit**: `6e73011` - "fix: filter builtin_player events by player_id to prevent cross-device playback"

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/services/device_id_service.dart` | UUID generation, reuse existing IDs |
| `lib/services/music_assistant_api.dart` | Connection guard, removed legacy ID check, event enrichment |
| `lib/providers/music_assistant_provider.dart` | Ghost filtering, event player_id filtering |
| `lib/services/settings_service.dart` | Owner name storage |
| `lib/screens/login_screen.dart` | "Your Name" field |
| `lib/screens/settings_screen.dart` | Ghost cleanup UI (limited effectiveness) |
