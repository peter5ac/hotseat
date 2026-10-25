# Face Tug-of-War Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local 2-player "Face Tug-of-War" game where two players drag a rope by leaning their heads, built on the existing shared front-camera Vision pipeline.

**Architecture:** Extend the single shared `AVCaptureSession`/Vision pass (no second camera). `FaceReading` gains a sorted `faceCentersX: [CGFloat]` (up to 2 faces); `FaceTracker` republishes it; a new `TugOfWarViewModel` integrates per-player lean into a `ropeProgress` over time via a `CADisplayLink`; a new `TugOfWarView` renders the rope and overlays. Wiring mirrors how Lane Dodge was added.

**Tech Stack:** SwiftUI (iOS 17+, Swift 5), `@Observable`, AVFoundation (`AVCaptureVideoDataOutput`), Vision (`VNDetectFaceRectanglesRequest`), `CADisplayLink`.

## Global Constraints

- **No second `AVCaptureSession`.** Only the existing shared `CameraPreviewView` captures. Tug-of-War reads face data through `FaceReading`/`FaceTracker`. (verbatim spec requirement)
- **Hot Take and Lane Dodge must not regress.** `foreheadPoint` and `roll` continue to derive from the single largest face. (verbatim spec requirement)
- `ropeProgress: CGFloat`, range **−1.0...+1.0**, starts **0.0**. **−1.0 = Player 1 wins, +1.0 = Player 2 wins, 0.0 = dead center.** (verbatim spec requirement)
- **Player 1 = lower X = left; Player 2 = higher X = right.** `faceCentersX` is sorted ascending. (verbatim spec requirement)
- `faceCentersX` holds **normalized Vision X** (`box.midX`, 0...1), NOT a converted screen point. Mirroring is already applied at the capture connection.
- **Up to 2 faces only.** Zero → empty array; one → one element; two+ → the two largest faces, sorted by X.
- Smoothing: per-element low-pass with the existing factor **0.35**; reset smoothing state when the detected face count changes.
- **Face loss → freeze:** if either player's X is absent, `tick` makes no change to `ropeProgress`.
- **Pull model (accumulate):** `ropeProgress += (p2Lean − p1Lean) * pullRate * delta`, clamped to [−1, 1], where `p1Lean = max(0, neutralX1 − player1X)`, `p2Lean = max(0, player2X − neutralX2)`.
- **No audio, no persistence, no rounds, no custom names, ≤2 players** (YAGNI scope cuts).
- **Visual language:** `.ultraThinMaterial`, rounded, white-on-dim, capsule back button — match Speed Tap / Lane Dodge exactly.
- **No XCTest target exists by design.** Per-task verification is the device compile gate: `xcodebuild -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build -allowProvisioningUpdates`, expecting `** BUILD SUCCEEDED **`. Plus targeted on-device manual testing at the end.
- **Commit after each task.** End commit messages with the Co-Authored-By trailer used in this repo.

---

## File Structure

- **New** `HotSeat/TugOfWarViewModel.swift` — `@Observable` game model: state machine, calibration, `ropeProgress` integration, win detection. No SwiftUI view code.
- **New** `HotSeat/TugOfWarView.swift` — SwiftUI view: rope/center-line/indicator rendering, countdown + win overlays, `CADisplayLink` tick driver. Owns its own private `DisplayLinkModifier`/`DisplayLinkView` copy (Lane Dodge's are `private` to that file).
- **Modify** `HotSeat/CameraPreviewView.swift` — add `faceCentersX` to `FaceReading`; emit the two largest faces' sorted X-centers with smoothing.
- **Modify** `HotSeat/ContentView.swift` — `FaceTracker.faceCentersX`; `AppScreen.tugOfWar`; `AppViewModel.openTugOfWar()`; camera-closure assignment; `.tugOfWar` routing; `HomeView` call gains `onSelectTugOfWar`.
- **Modify** `HotSeat/HomeView.swift` — `onSelectTugOfWar` param, `allGames` entry, tile + wheel switch cases.
- **Modify** `HotSeat.xcodeproj/project.pbxproj` — register the two new files (IDs `A1000012`/`A2000012`, `A1000013`/`A2000013`).

---

### Task 1: Emit `faceCentersX` from the camera (shared pipeline)

**Files:**
- Modify: `HotSeat/CameraPreviewView.swift`
- Modify: `HotSeat/ContentView.swift` (the `FaceTracker` consumer-side field only)

**Interfaces:**
- Consumes: existing `FaceReading`, `captureOutput`, `emit`, `smoothing` (0.35); existing `FaceTracker`.
- Produces: `FaceReading.faceCentersX: [CGFloat]` — normalized X-centers, up to 2, sorted ascending. New emit signature `emit(_ raw: CGPoint?, roll: CGFloat?, centersX: [CGFloat])`. `FaceTracker.faceCentersX: [CGFloat]` (default `[]`) — the consumer-side half of the same channel, read by `TugOfWarView` in Task 4.

This task is the one regression risk in the project — Hot Take and Lane Dodge read `foreheadPoint`/`roll`, which MUST keep deriving from the single largest face. Only the new `faceCentersX` field is added.

- [ ] **Step 1: Add the field to `FaceReading`**

In `HotSeat/CameraPreviewView.swift`, replace the struct:

```swift
/// A single frame's face-derived signals, emitted on the main thread.
/// `nil` fields mean "no face detected" for that signal.
struct FaceReading {
    var foreheadPoint: CGPoint?   // top-center of the largest face box, view coordinates
    var roll: CGFloat?            // head tilt in radians (largest face's VNFaceObservation.roll)
    var faceCentersX: [CGFloat]   // normalized X-centers (0...1) of up to 2 faces, sorted ascending
}
```

- [ ] **Step 2: Add a smoothing-state field for the centers**

Next to `private var smoothedRoll: CGFloat?` add:

```swift
    /// Low-pass-filtered, sorted normalized X-centers of up to 2 faces.
    /// Reset (not blended) when the detected face count changes.
    private var smoothedCentersX: [CGFloat] = []
```

- [ ] **Step 3: Compute the two largest faces' sorted X-centers in `captureOutput`**

In `captureOutput`, the existing code computes `largest` and the single-face `box`/`roll`. Keep all of that unchanged. Replace the no-face `guard let face = largest else { ... }` block and the trailing main-thread dispatch so BOTH the largest-face values and the centers are computed. Concretely:

Find:

```swift
        guard let face = largest else {
            DispatchQueue.main.async { [weak self] in self?.emit(nil, roll: nil) }
            return
        }

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

Replace with:

```swift
        let faces = (faceRequest.results as? [VNFaceObservation]) ?? []

        // Two largest faces by area, then their normalized X-centers sorted ascending.
        let twoLargest = faces
            .sorted { ($0.boundingBox.width * $0.boundingBox.height)
                    > ($1.boundingBox.width * $1.boundingBox.height) }
            .prefix(2)
        let centersX = twoLargest
            .map { $0.boundingBox.midX }
            .sorted()

        guard let face = largest else {
            DispatchQueue.main.async { [weak self] in self?.emit(nil, roll: nil, centersX: []) }
            return
        }

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
            self.emit(point, roll: roll, centersX: centersX)
        }
```

- [ ] **Step 4: Update the error and no-face emit calls**

In the same function there is a `catch` block that calls `emit(nil, roll: nil)`. Change it to:

```swift
        } catch {
            DispatchQueue.main.async { [weak self] in self?.emit(nil, roll: nil, centersX: []) }
            return
        }
```

- [ ] **Step 5: Update `emit` to smooth and forward the centers**

Replace the `emit` signature and body. The forehead/roll smoothing is unchanged; add per-element center smoothing that resets when the count changes:

```swift
    /// Applies jitter smoothing to the forehead point, roll, and face centers, forwards upstream.
    private func emit(_ raw: CGPoint?, roll: CGFloat?, centersX: [CGFloat]) {
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

        // Face-centers smoothing: blend element-wise only when the count matches;
        // otherwise snap to the new readings (a count change is not a continuous motion).
        if centersX.count == smoothedCentersX.count {
            smoothedCentersX = zip(smoothedCentersX, centersX).map { prev, new in
                prev + (new - prev) * smoothing
            }
        } else {
            smoothedCentersX = centersX
        }

        onReadingChange?(FaceReading(
            foreheadPoint: smoothedPoint,
            roll: smoothedRoll,
            faceCentersX: smoothedCentersX
        ))
    }
```

- [ ] **Step 6: Add `faceCentersX` to `FaceTracker`**

In `HotSeat/ContentView.swift`, in `final class FaceTracker`, after `var roll: CGFloat?` add:
```swift
    /// Normalized X-centers (0...1) of up to 2 detected faces, sorted ascending.
    var faceCentersX: [CGFloat] = []
```

- [ ] **Step 7: Build (compile gate)**

Run:
```bash
xcodebuild -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build -allowProvisioningUpdates 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`. (SourceKit "cannot find type UIView" diagnostics from the indexer are noise — trust xcodebuild.)

- [ ] **Step 8: Commit**

```bash
git add HotSeat/CameraPreviewView.swift HotSeat/ContentView.swift
git commit -m "feat: emit sorted face X-centers (up to 2) from camera

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `TugOfWarViewModel` — state, calibration, input setter

**Files:**
- Create: `HotSeat/TugOfWarViewModel.swift`
- Modify: `HotSeat.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: nothing (pure model).
- Produces: `enum TugOfWarState { case calibrating, playing, gameOver }`; `@Observable final class TugOfWarViewModel` with `ropeProgress: CGFloat`, `state`, `winnerName: String?`, derived `isGameOver`/`isCountingDown`, `laneCount`-free; methods `startCalibration()`, `updateRopePosition(player1X:player2X:)`, `finishCalibration()`, `tick(delta:)`, `reset()`. This task delivers everything EXCEPT the `tick` integration body (Task 3 fills it).

- [ ] **Step 1: Create the file with state + calibration**

Create `HotSeat/TugOfWarViewModel.swift`:

```swift
import SwiftUI

enum TugOfWarState {
    case calibrating
    case playing
    case gameOver
}

@Observable
final class TugOfWarViewModel {
    // MARK: Config
    /// How fast accumulated lean converts to rope movement. Tuned on-device.
    private let pullRate: CGFloat = 6.0

    // MARK: State
    var state: TugOfWarState = .calibrating
    /// -1.0 = Player 1 (left) wins, +1.0 = Player 2 (right) wins, 0.0 = center.
    var ropeProgress: CGFloat = 0.0
    var winnerName: String?

    var isGameOver: Bool { state == .gameOver }
    var isCountingDown: Bool { state == .calibrating }

    // MARK: Calibration
    private var samples1: [CGFloat] = []
    private var samples2: [CGFloat] = []
    private var neutralX1: CGFloat = 0.5
    private var neutralX2: CGFloat = 0.5

    // MARK: Live readings (set by updateRopePosition, integrated by tick)
    private var currentX1: CGFloat?
    private var currentX2: CGFloat?

    func startCalibration() {
        state = .calibrating
        ropeProgress = 0.0
        winnerName = nil
        samples1 = []
        samples2 = []
        neutralX1 = 0.5
        neutralX2 = 0.5
        currentX1 = nil
        currentX2 = nil
    }

    /// Feed the latest pair of normalized X readings. During calibration this
    /// collects neutral samples (only when BOTH faces are present); during play
    /// it stores the readings for the next `tick`.
    func updateRopePosition(player1X: CGFloat?, player2X: CGFloat?) {
        switch state {
        case .calibrating:
            if let p1 = player1X, let p2 = player2X {
                samples1.append(p1)
                samples2.append(p2)
            }
        case .playing:
            currentX1 = player1X
            currentX2 = player2X
        case .gameOver:
            break
        }
    }

    /// Lock in each player's neutral X and begin play. Falls back to 0.5 if a
    /// player produced no samples.
    func finishCalibration() {
        if !samples1.isEmpty {
            neutralX1 = samples1.reduce(0, +) / CGFloat(samples1.count)
        }
        if !samples2.isEmpty {
            neutralX2 = samples2.reduce(0, +) / CGFloat(samples2.count)
        }
        state = .playing
    }

    func reset() {
        startCalibration()
    }
}
```

(`tick(delta:)` is added in Task 3 — do not call it yet.)

- [ ] **Step 2: Register the file in `project.pbxproj` (PBXBuildFile)**

In `HotSeat.xcodeproj/project.pbxproj`, after the line:
```
		A1000011 /* LaneDodgeView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000011 /* LaneDodgeView.swift */; };
```
add:
```
		A1000012 /* TugOfWarViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000012 /* TugOfWarViewModel.swift */; };
```

- [ ] **Step 3: Register the file (PBXFileReference)**

After:
```
		A2000011 /* LaneDodgeView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LaneDodgeView.swift; sourceTree = "<group>"; };
```
add:
```
		A2000012 /* TugOfWarViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TugOfWarViewModel.swift; sourceTree = "<group>"; };
```

- [ ] **Step 4: Register the file (PBXGroup children)**

After:
```
				A2000011 /* LaneDodgeView.swift */,
```
add:
```
				A2000012 /* TugOfWarViewModel.swift */,
```

- [ ] **Step 5: Register the file (Sources build phase)**

After:
```
				A1000011 /* LaneDodgeView.swift in Sources */,
```
add:
```
				A1000012 /* TugOfWarViewModel.swift in Sources */,
```

- [ ] **Step 6: Build (compile gate)**

Run:
```bash
xcodebuild -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build -allowProvisioningUpdates 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add HotSeat/TugOfWarViewModel.swift HotSeat.xcodeproj/project.pbxproj
git commit -m "feat: add TugOfWarViewModel state, calibration, input setter

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `TugOfWarViewModel.tick` — accumulate pull and detect the win

**Files:**
- Modify: `HotSeat/TugOfWarViewModel.swift`

**Interfaces:**
- Consumes: `currentX1`, `currentX2`, `neutralX1`, `neutralX2`, `pullRate`, `ropeProgress`, `state`, `winnerName` (all from Task 2).
- Produces: `func tick(delta: CGFloat)` — integrates lean into `ropeProgress`, clamps to [−1, 1], sets `winnerName` and `.gameOver` at the bounds. Freezes when either reading is nil.

- [ ] **Step 1: Add `tick(delta:)`**

In `HotSeat/TugOfWarViewModel.swift`, add this method to `TugOfWarViewModel` (after `finishCalibration()`):

```swift
    /// Advance the rope by `delta` seconds. Player 1 pulls left (toward -1) by
    /// leaning toward their edge (lower X); Player 2 pulls right (toward +1) by
    /// leaning toward their edge (higher X). Freezes if either face is missing.
    func tick(delta: CGFloat) {
        guard state == .playing else { return }
        guard let x1 = currentX1, let x2 = currentX2 else { return }   // face loss → freeze

        let p1Lean = max(0, neutralX1 - x1)   // P1 leaning left, toward their edge
        let p2Lean = max(0, x2 - neutralX2)   // P2 leaning right, toward their edge

        ropeProgress += (p2Lean - p1Lean) * pullRate * delta
        ropeProgress = min(1.0, max(-1.0, ropeProgress))

        if ropeProgress <= -1.0 {
            ropeProgress = -1.0
            winnerName = "Player 1"
            state = .gameOver
        } else if ropeProgress >= 1.0 {
            ropeProgress = 1.0
            winnerName = "Player 2"
            state = .gameOver
        }
    }
```

- [ ] **Step 2: Build (compile gate)**

Run:
```bash
xcodebuild -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build -allowProvisioningUpdates 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add HotSeat/TugOfWarViewModel.swift
git commit -m "feat: add Tug-of-War rope accumulation and win detection

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `TugOfWarView` — rope rendering, overlays, display-link tick

**Files:**
- Create: `HotSeat/TugOfWarView.swift`
- Modify: `HotSeat.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `TugOfWarViewModel` (Task 2/3); `FaceTracker.faceCentersX: [CGFloat]` (added in Task 1 Step 6).
- Produces: `struct TugOfWarView: View` with `let faceTracker: FaceTracker`, `let onExit: () -> Void`.

- [ ] **Step 1: Create the view file**

Create `HotSeat/TugOfWarView.swift`:

```swift
import SwiftUI

struct TugOfWarView: View {
    @State private var viewModel = TugOfWarViewModel()
    let faceTracker: FaceTracker
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    // Calibration countdown (seconds).
    @State private var calibrationRemaining: CGFloat = 3.0
    // Display-link timing.
    @State private var lastTimestamp: CFTimeInterval = 0

    private var player1X: CGFloat? {
        faceTracker.faceCentersX.count >= 2 ? faceTracker.faceCentersX[0] : nil
    }
    private var player2X: CGFloat? {
        faceTracker.faceCentersX.count >= 2 ? faceTracker.faceCentersX[1] : nil
    }
    private var hasBothFaces: Bool {
        faceTracker.faceCentersX.count >= 2
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                centerLine(in: geo.size)
                ropeTrack(in: geo.size)
                topBar
                if viewModel.state == .calibrating {
                    countdownOverlay
                } else if viewModel.state == .gameOver {
                    winOverlay
                }
                if !hasBothFaces && viewModel.state != .gameOver {
                    twoFaceHint
                }
            }
        }
        .onAppear {
            viewModel.startCalibration()
            calibrationRemaining = 3.0
            lastTimestamp = 0
        }
        .onChange(of: faceTracker.faceCentersX) { _, _ in
            viewModel.updateRopePosition(player1X: player1X, player2X: player2X)
        }
        .modifier(TugDisplayLinkModifier { timestamp in
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
            // Only count down while both faces are present, so players have time to settle.
            if hasBothFaces {
                calibrationRemaining -= delta
                if calibrationRemaining <= 0 {
                    viewModel.finishCalibration()
                }
            }
        case .playing:
            viewModel.tick(delta: delta)
        case .gameOver:
            break
        }
    }
}

/// Drives a per-frame callback using CADisplayLink. Private copy for this view
/// (Lane Dodge's equivalent is file-private to LaneDodgeView.swift).
private struct TugDisplayLinkModifier: ViewModifier {
    let onFrame: (CFTimeInterval) -> Void

    func body(content: Content) -> some View {
        content.background(TugDisplayLinkView(onFrame: onFrame))
    }
}

private struct TugDisplayLinkView: UIViewRepresentable {
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

// MARK: - Rope + center line

private extension TugOfWarView {
    private var player1Color: Color { .cyan }
    private var player2Color: Color { .orange }

    @ViewBuilder
    func centerLine(in size: CGSize) -> some View {
        ZStack {
            // Player territory tints.
            HStack(spacing: 0) {
                player1Color.opacity(0.12)
                player2Color.opacity(0.12)
            }
            // Center divider.
            Rectangle()
                .fill(.white.opacity(0.5))
                .frame(width: 3)
                .position(x: size.width / 2, y: size.height / 2)
        }
    }

    @ViewBuilder
    func ropeTrack(in size: CGSize) -> some View {
        let halfWidth = size.width / 2
        let centerY = size.height / 2
        ZStack {
            // Horizontal rope track.
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: size.width * 0.9, height: 8)
                .position(x: size.width / 2, y: centerY)

            // Indicator node — slides left/right with ropeProgress.
            Circle()
                .fill(viewModel.ropeProgress < 0 ? player1Color : player2Color)
                .frame(width: isCompact ? 44 : 60, height: isCompact ? 44 : 60)
                .shadow(color: .white.opacity(0.6), radius: 10)
                .overlay(Text("🪢").font(.system(size: isCompact ? 24 : 32)))
                .position(x: size.width / 2, y: centerY)
                .offset(x: viewModel.ropeProgress * halfWidth)
                .animation(.linear(duration: 0.08), value: viewModel.ropeProgress)
        }
    }
}

// MARK: - Bars and overlays

private extension TugOfWarView {
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
                Text("Tug-of-War")
                    .font(isCompact ? .footnote.weight(.semibold) : .title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)
            Spacer()
        }
    }

    var countdownOverlay: some View {
        VStack(spacing: 16) {
            Text("Lean to pull!")
                .font(.system(size: isCompact ? 28 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(hasBothFaces ? "Get ready…" : "Both players, get on screen")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text(calibrationRemaining > 0 ? "\(max(1, Int(calibrationRemaining.rounded(.up))))" : "GO!")
                .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(isCompact ? 24 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    var winOverlay: some View {
        VStack(spacing: 20) {
            Text("\(viewModel.winnerName ?? "Player") WINS!")
                .font(.system(size: isCompact ? 36 : 56, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)

            HStack(spacing: isCompact ? 12 : 16) {
                Button("Rematch") {
                    viewModel.reset()
                    calibrationRemaining = 3.0
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
        .padding(isCompact ? 28 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

    var twoFaceHint: some View {
        VStack {
            Spacer()
            Text("Show both faces")
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

- [ ] **Step 2: Register the file in `project.pbxproj` (PBXBuildFile)**

After:
```
		A1000012 /* TugOfWarViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000012 /* TugOfWarViewModel.swift */; };
```
add:
```
		A1000013 /* TugOfWarView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000013 /* TugOfWarView.swift */; };
```

- [ ] **Step 3: Register the file (PBXFileReference)**

After:
```
		A2000012 /* TugOfWarViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TugOfWarViewModel.swift; sourceTree = "<group>"; };
```
add:
```
		A2000013 /* TugOfWarView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TugOfWarView.swift; sourceTree = "<group>"; };
```

- [ ] **Step 4: Register the file (PBXGroup children)**

After:
```
				A2000012 /* TugOfWarViewModel.swift */,
```
add:
```
				A2000013 /* TugOfWarView.swift */,
```

- [ ] **Step 5: Register the file (Sources build phase)**

After:
```
				A1000012 /* TugOfWarViewModel.swift in Sources */,
```
add:
```
				A1000013 /* TugOfWarView.swift in Sources */,
```

- [ ] **Step 6: Build (compile gate)**

`FaceTracker.faceCentersX` was added in Task 1 Step 6. Build:
```bash
xcodebuild -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build -allowProvisioningUpdates 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add HotSeat/TugOfWarView.swift HotSeat.xcodeproj/project.pbxproj
git commit -m "feat: add TugOfWarView with rope, overlays, and display-link tick

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Wire Tug-of-War into navigation and home

**Files:**
- Modify: `HotSeat/ContentView.swift`
- Modify: `HotSeat/HomeView.swift`

**Interfaces:**
- Consumes: `TugOfWarView(faceTracker:onExit:)` (Task 4); `FaceTracker.faceCentersX` (added in Task 1 Step 6).
- Produces: `AppScreen.tugOfWar`; `AppViewModel.openTugOfWar()`; `HomeView` gains `onSelectTugOfWar: () -> Void`.

(`FaceTracker.faceCentersX` was added in Task 1 Step 6 — no action needed here.)

- [ ] **Step 1: Add the `.tugOfWar` screen case and open method**

In `HotSeat/ContentView.swift`, change the enum:
```swift
enum AppScreen {
    case home
    case rank
    case speedTap
    case laneDodge
    case tugOfWar
}
```
and add to `AppViewModel`, after `openLaneDodge()`:
```swift
    func openTugOfWar() {
        screen = .tugOfWar
    }
```

- [ ] **Step 2: Assign `faceCentersX` in the camera closure**

In `HotSeat/ContentView.swift`, in `ContentView.body`, update the `CameraPreviewView` closure:
```swift
            CameraPreviewView { reading in
                faceTracker.foreheadPoint = reading.foreheadPoint
                faceTracker.roll = reading.roll
                faceTracker.faceCentersX = reading.faceCentersX
            }
            .ignoresSafeArea()
```

- [ ] **Step 3: Route the `.tugOfWar` case**

In the `switch appViewModel.screen` block, after the `.laneDodge` case, add:
```swift
            case .tugOfWar:
                TugOfWarView(
                    faceTracker: faceTracker,
                    onExit: {
                        withAnimation(.spring(duration: 0.3)) {
                            appViewModel.goHome()
                        }
                    }
                )
```

- [ ] **Step 4: Pass `onSelectTugOfWar` into `HomeView`**

In the `.home` case, update the `HomeView(...)` call to add the new closure after `onSelectLaneDodge`:
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
                    },
                    onSelectTugOfWar: {
                        appViewModel.openTugOfWar()
                    }
                )
```

- [ ] **Step 5: Add the `onSelectTugOfWar` param to `HomeView`**

In `HotSeat/HomeView.swift`, after `let onSelectLaneDodge: () -> Void`:
```swift
    let onSelectTugOfWar: () -> Void
```

- [ ] **Step 6: Add the game to `allGames`**

In `HotSeat/HomeView.swift`, replace the `allGames` array's trailing entries so Tug-of-War appears before the "coming soon" placeholder:
```swift
let allGames: [Game] = [
    Game(id: "hotTake", name: "Hot Take", emoji: "🏆", icon: "HotTakeIcon", isAvailable: true),
    Game(id: "speedTap", name: "Speed Tap", emoji: "⚡", icon: nil, isAvailable: true),
    Game(id: "laneDodge", name: "Lane Dodge", emoji: "🚗", icon: nil, isAvailable: true),
    Game(id: "tugOfWar", name: "Tug-of-War", emoji: "🪢", icon: nil, isAvailable: true),
    Game(id: "soon1", name: "New game coming soon", emoji: "✨", icon: nil, isAvailable: false),
]
```

- [ ] **Step 7: Handle the new id in the tile switch**

In `gameTile(_:)`, in the `switch game.id` block, after the `case "laneDodge":` line add:
```swift
                case "tugOfWar":
                    onSelectTugOfWar()
```

- [ ] **Step 8: Handle the new id in the spin-wheel switch**

In the `SpinWheelView` `onLanded` `switch landed.id` block, after the `laneDodge` case:
```swift
                        case "tugOfWar":
                            withAnimation(.spring(duration: 0.3)) {
                                onSelectTugOfWar()
                            }
```

- [ ] **Step 9: Build (compile gate)**

Run:
```bash
xcodebuild -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build -allowProvisioningUpdates 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Commit**

```bash
git add HotSeat/ContentView.swift HotSeat/HomeView.swift
git commit -m "feat: wire Tug-of-War into navigation and home screen

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Build, install on Thorin16, and stop

**Files:** none (verification only).

- [ ] **Step 1: Clean build for device**

```bash
xcodebuild -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build -allowProvisioningUpdates 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Install on Thorin16**

```bash
xcrun devicectl device install app --device 00008140-00065C5A14D1801C build/Build/Products/Debug-iphoneos/HotSeat.app 2>&1 | tail -3
```
Expected: `App installed:` with bundle id `com.audrey.HotSeat`.

- [ ] **Step 3: Stop for on-device testing**

Do not auto-verify gameplay (the simulator has no camera and the device needs two people). Report the on-device checklist to the human:
- Calibration completes only with two faces present; "GO!" then play.
- Player 1 (left) leaning left drives the rope toward their side and wins; Player 2 (right) leaning right wins. If inverted, the fix is the X-sort/lean direction — revisit Task 1/Task 3 mapping.
- Accumulation feels like a contest (tune `pullRate` in `TugOfWarViewModel` if too fast/slow).
- Losing a face freezes the rope; "Show both faces" hint appears.
- Win overlay + Rematch + Games all work.
- Hot Take forehead card and Lane Dodge still behave (shared-pipeline regression).

---

## Notes for the executor

- SourceKit may surface "Cannot find type 'UIView'/'Context' in scope" diagnostics after edits. These are stale-indexer noise. `xcodebuild` is the source of truth — if it prints `** BUILD SUCCEEDED **`, the task passes.
- The device UDID `00008140-00065C5A14D1801C` is Thorin16, confirmed in prior sessions.
- `FaceTracker.faceCentersX` is added once in Task 1 Step 6. Tasks 4 and 5 consume it — no duplication risk.
