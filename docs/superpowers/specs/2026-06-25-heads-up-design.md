# Heads-Up — Design

**Date:** 2026-06-25
**Game id:** `headsUp`
**Status:** Approved, ready for implementation plan

## Summary

A Heads Up-style guessing game for Hot Seat. A player holds the phone to their
forehead in landscape (screen facing the other players). A 90-second round runs:
one item from a chosen category is shown at a time. Other players act/describe to
help the holder guess. The holder tilts the phone **up** to mark **correct** or
**down** to **pass**, then returns to neutral to load the next item. When time
runs out (or the deck empties), a recap lists guessed vs missed items, with
Play Again / New Category.

No scores persist, no accounts, no network — per-session only, consistent with the
app's skill-game guardrails (timer + fail-ish states allowed, no leaderboards).

## Architecture & Files

Follows the established per-game pattern (`View` + `@Observable ViewModel`,
`CADisplayLink` tick, `FaceTracker`/`AppScreen` routing).

- **`HeadsUpView.swift`** — SwiftUI view. Category picker, landscape prompt,
  tilt-to-neutral readying, 3-2-1 countdown, in-play HUD (large centered item
  text for guessers + timer), correct/pass flash overlays, end-of-round recap.
  Owns a private `CADisplayLink` modifier (copy of the TugOfWar pattern) that
  drives the 90s timer and polls motion each frame.
- **`HeadsUpViewModel.swift`** — `@Observable`. Game state machine, 90s timer,
  current item selection (shuffled, no repeats), `guessed`/`missed` lists, and
  neutral-reset locking. **Does not import CoreMotion** — consumes plain `pitch`
  numbers so it stays unit-testable.
- **`MotionTracker.swift`** — new `@Observable` wrapper around `CMMotionManager`.
  Publishes `pitch: Double` (signed, landscape-stable, derived from the gravity
  vector) and `isLandscape: Bool`. `start()`/`stop()` tied to view
  `onAppear`/`onDisappear` so the sensor isn't running app-wide. This is the one
  new dependency in the project.
- **`HeadsUpCategories.swift`** — new dataset. `HeadsUpCategory { name, emoji,
  items: [String] }`, **each list 30+ items** (one explicit exception below).
  Separate from `RankCategory` so Hot Take's short blind-pick lists are untouched.

  **Categories at launch (34):**
  1. 90s Cartoons
  2. 90s Movies
  3. Pixar Movies
  4. Netflix Shows
  5. Dog Breeds
  6. Famous Actors
  7. Historical Figures
  8. Emojis
  9. Classic Fiction (novels)
  10. YouTubers
  11. WWE (wrestlers)
  12. Harry Potter Characters
  13. Percy Jackson Characters
  14. **Family Members** — fixed list, **27 items (under the 30 minimum by
      design; do NOT pad with invented names)**: Peter, Guy, Kate, Audrey, Vince,
      Bluebelle, Jackie, Berkley, Harry, RieRie, Grampy, Grammie, Pa, Uncle Jimmy,
      Fuffa, Little Guy, Garrison, Aunt Karen, Uncle Guy, Andrea, Steve, Crystal,
      Max, Layla, Noah, Nana Sullivan, Papa Sullivan.
  15. Actions / Charades (guessing-native)
  16. Animals (from Hot Take inspiration, expanded to 30+)
  17. Disney Animated Movies (Hot Take-inspired, expanded)
  18. Pokémon (Hot Take-inspired, expanded)
  19. Video Games (Hot Take-inspired, expanded)
  20. Superheroes (Hot Take-inspired, expanded)
  21. Mythical Creatures (Hot Take-inspired, expanded)
  22. Pop Stars / Musicians (Hot Take-inspired, expanded)
  23. Studio Ghibli & Anime Characters
  24. Marvel Characters
  25. Star Wars Characters
  26. Minecraft (mobs, items, blocks)
  27. Roblox Games
  28. Sports & Athletes
  29. Jobs & Professions (charades-friendly)
  30. Foods & Snacks (Hot Take-inspired, expanded)
  31. Ocean Animals (Hot Take-inspired, expanded)
  32. Dinosaurs (Hot Take-inspired, expanded)
  33. Disney Villains (Hot Take-inspired, expanded)
  34. Holidays & Seasons (Hot Take-inspired, expanded)

  All lists except Family Members must reach **30+** kid-appropriate items
  (ages 7–14). Reuse Hot Take names/emoji where a theme overlaps, but write
  fresh expanded item lists.

**Wire-up:**
- `AppScreen`: add `case headsUp`.
- `AppViewModel`: add `openHeadsUp()`.
- `HomeView`: add a tile to `allGames` + a spin-wheel `case "headsUp"`.
- `ContentView`: add `case .headsUp` to the screen switch; pass an `onExit` that
  returns home (same shape as TugOfWar).

## State Machine

```
categoryPicker → readying → countdown → playing → recap
```

- **categoryPicker** — grid of Heads-Up categories (mirrors Hot Take picker UI
  + "Spin for me" wheel).
- **readying** — after category pick. If portrait, show "Turn sideways"; once
  landscape, show "Hold it to your forehead." View polls `MotionTracker.pitch`;
  when pitch holds in the neutral band for ~1 continuous second → countdown.
- **countdown** — 3-2-1 (time to settle on forehead). On countdown start, capture
  current pitch as the **neutral reference** (calibration). Then → playing.
- **playing** — 90s timer via display link. One item at a time, random without
  repeats from the shuffled deck.
  - Tilt **up** past trigger threshold → **correct**: append to `guessed`, green
    "CORRECT" flash + success haptic.
  - Tilt **down** past trigger threshold → **pass**: append to `missed`, amber
    "PASS" flash + pass haptic.
  - After either, the item **locks** until pitch returns to the neutral band, then
    the next item loads. Neutral-reset prevents one tilt burning multiple items.
  - ≤10s remaining → final-seconds cue (flash + haptic).
  - Timer hits 0 → recap. Deck empties first → recap ("got through them all").
- **recap** — ✅ guessed and ❌ missed lists with counts. **Play Again** (same
  category, reshuffled) and **New Category** (→ picker).

**Hysteresis:** neutral band ±X°, trigger past ±Y° with Y > X, so jitter near a
boundary can't double-fire.

## Motion Sensing

`MotionTracker` wraps `CMMotionManager`:

- Device-motion updates (~60Hz) on `start()`, stopped on `stop()`.
- Reads gravity vector (`deviceMotion.gravity`); derives one signed `pitch` value
  stable in landscape whose sign flips between tilt-up and tilt-down.
- `@Observable` props `pitch` + `isLandscape`; VM never imports CoreMotion.
- **Calibration:** capture pitch at countdown start as neutral reference (like
  TugOfWar calibrates neutral X per player). Correct/pass thresholds are offsets
  from captured neutral — handles different holding angles.
- Axis mapping + thresholds **tuned on-device** (simulator has no motion; camera
  is black there too — consistent with TugOfWar's on-device `pullRate` tuning).
  Pick sane starting constants with a clear comment.

## Feedback

- **Haptics:** distinct correct vs pass taps so the holder feels registration
  without seeing the screen. Final-seconds haptic.
- **Color flash + word:** full-screen green "CORRECT" / amber "PASS" so guessers
  get instant confirmation.
- **Final-seconds cue:** visual + haptic under ~10s.
- **No room audio** for correct/pass (declined) — holder relies on haptics,
  guessers read the flash.

## Orientation

- **Require landscape.** Game logic assumes landscape; if portrait, show a "Turn
  sideways" prompt and don't start. Doesn't fight the app's all-orientations
  support (no force-lock plumbing added).

## Error Handling & Edge Cases

- **No motion (simulator/unsupported):** `MotionTracker` reports unavailable;
  readying shows a note. Game is effectively unplayable in simulator (no
  tap-fallback, by choice) — acceptable since the camera is already black there.
- **Rotation mid-game into portrait:** show "turn sideways" overlay but **timer
  keeps running** (Heads Up doesn't pause for fumbles; pausing invites cheating).
  Tunable.
- **Deck smaller than 90s of play:** no repeats; if exhausted, round ends early
  with a "got through them all" recap note. (Family Members at 27 items is the
  most likely to exhaust within 90s — handled by this same early-end path.)
- **Backgrounding/exit:** `onDisappear` stops motion + invalidates display link
  (same lifecycle as TugOfWar).

## Testing

- No test target exists today; games are validated on-device via XcodeBuildMCP.
- `HeadsUpViewModel` is pure (no CoreMotion) — state transitions, neutral-reset
  locking, deck-no-repeat, and correct/missed bucketing are unit-testable with
  injected pitch numbers if a test target is added later.
- Primary validation is manual on a physical device. Simulator only verifies
  layout/navigation.

## Out of Scope

- Persistence, scores, accounts, network (per guardrails).
- Force orientation lock.
- On-screen Correct/Pass tap fallback (declined).
- Per-correct room audio (declined).
