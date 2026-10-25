# Home / Game Picker Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Hot Take open to a top-level game/filter picker; selecting the one available game (Blind Ranking) enters the existing flow, with dimmed "coming soon" tiles signaling future games.

**Architecture:** Introduce an `AppViewModel` holding an `AppScreen` enum that decides which game is open. The root `ContentView` renders the shared camera background + dimming overlay and switches between a new `HomeView` (game picker) and the existing Rank flow. Rank's own `GameViewModel` is unchanged internally; returning home resets it for a clean re-entry.

**Tech Stack:** SwiftUI, iOS 17+, Swift 5, AVFoundation (existing camera preview). No test target exists; verification is build-and-run via XcodeBuildMCP simulator tools.

## Global Constraints

- Platform: iOS 17+, Swift 5, SwiftUI. Universal (iPhone + iPad), all orientations.
- Camera-as-background + `Color.black.opacity(0.4)` dimming overlay on every screen.
- No camera filters / AR / face effects are built. "Filter" is naming on placeholder tiles only.
- No `Game` protocol or plugin lifecycle (YAGNI). Light data-array scaffold only.
- No renaming of the `BlindRanking` project/target/directory.
- Large tap targets, legible at arm's length; responsive via `horizontalSizeClass` isCompact pattern (2 cols compact, 4 cols regular) matching existing category picker.
- Home title copy: **"Pick a game"**. Rank tile name/emoji: implementer's choice, on-brand and chill.
- Reuse existing glass-tile visuals: `.ultraThinMaterial`, `RoundedRectangle`, white stroke.

---

## File Structure

- `BlindRanking/HomeView.swift` — **new**. Holds the `Game` model, `allGames` array, and the `HomeView` game-picker view.
- `BlindRanking/ContentView.swift` — **modify**. Add `AppViewModel` + `AppScreen`. Root view renders shared camera background + overlay and switches `.home` / `.rank`. Existing Rank category picker + game views stay here; `GameViewModel` unchanged.
- `BlindRanking/CameraPreviewView.swift` — unchanged.

---

### Task 1: Game model, AppViewModel, and HomeView

**Files:**
- Create: `BlindRanking/HomeView.swift`
- Modify: `BlindRanking/ContentView.swift` (add `AppScreen` enum + `AppViewModel`)

**Interfaces:**
- Produces:
  - `enum AppScreen { case home, rank }`
  - `@Observable final class AppViewModel { var screen: AppScreen; func openRank(); func goHome() }`
  - `struct Game: Identifiable { let id: String; let name: String; let emoji: String; let isAvailable: Bool }`
  - `let allGames: [Game]`
  - `struct HomeView: View { let onSelectRank: () -> Void }` (renders content only — NOT the camera background; the root composes that. Available tile calls `onSelectRank`; the root wires that to reset + open Rank in Task 2.)

- [ ] **Step 1: Add `AppScreen` and `AppViewModel` to `ContentView.swift`**

Add near the top of `BlindRanking/ContentView.swift`, above `struct ContentView`:

```swift
enum AppScreen {
    case home
    case rank
}

@Observable
final class AppViewModel {
    var screen: AppScreen = .home

    func openRank() {
        screen = .rank
    }

    func goHome() {
        screen = .home
    }
}
```

- [ ] **Step 2: Create `HomeView.swift` with the `Game` model and picker UI**

Create `BlindRanking/HomeView.swift`:

```swift
import SwiftUI

struct Game: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let isAvailable: Bool
}

let allGames: [Game] = [
    Game(id: "rank", name: "Blind Ranking", emoji: "🏆", isAvailable: true),
    Game(id: "soon1", name: "New game coming soon", emoji: "✨", isAvailable: false),
    Game(id: "soon2", name: "New game coming soon", emoji: "🎉", isAvailable: false),
]

struct HomeView: View {
    let onSelectRank: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var columns: [GridItem] {
        if isCompact {
            return [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        } else {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        }
    }

    var body: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            Text("Pick a game")
                .font(.system(size: isCompact ? 32 : 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, isCompact ? 24 : 40)

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

    @ViewBuilder
    private func gameTile(_ game: Game) -> some View {
        Button {
            guard game.isAvailable else { return }
            withAnimation(.spring(duration: 0.3)) {
                onSelectRank()
            }
        } label: {
            VStack(spacing: 8) {
                Text(game.emoji)
                    .font(.system(size: isCompact ? 40 : 52))
                Text(game.name)
                    .font(isCompact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if !game.isAvailable {
                    Text("SOON")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.15)))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? 24 : 36)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .opacity(game.isAvailable ? 1.0 : 0.4)
        }
        .disabled(!game.isAvailable)
    }
}
```

- [ ] **Step 3: Verify it builds**

Run via XcodeBuildMCP: `build_sim` (confirm scheme/sim via `session_show_defaults` first).
Expected: build SUCCEEDS. `HomeView` compiles; coming-soon tiles are disabled and dimmed.

- [ ] **Step 4: Commit**

```bash
git add BlindRanking/HomeView.swift BlindRanking/ContentView.swift
git commit -m "feat: add Game model, AppViewModel, and HomeView game picker"
```

(If not a git repo, skip the commit step.)

---

### Task 2: Wire root navigation and home back-button

**Files:**
- Modify: `BlindRanking/ContentView.swift` (`ContentView.body`, header back action)

**Interfaces:**
- Consumes: `AppViewModel`, `AppScreen`, `HomeView(appViewModel:)` from Task 1.
- Produces: root view that owns `AppViewModel` and switches `.home` / `.rank`; Rank category-picker back returns to `.home`.

- [ ] **Step 1: Add `AppViewModel` state and switch on screen in `ContentView`**

In `BlindRanking/ContentView.swift`, in `struct ContentView`, add alongside the existing `@State private var viewModel = GameViewModel()`:

```swift
@State private var appViewModel = AppViewModel()
```

Replace the body's screen-selection block. Change:

```swift
            if viewModel.showingCategoryPicker {
                categoryPicker
            } else {
                gameView
            }
```

to:

```swift
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
```

(`startRank()` is added in Step 2.)

- [ ] **Step 2: Reset Rank state on entry and wire the home tile**

`HomeView` already takes `onSelectRank: () -> Void` (Task 1). The root wires that closure to reset Rank's state and then switch screens, so re-entering Rank from home always starts on a clean category picker.

Add an entry-reset method to `GameViewModel` in `ContentView.swift`:

```swift
    func startRank() {
        showingCategoryPicker = true
        currentCategory = nil
        items = []
        slots = []
        currentIndex = 0
    }
```

In `ContentView.body`, the home case wires the closure:

```swift
            case .home:
                HomeView(onSelectRank: {
                    viewModel.startRank()
                    appViewModel.openRank()
                })
```

- [ ] **Step 3: Rewire the category-picker back button to go home**

The existing header back button calls `viewModel.backToCategories()`. That header is shown in `gameView` (during play), where it should stay Rank-internal. But the category picker itself currently has no back button. Add a "Back" control to `categoryPicker` that returns to home.

In `ContentView.swift`, modify the `categoryPicker` computed property to add a back button above the title. Change:

```swift
    private var categoryPicker: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            Text("What are you ranking?")
                .font(.system(size: isCompact ? 32 : 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, isCompact ? 24 : 40)
```

to:

```swift
    private var categoryPicker: some View {
        VStack(spacing: isCompact ? 16 : 24) {
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
            }
            .padding(.horizontal, isCompact ? 16 : 40)
            .padding(.top, isCompact ? 16 : 24)

            Text("What are you ranking?")
                .font(.system(size: isCompact ? 32 : 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
```

- [ ] **Step 4: Verify it builds and runs**

Run via XcodeBuildMCP: `build_run_sim`.
Expected: build SUCCEEDS, app launches to "Pick a game" home screen.

- [ ] **Step 5: Manual verification on simulator**

Confirm each, capturing a `screenshot` where useful:
- App opens to home: "Pick a game" with the Rank tile bright + two dimmed "SOON" tiles.
- Tapping a "SOON" tile does nothing.
- Tapping the Rank tile → "What are you ranking?" category picker with a "Games" back button.
- "Games" back → returns to home.
- Pick a category, play, finish; "New topic" returns to the category picker (NOT home).
- From category picker, "Games" → home; re-enter Rank → fresh category picker (no stale state).
- Check both iPhone (compact) and iPad (regular) layouts/orientations.

- [ ] **Step 6: Commit**

```bash
git add BlindRanking/ContentView.swift BlindRanking/HomeView.swift
git commit -m "feat: wire top-level game picker navigation with home back-button"
```

(If not a git repo, skip the commit step.)

---

## Self-Review

**Spec coverage:**
- App opens to game picker → Task 2 root switch defaults to `.home`. ✓
- Rank is the available choice, leads to existing flow → Task 2 `onSelectRank`. ✓
- Cheap to add future game → append to `allGames`, add route case. ✓ (documented in File Structure)
- Camera background + overlay consistent → unchanged in `ContentView.body` ZStack, shared across screens; `HomeView` renders content only. ✓
- Dimmed non-tappable coming-soon tiles → Task 1 `opacity(0.4)` + `.disabled`. ✓
- Back from category picker → home; in-game back stays Rank-internal → Task 2 Step 3. ✓
- Clean Rank state on re-entry → Task 2 Step 2 `startRank()`. ✓
- No filters/AR, no protocol, no project rename → enforced by Global Constraints. ✓

**Placeholder scan:** No TBD/TODO; all code shown in full. ✓

**Type consistency:** `AppViewModel.openRank()/goHome()`, `Game(id:name:emoji:isAvailable:)`, `HomeView(onSelectRank:)` (final signature after Task 2 supersedes Task 1's `appViewModel:`), `GameViewModel.startRank()` — consistent across tasks. Note: Task 1 introduces `HomeView(appViewModel:)` and Task 2 Step 2 deliberately changes it to `onSelectRank:`; implementer ends on `onSelectRank:`.
