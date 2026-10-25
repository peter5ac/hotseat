# Tic Tac Toe (Mouth-Controlled) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a two-player, pass-the-phone Tic Tac Toe game where each player places their mark (Player 1 = O, Player 2 = X) by holding an open mouth over the target square for one second.

**Architecture:** One shared-code change (swap the camera Vision request to face landmarks so it emits open-mouth + mouth-center signals) plus two new self-contained files (`TicTacToeViewModel`, `TicTacToeView`) and navigation wiring. The view model is pure (no Vision/UIKit) and driven each frame by a `CADisplayLink`, mirroring the existing `HeadsUpView`/`HeadsUpViewModel` split.

**Tech Stack:** SwiftUI, iOS 17+, Swift 5, `@Observable` view models, AVFoundation + Vision (`VNDetectFaceLandmarksRequest`), CADisplayLink, UIKit haptics.

## Global Constraints

- Pre-teens 7–14. No recording, upload, network, accounts, analytics, or persistence. Per-session state only. (CLAUDE.md / PRODUCT.md)
- The live front camera is the background and the controller; the grid is drawn OVER the feed. The dimming overlay `Color.black.opacity(0.4)` stays — it is load-bearing for contrast. (PRODUCT.md)
- Camera is black in the simulator; this game is only fully verifiable on a physical device (Thorin16, id `00008140-00065C5A14D1801C`). (CLAUDE.md)
- No test target exists and this plan does NOT add one. Validation = `BUILD SUCCEEDED` (XcodeBuildMCP `build_sim`) + manual on-device test. View-model logic is written pure so a test target could be added later. (matches all 7 prior games)
- Both players use the same gesture: an **open mouth**. Turn order alone decides O vs X. O always goes first each round.
- Bundle id `com.audrey.HotSeat`. Open `HotSeat.xcodeproj` (objectVersion 56, hand-assigned IDs, no xcodegen — new files need manual pbxproj registration in 4 sections).
- Build via XcodeBuildMCP simulator tools (preferred over `xcodebuild` shell). Session defaults: scheme `HotSeat`, sim `iPhone 17`.

---

## File Structure

- **Create** `HotSeat/TicTacToeViewModel.swift` — `@Observable` board/turn/win/confirm/lockout state; pure, camera-free; per-frame `tick`.
- **Create** `HotSeat/TicTacToeView.swift` — grid over camera, hit-tests `mouthCenter` to a cell, drives the view model, shows confirm ring + turn indicator + end card.
- **Modify** `HotSeat/CameraPreviewView.swift` — swap `VNDetectFaceRectanglesRequest` → `VNDetectFaceLandmarksRequest`; add `mouthOpen` + `mouthCenter` to `FaceReading`; smooth and emit them.
- **Modify** `HotSeat/ContentView.swift` — add `mouthOpen`/`mouthCenter` to `FaceTracker`; populate them in `onReadingChange`; add `.ticTacToe` screen + `openTicTacToe()` + switch case.
- **Modify** `HotSeat/HomeView.swift` — add the Tic Tac Toe game tile, `onSelectTicTacToe` closure, and both tile-tap and spin-wheel `onLanded` cases.
- **Modify** `HotSeat.xcodeproj/project.pbxproj` — register the two new files (IDs `A1000018/A2000018`, `A1000019/A2000019`).

Task order: camera signals first (Task 1), then the pure view model (Task 2), then the view (Task 3), then navigation + Xcode registration + build (Task 4), then on-device verification (Task 5).

---

## Task 1: Emit open-mouth + mouth-center from the camera

**Files:**
- Modify: `HotSeat/CameraPreviewView.swift`

**Interfaces:**
- Consumes: existing `screenPoint(forNormalizedBox:bufferWidth:bufferHeight:)`, existing `smoothing` low-pass factor, existing `emit(...)` pattern.
- Produces: `FaceReading` extended with `var mouthOpen: Bool?` and `var mouthCenter: CGPoint?` (view-space, same coordinate system as `foreheadPoint`). `CameraUIView` now runs `VNDetectFaceLandmarksRequest`.

**Context — coordinate math (the fiddliest part):** `VNFaceLandmarks2D` region points are normalized *within the face bounding box* (0…1 across the box, bottom-left origin), NOT the image. To get a point into the same view space as `foreheadPoint`, first convert a landmark point to image-normalized coordinates: `imgX = box.origin.x + lp.x * box.width`, `imgY = box.origin.y + lp.y * box.height`. Then reuse the existing aspect-fill + Y-flip mapping. The current `screenPoint` only takes a box (it computes `box.midX` / `1 - box.maxY` internally), so this task adds a sibling that maps an arbitrary image-normalized point.

- [ ] **Step 1: Extend `FaceReading` with the two mouth fields**

In `HotSeat/CameraPreviewView.swift`, replace the `FaceReading` struct (currently lines ~7-11) with:

```swift
/// A single frame's face-derived signals, emitted on the main thread.
/// `nil` fields mean "no face detected" (or no landmarks) for that signal.
struct FaceReading {
    var foreheadPoint: CGPoint?   // top-center of the largest face box, view coordinates
    var roll: CGFloat?            // head tilt in radians (largest face's VNFaceObservation.roll)
    var faceCentersX: [CGFloat]   // normalized X-centers (0...1) of up to 2 faces, sorted ascending
    var mouthOpen: Bool?          // true when the inner-lip openness ratio exceeds a threshold
    var mouthCenter: CGPoint?     // centroid of inner-lip points, view coordinates (matches foreheadPoint space)
}
```

- [ ] **Step 2: Switch the Vision request to landmarks**

Replace line ~43 `private let faceRequest = VNDetectFaceRectanglesRequest()` with:

```swift
    private let faceRequest = VNDetectFaceLandmarksRequest()

    /// Inner-lip openness ratio above which the mouth counts as "open".
    /// (verticalGap / mouthWidth). Tuned on-device; start conservative.
    private let mouthOpenThreshold: CGFloat = 0.28
```

`VNDetectFaceLandmarksRequest` results are still `[VNFaceObservation]`, so the existing `faceRequest.results as? [VNFaceObservation]` casts at lines ~176 and ~182 keep working unchanged. The `roll`, `boundingBox`, and `faceCentersX` logic is untouched.

- [ ] **Step 3: Add mouth-fields to the smoothing state**

After the existing `private var smoothedCentersX: [CGFloat] = []` (line ~51), add:

```swift
    /// Low-pass-filtered mouth center (view space); nil when no mouth landmarks.
    private var smoothedMouthCenter: CGPoint?
    /// Latched mouth-open state; nil when no face/landmarks.
    private var smoothedMouthOpen: Bool?
```

- [ ] **Step 4: Compute openness + raw mouth center in `captureOutput`**

In `captureOutput`, after `let roll = face.roll.map { CGFloat(truncating: $0) }` (line ~199), add the inner-lip computation. Insert:

```swift
        // Inner-lip landmarks → openness ratio + image-normalized centroid.
        // Region points are normalized within the face bounding box.
        var mouthOpenRaw: Bool?
        var mouthCenterImageNorm: CGPoint?
        if let inner = face.landmarks?.innerLips, inner.pointCount > 0 {
            let pts = inner.normalizedPoints   // [CGPoint], 0...1 within the box
            let xs = pts.map { $0.x }
            let ys = pts.map { $0.y }
            if let minX = xs.min(), let maxX = xs.max(),
               let minY = ys.min(), let maxY = ys.max(), (maxX - minX) > 0 {
                let widthBox = maxX - minX
                let gapBox = maxY - minY
                mouthOpenRaw = (gapBox / widthBox) >= mouthOpenThreshold
                // Centroid in box-normalized space → image-normalized.
                let cx = xs.reduce(0, +) / CGFloat(pts.count)
                let cy = ys.reduce(0, +) / CGFloat(pts.count)
                mouthCenterImageNorm = CGPoint(
                    x: box.origin.x + cx * box.width,
                    y: box.origin.y + cy * box.height
                )
            }
        }
```

- [ ] **Step 5: Map the mouth center to view space on the main thread**

Replace the existing main-thread block at the end of `captureOutput` (the `DispatchQueue.main.async { ... self.emit(point, roll: roll, centersX: centersX) }`, lines ~202-210) with:

```swift
        // Coordinate math reads `bounds` and updates state — do it on main.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let point = self.screenPoint(
                forNormalizedBox: box,
                bufferWidth: bufferWidth,
                bufferHeight: bufferHeight
            )
            let mouthPoint = mouthCenterImageNorm.map {
                self.screenPoint(
                    forImageNormalized: $0,
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )
            }
            self.emit(point, roll: roll, centersX: centersX,
                      mouthOpen: mouthOpenRaw, mouthCenter: mouthPoint)
        }
```

- [ ] **Step 6: Add the image-normalized → view-space mapper**

Immediately after the existing `screenPoint(forNormalizedBox:...)` method (ends ~line 240), add a sibling that maps an arbitrary image-normalized point (Vision bottom-left origin) using the same aspect-fill geometry:

```swift
    /// Converts an image-normalized point (Vision space, bottom-left origin)
    /// into this view's coordinates, matching `.resizeAspectFill` and the Y-flip.
    private func screenPoint(
        forImageNormalized p: CGPoint,
        bufferWidth: CGFloat,
        bufferHeight: CGFloat
    ) -> CGPoint {
        let viewSize = bounds.size
        guard bufferWidth > 0, bufferHeight > 0, viewSize.width > 0 else { return .zero }
        let scale = max(viewSize.width / bufferWidth, viewSize.height / bufferHeight)
        let displayedWidth = bufferWidth * scale
        let displayedHeight = bufferHeight * scale
        let offsetX = (viewSize.width - displayedWidth) / 2
        let offsetY = (viewSize.height - displayedHeight) / 2
        let x = p.x * displayedWidth + offsetX
        let y = (1 - p.y) * displayedHeight + offsetY   // Vision Y is bottom-left
        return CGPoint(x: x, y: y)
    }
```

- [ ] **Step 7: Extend `emit` to smooth and forward the mouth signals**

Replace the `emit` signature and the early-return `emit(nil, roll: nil, centersX: [])` calls. First, update the three failure-path calls (lines ~171, ~194) and the signature. Change the signature line `private func emit(_ raw: CGPoint?, roll: CGFloat?, centersX: [CGFloat]) {` to:

```swift
    private func emit(_ raw: CGPoint?, roll: CGFloat?, centersX: [CGFloat],
                      mouthOpen: Bool? = nil, mouthCenter: CGPoint? = nil) {
```

Then, just before the final `onReadingChange?(FaceReading(...))` call, add mouth smoothing:

```swift
        // Mouth-center smoothing (same low-pass factor); snap on appear/disappear.
        if let mc = mouthCenter {
            if let prev = smoothedMouthCenter {
                smoothedMouthCenter = CGPoint(
                    x: prev.x + (mc.x - prev.x) * smoothing,
                    y: prev.y + (mc.y - prev.y) * smoothing
                )
            } else {
                smoothedMouthCenter = mc
            }
        } else {
            smoothedMouthCenter = nil
        }
        smoothedMouthOpen = mouthOpen
```

And replace the final emit call with:

```swift
        onReadingChange?(FaceReading(
            foreheadPoint: smoothedPoint,
            roll: smoothedRoll,
            faceCentersX: smoothedCentersX,
            mouthOpen: smoothedMouthOpen,
            mouthCenter: smoothedMouthCenter
        ))
```

The two failure-path early calls become `self?.emit(nil, roll: nil, centersX: [])` (unchanged — the new params default to nil, so they correctly clear the mouth state via the `else` branch and `smoothedMouthOpen = nil`).

- [ ] **Step 8: Build**

Via XcodeBuildMCP: `session_show_defaults`, then `build_sim`. Expected: BUILD SUCCEEDED. (SourceKit may report false "Cannot find type" / "No such module" errors across files — only `build_sim` is authoritative.)

- [ ] **Step 9: Commit**

```bash
git add HotSeat/CameraPreviewView.swift
git commit -m "feat: emit open-mouth and mouth-center signals from camera landmarks"
```

---

## Task 2: TicTacToeViewModel (pure board/turn/confirm/win logic)

**Files:**
- Create: `HotSeat/TicTacToeViewModel.swift`

**Interfaces:**
- Consumes: nothing (pure Swift; no Vision, no UIKit, no SwiftUI beyond `Foundation`/`Observation`).
- Produces:
  - `enum TTTMark: Equatable { case o, x }`
  - `@Observable final class TicTacToeViewModel`
  - `var board: [TTTMark?]` (count 9, index 0–8 row-major), `var currentPlayer: TTTMark`, `var winner: TTTMark?`, `var isDraw: Bool`, `var winningLine: [Int]?`, `var pendingCell: Int?`, `var confirmProgress: Double`
  - `var isGameOver: Bool` (true if `winner != nil || isDraw`)
  - `func tick(delta: Double, targetedCell: Int?, mouthOpen: Bool)`
  - `func playAgain()`
- The view calls `tick` every frame. `targetedCell` is the EMPTY cell index the mouth currently sits in, or `nil` (mouth outside grid / over a filled cell / no face). `mouthOpen` is `faceTracker.mouthOpen ?? false`.

**Context:** `tick` is the entire interaction state machine. Constants: `confirmDuration = 1.0`s (hold to place), `placementLockout = 0.5`s (after a placement, ignore input so one sustained open mouth can't claim a second cell). Win check = 8 standard lines. `place` writes `currentPlayer`, evaluates win/draw, flips the player, and starts the lockout.

- [ ] **Step 1: Create the file with marks, state, and constants**

Create `HotSeat/TicTacToeViewModel.swift`:

```swift
import Foundation
import Observation

enum TTTMark: Equatable {
    case o, x

    var glyph: String {
        switch self {
        case .o: return "O"
        case .x: return "X"
        }
    }

    var playerNumber: Int {
        switch self {
        case .o: return 1
        case .x: return 2
        }
    }
}

@Observable
final class TicTacToeViewModel {
    // Tuning. confirmDuration: how long the open mouth must stay over one empty
    // cell before the mark drops. placementLockout: dead time after a placement
    // so a still-open mouth can't immediately fill another cell.
    private let confirmDuration: Double = 1.0
    private let placementLockout: Double = 0.5

    // The 8 winning lines (row-major indices).
    private let lines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],   // rows
        [0, 3, 6], [1, 4, 7], [2, 5, 8],   // cols
        [0, 4, 8], [2, 4, 6]               // diagonals
    ]

    var board: [TTTMark?] = Array(repeating: nil, count: 9)
    var currentPlayer: TTTMark = .o
    var winner: TTTMark?
    var isDraw: Bool = false
    var winningLine: [Int]?

    // Confirm progress for the currently targeted cell.
    var pendingCell: Int?
    var confirmProgress: Double = 0   // 0...1

    private var lockoutRemaining: Double = 0

    var isGameOver: Bool { winner != nil || isDraw }
}
```

- [ ] **Step 2: Add the per-frame `tick` state machine**

Append inside the class:

```swift
    /// Per-frame driver. `targetedCell` = the empty cell the mouth is over (or nil).
    func tick(delta: Double, targetedCell: Int?, mouthOpen: Bool) {
        guard !isGameOver else { resetPending(); return }

        if lockoutRemaining > 0 {
            lockoutRemaining = max(0, lockoutRemaining - delta)
            resetPending()
            return
        }

        // A valid hold requires an open mouth over an empty, in-grid cell.
        guard mouthOpen,
              let cell = targetedCell,
              board.indices.contains(cell),
              board[cell] == nil
        else {
            resetPending()
            return
        }

        if pendingCell == cell {
            confirmProgress += delta / confirmDuration
            if confirmProgress >= 1.0 {
                place(at: cell)
            }
        } else {
            // New / different cell: start a fresh hold (cancel-on-move).
            pendingCell = cell
            confirmProgress = 0
        }
    }

    private func resetPending() {
        pendingCell = nil
        confirmProgress = 0
    }
```

- [ ] **Step 3: Add `place`, win/draw evaluation, and turn flip**

Append inside the class:

```swift
    private func place(at cell: Int) {
        board[cell] = currentPlayer
        resetPending()

        if let line = winningLine(for: currentPlayer) {
            winner = currentPlayer
            winningLine = line
        } else if board.allSatisfy({ $0 != nil }) {
            isDraw = true
        } else {
            currentPlayer = (currentPlayer == .o) ? .x : .o
            lockoutRemaining = placementLockout
        }
    }

    private func winningLine(for mark: TTTMark) -> [Int]? {
        lines.first { line in line.allSatisfy { board[$0] == mark } }
    }
```

- [ ] **Step 4: Add `playAgain`**

Append inside the class:

```swift
    /// Reset for a new round with the same two players. O goes first again.
    func playAgain() {
        board = Array(repeating: nil, count: 9)
        currentPlayer = .o
        winner = nil
        isDraw = false
        winningLine = nil
        resetPending()
        lockoutRemaining = 0
    }
```

- [ ] **Step 5: Build**

Via XcodeBuildMCP: `build_sim`. The new file is not yet registered in the Xcode project (Task 4), so it will NOT be compiled yet — expect BUILD SUCCEEDED with the file simply not part of the target. This step only confirms the existing project still builds. (Full compilation of this file is verified in Task 4 after registration.)

- [ ] **Step 6: Commit**

```bash
git add HotSeat/TicTacToeViewModel.swift
git commit -m "feat: add TicTacToeViewModel board/turn/confirm/win logic"
```

---

## Task 3: TicTacToeView (grid over camera, hit-test, feedback, end card)

**Files:**
- Create: `HotSeat/TicTacToeView.swift`

**Interfaces:**
- Consumes:
  - `FaceTracker` (from `ContentView.swift`) with `mouthOpen: Bool?` and `mouthCenter: CGPoint?` (added in Task 4 Step 1; this view reads them).
  - `TicTacToeViewModel` (Task 2): `board`, `currentPlayer`, `winner`, `isDraw`, `winningLine`, `pendingCell`, `confirmProgress`, `isGameOver`, `tick(delta:targetedCell:mouthOpen:)`, `playAgain()`, and `TTTMark` (`.glyph`, `.playerNumber`).
- Produces: `struct TicTacToeView: View { init(faceTracker: FaceTracker, onExit: @escaping () -> Void) }`.

**Context:** Mirror `HeadsUpView`'s structure: a `@State private var viewModel`, the injected `faceTracker`, an `onExit` closure, and a PRIVATE `CADisplayLink` modifier with file-unique type names (`TTTDisplayLinkModifier` / `TTTDisplayLinkView` / its `Coordinator`) — do NOT reuse Heads Up's types; SwiftUI files each carry their own copy. The grid frame is captured via `GeometryReader` so cell rects live in the same coordinate space as `faceTracker.mouthCenter`. Camera is NOT suppressed here (handled by ContentView showing the normal camera path for `.ticTacToe`).

- [ ] **Step 1: Create the file scaffold, state, and body**

Create `HotSeat/TicTacToeView.swift`:

```swift
import SwiftUI
import UIKit

struct TicTacToeView: View {
    @State private var viewModel = TicTacToeViewModel()
    var faceTracker: FaceTracker
    let onExit: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    // Display-link timing.
    @State private var lastTimestamp: CFTimeInterval = 0
    // The grid's frame in view space, captured via GeometryReader, used to
    // hit-test the mouth center against cells.
    @State private var gridFrame: CGRect = .zero

    // Pre-warmed haptic for a placement.
    @State private var impactHaptics = UIImpactFeedbackGenerator(style: .rigid)

    var body: some View {
        ZStack {
            gridLayer
            turnIndicator
            topBar
            if viewModel.isGameOver { endCard }
        }
        .onAppear {
            lastTimestamp = 0
            impactHaptics.prepare()
        }
        .onChange(of: viewModel.board) { _, _ in
            // Re-arm the generator after each board mutation (cheap, like Heads Up).
            impactHaptics.prepare()
        }
        .modifier(TTTDisplayLinkModifier { timestamp in
            advance(to: timestamp)
        })
    }
}
```

- [ ] **Step 2: Add the tick driver with hit-testing and placement haptic**

Append inside `struct TicTacToeView` (before the closing brace, or in the same extension — keep it in the struct):

```swift
    // MARK: - Tick driver

    private func advance(to timestamp: CFTimeInterval) {
        guard lastTimestamp != 0 else { lastTimestamp = timestamp; return }
        // Clamp delta so an app-resume can't deliver one huge step.
        let delta = min(Double(timestamp - lastTimestamp), 0.1)
        lastTimestamp = timestamp

        let before = viewModel.board
        let cell = targetedCell()
        viewModel.tick(delta: delta,
                       targetedCell: cell,
                       mouthOpen: faceTracker.mouthOpen ?? false)
        // Fire a haptic exactly when a mark lands (board changed this frame).
        if viewModel.board != before {
            impactHaptics.impactOccurred()
        }
    }

    /// The empty cell whose rect contains the mouth center, or nil.
    private func targetedCell() -> Int? {
        guard gridFrame.width > 0, let mc = faceTracker.mouthCenter else { return nil }
        guard gridFrame.contains(mc) else { return nil }
        let cellW = gridFrame.width / 3
        let cellH = gridFrame.height / 3
        let col = min(2, max(0, Int((mc.x - gridFrame.minX) / cellW)))
        let row = min(2, max(0, Int((mc.y - gridFrame.minY) / cellH)))
        let index = row * 3 + col
        return viewModel.board[index] == nil ? index : nil
    }
```

- [ ] **Step 3: Add the grid layer (cells, marks, confirm ring, winning-line highlight)**

Append inside the struct:

```swift
    // MARK: - Grid

    private var gridSide: CGFloat { isCompact ? 320 : 460 }

    private var gridLayer: some View {
        GeometryReader { geo in
            let side = min(gridSide, min(geo.size.width, geo.size.height) - 40)
            let origin = CGPoint(x: (geo.size.width - side) / 2,
                                 y: (geo.size.height - side) / 2)
            ZStack {
                ForEach(0..<9, id: \.self) { index in
                    cellView(index: index, side: side / 3)
                        .position(cellCenter(index: index, side: side, origin: origin))
                }
            }
            .onAppear { gridFrame = CGRect(origin: origin, size: CGSize(width: side, height: side)) }
            .onChange(of: geo.size) { _, _ in
                let s = min(gridSide, min(geo.size.width, geo.size.height) - 40)
                let o = CGPoint(x: (geo.size.width - s) / 2, y: (geo.size.height - s) / 2)
                gridFrame = CGRect(origin: o, size: CGSize(width: s, height: s))
            }
        }
        .ignoresSafeArea()
    }

    private func cellCenter(index: Int, side: CGFloat, origin: CGPoint) -> CGPoint {
        let cell = side / 3
        let col = CGFloat(index % 3)
        let row = CGFloat(index / 3)
        return CGPoint(x: origin.x + cell * (col + 0.5),
                       y: origin.y + cell * (row + 0.5))
    }

    private func cellView(index: Int, side: CGFloat) -> some View {
        let isPending = viewModel.pendingCell == index
        let isWinning = viewModel.winningLine?.contains(index) ?? false
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isPending ? 0.18 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isWinning ? Color.green : Color.white.opacity(0.5),
                                lineWidth: isWinning ? 4 : 2)
                )

            // Confirm ring grows with confirmProgress on the pending cell.
            if isPending {
                Circle()
                    .trim(from: 0, to: viewModel.confirmProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(side * 0.22)
            }

            if let mark = viewModel.board[index] {
                Text(mark.glyph)
                    .font(.system(size: side * 0.55, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: side - 8, height: side - 8)
    }
```

- [ ] **Step 4: Add the turn indicator, top bar, and end card**

Append inside the struct:

```swift
    // MARK: - Overlays

    private var turnIndicator: some View {
        VStack {
            Spacer()
            if !viewModel.isGameOver {
                let mark = viewModel.currentPlayer
                Text("Player \(mark.playerNumber): open mouth to place \(mark.glyph)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, isCompact ? 28 : 44)
            }
        }
    }

    private var topBar: some View {
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
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 12 : 20)
            Spacer()
        }
    }

    private var endCard: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            Text(endTitle)
                .font(.system(size: isCompact ? 34 : 50, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: isCompact ? 12 : 16) {
                Button("Play again") {
                    withAnimation(.spring(duration: 0.3)) { viewModel.playAgain() }
                }
                .font(.title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32).padding(.vertical, 14)
                .background(.white).foregroundStyle(.black).clipShape(Capsule())

                Button("Games") {
                    withAnimation(.spring(duration: 0.3)) { onExit() }
                }
                .font(.title2.weight(.semibold))
                .padding(.horizontal, isCompact ? 20 : 32).padding(.vertical, 14)
                .background(.white.opacity(0.2)).foregroundStyle(.white).clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(isCompact ? 24 : 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var endTitle: String {
        if let w = viewModel.winner { return "Player \(w.playerNumber) wins!" }
        if viewModel.isDraw { return "It's a draw!" }
        return ""
    }
```

- [ ] **Step 5: Add the private CADisplayLink modifier (file-unique names)**

Append at file scope (after the `struct TicTacToeView` closing brace):

```swift
// MARK: - Display link (private copy; unique names per file)

private struct TTTDisplayLinkModifier: ViewModifier {
    let onFrame: (CFTimeInterval) -> Void
    func body(content: Content) -> some View {
        content.background(TTTDisplayLinkView(onFrame: onFrame))
    }
}

private struct TTTDisplayLinkView: UIViewRepresentable {
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
        init(onFrame: @escaping (CFTimeInterval) -> Void) { self.onFrame = onFrame }
        func start() {
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        }
        func stop() { link?.invalidate(); link = nil }
        @objc private func step(_ link: CADisplayLink) { onFrame(link.timestamp) }
    }
}
```

- [ ] **Step 6: Build**

Via XcodeBuildMCP: `build_sim`. As with Task 2, the file is not yet registered in the project, so it won't compile into the target until Task 4. Confirm the existing project still builds: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add HotSeat/TicTacToeView.swift
git commit -m "feat: add TicTacToeView grid, hit-test, confirm ring, end card"
```

---

## Task 4: Wire navigation, register files, and build the full game

**Files:**
- Modify: `HotSeat/ContentView.swift`
- Modify: `HotSeat/HomeView.swift`
- Modify: `HotSeat.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `TicTacToeView(faceTracker:onExit:)` (Task 3), `FaceTracker` (extended here).
- Produces: `.ticTacToe` in `AppScreen`; `AppViewModel.openTicTacToe()`; `FaceTracker.mouthOpen`/`.mouthCenter`; a `ticTacToe` game tile.

- [ ] **Step 1: Add mouth fields to `FaceTracker` and populate them**

In `HotSeat/ContentView.swift`, in the `FaceTracker` class (after `var faceCentersX: [CGFloat] = []`, ~line 49) add:

```swift
    /// True when the tracked face's mouth is open (nil if no face).
    var mouthOpen: Bool?
    /// Mouth center in full-screen view coordinates, or nil if no face.
    var mouthCenter: CGPoint?
```

Then in the `CameraPreviewView { reading in ... }` closure (~lines 517-521), after `faceTracker.faceCentersX = reading.faceCentersX` add:

```swift
                    faceTracker.mouthOpen = reading.mouthOpen
                    faceTracker.mouthCenter = reading.mouthCenter
```

- [ ] **Step 2: Add the `.ticTacToe` screen and open method**

In `ContentView.swift`, add `case ticTacToe` to the `AppScreen` enum (after `case headsUp`, ~line 9):

```swift
    case ticTacToe
```

In `AppViewModel`, after `openHeadsUp()` (~line 34) add:

```swift
    func openTicTacToe() {
        screen = .ticTacToe
    }
```

- [ ] **Step 3: Add the screen switch case**

In `ContentView.body`'s `switch appViewModel.screen` (after the `case .headsUp:` block, ~line 585) add:

```swift
            case .ticTacToe:
                TicTacToeView(
                    faceTracker: faceTracker,
                    onExit: {
                        withAnimation(.spring(duration: 0.3)) {
                            appViewModel.goHome()
                        }
                    }
                )
```

Note: the camera-suppression branch (`if appViewModel.screen == .headsUp`) is NOT modified — Tic Tac Toe uses the normal camera path, so the live feed shows behind the grid.

- [ ] **Step 4: Add the home tile and selection closure**

In `HotSeat/HomeView.swift`, add to `allGames` (after the `headsUp` entry, ~line 16):

```swift
    Game(id: "ticTacToe", name: "Tic Tac Toe", emoji: "\u{2B55}", icon: nil, isAvailable: true),
```

Add the closure property to `HomeView` (after `let onSelectHeadsUp: () -> Void`, ~line 25):

```swift
    let onSelectTicTacToe: () -> Void
```

In the spin-wheel `onLanded` switch (after `case "headsUp": onSelectHeadsUp()`, ~line 109) add:

```swift
                                case "ticTacToe":
                                    onSelectTicTacToe()
```

In the `gameTile` tap switch (after `case "headsUp": onSelectHeadsUp()`, ~line 140) add:

```swift
                case "ticTacToe":
                    onSelectTicTacToe()
```

- [ ] **Step 5: Pass the closure from ContentView's HomeView call**

Back in `ContentView.swift`, in the `case .home: HomeView(...)` call, after the `onSelectHeadsUp:` argument (~line 544-546) add:

```swift
                    onSelectTicTacToe: {
                        appViewModel.openTicTacToe()
                    }
```

- [ ] **Step 6: Register the two new files in project.pbxproj (4 sections)**

The project uses hand-assigned IDs (highest existing pair is `A1000017/A2000017`). Use these new IDs:

| File | PBXBuildFile ID | PBXFileReference ID |
|------|-----------------|---------------------|
| TicTacToeViewModel.swift | A1000018 | A2000018 |
| TicTacToeView.swift | A1000019 | A2000019 |

**6a — PBXBuildFile:** after the line `A1000017 /* HeadsUpView.swift in Sources */ = {isa = PBXBuildFile; ...};` add:

```
		A1000018 /* TicTacToeViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000018 /* TicTacToeViewModel.swift */; };
		A1000019 /* TicTacToeView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000019 /* TicTacToeView.swift */; };
```

**6b — PBXFileReference:** after the line `A2000017 /* HeadsUpView.swift */ = {isa = PBXFileReference; ...};` add:

```
		A2000018 /* TicTacToeViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TicTacToeViewModel.swift; sourceTree = "<group>"; };
		A2000019 /* TicTacToeView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TicTacToeView.swift; sourceTree = "<group>"; };
```

**6c — PBXGroup (`A5000002 /* HotSeat */` children):** after `A2000017 /* HeadsUpView.swift */,` add:

```
				A2000018 /* TicTacToeViewModel.swift */,
				A2000019 /* TicTacToeView.swift */,
```

**6d — Sources build phase (`A7000001 /* Sources */` files):** after `A1000017 /* HeadsUpView.swift in Sources */,` add:

```
				A1000018 /* TicTacToeViewModel.swift in Sources */,
				A1000019 /* TicTacToeView.swift in Sources */,
```

Verify the anchor IDs first: `grep -n "A1000017\|A2000017\|A5000002\|A7000001" HotSeat.xcodeproj/project.pbxproj`.

- [ ] **Step 7: Build the full game**

Via XcodeBuildMCP: `build_sim`. Expected: BUILD SUCCEEDED with both new files compiled (no "Cannot find TicTacToeView/TicTacToeViewModel in scope" errors from ContentView/HomeView). If those symbols are missing, the pbxproj registration (Step 6) is incomplete.

- [ ] **Step 8: Commit**

```bash
git add HotSeat/ContentView.swift HotSeat/HomeView.swift HotSeat.xcodeproj/project.pbxproj
git commit -m "feat: wire Tic Tac Toe into navigation, face tracker, and home screen"
```

---

## Task 5: On-device verification (manual)

**Files:** none (manual test on Thorin16).

This game cannot be validated in the simulator (camera is black). Build, install, and test on the physical device.

- [ ] **Step 1: Build for device**

```bash
xcodebuild -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug \
  -destination 'id=00008140-00065C5A14D1801C' -allowProvisioningUpdates \
  -derivedDataPath /tmp/ttt-dd build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Install (retry once on transient disconnect)**

```bash
xcrun devicectl device install app --device 00008140-00065C5A14D1801C \
  /tmp/ttt-dd/Build/Products/Debug-iphoneos/HotSeat.app
```
CoreDeviceError 4000 ("disconnected immediately") is transient — `sleep 3` and retry. Success prints an incremented `databaseSequenceNumber`.

- [ ] **Step 3: Verify on device (fully kill + relaunch the app first)**

`devicectl install` updates the on-disk app but iOS keeps any backgrounded process running old code — swipe-close HotSeat from the app switcher and relaunch before testing. Then verify:
- Home → Tic Tac Toe tile launches the game; live camera shows behind the grid.
- Turn indicator reads "Player 1: open mouth to place O".
- Opening the mouth over an empty square starts the confirm ring; holding ~1s places an O.
- Moving the mouth / closing it before 1s cancels the ring (cancel-on-move).
- Turn flips to "Player 2 ... X"; placing fills an X.
- A sustained open mouth does NOT immediately fill a second cell (lockout).
- Three-in-a-row highlights the winning line and shows "Player N wins!"; a full board shows "It's a draw!".
- Play again clears the board (O first); Games returns home.

- [ ] **Step 4: Tune if needed**

If the mouth reads as open too easily / not easily enough, adjust `mouthOpenThreshold` in `CameraPreviewView.swift` (higher = harder to trigger). If the targeted cell is offset from where the mouth visually sits, the `screenPoint(forImageNormalized:)` mapping needs review (most likely the Y-flip or aspect-fill offset). Re-build, re-install, re-commit any tuning change.

---

## Self-Review Notes

- **Spec coverage:** camera signals (Task 1) ✓; pure board/turn/confirm/win/draw/lockout (Task 2) ✓; grid-over-camera + hit-test + confirm ring + turn indicator + end card (Task 3) ✓; navigation + FaceTracker + home tile + spin wheel + pbxproj (Task 4) ✓; on-device validation + tuning (Task 5) ✓.
- **O-goes-first / lockout / no-test-target / camera-not-suppressed:** all reflected.
- **Type consistency:** `TTTMark` (.glyph/.playerNumber), `tick(delta:targetedCell:mouthOpen:)`, `playAgain()`, `pendingCell`, `confirmProgress`, `winningLine`, `isGameOver`, `FaceReading.mouthOpen/.mouthCenter`, `FaceTracker.mouthOpen/.mouthCenter`, IDs `A1000018/19`, `A2000018/19` — consistent across tasks.
