# Lane Dodge — Design Spec

**Date:** 2026-06-23
**Status:** Approved (pending spec review)

## Summary

A new Hot Seat game: an infinite three-lane road where random obstacles approach
the player. The player steers by **tilting their head** — head level holds the
center lane, tilt left/right holds a side lane. The live front-camera selfie feed
remains the background (the face is the content); head tilt is read via the Vision
framework's `VNFaceObservation.roll`. The player has 3 lives; collisions cost a
heart, three strikes ends the run. Difficulty ramps: the road scrolls faster and
obstacles spawn more frequently the longer the player survives.

## Product guardrail amendment

This game intentionally deviates from the original PRODUCT.md principle
*"Express, don't compete: no scores, winners, timers, or leaderboards."* It is a
skill/reflex game with a score (distance survived) and a fail state. **PRODUCT.md
and CLAUDE.md will be amended first** to permit skill-based games with scores and
fail states, so the brief and the shipped app stay consistent. This is a
deliberate, recorded direction change — not an oversight.

## Control & head-tilt detection

- The existing `CameraPreviewView` already runs `VNDetectFaceRectanglesRequest`.
  `VNFaceObservation` exposes a `roll` property (head tilt, in radians) with no
  landmark request needed.
- The camera callback changes from `(CGPoint?) -> Void` to emit a small value
  type:

  ```swift
  struct FaceReading {
      var foreheadPoint: CGPoint?   // existing Hot Take forehead tracking
      var roll: CGFloat?            // head tilt for Lane Dodge
  }
  ```

  One detection pass, two consumers. Hot Take reads `.foreheadPoint`; Lane Dodge
  reads `.roll`. Both `nil` when no face is detected.
- **Calibration**: on game start, a ~2-second "hold your head still" phase
  averages the neutral roll `r0`. Lane thresholds are relative to `r0`.
- **Lane mapping**:
  - `roll - r0 > +threshold` → one side lane
  - `roll - r0 < -threshold` → other side lane
  - within ±threshold → center lane
  - Threshold ≈ 10–12°.
- **Known on-device unknown**: the front feed is mirrored, so which physical tilt
  direction maps to which screen-side lane must be verified on hardware and
  inverted if backwards. Expected, not a defect.
- Roll is smoothed (low-pass) to prevent lane flicker, consistent with the
  forehead-point smoothing already in `CameraPreviewView`.

## Game model — `LaneDodgeViewModel` (`@Observable`)

Mirrors the shape of the existing `SpeedTapViewModel`.

- **State machine**: `.calibrating → .playing → .gameOver`.
- **Lanes**: 3 lanes, indexed 0 / 1 / 2. `playerLane` is derived from the live
  smoothed roll each tick.
- **Obstacles**: each obstacle has a `lane: Int`, a `progress: CGFloat`
  (0 = far/top of road, 1 = at the player's line), an `id`, and an emoji.
  Spawned at intervals into a random lane.
- **Tick loop**: a display-synced timer (`CADisplayLink` preferred; `Timer`
  acceptable) advances every obstacle's `progress` by the current speed each
  frame. Speed and spawn frequency both increase as a function of elapsed time.
- **Collision**: when an obstacle crosses the player line (`progress >= hitZone`),
  if `obstacle.lane == playerLane`, the player loses one heart and that obstacle
  is consumed. Obstacles that pass the line in a clear lane are removed and count
  as successfully dodged.
- **Lives**: start at 3. Reaching 0 → `.gameOver`.
- **Score**: distance counter, incremented each tick while alive. Shown live and
  on the game-over card.
- **Difficulty curve**: speed ramps from a base rate; spawn interval shrinks
  toward a floor. Exact constants tuned during implementation; ramp is smooth and
  continuous, not stepped levels.

## View — `LaneDodgeView`

Camera feed stays as the background. Overlaid, matching Speed Tap's visual
language (`.ultraThinMaterial`, rounded, white-on-dim):

- **Road**: three translucent lane columns spanning the screen vertically. The
  player's current lane gets a glowing highlight — that highlight *is* the player
  (no separate avatar).
- **Obstacles**: large emoji (e.g. 🪨 🚧 💥) positioned by `(lane, progress)`,
  scaling up slightly as `progress` approaches 1 to suggest approach.
- **Top bar**: hearts (♥♥♥ depleting) and live distance, plus the existing
  back-to-Games button (same style as Speed Tap / category picker).
- **Calibration overlay**: "Hold your head still…" with a short countdown during
  the `.calibrating` phase.
- **Game-over card**: final distance + a retry button and a back-to-Games button,
  styled like Speed Tap's game-over view.
- **No-face fallback**: if `roll` is `nil` (no face detected), the player holds
  their last lane and a subtle "show your face" hint appears, so a dropped
  detection doesn't instantly kill the run.

## Wiring

- `AppScreen` gains a `.laneDodge` case.
- `AppViewModel` gains `openLaneDodge()`.
- `HomeView` gains a new game tile for Lane Dodge.
- `ContentView` routes the `.laneDodge` case and updates its `CameraPreviewView`
  closure to read `.foreheadPoint` off the new `FaceReading` struct (no behavior
  change to Hot Take).

## Scope cuts (YAGNI for v1)

- **No audio.** Speed Tap ships without audio; only the spin wheel has sound.
- **No persistent high score / leaderboard.** Score is per-run only.
- **No avatar art.** The glowing lane highlight represents the player.
- **No multiple obstacle types with distinct behavior.** Emoji vary cosmetically;
  all obstacles behave identically.

## Files

- **New**: `HotSeat/LaneDodgeViewModel.swift`, `HotSeat/LaneDodgeView.swift`
- **Edited**: `HotSeat/CameraPreviewView.swift` (emit `FaceReading`),
  `HotSeat/ContentView.swift` (struct consumer + `.laneDodge` routing),
  `HotSeat/HomeView.swift` (game tile), `PRODUCT.md` and `CLAUDE.md` (guardrail
  amendment).

## Testing / verification

- Builds for the simulator (compile check only — no camera, so `roll` is always
  `nil`; only the no-face fallback path is exercised there).
- Real verification requires a physical iPad/iPhone with a front camera: confirm
  calibration, lane mapping (and tilt-direction inversion if needed), collision,
  heart depletion, game over, retry, and difficulty ramp.
