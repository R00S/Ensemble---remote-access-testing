# Queue Button Debug Investigation

## Issue
Queue button in fullscreen player shows tap feedback (ink ripple) but doesn't navigate to QueueScreen. The down arrow (collapse) button next to it works fine.

## Symptoms
- Tap feedback visually appears on queue button
- No navigation occurs
- Down arrow button in same area works correctly
- No relevant logs appear even with extensive debug logging

## Investigation Timeline

### Attempt 1: IgnorePointer on Player Name (previous session)
- **Theory**: Player name text was intercepting taps
- **Fix**: Wrapped player name in `IgnorePointer`
- **Result**: Failed - no change

### Attempt 2: GestureDetector with HitTestBehavior.opaque
- **Theory**: Parent GestureDetector competing in gesture arena
- **Fix**: Changed IconButton to GestureDetector with `HitTestBehavior.opaque`
- **Result**: Failed - box no longer flashes but still no navigation

### Attempt 3: QueueScreen ReorderableDragStartListener crash
- **Theory**: QueueScreen was crashing on open due to `ReorderableDragStartListener` being used outside of `ReorderableListView`
- **Fix**: Removed ReorderableDragStartListener, replaced with plain Icon
- **Result**: Failed - still no navigation

### Attempt 4: Extensive debug logging
- **Logging added**: onTapDown, onTapUp, onTapCancel, onTap with try/catch
- **Result**: NO LOGS APPEARED AT ALL
- **Insight**: Gesture never reaches the button - something intercepts before hit testing

### Attempt 5: Listener instead of GestureDetector
- **Theory**: Listener works at pointer level before gesture arena
- **Fix**: Used `Listener` with `onPointerUp`
- **Result**: Pending test (skeptical)

### Attempt 6: Position test - move button to LEFT side
- **Theory**: Something specifically blocks the RIGHT side of the header
- **Fix**: Moved queue button to `left: 52` (next to collapse button)
- **Result**: PENDING TEST

## Key Observations
1. Down arrow button works (left side, `left: 4`)
2. Queue button doesn't work (right side, `right: 4`)
3. Both use identical widget structure (IconButton in Opacity in Positioned)
4. Tap feedback showed initially, then stopped after GestureDetector change
5. Debug logs never fire - gesture blocked before reaching button

## Current Hypothesis
Something invisible is overlapping/blocking the RIGHT side of the header area where the queue button sits. Possible culprits:
- Widget with unbounded width extending from left
- Invisible gesture absorber
- Stack ordering issue

## Files Involved
- `lib/widgets/expandable_player.dart` - main player widget
- `lib/screens/queue_screen.dart` - destination screen
- `lib/widgets/global_player_overlay.dart` - overlay wrapper

## Widget Hierarchy (relevant section)
```
Positioned (player container)
└── GestureDetector (onTap: expand, onVerticalDragUpdate: expand/collapse)
    └── Material
        └── SizedBox
            └── Stack
                ├── ... (album art, text, controls)
                ├── Positioned(left: 4) → IconButton (collapse) ✅ WORKS
                ├── Positioned(right: 4) → IconButton (queue) ❌ BROKEN
                └── Positioned(left: 56, right: 56) → IgnorePointer → Text (player name)
```

### Attempt 6 Result: Left-side position test
- **Result**: FAILED - button shows ripple but no action
- **Insight**: Position is NOT the issue. Problem is with the button/callback itself

### Attempt 7: State context + SnackBar verification
- **Theory**: Shadowed `context` from AnimatedBuilder/Consumer might be invalid for navigation
- **Fix**:
  - Created `_openQueue()` method on State class using `this.context`
  - Added SnackBar to visually confirm if `onPressed` executes at all
- **Result**: PENDING TEST

## Key Mystery
IconButton shows ripple (Material ink effect) which means:
- Hit testing passes
- The button receives the tap
- Material widget processes the touch

BUT `onPressed` doesn't fire. This is very unusual - ripple and callback should be tied together.

## Possible Explanations
1. **Context issue**: Navigation fails silently due to invalid context
2. **Async issue**: Something in the animation cycle interrupts the callback
3. **Flutter bug**: Edge case with IconButton in animated Stack
4. **Absorption**: Something absorbs the gesture after ripple starts but before callback

## Next Steps
1. Test SnackBar - if it shows, onPressed fires and issue is navigation
2. If no SnackBar - need to investigate why ripple shows but callback doesn't fire
3. Consider using raw `GestureDetector` or `InkWell` instead of `IconButton`
