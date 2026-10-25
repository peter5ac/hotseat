# Chocolate Rain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a toddler-friendly "Chocolate Rain" game where falling chocolates are caught by moving your mouth under them.

**Architecture:** Extends the shared FaceTracker with `mouthRect` + `faceBBoxWidth` fields. Game ViewModel receives these reactively, runs a display-link-driven simulation of falling items with rect-intersection collision. Audio/haptic feedback via VisualFeedback.swift extensions.

**Tech Stack:** SwiftUI, Vision (existing shared pipeline), AVAudioEngine, UIKit haptics

## Global Constraints

- iOS 17+, Swift 5, SwiftUI
- `@Observable` for all ViewModels (no Combine)
- Single shared `AVCaptureSession` in `CameraPreviewView` — never create another
- `FaceTracker` is the sole conduit for face data to game views
- No external dependencies, no audio files, no persistence
- CADisplayLink for game loops (not Timer)

---

### Task 1: Extend FaceReading and FaceTracker with mouthRect + faceBBoxWidth

**Files:**
- Modify: `HotSeat/CameraPreviewView.swift` (struct FaceReading ~line 14, captureOutput ~line 252, emit ~line 406, smoothed vars ~line 64)
- Modify: `HotSeat/ContentView.swift` (FaceTracker class ~line 58, CameraPreviewView callback ~line 548)

**Interfaces:**
- Produces: `FaceReading.mouthRect: CGRect?`, `FaceReading.faceBBoxWidth: CGFloat?`, `FaceTracker.mouthRect: CGRect?`, `FaceTracker.faceBBoxWidth: CGFloat?`

- [ ] **Step 1: Add fields to FaceReading struct**

In `HotSeat/CameraPreviewView.swift`, add two fields to the `FaceReading` struct (after line 25, before `perFaceExpressions`):

```swift
var mouthRect: CGRect?            // bounding rect of outerLips landmarks, view coordinates
var faceBBoxWidth: CGFloat?       // screen-space width of the largest face bounding box
```

- [ ] **Step 2: Add smoothed state variables to CameraUIView**

After line 83 (`private var smoothedRightEye: CGPoint?`), add:

```swift
private var smoothedMouthRect: CGRect?
private var smoothedFaceBBoxWidth: CGFloat?
```

- [ ] **Step 3: Compute mouthRect and faceBBoxWidth in captureOutput**

In the `captureOutput` method, after the existing eye-center computation (after line 308), add outerLips rect computation:

```swift
// Outer-lips bounding rect → image-normalized rect.
var mouthRectImageNorm: CGRect?
if let outerLips = face.landmarks?.outerLips, outerLips.pointCount > 0 {
    let pts = outerLips.normalizedPoints
    let xs = pts.map { $0.x }
    let ys = pts.map { $0.y }
    if let minX = xs.min(), let maxX = xs.max(),
       let minY = ys.min(), let maxY = ys.max() {
        // Convert from face-box-normalized to image-normalized.
        mouthRectImageNorm = CGRect(
            x: box.origin.x + minX * box.width,
            y: box.origin.y + minY * box.height,
            width: (maxX - minX) * box.width,
            height: (maxY - minY) * box.height
        )
    }
}
```

- [ ] **Step 4: Convert mouthRect to screen coordinates in the main-thread block**

Inside the `DispatchQueue.main.async` block (around line 314), after `rightEyePoint`, add:

```swift
let mouthRectScreen: CGRect? = mouthRectImageNorm.map { rect in
    let topLeft = self.screenPoint(
        forImageNormalized: CGPoint(x: rect.minX, y: rect.maxY),
        bufferWidth: bufferWidth,
        bufferHeight: bufferHeight
    )
    let bottomRight = self.screenPoint(
        forImageNormalized: CGPoint(x: rect.maxX, y: rect.minY),
        bufferWidth: bufferWidth,
        bufferHeight: bufferHeight
    )
    return CGRect(
        x: min(topLeft.x, bottomRight.x),
        y: min(topLeft.y, bottomRight.y),
        width: abs(bottomRight.x - topLeft.x),
        height: abs(bottomRight.y - topLeft.y)
    )
}

let faceBBoxScreenWidth: CGFloat? = {
    let left = self.screenPoint(
        forImageNormalized: CGPoint(x: box.minX, y: box.midY),
        bufferWidth: bufferWidth,
        bufferHeight: bufferHeight
    )
    let right = self.screenPoint(
        forImageNormalized: CGPoint(x: box.maxX, y: box.midY),
        bufferWidth: bufferWidth,
        bufferHeight: bufferHeight
    )
    return abs(right.x - left.x)
}()
```

- [ ] **Step 5: Update the emit call to pass mouthRect and faceBBoxWidth**

Update the `self.emit(...)` call (around line 349) to include the new parameters. Add `mouthRect: mouthRectScreen, faceBBoxWidth: faceBBoxScreenWidth` to the call.

- [ ] **Step 6: Update the emit method signature and add smoothing**

Add `mouthRect: CGRect? = nil, faceBBoxWidth: CGFloat? = nil` parameters to the `emit` method signature (line 406).

Add smoothing logic before the `onReadingChange?` call (after the right-eye smoothing block):

```swift
// Mouth rect smoothing: blend origin + size independently.
if let mr = mouthRect {
    if let prev = smoothedMouthRect {
        smoothedMouthRect = CGRect(
            x: prev.origin.x + (mr.origin.x - prev.origin.x) * smoothing,
            y: prev.origin.y + (mr.origin.y - prev.origin.y) * smoothing,
            width: prev.width + (mr.width - prev.width) * smoothing,
            height: prev.height + (mr.height - prev.height) * smoothing
        )
    } else {
        smoothedMouthRect = mr
    }
} else {
    smoothedMouthRect = nil
}

// Face bbox width smoothing.
if let fw = faceBBoxWidth {
    if let prev = smoothedFaceBBoxWidth {
        smoothedFaceBBoxWidth = prev + (fw - prev) * smoothing
    } else {
        smoothedFaceBBoxWidth = fw
    }
} else {
    smoothedFaceBBoxWidth = nil
}
```

- [ ] **Step 7: Include new fields in FaceReading emission**

Update the `FaceReading(...)` constructor call inside `emit` (around line 525) to include:

```swift
mouthRect: smoothedMouthRect,
faceBBoxWidth: smoothedFaceBBoxWidth,
```

- [ ] **Step 8: Add properties to FaceTracker**

In `HotSeat/ContentView.swift`, add to the `FaceTracker` class (after line 80):

```swift
/// Bounding rect of outer lips in full-screen view coordinates, or nil if no landmarks.
var mouthRect: CGRect?
/// Screen-space width of the largest face bounding box (for dynamic hitbox scaling).
var faceBBoxWidth: CGFloat?
```

- [ ] **Step 9: Wire new fields in CameraPreviewView callback**

In ContentView's `CameraPreviewView { reading in ... }` block (around line 559), add:

```swift
faceTracker.mouthRect = reading.mouthRect
faceTracker.faceBBoxWidth = reading.faceBBoxWidth
```

- [ ] **Step 10: Build and verify no compiler errors**

Run:
```bash
xcodebuild build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 11: Commit**

```bash
git add HotSeat/CameraPreviewView.swift HotSeat/ContentView.swift
git commit -m "feat(camera): emit mouthRect and faceBBoxWidth from outerLips landmarks"
```

---

### Task 2: Add ChompAudioEngine and ChompHaptics to VisualFeedback.swift

**Files:**
- Modify: `HotSeat/VisualFeedback.swift` (append after `LaserAudioEngine` class, ~line 205)

**Interfaces:**
- Produces: `ChompAudioEngine` class with `playChomp()` method, `ChompHaptics` struct with static `chomp()` method

- [ ] **Step 1: Add ChompHaptics struct**

Append to end of `HotSeat/VisualFeedback.swift`:

```swift
struct ChompHaptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)

    static func chomp() {
        impact.impactOccurred()
        impact.prepare()
    }
}
```

- [ ] **Step 2: Add ChompAudioEngine class**

Append after `ChompHaptics`:

```swift
private final class ChompOscillatorState {
    var remainingSamples: Int = 0
    var phase: Double = 0
}

final class ChompAudioEngine {
    private let audioEngine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private let state = ChompOscillatorState()
    private let sampleRate: Double = 44100.0

    init() {
        let oscState = state
        let sr = sampleRate
        sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            for frame in 0..<Int(frameCount) {
                var sample: Float = 0

                if oscState.remainingSamples > 0 {
                    let totalSamples = Int(sr * 0.1)
                    let progress = 1.0 - Double(oscState.remainingSamples) / Double(totalSamples)
                    // Sine sweep 300Hz → 100Hz
                    let freq = 300.0 - progress * 200.0
                    let phaseInc = freq / sr
                    oscState.phase += phaseInc
                    if oscState.phase >= 1.0 { oscState.phase -= 1.0 }
                    let sine = sin(oscState.phase * 2.0 * .pi)
                    // Exponential decay envelope
                    let env = exp(-progress * 4.0) * 0.3
                    sample = Float(sine * env)
                    oscState.remainingSamples -= 1
                } else {
                    oscState.phase = 0
                }

                buffer[frame] = sample
            }
            return noErr
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)

        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? audioEngine.start()
    }

    func playChomp() {
        state.remainingSamples = Int(sampleRate * 0.1)
        state.phase = 0
    }
}
```

- [ ] **Step 3: Build and verify**

Run:
```bash
xcodebuild build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add HotSeat/VisualFeedback.swift
git commit -m "feat(feedback): add ChompAudioEngine and ChompHaptics for Chocolate Rain"
```

---

### Task 3: Create ChocolateRainViewModel

**Files:**
- Create: `HotSeat/ChocolateRainViewModel.swift`

**Interfaces:**
- Consumes: `ChompAudioEngine.playChomp()`, `ChompHaptics.chomp()` (from Task 2)
- Produces: `ChocolateRainViewModel` class with `tick(delta:) -> Bool`, `updateMouth(rect:faceBBoxWidth:)`, `setCanvasSize(_:)`, `startGame()`, `reset()`. `ChocolateItem` struct. `ChocolateGameState` enum.

- [ ] **Step 1: Create ChocolateRainViewModel.swift**

Create `HotSeat/ChocolateRainViewModel.swift`:

```swift
import SwiftUI

struct ChocolateItem: Identifiable {
    let id = UUID()
    var position: CGPoint
    let emoji: String
    let size: CGFloat
}

enum ChocolateGameState: Equatable {
    case idle
    case countdown(Int)
    case playing
}

@Observable
final class ChocolateRainViewModel {
    var activeChocolates: [ChocolateItem] = []
    var score: Int = 0
    var gameState: ChocolateGameState = .idle

    private(set) var canvasSize: CGSize = .zero
    private var mouthRect: CGRect?
    private var faceBBoxWidth: CGFloat?
    private var timeSinceLastSpawn: Double = 0
    private let spawnInterval: Double = 1.2
    private let fallSpeed: CGFloat = 120
    private let maxChocolates = 5
    private let emojis = ["🍫", "🍬", "🍩", "🧁"]

    func setCanvasSize(_ size: CGSize) {
        canvasSize = size
    }

    func updateMouth(rect: CGRect?, faceBBoxWidth: CGFloat?) {
        self.mouthRect = rect
        self.faceBBoxWidth = faceBBoxWidth
    }

    func startGame() {
        score = 0
        activeChocolates = []
        timeSinceLastSpawn = 0
        gameState = .countdown(3)
        startCountdown()
    }

    func reset() {
        gameState = .idle
        activeChocolates = []
        score = 0
    }

    func tick(delta: Double) -> Bool {
        guard gameState == .playing else { return false }

        // Spawn
        timeSinceLastSpawn += delta
        if timeSinceLastSpawn >= spawnInterval && activeChocolates.count < maxChocolates {
            spawnChocolate()
            timeSinceLastSpawn = 0
        }

        // Move
        for i in activeChocolates.indices {
            activeChocolates[i].position.y += fallSpeed * delta
        }

        // Remove off-screen
        activeChocolates.removeAll { $0.position.y > canvasSize.height + 50 }

        // Collision
        if let hitbox = paddedMouthRect() {
            if let idx = activeChocolates.firstIndex(where: { hitbox.contains($0.position) }) {
                activeChocolates.remove(at: idx)
                score += 1
                return true
            }
        }

        return false
    }

    private func paddedMouthRect() -> CGRect? {
        guard let rect = mouthRect else { return nil }
        let padding = (faceBBoxWidth ?? 100) * 0.4
        return rect.insetBy(dx: -padding, dy: -padding)
    }

    private func spawnChocolate() {
        let insetX = canvasSize.width * 0.1
        let x = CGFloat.random(in: insetX...(canvasSize.width - insetX))
        let emoji = emojis.randomElement()!
        let size = CGFloat.random(in: 48...64)
        let item = ChocolateItem(position: CGPoint(x: x, y: -50), emoji: emoji, size: size)
        activeChocolates.append(item)
    }

    private func startCountdown() {
        guard case .countdown(let n) = gameState, n > 0 else {
            gameState = .playing
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            if n > 1 {
                self.gameState = .countdown(n - 1)
                self.startCountdown()
            } else {
                self.gameState = .playing
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add HotSeat/ChocolateRainViewModel.swift
git commit -m "feat(chocolate-rain): add ChocolateRainViewModel with spawn, fall, and collision logic"
```

---

### Task 4: Create ChocolateRainView

**Files:**
- Create: `HotSeat/ChocolateRainView.swift`

**Interfaces:**
- Consumes: `FaceTracker.mouthRect`, `FaceTracker.faceBBoxWidth` (Task 1), `ChocolateRainViewModel` (Task 3), `ChompAudioEngine`, `ChompHaptics` (Task 2)
- Produces: `ChocolateRainView` (SwiftUI View accepting `faceTracker: FaceTracker`, `onExit: () -> Void`)

- [ ] **Step 1: Create ChocolateRainView.swift**

Create `HotSeat/ChocolateRainView.swift`:

```swift
import SwiftUI

struct ChocolateRainView: View {
    let faceTracker: FaceTracker
    let onExit: () -> Void

    @State private var viewModel = ChocolateRainViewModel()
    @State private var audioEngine = ChompAudioEngine()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                chocolateLayer
                scoreLabel
                exitButton

                if viewModel.gameState == .idle {
                    startOverlay
                }
                if case .countdown(let n) = viewModel.gameState {
                    countdownOverlay(n)
                }

                #if DEBUG
                debugMouthOverlay
                #endif
            }
            .onAppear {
                viewModel.setCanvasSize(geo.size)
            }
            .onChange(of: geo.size) { _, newSize in
                viewModel.setCanvasSize(newSize)
            }
        }
        .modifier(ChocolateDisplayLinkModifier { delta in
            viewModel.updateMouth(
                rect: faceTracker.mouthRect,
                faceBBoxWidth: faceTracker.faceBBoxWidth
            )
            let caught = viewModel.tick(delta: delta)
            if caught {
                audioEngine.playChomp()
                ChompHaptics.chomp()
            }
        })
    }

    // MARK: - Chocolate Layer

    private var chocolateLayer: some View {
        ForEach(viewModel.activeChocolates) { item in
            Text(item.emoji)
                .font(.system(size: item.size))
                .position(item.position)
        }
    }

    // MARK: - Score

    private var scoreLabel: some View {
        VStack {
            Text("\(viewModel.score)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .padding(.top, 60)
            Spacer()
        }
    }

    // MARK: - Exit

    private var exitButton: some View {
        VStack {
            HStack {
                Button {
                    viewModel.reset()
                    withAnimation(.spring(duration: 0.3)) {
                        onExit()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(16)
                }
                Spacer()
            }
            Spacer()
        }
    }

    // MARK: - Start Overlay

    private var startOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Text("🍫")
                    .font(.system(size: 80))
                Text("Chocolate Rain")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("Catch the treats\nwith your mouth!")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button {
                    viewModel.startGame()
                } label: {
                    Text("Play")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(.brown))
                }
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Countdown

    private func countdownOverlay(_ n: Int) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            Text("\(n)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 10)
        }
    }

    // MARK: - Debug

    #if DEBUG
    private var debugMouthOverlay: some View {
        Group {
            if let rect = faceTracker.mouthRect {
                let padding = (faceTracker.faceBBoxWidth ?? 100) * 0.4
                let padded = rect.insetBy(dx: -padding, dy: -padding)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cyan.opacity(0.6), lineWidth: 2)
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: padded.width, height: padded.height)
                    .position(x: padded.midX, y: padded.midY)
            }
        }
    }
    #endif
}

// MARK: - Display Link

private struct ChocolateDisplayLinkModifier: ViewModifier {
    let onFrame: (_ delta: Double) -> Void
    @State private var lastTimestamp: CFTimeInterval = 0

    func body(content: Content) -> some View {
        content
            .onAppear { lastTimestamp = 0 }
            .background(ChocolateDisplayLinkRepresentable(onFrame: { ts in
                guard lastTimestamp != 0 else { lastTimestamp = ts; return }
                let delta = min(ts - lastTimestamp, 0.1)
                lastTimestamp = ts
                onFrame(delta)
            }))
    }
}

private struct ChocolateDisplayLinkRepresentable: UIViewRepresentable {
    let onFrame: (CFTimeInterval) -> Void

    func makeUIView(context: Context) -> ChocolateDisplayLinkUIView {
        let v = ChocolateDisplayLinkUIView()
        v.onFrame = onFrame
        return v
    }

    func updateUIView(_ uiView: ChocolateDisplayLinkUIView, context: Context) {
        uiView.onFrame = onFrame
    }
}

private class ChocolateDisplayLinkUIView: UIView {
    var onFrame: ((CFTimeInterval) -> Void)?
    private var link: CADisplayLink?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            let dl = CADisplayLink(target: self, selector: #selector(step))
            dl.add(to: .main, forMode: .common)
            link = dl
        } else {
            link?.invalidate()
            link = nil
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        onFrame?(link.timestamp)
    }
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add HotSeat/ChocolateRainView.swift
git commit -m "feat(chocolate-rain): add ChocolateRainView with display link, debug overlay, and start screen"
```

---

### Task 5: Wire navigation (AppScreen, HomeView, ContentView, Xcode project)

**Files:**
- Modify: `HotSeat/ContentView.swift` (AppScreen enum ~line 3, AppViewModel ~line 15, FaceTracker callback ~line 548, screen switch ~line 567, HomeView instantiation ~line 569)
- Modify: `HotSeat/HomeView.swift` (allGames ~line 11, HomeView struct ~line 22, gameTile switch ~line 169, SpinWheelView switch ~line 132)
- Modify: `HotSeat.xcodeproj/project.pbxproj` (add new .swift files to build phase)

**Interfaces:**
- Consumes: `ChocolateRainView(faceTracker:onExit:)` (Task 4)

- [ ] **Step 1: Add chocolateRain case to AppScreen**

In `HotSeat/ContentView.swift`, add to the `AppScreen` enum (after `case laserEyes`):

```swift
case chocolateRain
```

- [ ] **Step 2: Add openChocolateRain to AppViewModel**

After the `openLaserEyes()` method:

```swift
func openChocolateRain() {
    screen = .chocolateRain
}
```

- [ ] **Step 3: Add chocolateRain routing in ContentView screen switch**

After the `.laserEyes` case (around line 657):

```swift
case .chocolateRain:
    ChocolateRainView(
        faceTracker: faceTracker,
        onExit: {
            withAnimation(.spring(duration: 0.3)) {
                appViewModel.goHome()
            }
        }
    )
```

- [ ] **Step 4: Add onSelectChocolateRain closure to HomeView**

In `HotSeat/HomeView.swift`, add to the `HomeView` struct properties (after `let onSelectLaserEyes: () -> Void`):

```swift
let onSelectChocolateRain: () -> Void
```

- [ ] **Step 5: Add game entry to allGames**

After the laser eyes entry in the `allGames` array:

```swift
Game(id: "chocolateRain", name: "Chocolate Rain", emoji: "🍫", icon: nil, isAvailable: true),
```

- [ ] **Step 6: Add case to gameTile switch**

In the `gameTile` method's switch statement (around line 186), add before `default`:

```swift
case "chocolateRain":
    onSelectChocolateRain()
```

- [ ] **Step 7: Add case to SpinWheelView onLanded switch**

In the SpinWheelView's `onLanded` closure switch (around line 148), add before `default`:

```swift
case "chocolateRain":
    onSelectChocolateRain()
```

- [ ] **Step 8: Pass onSelectChocolateRain from ContentView**

In ContentView's `HomeView(...)` instantiation (around line 592), add after `onSelectLaserEyes`:

```swift
onSelectChocolateRain: {
    appViewModel.openChocolateRain()
},
```

- [ ] **Step 9: Add new Swift files to Xcode project**

Add `ChocolateRainViewModel.swift` and `ChocolateRainView.swift` to the Xcode project's HotSeat target build phase. Use the project.pbxproj or open Xcode. If editing pbxproj manually, follow the pattern of existing game files (LaserEyesView.swift, LaserEyesViewModel.swift) for file references and build phase membership.

- [ ] **Step 10: Build and verify**

Run:
```bash
xcodebuild build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 11: Commit**

```bash
git add HotSeat/ContentView.swift HotSeat/HomeView.swift HotSeat/ChocolateRainViewModel.swift HotSeat/ChocolateRainView.swift HotSeat.xcodeproj/project.pbxproj
git commit -m "feat(chocolate-rain): wire Chocolate Rain into navigation, home screen, and spin wheel"
```

---

### Task 6: Device build and verification

**Files:**
- No new files. Verification-only task.

- [ ] **Step 1: Build for physical device**

```bash
xcodebuild build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS,name=Thorin16"
```

- [ ] **Step 2: Install on device**

```bash
xcrun devicectl device install app --device "Thorin16" build/Debug-iphoneos/HotSeat.app
```

- [ ] **Step 3: Launch on device**

```bash
xcrun devicectl device process launch --terminate-existing --console --device "Thorin16" com.audrey.HotSeat
```

- [ ] **Step 4: Show build timestamp**

```bash
cat HotSeat/BuildTimestamp.swift
```

Display the timestamp (dd/mm/yy HH:mm:ss) to confirm which build is running.

- [ ] **Step 5: Manual test on device**

Verify:
1. Chocolate Rain tile appears on home screen
2. Tapping tile shows start overlay with "Play" button
3. Tapping "Play" shows 3-2-1 countdown
4. Chocolates fall at a slow, manageable speed
5. Moving mouth under a chocolate triggers catch (score increments, pop sound, haptic)
6. Debug overlay shows cyan hitbox rect tracking the mouth (only in Debug builds)
7. Exit button returns to home screen
8. Spin wheel includes Chocolate Rain and can land on it
