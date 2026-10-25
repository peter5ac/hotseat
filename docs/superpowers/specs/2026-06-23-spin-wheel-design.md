# Hot Take — Spin Wheel

**Date:** 2026-06-23
**Status:** Approved

## Problem

Hot Take lets kids pick a game (home screen) and a ranking category (ranking screen) by
tapping tiles. We want a "let fate decide" alternative: a spinning wheel that randomly
selects an item. It must work in both places, which have very different list sizes — 3 games
on home vs. 38 categories in ranking.

## Goals

- One reusable wheel component used in both the home game picker and the ranking category picker.
- The component is generic: it takes a list of items and reports which one it landed on. It
  knows nothing about games or categories.
- Visual form adapts to list size: pie wheel for short lists, slot reel for long lists.
- "Grab and go": after landing, auto-route to the chosen item with no extra confirm tap.

## Non-goals (YAGNI)

- No "spin again" / re-roll UI.
- No weighting, history, or "avoid repeats" logic — uniform random each spin.
- No sound (not in scope; can be added later).
- No change to the existing tile-tap flow — the wheel is an additive alternative.

## Component: `SpinWheelView`

New file `BlindRanking/SpinWheelView.swift`. A self-contained SwiftUI view presented as a
full-screen overlay over the existing camera + dimming background.

### Data type

```swift
struct WheelItem: Identifiable {
    let id: String
    let label: String
    let emoji: String?
}
```

### Interface

```swift
struct SpinWheelView: View {
    let items: [WheelItem]
    let onLanded: (WheelItem) -> Void
    let onCancel: () -> Void
}
```

- `onLanded` is called once, after the wheel stops and holds the winner ~1s.
- `onCancel` is called if the user dismisses without spinning (X button or tap on the dimmed
  backdrop outside the wheel).
- The view owns its own animation/selection state internally; callers pass data in and react
  to the two closures.

### Adaptive render mode

Chosen internally from `items.count`:

- `items.count < 10` → **pie wheel** (mode A): colored pie slices, one per item, pointer at
  top. Slice colors cycle through a fixed palette. Item label (+ emoji if present) drawn on
  each slice.
- `items.count >= 10` → **slot reel** (mode B): item labels scroll vertically past a fixed
  center selection window and decelerate onto the winner. Scales cleanly to 38 items.

### Spin behavior

- The wheel appears **stationary** with a prominent **"Spin!"** button. The spin starts on
  tap (not automatically on appear) — the tap is the anticipation moment.
- On tap: pick the winning index uniformly at random via `Int.random(in: 0..<items.count)`.
  Animate the wheel/reel decelerating to rest on that index over **~2.75 seconds** with an
  ease-out curve.
- When motion ends, highlight the winner for **~1 second**, then call `onLanded(winner)`.
- The "Spin!" button is disabled while a spin is in progress (no double-spin).

### Visual constraints

- Full-screen overlay over `CameraPreviewView` + `Color.black.opacity(0.4)` (the overlay is
  composed by the caller's screen; `SpinWheelView` renders its own additional scrim + wheel
  content, consistent with the rest of the app).
- Glass styling consistent with existing UI: `.ultraThinMaterial`, rounded rects, white
  strokes, rounded bold white type.
- Large tap targets; legible at arm's length over a (possibly black, in simulator) background.

## Integration

### Ranking category picker (`ContentView.swift`, `categoryPicker`)

- Add a "🎲 Spin for me" button near the title (always shown).
- Tapping presents `SpinWheelView` with the 38 categories mapped to `WheelItem`
  (`id` = category name, `label` = name, `emoji` = category emoji). Count ≥ 10 → slot reel.
- `onLanded` → call the existing `viewModel.selectCategory(matchingCategory)` (look up the
  `RankCategory` by the landed `WheelItem.id`), which starts the game. Dismiss the overlay.
- `onCancel` → dismiss the overlay, stay on the category picker.

### Home game picker (`HomeView.swift`)

- Add a "🎲 Spin for me" button, **rendered only when 2 or more games are `isAvailable`**.
  Today exactly one game (`rank`) is available, so the button is hidden on home now; it
  appears automatically when a second available game is added.
- When shown: present `SpinWheelView` with the available games mapped to `WheelItem`.
  Count < 10 → pie wheel.
- `onLanded` → route to the landed game. For the `rank` game this means the existing
  `onSelectRank()` path; the routing switch keys off `WheelItem.id`.
- `onCancel` → dismiss, stay on home.

## State / presentation

- Each screen owns a local `@State private var showingWheel = false` (and, for home, the
  available-games filter). Presented via a conditional overlay (`if showingWheel { SpinWheelView(...) }`)
  inside the existing ZStack, or `.fullScreenCover` — implementer's choice, but it must sit
  over the camera background and match the app's visual language.

## Motion & accessibility (impeccable)

The impeccable skill is a web-frontend skill; its CSS mechanics don't apply to SwiftUI, but
its motion philosophy does and is binding here:

- **Ease-out, no bounce, no elastic.** The spin decelerates on an ease-out (exponential-style,
  e.g. quint) curve and settles dead-still on the winner. No overshoot/wobble at rest.
- **The long spin is the justified exception to product-motion norms.** Product UI motion is
  normally 150–250ms and state-conveying; the ~2.75s spin is the deliberate "moment of
  delight" (the entertainment payload), so it's exempt. Everything *around* the wheel —
  overlay present/dismiss, button state changes — stays in the ~200ms band.
- **Reduced motion is mandatory.** Honor `@Environment(\.accessibilityReduceMotion)`. When
  enabled: skip the spin animation entirely and crossfade directly to the randomly-chosen
  winner (still held ~1s), then `onLanded`. Same random outcome, no spinning.
- **Full button states.** The "Spin!" button has default, pressed, and disabled (during spin)
  states — not default only.

## Error / edge handling

- Empty `items`: the spin button should not be shown if there are no items (ranking always
  has 38; home is gated at ≥2). `SpinWheelView` with an empty list must not crash — guard the
  random pick and render nothing spinnable.
- Single item (defensive): if `items.count == 1`, the wheel may land immediately on it; not a
  real case given the gates above, but must not crash.
- Camera is black in the simulator; the wheel must be fully usable over black.
- Dismissing mid-spin: disabled — the backdrop/X dismiss is only active before a spin starts
  or after it lands. (Simplest: disable cancel while spinning.)

## Testing / verification

No unit test target exists; verification is build-and-run on device (simulator unreliable per
prior session). Manual checks:

- Ranking → "Spin for me" → slot reel scrolls through categories, decelerates ~2.75s, holds
  winner ~1s, then the ranking game starts on that category.
- Home with only 1 available game → no spin button visible.
- (Forced test) temporarily flip a second game's `isAvailable` to true → home shows the spin
  button → pie wheel with the available games → lands → routes.
- Cancel before spinning returns to the picker with no selection.
- Spin button cannot be triggered twice during one spin.
- Check both iPhone (compact) and iPad (regular) layouts.

## Build / deploy

Build and install to the physical device (iPhone "Thorin16", id
`00008140-00065C5A14D1801C`) via `xcodebuild` + `xcrun devicectl`, as in the prior session.
New `SpinWheelView.swift` must be added to the Xcode target — the project uses explicit file
references in `project.pbxproj` (PBXFileReference + PBXBuildFile + group + sources phase), so
the new file requires the same four-spot pbxproj edit used when `HomeView.swift` was added.
