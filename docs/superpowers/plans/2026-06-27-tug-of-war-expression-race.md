# Tug-of-War Expression Race — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken lean-based Tug-of-War mechanic with an expression-race mechanic: show a facial expression prompt, first of the two detected faces to match it moves the rope one notch their direction, repeat until ±1.0.

**Architecture:** The camera pipeline already detects 2 faces and extracts landmarks for all of them (`VNDetectFaceLandmarksRequest`), but currently only reads expressions from the single largest face. We extend `FaceReading` with per-face expression data for 2 faces (mouthOpen, yaw, pitch, roll per face). The ViewModel becomes a round-based state machine: each round shows a random expression prompt; first player to match wins the round and the rope moves one notch; game ends when rope hits ±1.0.

**Tech Stack:** SwiftUI, Vision framework (`VNDetectFaceLandmarksRequest`), CADisplayLink, iOS 17+

## Global Constraints

- iOS 17+, Swift 5, SwiftUI only
- No ARKit (no blend shapes) — expressions detected via Vision landmarks only
- No persistence, no accounts, no network
- Camera pipeline is shared — single `AVCaptureSession`, changes must not regress Hot Take / Lane Dodge / Tic Tac Toe / etc.
- No XCTest target — verification is compile gate + on-device manual testing
- Expression set limited to what Vision landmarks can reliably distinguish: mouth open, head turn (yaw), look up (pitch), head tilt (roll)

---

### Task 1: Extend Camera Pipeline — Per-Face Expression Data

**Files:**
- Modify: `HotSeat/CameraPreviewView.swift` (FaceReading struct + captureOutput + emit)
- Modify: `HotSeat/ContentView.swift` (FaceTracker gains new field)

**Interfaces:**
- Consumes: existing `VNDetectFaceLandmarksRequest` results (already returns landmarks for all detected faces)
- Produces: `FaceReading.perFaceExpressions: [PerFaceExpression]` — array of up to 2 structs, sorted ascending by face X-center (matching `faceCentersX` ordering). `FaceTracker.perFaceExpressions: [PerFaceExpression]`

**Data structure (added to CameraPreviewView.swift, above `FaceReading`):**

```swift
struct PerFaceExpression {
    var mouthOpen: Bool
    var yaw: CGFloat      // radians, positive = turning right in mirrored feed
    var pitch: CGFloat    // radians, positive = looking up
    var roll: CGFloat     // radians, head tilt
}
```

- [ ] **Step 1: Add `PerFaceExpression` struct and extend `FaceReading`**

Add the struct above `FaceReading` and a new field to `FaceReading`:

```swift
struct PerFaceExpression {
    var mouthOpen: Bool
    var yaw: CGFloat
    var pitch: CGFloat
    var roll: CGFloat
}

struct FaceReading {
    // ... existing fields unchanged ...
    var perFaceExpressions: [PerFaceExpression]  // up to 2, sorted by X ascending
}
```

- [ ] **Step 2: Extract expressions from both faces in `captureOutput`**

After the existing `twoLargest` and `centersX` computation (around line 209-215), compute per-face expressions for those same two faces, keeping them sorted by X to match `centersX`:

```swift
// Per-face expression extraction — same faces as centersX, same X-ascending order.
let twoLargestByX = twoLargest.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
let perFaceExpressions: [PerFaceExpression] = twoLargestByX.map { obs in
    // Mouth open: same inner-lip ratio logic as the single-face path
    var isOpen = false
    if let inner = obs.landmarks?.innerLips, inner.pointCount > 0 {
        let pts = inner.normalizedPoints
        let xs = pts.map { $0.x }
        let ys = pts.map { $0.y }
        if let minX = xs.min(), let maxX = xs.max(),
           let minY = ys.min(), let maxY = ys.max(), (maxX - minX) > 0 {
            isOpen = ((maxY - minY) / (maxX - minX)) >= self.mouthOpenThreshold
        }
    }
    return PerFaceExpression(
        mouthOpen: isOpen,
        yaw: obs.yaw.map { CGFloat(truncating: $0) } ?? 0,
        pitch: obs.pitch.map { CGFloat(truncating: $0) } ?? 0,
        roll: obs.roll.map { CGFloat(truncating: $0) } ?? 0
    )
}
```

- [ ] **Step 3: Pass `perFaceExpressions` through the emit path**

Update the `emit` method signature to accept `perFaceExpressions: [PerFaceExpression] = []`. No smoothing needed for these (they're thresholded booleans + angles that the ViewModel will threshold itself). Pass it straight through to the `FaceReading` initializer at the end of `emit`.

Update both call sites of `emit`:
- The `guard let face = largest else` early-return path: pass `perFaceExpressions: []`
- The main emit call: pass `perFaceExpressions: perFaceExpressions`

- [ ] **Step 4: Add field to `FaceTracker` and wire it in `ContentView`**

In `ContentView.swift`, add to `FaceTracker`:

```swift
var perFaceExpressions: [PerFaceExpression] = []
```

In the `CameraPreviewView { reading in ... }` closure, add:

```swift
faceTracker.perFaceExpressions = reading.perFaceExpressions
```

- [ ] **Step 5: Build for device to verify no regressions**

```bash
xcodebuild build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS,name=Thorin16" 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED. All other games still compile and function — the new field is additive only.

- [ ] **Step 6: Commit**

```bash
git add HotSeat/CameraPreviewView.swift HotSeat/ContentView.swift
git commit -m "feat(camera): emit per-face expressions for 2 detected faces"
```

---

### Task 2: Rewrite TugOfWarViewModel — Round-Based Expression Race

**Files:**
- Rewrite: `HotSeat/TugOfWarViewModel.swift`

**Interfaces:**
- Consumes: `[PerFaceExpression]` (from Task 1), fed via a method call from the view
- Produces: `TugOfWarViewModel` with public state: `ropeProgress: CGFloat` (−1...+1, 5 notches each side), `state: TugOfWarState`, `currentPrompt: ExpressionPrompt`, `winnerName: String?`, `roundWinner: Int?` (1 or 2, briefly set after each round for animation). Methods: `startGame()`, `updateFaces(_: [PerFaceExpression])`, `reset()`.

**Design:**
- Rope has 10 notches: starts at 0, each round moves ±0.2. Hit ±1.0 = win.
- State: `.waitingForFaces` → `.countdown` → `.playing` → `.gameOver`
- During `.playing`, sub-state cycles: `.showingPrompt` → `.racing` → `.scored` → `.showingPrompt`
- Expression prompts: mouth open (threshold on `mouthOpen`), turn head left (yaw < −0.3), turn head right (yaw > 0.3), look up (pitch > 0.2), tilt head (abs(roll) > 0.3)
- Cooldown between rounds (0.8s) prevents button-mashing with held expressions
- Must see both faces to race; if a face drops mid-round, round pauses

```swift
enum ExpressionType: CaseIterable {
    case mouthOpen
    case turnLeft
    case turnRight
    case lookUp
    case tiltHead
}
```

- [ ] **Step 1: Define types and state**

Replace the entire contents of `TugOfWarViewModel.swift`:

```swift
import SwiftUI

enum TugOfWarState: Equatable {
    case waitingForFaces
    case countdown
    case playing
    case gameOver
}

enum RoundPhase: Equatable {
    case showingPrompt   // prompt just appeared, brief delay before detection starts
    case racing          // actively checking expressions
    case scored          // someone won the round, brief pause
}

enum ExpressionType: CaseIterable {
    case mouthOpen
    case turnLeft
    case turnRight
    case lookUp
    case tiltHead

    var label: String {
        switch self {
        case .mouthOpen: "Open your mouth!"
        case .turnLeft:  "Turn left!"
        case .turnRight: "Turn right!"
        case .lookUp:    "Look up!"
        case .tiltHead:  "Tilt your head!"
        }
    }

    var emoji: String {
        switch self {
        case .mouthOpen: "😮"
        case .turnLeft:  "👈"
        case .turnRight: "👉"
        case .lookUp:    "👆"
        case .tiltHead:  "🤸"
        }
    }
}

@Observable
final class TugOfWarViewModel {
    // MARK: - Config
    private let notchSize: CGFloat = 0.2        // rope moves this much per round
    private let promptDelay: CGFloat = 0.6      // seconds before detection starts
    private let scoredPause: CGFloat = 0.8      // seconds between rounds
    private let yawThreshold: CGFloat = 0.3     // radians
    private let pitchThreshold: CGFloat = 0.2   // radians
    private let rollThreshold: CGFloat = 0.3    // radians

    // MARK: - Public state
    var state: TugOfWarState = .waitingForFaces
    var roundPhase: RoundPhase = .showingPrompt
    var ropeProgress: CGFloat = 0.0             // -1...+1
    var currentPrompt: ExpressionType = .mouthOpen
    var winnerName: String?
    var roundWinner: Int?                        // 1 or 2, briefly non-nil after a score
    var countdownValue: Int = 3

    var isGameOver: Bool { state == .gameOver }
    var hasBothFaces: Bool { latestExpressions.count >= 2 }

    // MARK: - Private
    private var latestExpressions: [PerFaceExpression] = []
    private var phaseTimer: CGFloat = 0
    private var usedPrompts: [ExpressionType] = []

    // MARK: - Public methods

    func startGame() {
        state = .waitingForFaces
        ropeProgress = 0.0
        winnerName = nil
        roundWinner = nil
        countdownValue = 3
        phaseTimer = 0
        usedPrompts = []
        pickNextPrompt()
    }

    func updateFaces(_ expressions: [PerFaceExpression]) {
        latestExpressions = expressions

        if state == .waitingForFaces && expressions.count >= 2 {
            state = .countdown
            countdownValue = 3
            phaseTimer = 0
        }
    }

    /// Called every frame by the display link. Drives countdown, prompt timing, and detection.
    func tick(delta: CGFloat) {
        switch state {
        case .waitingForFaces:
            break

        case .countdown:
            guard latestExpressions.count >= 2 else {
                state = .waitingForFaces
                return
            }
            phaseTimer += delta
            if phaseTimer >= 1.0 {
                phaseTimer = 0
                countdownValue -= 1
                if countdownValue <= 0 {
                    state = .playing
                    roundPhase = .showingPrompt
                    phaseTimer = 0
                }
            }

        case .playing:
            guard latestExpressions.count >= 2 else { return } // freeze if face lost

            switch roundPhase {
            case .showingPrompt:
                phaseTimer += delta
                if phaseTimer >= promptDelay {
                    roundPhase = .racing
                    phaseTimer = 0
                }

            case .racing:
                checkExpressions()

            case .scored:
                phaseTimer += delta
                if phaseTimer >= scoredPause {
                    roundWinner = nil
                    roundPhase = .showingPrompt
                    phaseTimer = 0
                    pickNextPrompt()
                }
            }

        case .gameOver:
            break
        }
    }

    func reset() {
        startGame()
    }

    // MARK: - Private

    private func checkExpressions() {
        guard latestExpressions.count >= 2 else { return }
        let p1 = latestExpressions[0]
        let p2 = latestExpressions[1]

        let p1Matches = matches(expression: p1, prompt: currentPrompt)
        let p2Matches = matches(expression: p2, prompt: currentPrompt)

        if p1Matches && !p2Matches {
            scoreRound(winner: 1)
        } else if p2Matches && !p1Matches {
            scoreRound(winner: 2)
        } else if p1Matches && p2Matches {
            // Tie — both matched same frame. No score, pick new prompt.
            roundPhase = .scored
            phaseTimer = 0
            roundWinner = nil
        }
    }

    private func matches(expression: PerFaceExpression, prompt: ExpressionType) -> Bool {
        switch prompt {
        case .mouthOpen: return expression.mouthOpen
        case .turnLeft:  return expression.yaw < -yawThreshold
        case .turnRight: return expression.yaw > yawThreshold
        case .lookUp:    return expression.pitch > pitchThreshold
        case .tiltHead:  return abs(expression.roll) > rollThreshold
        }
    }

    private func scoreRound(winner: Int) {
        roundWinner = winner
        if winner == 1 {
            ropeProgress -= notchSize
        } else {
            ropeProgress += notchSize
        }
        ropeProgress = min(1.0, max(-1.0, ropeProgress))

        if ropeProgress <= -1.0 {
            winnerName = "Player 1"
            state = .gameOver
        } else if ropeProgress >= 1.0 {
            winnerName = "Player 2"
            state = .gameOver
        } else {
            roundPhase = .scored
            phaseTimer = 0
        }
    }

    private func pickNextPrompt() {
        // Avoid repeating the same prompt twice in a row. Cycle through all before repeating.
        var available = ExpressionType.allCases.filter { !usedPrompts.contains($0) }
        if available.isEmpty {
            usedPrompts = []
            available = ExpressionType.allCases
        }
        // Remove current to avoid immediate repeat
        available = available.filter { $0 != currentPrompt }
        if available.isEmpty { available = ExpressionType.allCases }
        currentPrompt = available.randomElement() ?? .mouthOpen
        usedPrompts.append(currentPrompt)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
xcodebuild build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS,name=Thorin16" 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED (TugOfWarView will need updates in Task 3 but should still compile since it references the same type name — if not, stub out a minimal fix to unblock).

- [ ] **Step 3: Commit**

```bash
git add HotSeat/TugOfWarViewModel.swift
git commit -m "feat(tug-of-war): rewrite ViewModel as expression-race with round-based scoring"
```

---

### Task 3: Rewrite TugOfWarView — Expression Prompt UI

**Files:**
- Rewrite: `HotSeat/TugOfWarView.swift`

**Interfaces:**
- Consumes: `TugOfWarViewModel` (from Task 2), `FaceTracker` (with `perFaceExpressions` from Task 1)
- Produces: Complete SwiftUI view with expression prompt display, rope track, countdown, win overlay

**Design:**
- Big emoji + text prompt in center of screen during rounds
- Rope track stays (horizontal bar with sliding node), but now moves in discrete notches
- Flash the screen half in the winner's color briefly on score
- Countdown overlay during `.countdown` state
- "Show both faces" hint when fewer than 2 faces detected
- Same top bar / exit pattern as current implementation

- [ ] **Step 1: Rewrite TugOfWarView**

Replace the entire contents of `TugOfWarView.swift`:

```swift
import SwiftUI

struct TugOfWarView: View {
    @State private var viewModel = TugOfWarViewModel()
    let faceTracker: FaceTracker
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    @State private var lastTimestamp: CFTimeInterval = 0
    @State private var flashPlayer: Int? = nil  // 1 or 2, briefly set for score flash

    private var hasBothFaces: Bool { faceTracker.perFaceExpressions.count >= 2 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Territory tints
                territoryBackground

                // Rope track
                ropeTrack(in: geo.size)

                // Center prompt (during play)
                if viewModel.state == .playing {
                    promptDisplay
                }

                // Countdown
                if viewModel.state == .countdown {
                    countdownOverlay
                }

                // Waiting for faces
                if viewModel.state == .waitingForFaces {
                    waitingOverlay
                }

                // Win screen
                if viewModel.state == .gameOver {
                    winOverlay
                }

                // Face hint (during play, not game over)
                if !hasBothFaces && viewModel.state == .playing {
                    twoFaceHint
                }

                // Score flash
                if let player = flashPlayer {
                    scoreFlash(player: player, in: geo.size)
                }

                // Top bar
                topBar
            }
        }
        .onAppear {
            viewModel.startGame()
            lastTimestamp = 0
        }
        .onChange(of: faceTracker.perFaceExpressions) { _, newValue in
            viewModel.updateFaces(newValue)
        }
        .onChange(of: viewModel.roundWinner) { _, newValue in
            if let winner = newValue {
                flashPlayer = winner
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    flashPlayer = nil
                }
            }
        }
        .modifier(TugDisplayLinkModifier { timestamp in
            advance(to: timestamp)
        })
    }

    private func advance(to timestamp: CFTimeInterval) {
        guard lastTimestamp != 0 else { lastTimestamp = timestamp; return }
        let delta = CGFloat(timestamp - lastTimestamp)
        lastTimestamp = timestamp
        viewModel.tick(delta: delta)
    }
}

// MARK: - Prompt display

private extension TugOfWarView {
    var promptDisplay: some View {
        VStack(spacing: 12) {
            if viewModel.roundPhase == .racing || viewModel.roundPhase == .showingPrompt {
                Text(viewModel.currentPrompt.emoji)
                    .font(.system(size: isCompact ? 80 : 120))
                Text(viewModel.currentPrompt.label)
                    .font(.system(size: isCompact ? 24 : 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else if viewModel.roundPhase == .scored {
                if let winner = viewModel.roundWinner {
                    Text("Player \(winner) scores!")
                        .font(.system(size: isCompact ? 22 : 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("Tie! Go again!")
                        .font(.system(size: isCompact ? 22 : 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(isCompact ? 20 : 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Rope track

private extension TugOfWarView {
    private var player1Color: Color { .cyan }
    private var player2Color: Color { .orange }

    var territoryBackground: some View {
        HStack(spacing: 0) {
            player1Color.opacity(0.08)
            player2Color.opacity(0.08)
        }
    }

    @ViewBuilder
    func ropeTrack(in size: CGSize) -> some View {
        let halfWidth = size.width / 2
        let centerY = size.height * 0.82  // lower on screen to not overlap prompt
        VStack(spacing: 8) {
            // Notch markers
            HStack(spacing: 0) {
                ForEach(-5..<6, id: \.self) { notch in
                    Circle()
                        .fill(notch < 0 ? player1Color.opacity(0.5) :
                              notch > 0 ? player2Color.opacity(0.5) :
                              Color.white.opacity(0.7))
                        .frame(width: notch == 0 ? 10 : 6, height: notch == 0 ? 10 : 6)
                    if notch < 5 { Spacer() }
                }
            }
            .frame(width: size.width * 0.85)

            // Track bar
            ZStack {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: size.width * 0.85, height: 8)

                // Indicator node
                Circle()
                    .fill(viewModel.ropeProgress < 0 ? player1Color : player2Color)
                    .frame(width: isCompact ? 40 : 52, height: isCompact ? 40 : 52)
                    .shadow(color: .white.opacity(0.6), radius: 8)
                    .offset(x: viewModel.ropeProgress * (size.width * 0.85 / 2))
                    .animation(.spring(duration: 0.3), value: viewModel.ropeProgress)
            }
        }
        .position(x: size.width / 2, y: centerY)
    }

    @ViewBuilder
    func scoreFlash(player: Int, in size: CGSize) -> some View {
        let color = player == 1 ? player1Color : player2Color
        color.opacity(0.2)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}

// MARK: - Overlays

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
                // Player labels
                HStack(spacing: 12) {
                    Text("P1")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                    Text("P2")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)
            Spacer()
        }
    }

    var countdownOverlay: some View {
        VStack(spacing: 16) {
            Text("Get ready!")
                .font(.system(size: isCompact ? 28 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("\(viewModel.countdownValue)")
                .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: viewModel.countdownValue)
        }
        .padding(isCompact ? 24 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    var waitingOverlay: some View {
        VStack(spacing: 16) {
            Text("🪢")
                .font(.system(size: 60))
            Text("Tug-of-War")
                .font(.system(size: isCompact ? 28 : 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Two players face the camera")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
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

// MARK: - Display Link

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
```

- [ ] **Step 2: Build for device**

```bash
xcodebuild build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS,name=Thorin16" 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add HotSeat/TugOfWarView.swift
git commit -m "feat(tug-of-war): rewrite View with expression prompt UI and round scoring"
```

---

### Task 4: Wire Up and Verify

**Files:**
- Possibly modify: `HotSeat/ContentView.swift` (if the onChange/routing needs adjusting for new `perFaceExpressions` dependency)

**Interfaces:**
- Consumes: Everything from Tasks 1-3
- Produces: Working end-to-end game on device

- [ ] **Step 1: Verify ContentView wiring compiles and routes correctly**

Check that `ContentView`'s `.tugOfWar` case passes `faceTracker` to `TugOfWarView` — this should already work since the view's init signature hasn't changed (`faceTracker: FaceTracker, onExit: () -> Void`). If the view now uses `faceTracker.perFaceExpressions` via `onChange`, ensure the `FaceTracker` field is being set in the camera closure (done in Task 1 Step 4).

- [ ] **Step 2: Full clean build for device**

```bash
xcodebuild clean build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS,name=Thorin16" 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Install and launch on device**

```bash
xcrun devicectl device install app --device "Thorin16" build/Debug-iphoneos/HotSeat.app
xcrun devicectl device process launch --terminate-existing --console --device "Thorin16" com.audrey.HotSeat
```

- [ ] **Step 4: On-device verification checklist**

Manual testing with two people in front of camera:
1. Navigate to Tug-of-War from home screen
2. "Show both faces" / waiting state shows when only one face visible
3. Countdown starts when both faces appear
4. Expression prompt appears after countdown
5. Opening mouth (when prompt says "Open your mouth!") moves rope for the faster player
6. Head turn detection works for turnLeft/turnRight prompts
7. Rope moves in discrete notches (0.2 per round)
8. Ties (both match same frame) don't score — new prompt appears
9. Game ends when rope reaches ±1.0 (5 rounds to one side)
10. Win overlay shows, rematch resets cleanly
11. Back button returns to home screen
12. Other games (Hot Take, Lane Dodge, Tic Tac Toe) still work — no regression

- [ ] **Step 5: Tune thresholds if needed**

On-device, if expressions trigger too easily or not easily enough, adjust these constants in `TugOfWarViewModel`:
- `yawThreshold` (default 0.3 rad ≈ 17°) — turn detection sensitivity
- `pitchThreshold` (default 0.2 rad ≈ 11°) — look-up sensitivity
- `rollThreshold` (default 0.3 rad ≈ 17°) — tilt sensitivity
- `mouthOpenThreshold` in `CameraPreviewView.swift` (already 0.28) — shared with all games

- [ ] **Step 6: Commit any tuning changes**

```bash
git add -A
git commit -m "feat(tug-of-war): expression-race tuning from on-device testing"
```
