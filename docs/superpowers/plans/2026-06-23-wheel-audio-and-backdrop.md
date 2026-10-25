# Wheel Audio & Backdrop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add decelerating tick + landing ding audio to the spin wheel, and hide the background list when the wheel is displayed.

**Architecture:** Two independent changes. Part A gates rendering of the caller's list content while the wheel is up (pure SwiftUI conditional). Part B adds a new `WheelAudio` class that uses `AVAudioEngine` to play runtime-synthesized PCM ticks/ding, wired into `SpinWheelView`'s spin lifecycle.

**Tech Stack:** SwiftUI, AVFoundation (`AVAudioEngine`, `AVAudioSession`, `AVAudioPlayerNode`), `AVAudioPCMBuffer` for runtime-synthesized waveforms.

## Global Constraints

- iOS 17+, Swift 5. Universal (iPhone + iPad).
- NOT a git repo — skip all commit steps; no version-control safety net.
- No unit test target. Verification = `xcodebuild` build succeeds + on-device manual check.
- New `.swift` files require 4 edits to `BlindRanking.xcodeproj/project.pbxproj` (PBXBuildFile, PBXFileReference, group children, Sources phase). Ids for this file: `A1000007` (build) / `A2000007` (fileRef).
- Audio must never crash or block the wheel — all audio calls are best-effort (errors swallowed → silence).
- `AVAudioSession` category `.ambient` — respects silent switch, mixes with other audio.
- Sound: synthesized PCM buffers only, no bundled audio assets.
- Device: iPhone "Thorin16" (`00008140-00065C5A14D1801C`). Use XcodeBuildMCP or `xcodebuild -destination 'platform=iOS,id=00008140-00065C5A14D1801C'` with `derivedDataPath /tmp/hottake-dd`.
- SourceKit may report false "Cannot find X in scope" errors mid-edit. Trust `BUILD SUCCEEDED`, not live diagnostics.

---

### Task 1: Hide background list behind wheel (Part A)

**Files:**
- Modify: `BlindRanking/ContentView.swift:304-306` (the `.rank` / `showingCategoryPicker` branch)
- Modify: `BlindRanking/HomeView.swift:46-78` (the `VStack` body content)

**Interfaces:**
- Consumes: existing `@State showingCategoryWheel` in `ContentView`, existing `@State showingGameWheel` in `HomeView`.
- Produces: visual suppression of list content when the wheel is up (no new API surface; later tasks don't depend on this).

- [ ] **Step 1: Gate categoryPicker in ContentView**

In `ContentView.swift`, replace the `.rank` case's category-picker branch so it renders nothing when the wheel is up. The wheel is an `.overlay` above the ZStack, so the content below just needs to disappear.

Replace lines 304–306:

```swift
            case .rank:
                if viewModel.showingCategoryPicker {
                    categoryPicker
```

With:

```swift
            case .rank:
                if viewModel.showingCategoryPicker {
                    if !showingCategoryWheel {
                        categoryPicker
                    }
```

This makes the category grid disappear when the wheel is presented. The camera + 0.4 dim (lines 291–295) remain untouched. The `.overlay` containing `SpinWheelView` + its 0.55 scrim renders on top of the now-empty space.

- [ ] **Step 2: Gate home content in HomeView**

In `HomeView.swift`, wrap the body's `VStack` content so it is hidden when `showingGameWheel` is true. The `.overlay` containing the wheel remains unconditional.

Replace the body (lines 45–103):

```swift
    var body: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            if !showingGameWheel {
                Text("Pick a game")
                    .font(.system(size: isCompact ? 32 : 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, isCompact ? 24 : 40)

                if availableGames.count >= 2 {
                    Button {
                        showingGameWheel = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("🎲")
                            Text("Spin for me")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: isCompact ? 12 : 16) {
                        ForEach(allGames) { game in
                            gameTile(game)
                        }
                    }
                    .padding(.horizontal, isCompact ? 16 : 40)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay {
            if showingGameWheel {
                SpinWheelView(
                    items: availableGames.map {
                        WheelItem(id: $0.id, label: $0.name, emoji: $0.emoji)
                    },
                    onLanded: { landed in
                        showingGameWheel = false
                        switch landed.id {
                        case "rank":
                            withAnimation(.spring(duration: 0.3)) {
                                onSelectRank()
                            }
                        default:
                            break
                        }
                    },
                    onCancel: {
                        showingGameWheel = false
                    }
                )
                .transition(.opacity)
            }
        }
    }
```

- [ ] **Step 3: Build and verify**

Build for device (or simulator — this is a view-logic change, doesn't need camera/audio):

```bash
xcodebuild -project BlindRanking.xcodeproj -scheme BlindRanking \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath /tmp/hottake-dd build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: On-device verification (human)**

Install on Thorin16. Check:
- Ranking screen → "Spin for me" → category grid disappears; dimmed camera face stays behind the reel + scrim.
- Cancel → category grid reappears.
- Home screen (forced test: set `soon1` `isAvailable: true` in `allGames`, build, open pie wheel, grid disappears). **Revert** `isAvailable` after testing.

---

### Task 2: Create WheelAudio class (Part B — audio engine + synth buffers)

**Files:**
- Create: `BlindRanking/WheelAudio.swift`
- Modify: `BlindRanking.xcodeproj/project.pbxproj` (4 spots)

**Interfaces:**
- Consumes: nothing (standalone utility class).
- Produces: `WheelAudio` class with API:
  - `init()` — synthesizes PCM buffers (tick + ding).
  - `func start()` — configures audio session + starts engine.
  - `func stop()` — stops engine.
  - `func playTick()` — plays tick buffer.
  - `func playDing()` — plays ding buffer.

- [ ] **Step 1: Create WheelAudio.swift**

Create file `BlindRanking/WheelAudio.swift` with this content:

```swift
import AVFoundation

final class WheelAudio {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let tickBuffer: AVAudioPCMBuffer
    private let dingBuffer: AVAudioPCMBuffer

    init() {
        let sampleRate: Double = 44100
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        tickBuffer = WheelAudio.synthesizeTick(format: format, sampleRate: sampleRate)
        dingBuffer = WheelAudio.synthesizeDing(format: format, sampleRate: sampleRate)
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }

    func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient)
            try session.setActive(true)
            try engine.start()
        } catch {
            // Best-effort: silence on failure
        }
    }

    func stop() {
        playerNode.stop()
        engine.stop()
    }

    func playTick() {
        guard engine.isRunning else { return }
        playerNode.scheduleBuffer(tickBuffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    func playDing() {
        guard engine.isRunning else { return }
        playerNode.scheduleBuffer(dingBuffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    // MARK: - Synthesis

    private static func synthesizeTick(format: AVAudioFormat, sampleRate: Double) -> AVAudioPCMBuffer {
        let duration: Double = 0.010  // 10ms
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        let frequency: Double = 1200  // Hz — dry click
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 500)  // fast decay
            data[i] = Float(sin(2.0 * .pi * frequency * t) * envelope * 0.4)
        }
        return buffer
    }

    private static func synthesizeDing(format: AVAudioFormat, sampleRate: Double) -> AVAudioPCMBuffer {
        let duration: Double = 0.400  // 400ms
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        let freq1: Double = 880   // A5
        let freq2: Double = 1109  // ~C#6 (major third above)
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 6.0)  // gentler decay — bell ring
            let sample = (sin(2.0 * .pi * freq1 * t) + 0.6 * sin(2.0 * .pi * freq2 * t)) * envelope * 0.35
            data[i] = Float(sample)
        }
        return buffer
    }
}
```

- [ ] **Step 2: Register WheelAudio.swift in project.pbxproj**

Four edits to `BlindRanking.xcodeproj/project.pbxproj`:

**2a. PBXBuildFile section** — add after line 15 (the SpinWheelView entry):
```
		A1000007 /* WheelAudio.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000007 /* WheelAudio.swift */; };
```

**2b. PBXFileReference section** — add after line 24 (the SpinWheelView entry):
```
		A2000007 /* WheelAudio.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WheelAudio.swift; sourceTree = "<group>"; };
```

**2c. Group children** — add `A2000007 /* WheelAudio.swift */,` after line 54 (SpinWheelView in group):
```
				A2000007 /* WheelAudio.swift */,
```

**2d. Sources build phase** — add after line 136 (SpinWheelView in Sources):
```
				A1000007 /* WheelAudio.swift in Sources */,
```

- [ ] **Step 3: Build to verify compilation**

```bash
xcodebuild -project BlindRanking.xcodeproj -scheme BlindRanking \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath /tmp/hottake-dd build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

---

### Task 3: Wire audio into SpinWheelView (tick scheduling + ding)

**Files:**
- Modify: `BlindRanking/SpinWheelView.swift`

**Interfaces:**
- Consumes: `WheelAudio` class from Task 2 (`.start()`, `.stop()`, `.playTick()`, `.playDing()`).
- Produces: audible tick/ding during wheel spins; no API surface changes to `SpinWheelView`.

- [ ] **Step 1: Add audio state and lifecycle**

In `SpinWheelView.swift`, add an audio property after the existing `@State` declarations (after line 21):

```swift
    @State private var audio = WheelAudio()
```

Add `.onAppear` / `.onDisappear` lifecycle to the outermost `ZStack` in `body`. Replace the existing `ZStack {` opening (line 42) through the end of `body`'s ZStack content. Specifically, wrap the body's ZStack with lifecycle modifiers. After the closing of the ZStack (before the end of `body`), append:

```swift
        .onAppear { audio.start() }
        .onDisappear { audio.stop() }
```

Place these modifiers on the outermost ZStack in `body`, just before the closing `}` of the `body` computed property. The full tail of `body` becomes:

```swift
            .padding(.vertical, 40)
        }
        .onAppear { audio.start() }
        .onDisappear { audio.stop() }
    }
```

- [ ] **Step 2: Schedule ticks + ding in the animated spin path**

In the `spin()` function, after the animation block and before the `DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration)` call (which is at line 199), insert the tick scheduling and ding:

```swift
        // Schedule decelerating ticks
        let tickCount: Int
        if isReel {
            tickCount = reelLandingIndex
        } else {
            tickCount = items.count * 5
        }
        var lastTickTime: Double = -1
        let minInterval: Double = 0.045  // 45ms floor
        for k in 1...tickCount {
            let fraction = Double(k) / Double(tickCount)
            let t = spinDuration * (1.0 - pow(1.0 - fraction, 1.0 / 3.0))
            if t - lastTickTime < minInterval { continue }
            lastTickTime = t
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [audio] in
                audio.playTick()
            }
        }
        // Schedule ding at landing
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) { [audio] in
            audio.playDing()
        }
```

This goes inside `spin()`, in the non-reduced-motion path, AFTER the `if isReel { ... } else { ... }` animation block (line 197) and BEFORE the existing `DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) { landedIndex = ...` (line 199).

- [ ] **Step 3: Add ding-only for reduced motion**

In the reduced-motion path of `spin()` (the early-return block starting at line 170), add the ding after the winner is set. After the line that sets `landedIndex` (or `rotation` for pie), add:

```swift
            audio.playDing()
```

The reduced-motion block (currently lines 170–181) becomes:

```swift
        if reduceMotion {
            if isReel {
                reelOffset = -CGFloat(winner) * rowHeight + rowHeight * 2
                landedIndex = winner
            } else {
                let sliceAngle = 360.0 / Double(items.count)
                rotation = -(sliceAngle * (Double(winner) + 0.5))
            }
            audio.playDing()
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                finish(winner)
            }
            return
        }
```

- [ ] **Step 4: Build**

```bash
xcodebuild -project BlindRanking.xcodeproj -scheme BlindRanking \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath /tmp/hottake-dd build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: On-device verification (human)**

Install on Thorin16. Check:
- Ranking → "Spin for me" → hear rapid ticks decelerating as reel slows → ding on landing.
- Silent switch ON → no sound; wheel still animates and lands correctly.
- Accessibility → Reduce Motion ON → no ticks; single ding when winner highlights; hold, then game starts.
- Cancel (X) before spinning → no sound at all.
- Tick feel: early ticks are rapid but distinct (not a buzz); late ticks are clearly spaced. If the 45ms floor is too tight or too loose, adjust `minInterval`.
- Ding timbre: pleasant bell, not jarring. If too harsh, reduce `freq2` amplitude or lower frequencies.

---

## Execution Notes for Subagents

- Tasks 1 and 2 are fully independent — can be dispatched in parallel.
- Task 3 depends on Task 2 (needs `WheelAudio` to exist and compile).
- Skip all commit steps (not a git repo).
- Do NOT rely on SourceKit/diagnostics between edits — only `BUILD SUCCEEDED` counts.
- Subagents cannot screenshot the device or hear audio. Report DONE on build success; the human verifies visuals and audio on-device.
- The `reelLandingIndex` local used in tick scheduling is already computed earlier in `spin()` (line 184: `let reelLandingIndex = items.count * reelFullPasses + winner`). The tick code references it; it's in scope.
