# Search Improvements

Branch: `feature/search-improvements`

## Completed

- [x] Add playlists and audiobooks to search results
  - Parse from MA API response
  - Filter chips for each type
  - Tile builders with navigation to detail screens

- [x] Unified Relevance-Based "All" Results
  - Scoring algorithm implemented:
    - Exact match: 100 points
    - Starts with query: 80 points
    - Contains query (word boundary): 60 points
    - Contains query (anywhere): 40 points
    - Fuzzy match: 20 points
    - Bonus for library items (albums): +10 points
    - Bonus for favorites: +5 points
    - Secondary field matching (artist name in albums/tracks)
  - Merged all results into single sorted list
  - Type indicators in subtitle (e.g., "Artist • Album")

- [x] Smart Cross-Referencing
  - Extracts unique artists from matched tracks/albums
  - Filters to artists whose name contains query words (min 3 chars)
  - Adds cross-referenced artists with lower relevance score (25)
  - Avoids duplicates with direct search results

- [x] Past Searches Row
  - Added SearchHistory table to database (schema v4)
  - Saves successful searches (deduplicated, max 10)
  - Displays as ActionChips in empty state
  - Clicking chip performs that search

## Remaining Ideas (Lower Priority)

- **Library-only toggle:** Add switch to filter search to library items only (MA API supports this)
- **Voice search:** Add microphone button if platform supports speech recognition
- **Search suggestions:** Typeahead from library as user types
- **Quick actions:** Long-press result for play/queue options without navigating
- **Clear history in settings:** Add option to clear search history

## Files Modified

| File | Changes |
|------|---------|
| `lib/database/database.dart` | Added SearchHistory table, schema v4 |
| `lib/services/database_service.dart` | Added search history methods |
| `lib/screens/search_screen.dart` | Relevance scoring, cross-refs, history UI |
| `lib/l10n/app_en.arb` | Added localization strings |
