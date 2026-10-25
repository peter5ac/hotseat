# Hot Take — Home / Game Picker Redesign

**Date:** 2026-06-23
**Status:** Approved

## Problem

Hot Take is a kids' (7–14) camera-game app — a TikTok-style filter/game experience with
no video, posting, accounts, or social feed. Today the app opens directly into the Blind
Ranking game's category picker. To support "add more games/filters later," the app should
open to a top-level game picker. Only the Rank game exists now; the picker must communicate
that more are coming without looking broken.

## Goals

- App opens to a home screen where the player chooses a game/filter.
- Rank game is the one available choice; selecting it leads into the existing, unchanged flow.
- Adding a future game is cheap: append to a data array + add one route case.
- Keep the camera-as-background + dimming overlay consistent across all screens.

## Non-goals (YAGNI)

- No camera filters / AR / face effects are built. "Filter" is aspirational naming on
  placeholder tiles only.
- No `Game` protocol or plugin lifecycle for games that don't exist yet.
- No renaming of the `BlindRanking` project/target/directory (separate debt).

## Architecture

Introduce a top-level navigation state, separate from Rank's internal state.

### `AppViewModel` (new, `@Observable`)

```swift
enum AppScreen {
    case home
    case rank
}
```

- Holds `var screen: AppScreen = .home`.
- Only decides *which game is open*. Does not own Rank's sub-state.
- Methods: `openRank()` → `.rank`; `goHome()` → `.home`.

### `GameViewModel` (existing, unchanged internally)

Continues to own Rank's own state (`showingCategoryPicker`, slots, currentIndex, etc.).
Created/owned by the Rank view. When the app returns to home, Rank state resets for a fresh
start on next entry (re-init or explicit reset — implementer's choice, must start clean).

### `Game` model (new, light scaffold)

```swift
struct Game: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let isAvailable: Bool   // false → "coming soon", dimmed, non-tappable
}

let allGames: [Game] = [
    Game(id: "rank", name: "Blind Ranking", emoji: "🏆", isAvailable: true),
    // placeholders — dimmed "coming soon" tiles
    Game(id: "soon1", name: "New game coming soon", emoji: "✨", isAvailable: false),
    Game(id: "soon2", name: "New game coming soon", emoji: "🎉", isAvailable: false),
]
```

(Exact emoji/name copy for Rank tile is implementer's choice; keep on-brand and chill.)

## Screens & flow

```
.home (game picker)
  └─ tap Rank tile → .rank
         └─ Rank category picker  ── Back ──▶ .home
               └─ Rank game ── "New topic" / back ──▶ Rank category picker
```

### Home screen (`HomeView.swift`, new file)

- Same `CameraPreviewView` background + `Color.black.opacity(0.4)` dimming overlay as today.
- Title: **"Pick a game"** (rounded bold white, matching existing picker title styling).
- Grid of tiles reusing the existing glass-tile visual style from the category picker
  (`.ultraThinMaterial`, rounded rect, white stroke). Layout responsive via existing
  `horizontalSizeClass` isCompact pattern (2 columns compact, more on regular).
- Available tile: tappable → `appViewModel.openRank()`.
- Coming-soon tiles: dimmed (reduced opacity), `.disabled(true)`, with a small "soon"/lock
  affordance so it reads as intentional, not broken.
- Large tap targets, legible at arm's length (PRODUCT.md "pass-the-phone ready").

### Rank flow (existing)

- Unchanged game logic. The category picker's existing back button is rewired: instead of
  (or in addition to) returning within Rank, the top-level back from the category picker
  calls `appViewModel.goHome()`.
- In-game back / "New topic" continues to return to the category picker (Rank-internal),
  not all the way home.

## File layout

- `BlindRanking/ContentView.swift` — becomes the root view holding `AppViewModel` and
  switching on `AppScreen`. Camera background + overlay live here, shared across screens.
  Rank's category picker + game views stay here (or extract later — not required now).
- `BlindRanking/HomeView.swift` — **new**. Home game picker view + `Game` model + `allGames`.
- `BlindRanking/CameraPreviewView.swift` — unchanged.

## Error / edge handling

- Camera preview is black in the simulator; live feed only on device. Home screen must still
  be fully usable over a black background (the dimming overlay already assumes this).
- Returning home mid-Rank-game must leave Rank in a clean state for the next entry.
- Coming-soon tiles must be impossible to activate (disabled + no navigation side effect).

## Testing / verification

- Manual: launch → home shows Rank tile + dimmed coming-soon tiles. Tap Rank → category
  picker. Back → home. Play a game, return home, re-enter → fresh game state.
- Verify coming-soon tiles do not respond to taps.
- Verify layout on both iPhone (compact) and iPad (regular) orientations.
- Build/run via XcodeBuildMCP simulator tools.
