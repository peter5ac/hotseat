# Spin Wheel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable spinning-wheel picker that randomly selects an item, used in the ranking category picker (38 items → slot reel) and, once 2+ games exist, the home game picker (pie wheel).

**Architecture:** One self-contained SwiftUI view, `SpinWheelView`, parameterized by `[WheelItem]` and two closures (`onLanded`, `onCancel`). It chooses its render mode internally from item count (<10 → pie wheel; ≥10 → slot reel), owns its spin animation, and reports the landed item. Callers present it as a full-screen overlay and route from `onLanded`.

**Tech Stack:** SwiftUI, iOS 17+, Swift 5. No test target; verification is build-and-run on the physical device (simulator unreliable in this project).

## Global Constraints

- Platform: iOS 17+, Swift 5, SwiftUI. Universal (iPhone + iPad), all orientations.
- This is NOT a git repository — do NOT run git commands or commit. Skip all commit steps.
- New `.swift` files MUST be added to `BlindRanking.xcodeproj/project.pbxproj` in all FOUR spots: PBXBuildFile entry, PBXFileReference entry, the group children list, and the Sources build phase. Mirror the existing `HomeView.swift` entries (ids `A1000005` / `A2000005`).
- Spin animation: ease-out (exponential-style, e.g. easeOut), **no bounce, no elastic**, settles dead-still. Spin duration **~2.75s**. Winner held highlighted **~1s** before `onLanded`.
- Reduced motion mandatory: honor `@Environment(\.accessibilityReduceMotion)` — when on, skip the spin and crossfade directly to the (still randomly chosen) winner, hold ~1s, then `onLanded`.
- Overlay chrome (present/dismiss, button state changes) stays ~200ms — only the spin itself is long.
- Random pick: `Int.random(in: 0..<items.count)`. Uniform; no weighting/history.
- Render-mode threshold: `items.count < 10` → pie wheel; `>= 10` → slot reel.
- "Spin!" button has default / pressed / disabled (during spin) states; disabled prevents double-spin.
- Cancel (X button / tap on backdrop) only active BEFORE a spin starts or AFTER it lands — disabled mid-spin.
- Visual language: `.ultraThinMaterial`, rounded rects, white strokes, rounded bold white type; large tap targets; legible over a black background (camera is black in simulator).
- Home spin button shown ONLY when 2+ games are `isAvailable`. Today exactly one (`rank`) is available → hidden on home.
- Build/deploy to device: iPhone "Thorin16", id `00008140-00065C5A14D1801C`, via `xcodebuild` + `xcrun devicectl` (see Task 1 Step 4 for exact commands). Scheme `BlindRanking`, project `BlindRanking.xcodeproj`, bundle id `com.audrey.HotTake`, team `KWDH533B22`.

---

## File Structure

- `BlindRanking/SpinWheelView.swift` — **new**. `WheelItem` struct + `SpinWheelView` (both render modes, spin animation, reduced-motion path). Self-contained; no knowledge of games/categories.
- `BlindRanking/ContentView.swift` — **modify**. Add spin button + overlay to `categoryPicker`; map `allCategories` → `[WheelItem]`; route `onLanded` to `selectCategory`.
- `BlindRanking/HomeView.swift` — **modify**. Add gated spin button + overlay; map available games → `[WheelItem]`; route `onLanded` to `onSelectRank`.
- `BlindRanking.xcodeproj/project.pbxproj` — **modify**. Register `SpinWheelView.swift` (four spots).

---

### Task 1: `SpinWheelView` reusable component

**Files:**
- Create: `BlindRanking/SpinWheelView.swift`
- Modify: `BlindRanking.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces:
  - `struct WheelItem: Identifiable { let id: String; let label: String; let emoji: String? }`
  - `struct SpinWheelView: View { let items: [WheelItem]; let onLanded: (WheelItem) -> Void; let onCancel: () -> Void }`

- [ ] **Step 1: Create `BlindRanking/SpinWheelView.swift`**

```swift
import SwiftUI

struct WheelItem: Identifiable {
    let id: String
    let label: String
    let emoji: String?
}

struct SpinWheelView: View {
    let items: [WheelItem]
    let onLanded: (WheelItem) -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Spin state
    @State private var rotation: Double = 0          // pie wheel, degrees
    @State private var reelOffset: CGFloat = 0       // slot reel, points
    @State private var isSpinning = false
    @State private var landedIndex: Int? = nil

    private let spinDuration: Double = 2.75
    private let holdDuration: Double = 1.0
    private let rowHeight: CGFloat = 64

    private var isReel: Bool { items.count >= 10 }

    private let sliceColors: [Color] = [
        Color(red: 1.00, green: 0.42, blue: 0.42),
        Color(red: 1.00, green: 0.79, blue: 0.34),
        Color(red: 0.28, green: 0.86, blue: 0.98),
        Color(red: 0.11, green: 0.82, blue: 0.63),
        Color(red: 0.37, green: 0.15, blue: 0.80),
        Color(red: 1.00, green: 0.62, blue: 0.95),
        Color(red: 0.33, green: 0.63, blue: 1.00),
        Color(red: 0.55, green: 0.91, blue: 0.45)
    ]

    var body: some View {
        ZStack {
            // Scrim — tappable to cancel only when allowed
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { cancelIfAllowed() }

            VStack(spacing: 28) {
                HStack {
                    Spacer()
                    Button {
                        cancelIfAllowed()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(isSpinning)
                    .opacity(isSpinning ? 0.3 : 1.0)
                }
                .padding(.horizontal, 24)

                if items.isEmpty {
                    Text("Nothing to spin")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                } else if isReel {
                    reelView
                } else {
                    pieView
                }

                Button {
                    spin()
                } label: {
                    Text(isSpinning ? "Spinning…" : "Spin!")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 16)
                        .background(.white, in: Capsule())
                }
                .disabled(isSpinning || items.isEmpty)
                .opacity(isSpinning ? 0.5 : 1.0)
                .scaleEffect(isSpinning ? 0.97 : 1.0)
            }
            .padding(.vertical, 40)
        }
    }

    // MARK: - Pie wheel (<10 items)

    private var pieView: some View {
        ZStack {
            // Pointer
            Triangle()
                .fill(.white)
                .frame(width: 26, height: 20)
                .offset(y: -150)
                .zIndex(2)

            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PieSlice(index: index, total: items.count)
                        .fill(sliceColors[index % sliceColors.count])
                    sliceLabel(item, index: index)
                }
            }
            .frame(width: 280, height: 280)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 4))
            .rotationEffect(.degrees(rotation))
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        }
        .frame(height: 320)
    }

    private func sliceLabel(_ item: WheelItem, index: Int) -> some View {
        let sliceAngle = 360.0 / Double(items.count)
        let mid = sliceAngle * (Double(index) + 0.5)
        return Text("\(item.emoji ?? "") \(item.label)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: 110, alignment: .leading)
            .rotationEffect(.degrees(mid))
            .offset(x: 55 * cos((mid - 90) * .pi / 180),
                    y: 55 * sin((mid - 90) * .pi / 180))
    }

    // MARK: - Slot reel (>=10 items)

    private var reelView: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Text("\(item.emoji ?? "") \(item.label)")
                    .font(.title3.weight(landedIndex == index ? .bold : .semibold))
                    .foregroundStyle(landedIndex == index ? .white : .white.opacity(0.55))
                    .frame(height: rowHeight)
                    .frame(maxWidth: .infinity)
            }
        }
        .offset(y: reelOffset)
        .frame(height: rowHeight * 5, alignment: .top)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white, lineWidth: 3)
                .frame(height: rowHeight)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Spin logic

    private func spin() {
        guard !isSpinning, !items.isEmpty else { return }
        let winner = Int.random(in: 0..<items.count)
        isSpinning = true
        landedIndex = nil

        if reduceMotion {
            landedIndex = winner
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                finish(winner)
            }
            return
        }

        if isReel {
            // Scroll up through several full passes, landing the winner row in the window.
            let fullPasses = 4
            let totalRows = items.count * fullPasses + winner
            let target = -CGFloat(totalRows) * rowHeight + rowHeight * 2  // center winner in 5-row window
            withAnimation(.easeOut(duration: spinDuration)) {
                reelOffset = target
            }
        } else {
            let sliceAngle = 360.0 / Double(items.count)
            // Land so winner's slice mid sits under the top pointer.
            let landing = 360.0 * 5 - (sliceAngle * (Double(winner) + 0.5))
            withAnimation(.easeOut(duration: spinDuration)) {
                rotation = landing
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            landedIndex = winner
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                finish(winner)
            }
        }
    }

    private func finish(_ index: Int) {
        guard index < items.count else { return }
        onLanded(items[index])
    }

    private func cancelIfAllowed() {
        guard !isSpinning else { return }
        onCancel()
    }
}

// MARK: - Shapes

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

private struct PieSlice: Shape {
    let index: Int
    let total: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let sliceAngle = 360.0 / Double(total)
        let start = Angle.degrees(sliceAngle * Double(index) - 90)
        let end = Angle.degrees(sliceAngle * Double(index + 1) - 90)
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

#Preview("Pie (3)") {
    SpinWheelView(
        items: [
            WheelItem(id: "a", label: "Blind Ranking", emoji: "🏆"),
            WheelItem(id: "b", label: "Game Two", emoji: "✨"),
            WheelItem(id: "c", label: "Game Three", emoji: "🎉")
        ],
        onLanded: { _ in },
        onCancel: {}
    )
}

#Preview("Reel (12)") {
    SpinWheelView(
        items: (1...12).map { WheelItem(id: "\($0)", label: "Category \($0)", emoji: "🎲") },
        onLanded: { _ in },
        onCancel: {}
    )
}
```

- [ ] **Step 2: Register `SpinWheelView.swift` in `project.pbxproj`**

Open `BlindRanking.xcodeproj/project.pbxproj`. Find the four `HomeView.swift` lines (ids `A1000005` build file, `A2000005` file reference) and add parallel entries for `SpinWheelView.swift` using new unique ids `A1000006` / `A2000006`:

1. In the `PBXBuildFile` section, after the `A1000005 /* HomeView.swift in Sources */` line:
```
		A1000006 /* SpinWheelView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A2000006 /* SpinWheelView.swift */; };
```
2. In the `PBXFileReference` section, after the `A2000005 /* HomeView.swift */` line:
```
		A2000006 /* SpinWheelView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SpinWheelView.swift; sourceTree = "<group>"; };
```
3. In the group `children` list, after the `A2000005 /* HomeView.swift */,` line:
```
				A2000006 /* SpinWheelView.swift */,
```
4. In the Sources build phase `files` list, after the `A1000005 /* HomeView.swift in Sources */,` line:
```
				A1000006 /* SpinWheelView.swift in Sources */,
```

- [ ] **Step 3: Verify it builds for the device**

Run:
```bash
xcodebuild -project BlindRanking.xcodeproj -scheme BlindRanking -configuration Debug \
  -destination 'platform=iOS,id=00008140-00065C5A14D1801C' \
  -allowProvisioningUpdates -derivedDataPath /tmp/hottake-dd build 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`. Fix any compile errors (this is the animation-heavy file; read the actual error). Do NOT install yet — wiring lands in Tasks 2–3.

---

### Task 2: Wire the wheel into the ranking category picker

**Files:**
- Modify: `BlindRanking/ContentView.swift`

**Interfaces:**
- Consumes: `WheelItem`, `SpinWheelView(items:onLanded:onCancel:)` from Task 1; existing `allCategories: [RankCategory]` (each has `name`, `emoji`, `items`) and `viewModel.selectCategory(_:)`.

- [ ] **Step 1: Add wheel presentation state to `ContentView`**

In `struct ContentView`, after `@State private var appViewModel = AppViewModel()`, add:
```swift
    @State private var showingCategoryWheel = false
```

- [ ] **Step 2: Add a "Spin for me" button to the category picker header**

In the `categoryPicker` computed property, the first child is an `HStack` containing the "Games" back button and a `Spacer()`. Add a spin button after the `Spacer()`, inside that same HStack, so the HStack reads:
```swift
            HStack {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        appViewModel.goHome()
                    }
                } label: {
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
                Button {
                    showingCategoryWheel = true
                } label: {
                    HStack(spacing: 6) {
                        Text("🎲")
                        Text("Spin for me")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, isCompact ? 12 : 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 16 : 24)
```

- [ ] **Step 3: Present the wheel as an overlay over the root ZStack**

In `ContentView.body`, the outermost `ZStack` currently ends after the `switch appViewModel.screen { ... }`. Add an overlay modifier on that ZStack (after its closing brace, before `body`'s closing brace). The body becomes:
```swift
    var body: some View {
        ZStack {
            CameraPreviewView()
                .ignoresSafeArea()

            Color.black.opacity(0.4)
                .ignoresSafeArea()

            switch appViewModel.screen {
            case .home:
                HomeView(onSelectRank: {
                    viewModel.startRank()
                    appViewModel.openRank()
                })
            case .rank:
                if viewModel.showingCategoryPicker {
                    categoryPicker
                } else {
                    gameView
                }
            }
        }
        .overlay {
            if showingCategoryWheel {
                SpinWheelView(
                    items: allCategories.map {
                        WheelItem(id: $0.name, label: $0.name, emoji: $0.emoji)
                    },
                    onLanded: { landed in
                        if let category = allCategories.first(where: { $0.name == landed.id }) {
                            showingCategoryWheel = false
                            withAnimation(.spring(duration: 0.3)) {
                                viewModel.selectCategory(category)
                            }
                        } else {
                            showingCategoryWheel = false
                        }
                    },
                    onCancel: {
                        showingCategoryWheel = false
                    }
                )
                .transition(.opacity)
            }
        }
    }
```

- [ ] **Step 4: Build, install, and run on device**

Run:
```bash
xcodebuild -project BlindRanking.xcodeproj -scheme BlindRanking -configuration Debug \
  -destination 'platform=iOS,id=00008140-00065C5A14D1801C' \
  -allowProvisioningUpdates -derivedDataPath /tmp/hottake-dd build 2>&1 | tail -8
xcrun devicectl device install app --device 00008140-00065C5A14D1801C \
  /tmp/hottake-dd/Build/Products/Debug-iphoneos/BlindRanking.app 2>&1 | tail -5
xcrun devicectl device process launch --device 00008140-00065C5A14D1801C com.audrey.HotTake 2>&1 | tail -3
```
Expected: build succeeds, app installs and launches.

- [ ] **Step 5: Manual verification (ranking) — ask the user to confirm on device**

The implementer cannot screenshot the physical device. Report what to check; the controller/user verifies:
- Enter Blind Ranking → category picker shows a "🎲 Spin for me" button next to "Games".
- Tap it → full-screen wheel overlay (slot reel, since 38 ≥ 10).
- Tap "Spin!" → reel scrolls and decelerates (~2.75s, ease-out, no bounce), holds the winner ~1s, then the ranking game starts on that category.
- "Spin!" can't be tapped twice during a spin; X/backdrop disabled mid-spin.
- Cancel (X or tap backdrop) before spinning → returns to category picker, no selection.
- With Settings → Accessibility → Reduce Motion ON: no spin; jumps to a winner, holds, then starts.

---

### Task 3: Wire the wheel into the home game picker (gated at 2+ games)

**Files:**
- Modify: `BlindRanking/HomeView.swift`

**Interfaces:**
- Consumes: `WheelItem`, `SpinWheelView(items:onLanded:onCancel:)` from Task 1; existing `allGames: [Game]`, `HomeView.onSelectRank: () -> Void`.

- [ ] **Step 1: Add wheel state and an available-games helper to `HomeView`**

In `struct HomeView`, after the `onSelectRank` property and `horizontalSizeClass`, add:
```swift
    @State private var showingGameWheel = false

    private var availableGames: [Game] {
        allGames.filter { $0.isAvailable }
    }
```

- [ ] **Step 2: Add the gated spin button under the title**

In `HomeView.body`, the `VStack` currently holds the "Pick a game" `Text` then the `ScrollView`. Insert the spin button between them, shown only when 2+ games are available:
```swift
        VStack(spacing: isCompact ? 16 : 24) {
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
```

- [ ] **Step 3: Present the wheel overlay and route by game id**

Add an `.overlay` to the outer `VStack` in `HomeView.body` (after its closing brace). Routing keys off the landed `WheelItem.id`, which equals `Game.id`; the only currently-available game is `rank`:
```swift
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
```

- [ ] **Step 4: Build and run on device**

Run:
```bash
xcodebuild -project BlindRanking.xcodeproj -scheme BlindRanking -configuration Debug \
  -destination 'platform=iOS,id=00008140-00065C5A14D1801C' \
  -allowProvisioningUpdates -derivedDataPath /tmp/hottake-dd build 2>&1 | tail -8
xcrun devicectl device install app --device 00008140-00065C5A14D1801C \
  /tmp/hottake-dd/Build/Products/Debug-iphoneos/BlindRanking.app 2>&1 | tail -5
xcrun devicectl device process launch --device 00008140-00065C5A14D1801C com.audrey.HotTake 2>&1 | tail -3
```
Expected: build succeeds, app installs and launches.

- [ ] **Step 5: Manual verification (home gate) — ask the user to confirm on device**

- With only `rank` available (current state): the home screen shows NO spin button. Confirm.
- Forced test: temporarily edit `allGames` in `HomeView.swift` to set one `soon` game's `isAvailable` to `true`, rebuild → home now shows the spin button → tapping it opens a pie wheel (count < 10) with the available games → landing on Blind Ranking starts the rank flow. **Revert this edit afterward** so the released state keeps one available game.

---

## Self-Review

**Spec coverage:**
- Reusable generic component with `WheelItem` + two closures → Task 1. ✓
- Adaptive mode <10 pie / ≥10 reel → Task 1 `isReel`, both render paths. ✓
- Tap-to-spin "Spin!" button, disabled during spin → Task 1 button + `isSpinning`. ✓
- ~2.75s ease-out, no bounce, hold ~1s, then `onLanded` → Task 1 `spin()`/`finish()`. ✓
- Reduced motion: skip spin, crossfade to winner → Task 1 `reduceMotion` branch. ✓
- Cancel via X/backdrop, disabled mid-spin → Task 1 `cancelIfAllowed()`. ✓
- Full-screen overlay over camera/dimming → Tasks 2 & 3 `.overlay` over root ZStack/VStack. ✓
- Ranking: button always shown, 38 items, route to `selectCategory` → Task 2. ✓
- Home: button gated at 2+ available games, route by id → Task 3. ✓
- Empty/single-item guards → Task 1 `items.isEmpty` checks + `guard` in `spin`/`finish`. ✓
- New file registered in pbxproj (4 spots) → Task 1 Step 2. ✓
- Device build/deploy commands → Tasks 1–3 Step 4 (and Task 1 Step 3 build-only). ✓

**Placeholder scan:** No TBD/TODO; all code shown in full. ✓

**Type consistency:** `WheelItem(id:label:emoji:)`, `SpinWheelView(items:onLanded:onCancel:)`, `onLanded: (WheelItem) -> Void` — consistent across Tasks 1–3. Category routing uses `WheelItem.id == RankCategory.name`; game routing uses `WheelItem.id == Game.id`. Both mappings set `id` accordingly in the call sites. ✓

**Known risk:** the slot-reel landing math and pie-wheel landing angle (Task 1 `spin()`) are the parts most likely to need on-device tuning so the winner sits exactly in the window / under the pointer. The reviewer should treat visual landing accuracy as a verify-on-device item, not assume the first numbers are pixel-perfect.
