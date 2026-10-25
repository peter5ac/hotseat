# Chocolate Rain — Design Spec

**Date:** 2026-06-27
**Game type:** Expressive / skill hybrid (no failure state, but scored)
**Target audience:** Toddlers (ages 3–5), extremely forgiving

## Overview

Chocolates fall from the top of the screen. The child positions their open mouth under a falling chocolate to "eat" it. Each catch increments the score and fires a satisfying pop sound + haptic. No timer, no game-over — endless mode. The child can play until they lose interest.

## Architecture

Follows the shared-camera FaceTracker pattern used by all other games.

### Infrastructure Extensions

#### FaceReading + CameraPreviewView

Add two new fields to `FaceReading`:

- `mouthRect: CGRect?` — bounding rect of `outerLips` landmarks converted to screen coordinates. Computed from the min/max X and Y of the outer lip landmark points (image-normalized → screen space via `screenPoint(forImageNormalized:bufferWidth:bufferHeight:)`).
- `faceBBoxWidth: CGFloat?` — screen-space width of the largest face's bounding box. Used by the game to compute dynamic hitbox padding.

Both fields are smoothed via the existing low-pass filter (factor 0.35) before emission. `FaceTracker` gets corresponding published properties.

#### VisualFeedback.swift

Add `ChompAudioEngine`:
- `AVAudioSourceNode`-based, same pattern as `LaserAudioEngine`
- Synthesizes a ~100ms "pop": sine wave sweeping 300→100Hz with exponential decay envelope (amplitude 0.3 peak)
- `playChomp()` triggers by setting a remaining-samples counter
- Runs in `.ambient` audio session (shared with laser audio, no ducking)

Add `ChompHaptics`:
- Static `chomp()` → `UIImpactFeedbackGenerator(style: .medium).impactOccurred()`

### New Files

#### ChocolateRainViewModel.swift

`@Observable` class.

**State:**
- `score: Int`
- `activeChocolates: [ChocolateItem]`
- `gameState: GameState` (idle, countdown, playing)
- `canvasSize: CGSize`

**ChocolateItem:**
- `id: UUID`
- `position: CGPoint` (center of the chocolate)
- `emoji: String` (randomly chosen from ["🍫", "🍬", "🍩", "🧁"])
- `size: CGFloat` (48–64pt, large for toddler visibility)

**Game loop (`tick(delta:)`):**
1. Move each chocolate down by `velocity * delta` (velocity: ~120 pt/s — slow enough for a 4-year-old to track)
2. Remove chocolates that fall below `canvasSize.height + 50`
3. Collision check: if chocolate center falls within the padded mouth rect, remove it, increment score, return `true` (view triggers feedback)

**Spawning:**
- Every ~1.2 seconds (configurable), spawn a new chocolate at random X within safe inset (10%–90% of canvas width), Y = -50
- Maximum 5 active chocolates (prevents overwhelming)

**Collision hitbox:**
- `mouthRect` padded by 40% of `faceBBoxWidth` on all sides
- This makes the hitbox ~2.5× the actual mouth area — very forgiving

**Methods:**
- `setCanvasSize(_:)` — called on geometry change
- `updateMouth(rect: CGRect?, faceBBoxWidth: CGFloat?)` — stores latest tracking data
- `tick(delta: Double) -> Bool` — advances simulation, returns true if a chocolate was caught this frame
- `startGame()` / `reset()`

#### ChocolateRainView.swift

**Structure:**
- `let faceTracker: FaceTracker`
- `let onExit: () -> Void`
- `@State private var viewModel = ChocolateRainViewModel()`
- `@State private var audioEngine = ChompAudioEngine()`

**Layout (ZStack inside GeometryReader):**
1. Falling chocolates: `ForEach(viewModel.activeChocolates)` — `Text(item.emoji)` at `.position(item.position)`, font size = item.size
2. Score display: top-center, large bold white text with shadow
3. Exit button: top-left corner
4. Start overlay (idle state): "Tap to Play" centered prompt
5. Debug overlay: `#if DEBUG` — translucent blue rounded rect at `mouthRect` position

**Display link:**
- Reuses the `DisplayLinkModifier` pattern (same as Laser Eyes)
- Each frame: `viewModel.updateMouth(...)` then `viewModel.tick(delta:)`
- If tick returns true → `audioEngine.playChomp()` + `ChompHaptics.chomp()`

**Face data flow:**
- `.onChange(of: faceTracker.mouthRect)` and `.onChange(of: faceTracker.faceBBoxWidth)` feed into ViewModel

### Navigation Wiring

- `AppScreen.chocolateRain` case
- `AppViewModel.openChocolateRain()`
- `allGames` entry: `Game(id: "chocolateRain", name: "Chocolate Rain", emoji: "🍫", icon: nil, isAvailable: true)`
- `HomeView.onSelectChocolateRain` closure
- `ContentView` switch case routing to `ChocolateRainView(faceTracker:onExit:)`

## Coordinate Space

The front camera is mirrored. `CameraPreviewView` already handles the mirror transform in its coordinate conversion methods (`screenPoint(forImageNormalized:...)`). The `mouthRect` will be emitted in screen coordinates that already account for the mirror — no additional flipping needed in the game layer.

## Performance Considerations

- No new Vision requests. We're adding ~10 `outerLips` point reads to the existing per-frame face processing — negligible cost.
- Chocolate count capped at 5. ForEach over 5 positioned Text views has zero performance impact.
- Display link tick does simple arithmetic (5 position updates + 1 rect intersection check). Sub-microsecond.
- Audio engine idles at zero CPU when not playing (same design as LaserAudioEngine).
