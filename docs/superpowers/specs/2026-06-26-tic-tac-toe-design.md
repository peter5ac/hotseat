# Tic Tac Toe (Mouth-Controlled) — Design

**Status:** Approved design, ready for implementation planning.

## Goal

Add a fifth game to Hot Seat: a two-player, pass-the-phone Tic Tac Toe where
each player places their mark by holding their **open mouth** over the target
square for one second. Turn order determines the mark — Player 1 = **O**,
Player 2 = **X**. No tapping, no cursor: the position of the mouth on screen is
the targeting mechanism.

## Audience & guardrails (from PRODUCT.md / CLAUDE.md)

- Pre-teens 7–14. No recording, upload, network, accounts, or persistence.
  Per-session only.
- The camera feed is the content. The grid is drawn *over* the live selfie
  feed; players must see their own mouth over the squares. The dimming overlay
  (`Color.black.opacity(0.4)`) stays — it is load-bearing for contrast.
- Pass-the-phone, grab-and-go, large tap/target areas, legible at arm's length.

## Mechanic (agreed)

- **Both players use the same gesture: an open mouth.** The O-vs-kiss idea was
  dropped for reliability. Turn order alone decides whether a placement is an O
  or an X.
- **Targeting:** the player positions their open mouth so its on-screen center
  falls within the bounds of an empty square.
- **Confirm:** while the mouth stays open and inside that same empty square, a
  1-second hold accrues. The square visibly fills/rings to show progress.
- **Cancel-on-move:** if the mouth closes, leaves the square, or moves to a
  different square before the hold completes, the selection cancels and that
  player re-attempts. (Explicit user requirement.)
- **Placement:** at hold completion, the current player's mark drops into the
  square, win/draw is evaluated, and the turn flips.
- **Post-placement lockout (~0.5s):** after a mark is placed, no new placement
  can begin for ~0.5s, so a single sustained open mouth cannot immediately
  claim a second square. (Designer-added; considered required, not optional.)
- **O always goes first** each round (convention; alternating-start is a
  trivial future change, explicitly out of scope now).

## Architecture

One shared-code change (the camera pipeline); everything else is two new,
self-contained files plus navigation wiring. Mirrors the existing per-game
structure (`HeadsUpView` + `HeadsUpViewModel`, etc.).

### 1. Camera pipeline (`CameraPreviewView.swift`) — MODIFY

Swap `VNDetectFaceRectanglesRequest` → `VNDetectFaceLandmarksRequest`. Landmarks
is a superset: it still yields the bounding box and roll (so `foreheadPoint`,
`roll`, `faceCentersX` are unchanged and **Hot Take / Lane Dodge / Tug-of-War
are unaffected**), and it adds `landmarks.innerLips`. One request replaces one
request, so per-frame cost stays comparable.

`FaceReading` gains two fields:

- `mouthOpen: Bool?` — `nil` when no face. True when the openness ratio exceeds
  a tuned threshold.
- `mouthCenter: CGPoint?` — centroid of the `innerLips` points, in the same
  view-space coordinates as `foreheadPoint`.

**Openness ratio** (scale/distance invariant): vertical inner-lip gap ÷ mouth
width. A threshold constant (tuned on-device) maps it to `mouthOpen`. Using a
ratio rather than absolute pixels keeps detection stable regardless of how far
the child holds the phone.

**Coordinate conversion — the fiddliest part.** `VNFaceLandmarks2D` points are
normalized *within the face bounding box*, not the image. The pipeline must
compose: landmark point (box-relative) → image-normalized (offset+scale by the
bounding box) → existing aspect-fill → view-space mapping (the current
`screenPoint` math, which already handles the Vision Y-flip and
`.resizeAspectFill` crop). `mouthCenter` and `mouthOpen` are smoothed with the
same low-pass approach already used for `foreheadPoint`/`roll` to kill
per-frame jitter. Expect threshold + mapping to need on-device tuning.

`FaceTracker` (in `ContentView.swift`) gains matching `mouthOpen` / `mouthCenter`
properties, populated in the existing `onReadingChange` closure.

### 2. `TicTacToeViewModel.swift` — CREATE (`@Observable`)

State:

- `enum Mark { case o, x }`
- `board: [Mark?]` — 9 cells, index 0–8 row-major.
- `currentPlayer: Mark` — starts `.o`, flips on each successful placement.
- `winner: Mark?`, `isDraw: Bool`, `winningLine: [Int]?` (the 3 winning cell
  indices, for highlight).
- `pendingCell: Int?`, `confirmProgress: Double` (0→1 over the hold).
- A lockout timer (seconds remaining) for the post-placement window.

Tuning constants: `confirmDuration = 1.0`, `placementLockout = 0.5`.

Pure, camera-free API so it is sim-testable:

- `tick(delta:targetedCell:mouthOpen:)` — the per-frame driver. `targetedCell`
  is the empty cell index the mouth currently sits in (or `nil`); the view
  computes it from `mouthCenter` + cell rects. Logic:
  - If in lockout, decrement and ignore input.
  - If `mouthOpen` and `targetedCell` is a non-nil empty cell:
    - same cell as `pendingCell` → accrue `confirmProgress += delta /
      confirmDuration`; at ≥ 1.0 call `place(at:)`.
    - different/new cell → set `pendingCell`, reset progress.
  - Otherwise (mouth closed, outside grid, or filled cell) → cancel:
    `pendingCell = nil`, `confirmProgress = 0`.
- `place(at:)` — writes `currentPlayer` into the cell, runs win/draw check, sets
  `winner`/`winningLine` or `isDraw`, flips `currentPlayer`, starts lockout,
  clears pending state.
- `playAgain()` — clears board/winner/draw/pending, `currentPlayer = .o`.
- Win check: the standard 8 lines (3 rows, 3 cols, 2 diagonals). First complete
  line sets `winner` + `winningLine`. Full board with no winner → `isDraw`.

### 3. `TicTacToeView.swift` — CREATE

Follows `HeadsUpView`: owns the view model, receives `faceTracker: FaceTracker`
and `onExit: () -> Void`, drives logic via the same private `CADisplayLink`
modifier pattern (unique type names per file).

Layout:

- Camera feed is the background (provided by `ContentView`; **not** suppressed —
  the face is the controller). The existing dim overlay stays.
- A 3×3 grid centered on screen. Cells use thin light strokes and translucent
  fills so the camera shows through. The grid's frame is read via
  `GeometryReader` so each cell's rect is known in the **same view-space
  coordinates as `mouthCenter`** — this is what makes "mouth inside this square"
  resolvable. The view maps `faceTracker.mouthCenter` → targeted cell index each
  frame and passes it to `viewModel.tick`.
- Placed marks render as bold rounded **"O" / "X" text glyphs** (no emoji, no
  custom shapes, no assets). Winning line gets a highlight stroke.
- Top bar: "Games" back button (matches other games) + turn indicator —
  "Player 1: open mouth to place O" / "Player 2: ... X".

Detection feedback (important — the gesture is inherently flaky):

- The `pendingCell` shows a growing ring/fill tracking `confirmProgress` 0→1, so
  the player sees "holding…" before the mark drops.
- A small mouth-open indicator (e.g. a dot) so players learn what the camera
  sees.
- `UIImpactFeedbackGenerator` fires on successful placement, pre-warmed in
  `onAppear` like Heads Up.

End state: an overlay card — "Player 1 wins!" / "Player 2 wins!" / "It's a
draw!" — with **Play again** (same players, board cleared) and **Games** (exit).
Mirrors the Heads Up recap.

### 4. Navigation wiring — MODIFY

- `ContentView.swift`: add `.ticTacToe` to `AppScreen`; add
  `openTicTacToe()` to `AppViewModel`; add the `case .ticTacToe` to the screen
  switch, constructing `TicTacToeView(faceTracker:onExit:)`. Camera is NOT
  suppressed for this screen (the `screen == .headsUp` black-background branch is
  untouched; tic-tac-toe uses the normal camera path).
- `HomeView.swift`: add a `Game` entry (id `ticTacToe`, name "Tic Tac Toe",
  emoji e.g. ❌⭕ / 🎯, `isAvailable: true`); add `onSelectTicTacToe` to the
  `HomeView` initializer; handle the id in both the tile-tap switch and the
  spin-wheel `onLanded` switch.
- `HotSeat.xcodeproj`: register both new source files in the build (explicit
  step — new files do not auto-add; precedent: the "register Heads Up source
  files" commit).

## Data flow (per frame, while playing)

```
CameraUIView (bg queue): Vision landmarks
  → innerLips → openness ratio → mouthOpen; centroid → mouthCenter (view space)
  → main thread, smoothed → FaceReading
ContentView.onReadingChange → faceTracker.mouthOpen / .mouthCenter
TicTacToeView CADisplayLink tick:
  mouthCenter → hit-test cell rects → targetedCell (empty cells only)
  viewModel.tick(delta:targetedCell:mouthOpen:)
    → accrue / cancel confirmProgress → place → win/draw → flip turn → lockout
View re-renders board, pending ring, turn indicator, end card.
```

## Error / edge handling

- No face / `mouthCenter == nil` → treated as no target; any in-progress hold
  cancels.
- Mouth open but center outside the grid, or over a filled cell → no-op.
- Rapid open/close or drifting between cells → cancel-on-move resets the hold.
- Sustained open mouth after a placement → blocked by the lockout window.
- Game over → `tick` ignores input until `playAgain()` or exit.
- Motion/landmark unavailable is not applicable (no CoreMotion here); if Vision
  yields no landmarks, `mouthOpen`/`mouthCenter` are nil and the board simply
  cannot be advanced — acceptable degradation.

## Testing

- **Sim-testable (pure logic):** placement, turn flip, cancel-on-move (via
  feeding `tick` synthetic `targetedCell`/`mouthOpen` sequences), win detection
  on all 8 lines, draw detection, lockout behavior, `playAgain` reset. The view
  model is built camera-free precisely so this is possible.
- **Thorin16-only (camera):** openness threshold, ratio behavior at varying
  distances/lighting, and the box-relative→view-space `mouthCenter` mapping
  accuracy over the grid. The simulator camera is black, so the full game is
  only verifiable on the physical device and will need threshold tuning there.

## Out of scope (YAGNI)

- Alternating who-goes-first across rounds.
- Score tracking across games / any persistence.
- Single-player / AI opponent.
- Distinguishing the two players by face identity (pass-the-phone makes this
  unnecessary).
- Any mark other than O and X; any gesture other than open-mouth.
