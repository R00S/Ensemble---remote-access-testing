# Audiobooks Integration - Implementation Plan

## Overview

Add audiobook support to Ensemble with automatic user profile separation based on Music Assistant authentication. Includes local database for performance caching and per-user data isolation.

---

## Phase 1: Database Foundation

**Goal:** Add persistent local storage layer using Drift (SQLite)

### Tasks
- [ ] Add Drift package dependencies (`drift`, `drift_flutter`, `path_provider`)
- [ ] Create database class with schema version management
- [ ] Create `profiles` table:
  ```dart
  class Profiles extends Table {
    TextColumn get username => text()();  // MA username (primary key)
    TextColumn get displayName => text().nullable()();
    TextColumn get source => text()();  // 'ma_auth' or 'manual'
    DateTimeColumn get createdAt => dateTime()();
    BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  }
  ```
- [ ] Create `recently_played` table:
  ```dart
  class RecentlyPlayed extends Table {
    IntColumn get id => integer().autoIncrement()();
    TextColumn get profileUsername => text().references(Profiles, #username)();
    TextColumn get mediaId => text()();
    TextColumn get mediaType => text()();  // 'track', 'album', 'artist', 'audiobook'
    TextColumn get name => text()();
    TextColumn get artist => text().nullable()();
    TextColumn get imageUrl => text().nullable()();
    DateTimeColumn get playedAt => dateTime()();
  }
  ```
- [ ] Create `library_cache` table for albums/artists/audiobooks
- [ ] Generate Drift code (`dart run build_runner build`)
- [ ] Create `DatabaseService` singleton with initialization

### Acceptance Criteria
- Database initializes on app startup
- Schema migrations work correctly
- CRUD operations functional for all tables

---

## Phase 2: Profile System

**Goal:** Auto-create and manage user profiles based on MA authentication

### Tasks
- [ ] Create `ProfileService` class
- [ ] On MA login success: check if profile exists for username
  - If not, create new profile with `displayName` from MA user info
  - Set as active profile
- [ ] On manual name entry (no-auth): create/select profile by entered name
- [ ] Add `getCurrentProfile()` method
- [ ] Migrate existing `ownerName` to profile on first launch post-update
- [ ] Add profile indicator to settings screen (show current profile name)

### Acceptance Criteria
- Profile auto-created on first login
- Correct profile selected on subsequent logins
- Existing users migrated seamlessly

---

## Phase 3: Recently Played Migration

**Goal:** Move recently played from memory cache to database, scoped by profile

### Tasks
- [ ] Update `CacheService` to use database for recently played
- [ ] Scope all recently played queries by `profileUsername`
- [ ] Update home screen to load recently played from database
- [ ] Add `addRecentlyPlayed()` method that records profile + media info
- [ ] Limit recently played to last 50 items per profile
- [ ] Remove old memory-based recently played logic

### Acceptance Criteria
- Recently played persists across app restarts
- Each profile sees only their own recently played
- No cross-contamination between profiles

---

## Phase 4: Library Caching

**Goal:** Cache library data locally for instant UI and reduced API calls

### Tasks
- [ ] Create `SyncService` for background library synchronization
- [ ] On app launch: load from cache immediately, sync in background
- [ ] Store albums, artists in `library_cache` table
- [ ] Add `lastSynced` timestamp to track freshness
- [ ] Implement delta sync (only fetch changed items if MA supports it)
- [ ] Add pull-to-refresh that forces full sync
- [ ] Show subtle sync indicator when background sync in progress

### Acceptance Criteria
- Home screen loads instantly from cache
- Library tabs load instantly
- Background sync updates data without blocking UI
- Stale data refreshed within reasonable timeframe

---

## Phase 5: Scrollable Library Tabs

**Goal:** Make library tab row scrollable to accommodate more tabs

### Tasks
- [ ] Convert `TabBar` to scrollable variant (`isScrollable: true`)
- [ ] Adjust tab styling for scrollable layout
- [ ] Ensure indicator line spans correctly
- [ ] Test with varying number of tabs
- [ ] Add "Books" tab placeholder (disabled until Phase 6)

### Acceptance Criteria
- Tabs scroll horizontally when they exceed screen width
- Current tab indicator works correctly
- Smooth scrolling experience

---

## Phase 6: Audiobooks Tab - Browse by Author

**Goal:** Add Books tab with author → books hierarchy

### Tasks
- [ ] Add MA API method to fetch audiobooks: `getAudiobooks()`
- [ ] Add MA API method to fetch audiobook authors
- [ ] Create `AudiobookAuthor` model
- [ ] Create `Audiobook` model with fields:
  - `id`, `name`, `authors`, `narrators`, `description`
  - `duration`, `imageUrl`, `chapters`, `resumePosition`, `fullyPlayed`
- [ ] Create `BooksScreen` with author list view
- [ ] Tapping author expands to show their books
- [ ] Add to library tab bar
- [ ] Cache audiobooks in local database

### Acceptance Criteria
- Books tab shows list of authors
- Authors expandable to show their audiobooks
- Audiobook covers and titles display correctly
- Data cached locally for fast subsequent loads

---

## Phase 7: Audiobook Detail Screen

**Goal:** Full audiobook detail view with metadata and chapters

### Tasks
- [ ] Create `AudiobookDetailScreen`
- [ ] Display: cover art, title, author(s), narrator(s)
- [ ] Display: description (expandable if long)
- [ ] Display: total duration, progress indicator
- [ ] Chapter list with:
  - Chapter title
  - Duration
  - Played indicator (based on resume position)
- [ ] Tapping chapter starts playback from that chapter
- [ ] "Resume" button that continues from `resume_position_ms`
- [ ] "Start Over" option

### Acceptance Criteria
- All metadata displays correctly
- Chapters show with accurate durations
- Resume position reflected in UI
- Can start playback from any chapter

---

## Phase 8: Audiobook Playback Integration

**Goal:** Proper audiobook playback with seek and resume

### Tasks
- [ ] Implement `playAudiobook(bookId, startPosition?)` method
- [ ] Use `queueCommandSeek()` to resume at correct position
- [ ] Update now playing UI to show:
  - Book title instead of track
  - Current chapter name
  - Chapter progress (not just total progress)
- [ ] Add skip forward/back buttons (30 sec for audiobooks?)
- [ ] Add chapter skip buttons (next/previous chapter)
- [ ] Record to recently played when audiobook starts (with 'audiobook' type)

### Acceptance Criteria
- Audiobooks resume from correct position
- Chapter information shows in now playing
- Skip controls work correctly
- Recently played records audiobook plays

---

## Phase 9: Polish & Edge Cases

**Goal:** Handle edge cases and improve UX

### Tasks
- [ ] Handle audiobooks with no chapters gracefully
- [ ] Handle very long audiobooks (20+ hours)
- [ ] Add "Mark as Finished" option
- [ ] Add "Mark as Unplayed" option
- [ ] Ensure offline browsing works for cached audiobooks
- [ ] Test with various audiobook lengths and chapter counts
- [ ] Performance testing with large audiobook libraries

### Acceptance Criteria
- No crashes on edge cases
- Smooth performance
- All user actions have appropriate feedback

---

## Future Enhancements (Out of Scope)

- Sleep timer
- Playback speed control
- Series support (requires MA provider update)
- Bookmarks
- Listening statistics
- Download for offline playback

---

## Technical Notes

### Database Choice: Drift
- SQLite wrapper with type-safe queries
- Good for relational data (profiles → recently_played)
- Mature, well-documented
- Supports migrations

### MA API Endpoints Used
- `music/audiobooks` - List audiobooks
- `music/audiobook/{id}` - Get audiobook details
- `player_queues/play_media` - Start playback
- `player_queues/seek` - Seek to position
- `music/in_progress_items` - Get items with resume positions

### Profile Data Flow
```
MA Login → Get user_info → Check/Create Profile → Set Active → Load Profile Data
```

### Recently Played Flow
```
Play Media → Check Active Profile → Insert RecentlyPlayed Row → Update UI
```
