# Lane Dodge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a head-tilt-controlled, three-lane infinite dodge game ("Lane Dodge") to Hot Seat, reusing the existing Vision face-detection pipeline.

**Architecture:** A new `@Observable LaneDodgeViewModel` holds all game state and the tick/spawn/collision logic (pure, no UIKit). `LaneDodgeView` renders lanes, obstacles, hearts, and overlays over the live camera background and drives a `CADisplayLink` tick. `CameraPreviewView`'s callback is widened from `(CGPoint?)` to a `FaceReading` struct carrying both the existing forehead point and the new head-tilt `roll`, so one Vision pass serves both Hot Take and Lane Dodge. Routing follows the established `AppScreen`/`AppViewModel`/`HomeView` pattern.

**Tech Stack:** SwiftUI, AVFoundation, Vision (`VNDetectFaceRectanglesRequest` → `VNFaceObservation.roll`), `CADisplayLink`, iOS 17+, Swift 5.

## Global Constraints

- iOS 17+, Swift 5, SwiftUI. Universal (iPhone + iPad), all orientations.
- No new third-party dependencies. AVFoundation + Vision only.
- No audio in v1 (matches Speed Tap).
- No persistent state / no high-score storage. Per-run score only.
- No network, no analytics, no accounts (product invariant — unchanged).
- The live front-camera selfie feed remains the background; overlays use the
  existing visual language: `.ultraThinMaterial`, rounded rects, white text on the
  load-bearing dim overlay.
- This project has **no XCTest target** and ships no tests; both existing games
  follow a ViewModel+View pattern verified by compile + on-device manual checks.
  Do **not** add a test target. Each task's "test" cycle is: build for the
  simulator (compile gate) and, where stated, an on-device manual check.
- Camera is black and `roll` is always `nil` in the simulator. Tilt/collision
  behavior is only verifiable on a physical device.
- Bundle id `com.audrey.HotSeat`. Device for manual checks: Thorin16
  (UDID `00008140-00065C5A14D1801C`).

**Standard build (compile gate) — used as the "run the test" step throughout:**
```bash
cd /Users/pvacca/git/audrey
xcodebuild -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build build 2>&1 | tail -5
```
Expected on success: `** BUILD SUCCEEDED **`

---

### Task 1: Amend product guardrails

**Files:**
- Modify: `PRODUCT.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing code-facing. Removes the contradiction between the new game
  and the written product principles so later tasks are consistent with the brief.

- [ ] **Step 1: Update PRODUCT.md design principle**

In `PRODUCT.md`, find the principle that forbids competition (the "Express, don't
compete: no scores, winners, timers, or leaderboards" guardrail). Replace the
absolute prohibition with an allowance for skill games, preserving the spirit for
the expressive games. Use this wording:

> **Two kinds of play.** *Expressive games* (Hot Take) have no scores, winners, or
> timers — they're about revealing taste, not winning. *Skill games* (Speed Tap,
> Lane Dodge) may have scores, lives, and fail states, but stay per-session only:
> no leaderboards, no persistent ranks, no accounts. Either way: nothing is
> recorded, uploaded, or shared.

If `PRODUCT.md` lists "generic quiz apps" or similar as anti-references in a way
that now conflicts, leave the anti-references as-is (they still apply to expressive
games) — the new wording above scopes the rule, which resolves the conflict.

- [ ] **Step 2: Update CLAUDE.md guardrails section**

In `CLAUDE.md`, under "Product guardrails (from PRODUCT.md)", change the line:

```
- **Express, don't compete**: no scores, winners, timers, or leaderboards.
```

to:

```
- **Two kinds of play**: expressive games (Hot Take) have no scores/winners/timers;
  skill games (Speed Tap, Lane Dodge) may have scores/lives/fail states but stay
  per-session only — no leaderboards, no persistence, no accounts.
```

- [ ] **Step 3: Commit**

```bash
cd /Users/pvacca/git/audrey
git add PRODUCT.md CLAUDE.md
git commit -m "docs: amend guardrails to permit per-session skill games

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Widen the camera callback to `FaceReading`

**Files:**
- Modify: `HotSeat/CameraPreviewView.swift`
- Modify: `HotSeat/ContentView.swift` (the `CameraPreviewView { ... }` call site and `FaceTracker`)

**Interfaces:**
- Consumes: existing `CameraUIView` Vision pipeline, existing `FaceTracker`.
- Produces:
  - `struct FaceReading { var foreheadPoint: CGPoint?; var roll: CGFloat? }`
  - `CameraPreviewView.onReadingChange: (FaceReading) -> Void` (replaces
    `onForeheadChange: (CGPoint?) -> Void`).
  - `CameraUIView.onReadingChange: ((FaceReading) -> Void)?` (replaces
    `onForeheadChange`).
  - `FaceTracker.foreheadPoint: CGPoint?` (unchanged) plus new
    `FaceTracker.roll: CGFloat?`.

- [ ] **Step 1: Add the `FaceReading` struct**

At the top of `HotSeat/CameraPreviewView.swift`, below the imports, add:

```swift
/// A single frame's face-derived signals, emitted on the main thread.
/// `nil` fields mean "no face detected" for that signal.
struct FaceReading {
    var foreheadPoint: CGPoint?   // top-center of the face box, view coordinates
    var roll: CGFloat?            // head tilt in radians (VNFaceObservation.roll)
}
```

- [ ] **Step 2: Swap the `CameraPreviewView` callback type**

In `CameraPreviewView`, replace:

```swift
    var onForeheadChange: (CGPoint?) -> Void

    func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        view.onForeheadChange = onForeheadChange
        return view
    }

    func updateUIView(_ uiView: CameraUIView, context: Context) {
        uiView.onForeheadChange = onForeheadChange
    }
```

with:

```swift
    var onReadingChange: (FaceReading) -> Void

    func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        view.onReadingChange = onReadingChange
        return view
    }

    func updateUIView(_ uiView: CameraUIView, context: Context) {
        uiView.onReadingChange = onReadingChange
    }
```

- [ ] **Step 3: Update `CameraUIView` storage and capture the roll**

In `CameraUIView`, replace the stored callback:

```swift
    /// Forehead point in this view's coordinate space, or nil. Always invoked on main.
    var onForeheadChange: ((CGPoint?) -> Void)?
```

with:

```swift
    /// Latest face reading (forehead point + roll). Always invoked on main.
    var onReadingChange: ((FaceReading) -> Void)?
```

Then in `captureOutput(_:didOutput:from:)`, the largest-face block currently
computes only the box. Capture the roll alongside it. Replace:

```swift
        let box = face.boundingBox   // normalized, bottom-left origin

        // Coordinate math reads `bounds` and updates state — do it on main.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let point = self.screenPoint(
                forNormalizedBox: box,
                bufferWidth: bufferWidth,
                bufferHeight: bufferHeight
            )
            self.emit(point)
        }
```

with:

```swift
        let box = face.boundingBox   // normalized, bottom-left origin
        let roll = face.roll.map { CGFloat(truncating: $0) }

        // Coordinate math reads `bounds` and updates state — do it on main.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let point = self.screenPoint(
                forNormalizedBox: box,
                bufferWidth: bufferWidth,
                bufferHeight: bufferHeight
            )
            self.emit(point, roll: roll)
        }
```

- [ ] **Step 4: Update both `emit` call sites and the `emit` signature**

In `captureOutput`, there are two no-face early-returns that call
`self?.emit(nil)`. Replace each:

```swift
            DispatchQueue.main.async { [weak self] in self?.emit(nil) }
```

with:

```swift
            DispatchQueue.main.async { [weak self] in self?.emit(nil, roll: nil) }
```

Then replace the entire `emit` method:

```swift
    /// Applies jitter smoothing and forwards the result upstream.
    private func emit(_ raw: CGPoint?) {
        guard let raw else {
            smoothedPoint = nil
            onForeheadChange?(nil)
            return
        }

        if let prev = smoothedPoint {
            smoothedPoint = CGPoint(
                x: prev.x + (raw.x - prev.x) * smoothing,
                y: prev.y + (raw.y - prev.y) * smoothing
            )
        } else {
            smoothedPoint = raw
        }
        onForeheadChange?(smoothedPoint)
    }
```

with:

```swift
    /// Applies jitter smoothing to the forehead point and roll, forwards upstream.
    private func emit(_ raw: CGPoint?, roll: CGFloat?) {
        // Forehead point smoothing (unchanged behavior).
        if let raw {
            if let prev = smoothedPoint {
                smoothedPoint = CGPoint(
                    x: prev.x + (raw.x - prev.x) * smoothing,
                    y: prev.y + (raw.y - prev.y) * smoothing
                )
            } else {
                smoothedPoint = raw
            }
        } else {
            smoothedPoint = nil
        }

        // Roll smoothing (same low-pass factor).
        if let roll {
            if let prev = smoothedRoll {
                smoothedRoll = prev + (roll - prev) * smoothing
            } else {
                smoothedRoll = roll
            }
        } else {
            smoothedRoll = nil
        }

        onReadingChange?(FaceReading(foreheadPoint: smoothedPoint, roll: smoothedRoll))
    }
```

Add the new stored property next to `smoothedPoint`:

```swift
    /// Low-pass-filtered roll (main thread only) to prevent lane flicker.
    private var smoothedRoll: CGFloat?
```

- [ ] **Step 5: Update `FaceTracker` and the call site in `ContentView.swift`**

In `HotSeat/ContentView.swift`, replace the `FaceTracker` class:

```swift
/// Holds the live forehead coordinate emitted by the camera layer.
@Observable
final class FaceTracker {
    /// Forehead point in full-screen coordinates (points), or nil if no face.
    var foreheadPoint: CGPoint?
}
```

with:

```swift
/// Holds the live face signals emitted by the camera layer.
@Observable
final class FaceTracker {
    /// Forehead point in full-screen coordinates (points), or nil if no face.
    var foreheadPoint: CGPoint?
    /// Head tilt in radians, or nil if no face.
    var roll: CGFloat?
}
```

Then replace the camera call site:

```swift
            CameraPreviewView { point in
                faceTracker.foreheadPoint = point
            }
            .ignoresSafeArea()
```

with:

```swift
            CameraPreviewView { reading in
                faceTracker.foreheadPoint = reading.foreheadPoint
                faceTracker.roll = reading.roll
            }
            .ignoresSafeArea()
```

- [ ] **Step 6: Build (compile gate)**

Run the Standard build from Global Constraints.
Expected: `** BUILD SUCCEEDED **`. Hot Take forehead tracking is unchanged
(reads `reading.foreheadPoint`).

- [ ] **Step 7: Commit**

```bash
cd /Users/pvacca/git/audrey
git add HotSeat/CameraPreviewView.swift HotSeat/ContentView.swift
git commit -m "feat: emit FaceReading (forehead + head roll) from camera view

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `LaneDodgeViewModel` — state, lanes, calibration

**Files:**
- Create: `HotSeat/LaneDodgeViewModel.swift`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces (relied on by Tasks 4 and 5):
  - `enum LaneDodgeState { case calibrating, playing, gameOver }`
  - `struct Obstacle: Identifiable { let id: UUID; let lane: Int; var progress: CGFloat; let emoji: String }`
  - `@Observable final class LaneDodgeViewModel`
    - `var state: LaneDodgeState`
    - `var lives: Int` (starts 3)
    - `var distance: Int`
    - `var playerLane: Int` (0, 1, 2)
    - `var obstacles: [Obstacle]`
    - `let laneCount = 3`
    - `func startCalibration()`
    - `func addCalibrationSample(roll: CGFloat?)`
    - `func finishCalibration()`
    - `func updatePlayerLane(roll: CGFloat?)`
    - `func tick(delta: CGFloat)`  — advances obstacles, handles spawning/collision/score
    - `func reset()`
  - Tuning constants as `private` stored properties (documented inline).

- [ ] **Step 1: Create the file with state types and the calibration logic**

Create `HotSeat/LaneDodgeViewModel.swift`:

```swift
import SwiftUI

enum LaneDodgeState {
    case calibrating
    case playing
    case gameOver
}

struct Obstacle: Identifiable {
    let id = UUID()
    let lane: Int
    var progress: CGFloat   // 0 = far (top), 1 = player line (bottom)
    let emoji: String
}

@Observable
final class LaneDodgeViewModel {
    // MARK: Config
    let laneCount = 3
    private let startingLives = 3

    /// Tilt past this many radians from neutral selects a side lane (~11°).
    private let laneThreshold: CGFloat = 0.20
    /// If true, positive roll maps to the right lane. Flipped on-device if needed.
    private let positiveRollIsRightLane = true

    /// Obstacle approach speed (progress units per second) at run start.
    private let baseSpeed: CGFloat = 0.45
    /// Added to speed per second survived (difficulty ramp).
    private let speedRampPerSecond: CGFloat = 0.03
    /// Seconds between spawns at run start.
    private let baseSpawnInterval: CGFloat = 1.3
    /// Spawn interval never drops below this (seconds).
    private let minSpawnInterval: CGFloat = 0.45
    /// How fast the spawn interval shrinks per second survived.
    private let spawnRampPerSecond: CGFloat = 0.04
    /// Progress at which an obstacle is at the player line.
    private let hitZone: CGFloat = 1.0
    private let obstacleEmojis = ["🪨", "🚧", "💥", "🛢️", "🚙"]

    // MARK: State
    var state: LaneDodgeState = .calibrating
    var lives: Int = 3
    var distance: Int = 0
    var playerLane: Int = 1
    var obstacles: [Obstacle] = []

    // MARK: Calibration
    private var calibrationSamples: [CGFloat] = []
    private var neutralRoll: CGFloat = 0

    // MARK: Runtime
    private var elapsed: CGFloat = 0
    private var timeSinceSpawn: CGFloat = 0
    /// Deterministic-ish spawn lane cursor; avoids Math.random (unavailable in
    /// some sandboxes and untestable). Uses a simple LCG seeded by spawn count.
    private var spawnCount: Int = 0

    func startCalibration() {
        state = .calibrating
        lives = startingLives
        distance = 0
        playerLane = 1
        obstacles = []
        calibrationSamples = []
        neutralRoll = 0
        elapsed = 0
        timeSinceSpawn = 0
        spawnCount = 0
    }

    /// Collect a roll reading during the calibration phase.
    func addCalibrationSample(roll: CGFloat?) {
        guard state == .calibrating, let roll else { return }
        calibrationSamples.append(roll)
    }

    /// Lock in the neutral roll and begin play. Falls back to 0 if no samples.
    func finishCalibration() {
        if !calibrationSamples.isEmpty {
            neutralRoll = calibrationSamples.reduce(0, +) / CGFloat(calibrationSamples.count)
        } else {
            neutralRoll = 0
        }
        state = .playing
    }
}
```

- [ ] **Step 2: Build (compile gate)**

Run the Standard build. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/pvacca/git/audrey
git add HotSeat/LaneDodgeViewModel.swift
git commit -m "feat: add LaneDodgeViewModel state types and calibration

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `LaneDodgeViewModel` — lane derivation, tick, spawn, collision

**Files:**
- Modify: `HotSeat/LaneDodgeViewModel.swift`

**Interfaces:**
- Consumes: all properties/constants from Task 3.
- Produces: `updatePlayerLane(roll:)`, `tick(delta:)`, `reset()`, and the private
  `spawnObstacle()` / `nextSpawnLane()` helpers relied on by Task 5's display loop.

- [ ] **Step 1: Add lane derivation**

Append to `LaneDodgeViewModel` (inside the class, after `finishCalibration`):

```swift
    /// Map a smoothed roll reading to a lane. No face → keep current lane.
    func updatePlayerLane(roll: CGFloat?) {
        guard state == .playing, let roll else { return }
        let delta = roll - neutralRoll
        let leftLane = 0
        let rightLane = laneCount - 1
        let centerLane = laneCount / 2

        if delta > laneThreshold {
            playerLane = positiveRollIsRightLane ? rightLane : leftLane
        } else if delta < -laneThreshold {
            playerLane = positiveRollIsRightLane ? leftLane : rightLane
        } else {
            playerLane = centerLane
        }
    }
```

- [ ] **Step 2: Add the spawn helpers**

Append:

```swift
    /// Linear-congruential lane picker — avoids Math.random, spreads lanes.
    private func nextSpawnLane() -> Int {
        spawnCount &+= 1
        let pseudo = (spawnCount &* 1103515245 &+ 12345) & 0x7fffffff
        return pseudo % laneCount
    }

    private func spawnObstacle() {
        let lane = nextSpawnLane()
        let emoji = obstacleEmojis[(spawnCount - 1) % obstacleEmojis.count]
        obstacles.append(Obstacle(lane: lane, progress: 0, emoji: emoji))
    }
```

- [ ] **Step 3: Add the tick loop (advance, spawn, collide, score)**

Append:

```swift
    /// Advance the simulation by `delta` seconds.
    func tick(delta: CGFloat) {
        guard state == .playing else { return }
        elapsed += delta
        distance += 1

        // Difficulty ramp.
        let speed = baseSpeed + speedRampPerSecond * elapsed
        let spawnInterval = max(minSpawnInterval, baseSpawnInterval - spawnRampPerSecond * elapsed)

        // Advance obstacles.
        for i in obstacles.indices {
            obstacles[i].progress += speed * delta
        }

        // Resolve obstacles that reached the player line.
        var survivors: [Obstacle] = []
        for obstacle in obstacles {
            if obstacle.progress >= hitZone {
                if obstacle.lane == playerLane {
                    lives -= 1
                }
                // Either way the obstacle is consumed (dodged or hit).
            } else {
                survivors.append(obstacle)
            }
        }
        obstacles = survivors

        // Spawn.
        timeSinceSpawn += delta
        if timeSinceSpawn >= spawnInterval {
            timeSinceSpawn = 0
            spawnObstacle()
        }

        // Fail state.
        if lives <= 0 {
            lives = 0
            state = .gameOver
        }
    }

    /// Restart a fresh run from calibration.
    func reset() {
        startCalibration()
    }
```

- [ ] **Step 4: Build (compile gate)**

Run the Standard build. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Manual logic trace (no test harness exists)**

Since there is no XCTest target, verify the logic by reading the tick path against
these invariants and confirming each holds in the code:
- A fresh `startCalibration()` sets `lives == 3`, `state == .calibrating`,
  `playerLane == 1`, empty `obstacles`.
- `finishCalibration()` with no samples sets `neutralRoll == 0` and
  `state == .playing` (does not crash on empty array).
- In `tick`, an obstacle with `progress >= 1.0` in `playerLane` decrements `lives`;
  in a different lane it is removed without penalty.
- `lives` reaching 0 sets `state == .gameOver` and clamps `lives` to 0.
- `spawnInterval` never drops below `minSpawnInterval`.

Confirm each by inspection. If any fails, fix before committing.

- [ ] **Step 6: Commit**

```bash
cd /Users/pvacca/git/audrey
git add HotSeat/LaneDodgeViewModel.swift
git commit -m "feat: add Lane Dodge tick loop, spawning, and collision

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: `LaneDodgeView` — rendering, display link, overlays

**Files:**
- Create: `HotSeat/LaneDodgeView.swift`

**Interfaces:**
- Consumes: `LaneDodgeViewModel` (Tasks 3–4), `FaceTracker.roll` (Task 2).
- Produces: `struct LaneDodgeView: View` with initializer
  `init(faceTracker: FaceTracker, onExit: @escaping () -> Void)` — consumed by
  Task 6's routing.

- [ ] **Step 1: Create the view shell with calibration + game-over states**

Create `HotSeat/LaneDodgeView.swift`:

```swift
import SwiftUI

struct LaneDodgeView: View {
    @State private var viewModel = LaneDodgeViewModel()
    let faceTracker: FaceTracker
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    // Calibration countdown (seconds).
    @State private var calibrationRemaining: CGFloat = 2.0
    // Display-link timing.
    @State private var lastTimestamp: CFTimeInterval = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                lanes(in: geo.size)
                obstacleLayer(in: geo.size)
                topBar
                if viewModel.state == .calibrating {
                    calibrationOverlay
                } else if viewModel.state == .gameOver {
                    gameOverCard
                }
                if viewModel.state == .playing && faceTracker.roll == nil {
                    noFaceHint
                }
            }
        }
        .onAppear {
            viewModel.startCalibration()
            calibrationRemaining = 2.0
            lastTimestamp = 0
        }
        .onChange(of: faceTracker.roll) { _, newRoll in
            if viewModel.state == .calibrating {
                viewModel.addCalibrationSample(roll: newRoll)
            } else {
                viewModel.updatePlayerLane(roll: newRoll)
            }
        }
        .modifier(DisplayLinkModifier { timestamp in
            advance(to: timestamp)
        })
    }

    // MARK: - Tick driver

    private func advance(to timestamp: CFTimeInterval) {
        guard lastTimestamp != 0 else { lastTimestamp = timestamp; return }
        let delta = CGFloat(timestamp - lastTimestamp)
        lastTimestamp = timestamp

        switch viewModel.state {
        case .calibrating:
            calibrationRemaining -= delta
            if calibrationRemaining <= 0 {
                viewModel.finishCalibration()
            }
        case .playing:
            viewModel.tick(delta: delta)
        case .gameOver:
            break
        }
    }
}
```

- [ ] **Step 2: Add the `DisplayLinkModifier`**

Append to `HotSeat/LaneDodgeView.swift` (a reusable `CADisplayLink` bridge —
SwiftUI has no built-in per-frame callback):

```swift
/// Drives a per-frame callback using CADisplayLink for smooth animation.
private struct DisplayLinkModifier: ViewModifier {
    let onFrame: (CFTimeInterval) -> Void

    func body(content: Content) -> some View {
        content.background(DisplayLinkView(onFrame: onFrame))
    }
}

private struct DisplayLinkView: UIViewRepresentable {
    let onFrame: (CFTimeInterval) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        context.coordinator.start()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onFrame = onFrame
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFrame: onFrame) }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var onFrame: (CFTimeInterval) -> Void
        private var link: CADisplayLink?

        init(onFrame: @escaping (CFTimeInterval) -> Void) {
            self.onFrame = onFrame
        }

        func start() {
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        func stop() {
            link?.invalidate()
            link = nil
        }

        @objc private func step(_ link: CADisplayLink) {
            onFrame(link.timestamp)
        }
    }
}
```

- [ ] **Step 3: Add the lanes, obstacle layer, and player highlight**

Append the rendering helpers as a `LaneDodgeView` extension:

```swift
private extension LaneDodgeView {
    func laneWidth(in size: CGSize) -> CGFloat {
        size.width / CGFloat(viewModel.laneCount)
    }

    func laneCenterX(_ lane: Int, in size: CGSize) -> CGFloat {
        laneWidth(in: size) * (CGFloat(lane) + 0.5)
    }

    @ViewBuilder
    func lanes(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<viewModel.laneCount, id: \.self) { lane in
                let isPlayer = lane == viewModel.playerLane && viewModel.state == .playing
                Rectangle()
                    .fill(isPlayer ? Color.white.opacity(0.18) : Color.white.opacity(0.04))
                    .overlay(
                        Rectangle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .frame(width: laneWidth(in: size))
                    .position(x: laneCenterX(lane, in: size), y: size.height / 2)
                    .animation(.easeOut(duration: 0.12), value: viewModel.playerLane)
            }

            // Player line near the bottom — where obstacles must be dodged.
            if viewModel.state == .playing {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 22, height: 22)
                    .shadow(color: .white.opacity(0.6), radius: 8)
                    .position(
                        x: laneCenterX(viewModel.playerLane, in: size),
                        y: size.height * 0.82
                    )
                    .animation(.easeOut(duration: 0.12), value: viewModel.playerLane)
            }
        }
    }

    @ViewBuilder
    func obstacleLayer(in size: CGSize) -> some View {
        ForEach(viewModel.obstacles) { obstacle in
            let y = size.height * 0.82 * obstacle.progress
            let scale = 0.6 + 0.6 * obstacle.progress
            Text(obstacle.emoji)
                .font(.system(size: isCompact ? 44 : 64))
                .scaleEffect(scale)
                .position(x: laneCenterX(obstacle.lane, in: size), y: y)
        }
    }
}
```

- [ ] **Step 4: Add the top bar, calibration overlay, game-over card, no-face hint**

Append a second `LaneDodgeView` extension:

```swift
private extension LaneDodgeView {
    var topBar: some View {
        VStack {
            HStack {
                Button(action: onExit) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Games")
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, isCompact ? 12 : 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()

                if viewModel.state == .playing {
                    Text("\(viewModel.distance)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < viewModel.lives ? "heart.fill" : "heart")
                            .foregroundStyle(i < viewModel.lives ? .red : .white.opacity(0.4))
                    }
                }
                .font(.title3)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)

            Spacer()
        }
    }

    var calibrationOverlay: some View {
        VStack(spacing: 16) {
            Text("Hold your head still")
                .font(.system(size: isCompact ? 28 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Tilt left or right to change lanes")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text("\(max(1, Int(calibrationRemaining.rounded(.up))))")
                .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(isCompact ? 24 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    var gameOverCard: some View {
        VStack(spacing: 16) {
            Text("Crashed!")
                .font(.system(size: isCompact ? 28 : 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Distance: \(viewModel.distance)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: isCompact ? 12 : 16) {
                Button("Play again") {
                    viewModel.reset()
                    calibrationRemaining = 2.0
                    lastTimestamp = 0
                }
                .font(.title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32)
                .padding(.vertical, 14)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(Capsule())

                Button("Games", action: onExit)
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, isCompact ? 20 : 32)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(isCompact ? 24 : 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    var noFaceHint: some View {
        VStack {
            Spacer()
            Text("Show your face to steer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 40)
        }
    }
}
```

- [ ] **Step 5: Build (compile gate)**

Run the Standard build. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
cd /Users/pvacca/git/audrey
git add HotSeat/LaneDodgeView.swift
git commit -m "feat: add LaneDodgeView with lanes, obstacles, and display-link tick

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Wire Lane Dodge into navigation and home screen

**Files:**
- Modify: `HotSeat/ContentView.swift` (`AppScreen`, `AppViewModel`, routing switch)
- Modify: `HotSeat/HomeView.swift` (new game tile + callback)

**Interfaces:**
- Consumes: `LaneDodgeView(faceTracker:onExit:)` (Task 5), `FaceTracker` (Task 2).
- Produces: `AppScreen.laneDodge`, `AppViewModel.openLaneDodge()`,
  `HomeView` `onSelectLaneDodge` callback.

- [ ] **Step 1: Add the `AppScreen` case and `AppViewModel` method**

In `HotSeat/ContentView.swift`, change:

```swift
enum AppScreen {
    case home
    case rank
    case speedTap
}
```

to:

```swift
enum AppScreen {
    case home
    case rank
    case speedTap
    case laneDodge
}
```

and add to `AppViewModel` (next to `openSpeedTap`):

```swift
    func openLaneDodge() { screen = .laneDodge }
```

- [ ] **Step 2: Route the new screen**

In `ContentView`'s main `switch appViewModel.screen`, add a case after `.speedTap`:

```swift
            case .laneDodge:
                LaneDodgeView(
                    faceTracker: faceTracker,
                    onExit: {
                        withAnimation(.spring(duration: 0.3)) {
                            appViewModel.goHome()
                        }
                    }
                )
```

- [ ] **Step 3: Read the `HomeView` interface, then add the tile**

First inspect the current tile/callback shape:

```bash
cd /Users/pvacca/git/audrey
sed -n '1,80p' HotSeat/HomeView.swift
```

`HomeView` currently takes `onSelectRank` and `onSelectSpeedTap` closures and
renders a tile per game. Add a third parameter `onSelectLaneDodge: () -> Void` to
the `HomeView` signature, and add a matching game tile following the **exact**
pattern the existing Speed Tap tile uses (same container, font, padding — copy that
tile's code and change its emoji to `🚗`, its title to `Lane Dodge`, its subtitle to
match the existing subtitle style, and its action to `onSelectLaneDodge`). Do not
invent a new tile style; mirror the existing one so the home screen stays uniform.

- [ ] **Step 4: Pass the new callback from `ContentView`**

In `ContentView`, update the `HomeView(...)` call in the `.home` case to pass the
new closure alongside the existing ones:

```swift
                HomeView(
                    onSelectRank: {
                        viewModel.startRank()
                        appViewModel.openRank()
                    },
                    onSelectSpeedTap: {
                        appViewModel.openSpeedTap()
                    },
                    onSelectLaneDodge: {
                        appViewModel.openLaneDodge()
                    }
                )
```

- [ ] **Step 5: Build (compile gate)**

Run the Standard build. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
cd /Users/pvacca/git/audrey
git add HotSeat/ContentView.swift HotSeat/HomeView.swift
git commit -m "feat: wire Lane Dodge into navigation and home screen

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: On-device verification

**Files:** none (manual verification on hardware).

**Interfaces:** Consumes the fully wired app from Tasks 1–6.

- [ ] **Step 1: Build and install on Thorin16**

```bash
cd /Users/pvacca/git/audrey
xcodebuild -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug \
  -destination 'platform=iOS,id=00008140-00065C5A14D1801C' \
  -derivedDataPath build -allowProvisioningUpdates build 2>&1 | tail -5
xcrun devicectl device install app --device 00008140-00065C5A14D1801C \
  build/Build/Products/Debug-iphoneos/HotSeat.app 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **` then `App installed:`.

- [ ] **Step 2: Manual checks (perform on the device, report results)**

- Home screen shows the Lane Dodge tile; tapping it opens the game.
- Calibration overlay shows "Hold your head still" with a countdown, then play
  starts.
- Head level → player highlight in center lane; tilt left/right moves it.
- **Verify tilt direction is correct.** If tilting left moves the player right
  (mirroring inversion), set `positiveRollIsRightLane = false` in
  `LaneDodgeViewModel`, rebuild, reinstall.
- Obstacles approach in lanes; being in the obstacle's lane at the bottom costs a
  heart; a clear lane passes safely.
- Three hits → "Crashed!" card with distance; "Play again" recalibrates and
  restarts; "Games" returns home.
- Speed/spawn rate visibly increase over a ~30s run.
- Hot Take still tracks the forehead (regression check on the shared camera view).

- [ ] **Step 3: Commit any tuning changes**

If `positiveRollIsRightLane` or any tuning constant was adjusted:

```bash
cd /Users/pvacca/git/audrey
git add HotSeat/LaneDodgeViewModel.swift
git commit -m "fix: correct Lane Dodge tilt mapping / tuning after device test

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Guardrail amendment → Task 1. ✓
- `FaceReading` struct + roll from Vision → Task 2. ✓
- Calibration (2s neutral capture) → Tasks 3 (logic) + 5 (countdown UI). ✓
- Lane mapping w/ threshold + mirror-inversion flag → Task 4 + Task 7 verify. ✓
- 3 lanes, obstacles by (lane, progress), tick loop, spawn → Task 4. ✓
- 3 lives, collision, game over → Task 4. ✓
- Distance score → Task 4 (`distance`) + Task 5 (display). ✓
- Difficulty ramp (speed + spawn) → Task 4. ✓
- Emoji obstacles, translucent lanes, glowing player lane → Task 5. ✓
- Hearts + distance top bar, calibration overlay, game-over card, no-face hint
  → Task 5. ✓
- Routing (`AppScreen`/`AppViewModel`) + home tile → Task 6. ✓
- No audio / no persistence / no avatar → honored (not built). ✓
- Simulator compile gate + device manual verification → every task + Task 7. ✓

**Placeholder scan:** No TBD/TODO; the one "inspect existing code" step (Task 6
Step 3) is a deliberate read of `HomeView` to copy its tile pattern, with explicit
instructions on what to change — not a vague placeholder.

**Type consistency:** `FaceReading.foreheadPoint`/`.roll`, `onReadingChange`,
`FaceTracker.roll`, `LaneDodgeState`, `Obstacle(lane:progress:emoji:)`,
`startCalibration()`/`addCalibrationSample(roll:)`/`finishCalibration()`/
`updatePlayerLane(roll:)`/`tick(delta:)`/`reset()`, `playerLane`, `laneCount`,
`positiveRollIsRightLane`, `LaneDodgeView(faceTracker:onExit:)`,
`AppScreen.laneDodge`, `openLaneDodge()` — names consistent across Tasks 2–6.
