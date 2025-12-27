# Search Improvements - Remaining Work

Branch: `feature/search-improvements`

## Completed

- [x] Add playlists and audiobooks to search results
  - Parse from MA API response
  - Filter chips for each type
  - Tile builders with navigation to detail screens

## Remaining Tasks

### 1. Unified Relevance-Based "All" Results

**Current behavior:** Results grouped by type (Artists, Albums, Tracks, etc.)

**Desired behavior:** Single unified list sorted by match relevance

**Implementation:**
- Create `ScoredSearchResult` class wrapping MediaItem with relevance score
- Scoring algorithm:
  - Exact match: 100 points
  - Starts with query: 80 points
  - Contains query (word boundary): 60 points
  - Contains query (anywhere): 40 points
  - Fuzzy match: 20 points
  - Bonus for library items: +10 points
  - Bonus for favorites: +5 points

```dart
class ScoredSearchResult {
  final MediaItem item;
  final double score;
  final String? matchReason; // Optional: "Exact match", "Artist name"
}
```

- Merge all results into single list
- Sort by score descending
- Show type indicator on each tile (small icon/badge)

### 2. Smart Cross-Referencing

**Goal:** If user searches for "Yesterday Beatles", include The Beatles artist

**Implementation:**
- Extract artist names from track/album results
- Check if any extracted artist matches or partially matches query
- Add artist to results with lower score + reason tag ("Artist of matched tracks")
- Similar for albums: if track matches, consider adding its album

### 3. Past Searches Row

**Goal:** Show recent searches in empty state before user types

**Implementation:**

1. Add `SearchHistory` table to database:
```dart
class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

2. Bump schema version and add migration

3. Save search queries on successful search (dedupe, limit to 10)

4. Display in empty state:
```dart
// Before search icon, show:
Column(
  children: [
    Text('Recent Searches'),
    Wrap(
      children: recentSearches.map((q) =>
        ActionChip(label: Text(q), onPressed: () => _performSearch(q))
      ).toList(),
    ),
  ],
)
```

5. Add clear history option in settings

### 4. Additional Ideas (Lower Priority)

- **Library-only toggle:** Add switch to filter search to library items only (MA API supports this)
- **Voice search:** Add microphone button if platform supports speech recognition
- **Search suggestions:** Typeahead from library as user types
- **Quick actions:** Long-press result for play/queue options without navigating

## Files to Modify

| File | Changes |
|------|---------|
| `lib/database/database.dart` | Add SearchHistory table, bump version |
| `lib/services/database_service.dart` | Add search history methods |
| `lib/screens/search_screen.dart` | Relevance scoring, cross-refs, history UI |
| `lib/providers/music_assistant_provider.dart` | Save search history on search |

## Testing Notes

- Test with various query types: artist name, track title, partial matches
- Verify cross-referencing doesn't duplicate results
- Test search history persists across app restarts
- Verify history clears properly
