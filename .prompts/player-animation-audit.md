# Player System Animation & Polish Audit

## Context

This is a Music Assistant client app (Ensemble) built with Flutter. The player system has undergone extensive development and now needs a comprehensive polish audit. The goal is buttery smooth 60fps animations and a premium user experience.

## Architecture Overview

The player system consists of three interconnected components:

1. **Mini Player** (collapsed state) - Floating card at bottom, shows current track
2. **Expanded Player** - Full-screen player with album art, controls, progress
3. **Queue Panel** - Slides in from right of expanded player, shows playback queue

Additionally:
- **Player Selector** - Horizontal swipe between multiple players (collapsed mode)
- **Device Reveal** - Swipe down from mini player to show available players

## Key Files

```
lib/widgets/
├── expandable_player.dart      # Main player widget (1800+ lines)
├── global_player_overlay.dart  # Overlay wrapper, static accessors
├── player/
│   ├── queue_panel.dart        # Queue list with great_list_view
│   ├── chapters_panel.dart     # Audiobook chapters
│   └── mini_player_content.dart
```

## CRITICAL CONSTRAINTS

1. **DO NOT MODIFY the queue list implementation** - It uses `great_list_view` package with `AutomaticAnimatedListView`. This was chosen specifically to avoid Flutter's grey screen overlay bug (#103804). The current implementation works correctly.

2. **Preserve all existing functionality** - Focus on polish, not rewrites

3. **Test changes incrementally** - This system is complex with many interdependencies

## Audit Areas

### 1. Animation Performance Audit

Use sub-agents to analyze each animation system:

**Agent 1: Expand/Collapse Animation**
- Analyze `_controller` and `_expandAnimation`
- Check for jank during morphing transition
- Verify lerp functions are efficient
- Look for unnecessary rebuilds during animation
- Check `RepaintBoundary` placement

**Agent 2: Queue Panel Animation**
- Analyze `_queuePanelController` and `_queuePanelAnimation`
- Verify slide-in/out is smooth
- Check interaction with expanded player state
- Verify the Listener-based swipe detection doesn't cause issues

**Agent 3: Player Selector Animation**
- Analyze horizontal swipe between players
- Check `_slideOffset` and peek player animations
- Verify finger-following feels natural
- Look for edge cases with rapid swipes

**Agent 4: Micro-interactions**
- Play/pause button animations
- Progress bar interactions
- Volume swipe overlay
- Favorite button feedback
- Skip button responsiveness

### 2. State Management Audit

**Check for:**
- Unnecessary `setState` calls during animations
- ValueNotifier usage efficiency
- Animation listener cleanup
- Memory leaks from subscriptions
- State synchronization between components

### 3. Visual Polish Audit

**Check for:**
- Color transitions during expand/collapse
- Text fade/scale animations
- Image loading placeholders
- Shadow/elevation consistency
- Border radius morphing smoothness
- Safe area handling

### 4. Gesture Conflict Resolution

**Verify:**
- Vertical drag (expand/collapse) vs horizontal drag (player switch)
- Queue panel swipe-right-to-close vs Dismissible swipe-left-to-delete
- Edge dead zones for Android back gesture
- Tap vs drag disambiguation

### 5. Edge Cases

**Test scenarios:**
- Rapid expand/collapse
- Swipe during animation
- Back button during animations
- Track change during queue scroll
- Network image loading failures
- Very long track/artist names

## Execution Strategy

```
ultrathink: true
```

### Phase 1: Discovery (Read-Only)
Launch parallel sub-agents to analyze each file:
- Read and understand the animation architecture
- Map all animation controllers and their relationships
- Identify potential performance bottlenecks
- Document current RepaintBoundary usage

### Phase 2: Analysis Report
Compile findings into categories:
- **Critical**: Causes visible jank or bugs
- **Important**: Noticeable but not breaking
- **Nice-to-have**: Minor polish improvements

### Phase 3: Implementation Plan
For each finding:
- Specific file and line numbers
- Proposed change
- Risk assessment
- Testing approach

### Phase 4: Incremental Fixes
- One fix at a time
- Build and test after each change
- Verify no regressions

## Output Format

Provide a structured audit report:

```markdown
## Animation Audit Report

### Executive Summary
[2-3 sentences on overall state]

### Critical Issues
1. [Issue]: [File:Line] - [Description] - [Proposed Fix]

### Important Issues
1. [Issue]: [File:Line] - [Description] - [Proposed Fix]

### Polish Opportunities
1. [Issue]: [File:Line] - [Description] - [Proposed Fix]

### Architecture Observations
[Notes on overall structure, patterns noticed]

### Recommended Priority Order
1. [First fix]
2. [Second fix]
...
```

## Success Criteria

After this audit and fixes:
- All animations run at consistent 60fps
- No jank during any transition
- Gestures feel responsive and natural
- State transitions are seamless
- No visual glitches or flickers
- Memory usage is stable during interactions

## Notes

- The app uses adaptive theming (colors extracted from album art)
- There's an `AnimationDebugger` utility for profiling
- Position tracking uses a shared `PositionTracker` singleton
- The player supports both music and audiobooks (different UI modes)
