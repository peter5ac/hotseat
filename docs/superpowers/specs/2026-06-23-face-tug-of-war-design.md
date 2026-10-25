# Face Tug-of-War — Design Spec

**Date:** 2026-06-23
**Status:** Approved (pending spec review)

## Summary

A new Hot Seat game: a local **2-player** head-to-head contest. Two players sit
side by side in front of the one shared front camera. The Vision framework
tracks both faces; each player "pulls" a virtual rope by leaning toward their
own side of the screen. The rope indicator slides left or right in real time;
the first player to drag it fully to their side wins. The live selfie feed
stays as the background (the face is the content). Per-session only — no
scores persisted, no accounts, no network.

## Product guardrail

This is the first **head-to-head competitive** game (a declared winner between
two players). The existing PRODUCT.md/CLAUDE.md amendment already permits skill
games with scores and fail states, per-session only. Confirmed in design: this
game **fits the existing guardrail as-is** — no further PRODUCT.md amendment
required. It introduces no leaderboards, no persistence, no accounts.

## Architecture — shared camera, NOT a second feed

The app mounts a single `CameraPreviewView` at the root of `ContentView`'s
`ZStack`, running one `AVCaptureSession` on the front camera for every screen.
Hot Take and Lane Dodge both consume that single pipeline via the
`FaceReading` → `FaceTracker` channel. Tug-of-War does the same. **No second
`AVCaptureSession` is created** — that would contend for the front camera and
break the codebase's established pattern.

The work extends the shared pipeline, exactly as `roll` was added for Lane
Dodge:

- `FaceReading` (in `CameraPreviewView.swift`) gains a new field:

  ```swift
  struct FaceReading {
      var foreheadPoint: CGPoint?   // existing: top-center of largest face
      var roll: CGFloat?            // existing: head tilt of largest face
      var faceCentersX: [CGFloat]   // NEW: normalized X-centers, up to 2,
                                    // sorted ascending (lower X first)
  }
  ```

- `captureOutput` currently selects only the single largest face (by bounding
  box area) for `foreheadPoint`/`roll`. It continues to do so — **Hot Take and
  Lane Dodge are unaffected.** Additionally, it now takes the two largest faces,
  computes each one's normalized X-center (`box.midX`), and sorts those two
  values ascending into `faceCentersX`. Zero faces → empty array; one face →
  one element; two-or-more → the two largest, sorted by X.
- Coordinate note: `faceCentersX` is the **normalized Vision X** (`box.midX`,
  range 0...1), NOT a converted screen point. Front-camera mirroring is already
  applied at the capture connection (`isVideoMirrored = true`), so a player
  physically on the viewer's left appears on the left of the feed and gets the
  lower X. Player 1 = lower X = left; Player 2 = higher X = right.
- `faceCentersX` is smoothed per-element with the same low-pass factor (0.35)
  already used for the forehead point and roll, to prevent rope jitter. When the
  detected face count changes (2→1, 1→2, →0), the smoothing state resets rather
  than blending across a count change.
- `FaceTracker` (`@Observable`, in `ContentView.swift`) gains
  `var faceCentersX: [CGFloat] = []`, assigned from the camera closure
  alongside `foreheadPoint` and `roll`.

## Game model — `TugOfWarViewModel` (`@Observable`)

Mirrors the shape of `LaneDodgeViewModel`.

- **State machine:** `.calibrating → .playing → .gameOver`.
- **`ropeProgress: CGFloat`**, range −1.0...+1.0, starts at 0.0.
  **−1.0 = Player 1 wins, +1.0 = Player 2 wins, 0.0 = dead center.**
- **Game state:** `isGameOver: Bool` (derived: `state == .gameOver`),
  `winnerName: String?` ("Player 1" / "Player 2"), `isCountingDown: Bool`
  (derived: `state == .calibrating`).
- **Calibration (2 seconds):** during `.calibrating`, collect samples of both
  players' X-positions and average each into `neutralX1` and `neutralX2`. These
  are each player's resting position; leaning is measured relative to a player's
  OWN neutral, so players seated at different distances from center start fair.
  Calibration requires two faces present continuously; if `faceCentersX` has
  fewer than 2 elements, no samples are taken that frame.
- **Input setter** — keeps the spec's method name:

  ```swift
  func updateRopePosition(player1X: CGFloat?, player2X: CGFloat?)
  ```

  During `.calibrating` it feeds calibration samples; during `.playing` it
  stores the latest pair as the current readings for the next `tick`. It does
  NOT itself move the rope when accumulating (see tick).
- **Pull model (accumulate over time):** a per-frame `tick(delta:)` integrates
  pull. Each frame:
  - `p1Lean = max(0, neutralX1 - player1X)` — Player 1 pulls by leaning toward
    their edge (lower X / left).
  - `p2Lean = max(0, player2X - neutralX2)` — Player 2 pulls by leaning toward
    their edge (higher X / right).
  - `ropeProgress += (p2Lean - p1Lean) * pullRate * delta`, clamped to
    [−1.0, +1.0]. Sustained leaning accumulates and holds; easing off stops
    pulling but does not snap back. `pullRate` tuned during implementation
    (starting estimate ≈ 6.0, so a firm sustained lean wins in a few seconds).
- **Face loss → freeze:** if either `player1X` or `player2X` is nil/absent,
  `tick` makes no change — the rope holds position. A dropped detection cannot
  hand the other player a win.
- **Win:** when `ropeProgress <= -1.0` → `winnerName = "Player 1"`,
  `state = .gameOver`. When `ropeProgress >= +1.0` → `winnerName = "Player 2"`,
  `state = .gameOver`. Rope clamps to exactly ±1.0.
- **`reset()`** returns to `.calibrating` with `ropeProgress = 0`,
  `winnerName = nil`, neutrals cleared.

### Why two methods (`updateRopePosition` + `tick`)

The spec's `updateRopePosition` alone cannot produce accumulation: "shift toward
whoever leans further over time" requires a frame clock. `updateRopePosition`
stores the latest reading; `tick(delta:)` integrates it against elapsed time,
driven by a `CADisplayLink` — the same display-link bridge Lane Dodge uses. The
two-method split is deliberate and matches the existing Lane Dodge pattern
(`updatePlayerLane` + `tick`).

## View — `TugOfWarView`

Camera feed stays as the shared background (the view does NOT create its own
camera). Overlaid, matching Speed Tap / Lane Dodge visual language
(`.ultraThinMaterial`, rounded, white-on-dim):

- **Center line:** a distinct vertical line down the screen middle separating
  the two players' territories.
- **Rope track:** a horizontal track across the vertical center of the screen.
- **Indicator node:** a bright ball/flag on the track, positioned with
  `.offset(x: ropeProgress * halfScreenWidth)` so it slides left/right in real
  time. (`halfScreenWidth` from a `GeometryReader`.)
- **Player tint:** left half subtly tinted Player 1's color, right half Player
  2's, so it's obvious which side is which.
- **Countdown overlay:** big, bold "3 — 2 — 1 — GO!" during `.calibrating`.
- **Win overlay:** massive "PLAYER 1 WINS!" / "PLAYER 2 WINS!" celebration over
  the camera on `.gameOver`, with a rematch button and a back-to-Games button
  (same style as Lane Dodge's game-over card).
- **Top bar:** back-to-Games button (same capsule style as the other games).
- **Two-face fallback:** when `faceCentersX` has fewer than 2 elements, show a
  subtle "Show both faces" hint; per the freeze rule the rope holds.
- **Tick:** a `CADisplayLink` drives `tick(delta:)` via the same
  `DisplayLinkView`/`DisplayLinkModifier` UIViewRepresentable bridge Lane Dodge
  introduced. On `.calibrating`, the view drives the 2-second countdown then
  calls `finishCalibration()` (or the equivalent state transition).

## Wiring

- `AppScreen` gains `.tugOfWar`.
- `AppViewModel` gains `openTugOfWar()`.
- `HomeView` gains a new game tile for Tug-of-War (emoji 🪢, available).
- `ContentView` routes the `.tugOfWar` case to `TugOfWarView`, and updates its
  `CameraPreviewView` closure to also assign `faceTracker.faceCentersX =
  reading.faceCentersX` (no behavior change to Hot Take / Lane Dodge).

## Scope cuts (YAGNI for v1)

- **No audio.** Consistent with Speed Tap and Lane Dodge (only the spin wheel
  has sound).
- **No persistent score / match history.** Per-run only.
- **No best-of-N / rounds.** A single rope-to-the-edge ends the match; rematch
  button restarts.
- **No custom player names or avatars.** "Player 1" / "Player 2" and side tints.
- **No more than 2 players.** The pipeline emits at most 2 face centers.

## Files

- **New:** `HotSeat/TugOfWarViewModel.swift`, `HotSeat/TugOfWarView.swift`
- **Edited:** `HotSeat/CameraPreviewView.swift` (emit `faceCentersX`),
  `HotSeat/ContentView.swift` (FaceTracker field + `.tugOfWar` routing),
  `HotSeat/HomeView.swift` (game tile).
- **Xcode project:** register the two new files in `HotSeat.xcodeproj`
  (`project.pbxproj`).

## Testing / verification

- Builds for device (`xcodebuild ... -destination 'generic/platform=iOS'`);
  the project has no XCTest target by design, so verification is the compile
  gate plus on-device manual testing.
- Simulator has no camera, so `faceCentersX` is always empty there — only the
  "Show both faces" frozen-rope path is exercisable in the simulator.
- Real verification requires a physical iPad/iPhone with a front camera and TWO
  people: confirm calibration completes with two faces, both leans move the rope
  the correct direction (Player 1 leaning left drives the rope toward −1 / P1
  win), accumulation feels like a contest, face-loss freezes the rope, win
  overlay and rematch work, and Hot Take / Lane Dodge still behave (shared
  pipeline regression check).
- **On-device unknown:** `pullRate` tuning (how hard/long a lean takes to win)
  and whether left/right mapping feels correct under mirroring. Both are tuned
  on hardware; the mirroring is already handled at the capture connection so the
  mapping is expected to be correct, but confirm.
