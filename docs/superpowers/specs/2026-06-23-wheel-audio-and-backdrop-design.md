# Hot Take — Spin Wheel: Tick/Ding Audio + Background Hiding

**Date:** 2026-06-23
**Status:** Approved

## Problem

The Spin Wheel feature (shipped) has two gaps:

1. **No sound.** A spinning wheel should tick like Wheel of Fortune / The Price Is
   Right — rapid ticks that spread out as it decelerates — with a payoff sound when it
   lands. Today it spins silently.
2. **Background bleeds through.** When the wheel/reel overlay appears, the underlying
   screen (the ranking category grid, or the home game grid) is still rendered behind
   the wheel's translucent scrim, so the list shows through and clutters the moment.

## Goals

- Decelerating tick sound during the spin + a distinct landing "ding".
- Sound is synthesized at runtime — no bundled audio files (app is fully offline and
  self-contained; asset catalog has no sounds today).
- Sound respects the hardware silent switch.
- When the wheel is presented, the underlying list stops rendering; the live (dimmed)
  camera feed stays visible behind the wheel (product guardrail: "the face is the
  content").

## Non-goals (YAGNI)

- No volume control / settings UI.
- No bundled / downloaded audio assets.
- No haptics (could be added later; out of scope here).
- No music or background loops — only the tick and the landing ding.
- No change to the spin animation, landing math, or the wheel's own 0.55 scrim.

## Context (current state)

- No audio code exists anywhere (`AVAudio*`, `AudioServices`, etc. — none). Asset
  catalog contains only `AppIcon`. This is greenfield audio.
- `SpinWheelView` renders its own backdrop: `Color.black.opacity(0.55)`
  (`SpinWheelView.swift:44`), layered over the caller's screen content.
- Z-order in each caller: `CameraPreviewView` → `Color.black.opacity(0.4)` dim →
  screen content (list) → (overlay) `SpinWheelView` scrim 0.55 → wheel. The list sits
  ABOVE the camera, so a translucent scrim cannot hide the list while keeping the
  camera; the list itself must stop rendering.
- `SpinWheelView` spin internals (already shipped):
  - Reel (`items.count >= 10`): `reelLandingIndex = items.count * reelFullPasses + winner`
    (`reelFullPasses = 4`); rows repeated `reelRepeats = 6`×; animates `reelOffset` with
    `.easeOut(duration: spinDuration)`; `spinDuration = 2.75`, `holdDuration = 1.0`.
  - Pie (`items.count < 10`): `rotation = 360*5 - sliceAngle*(winner+0.5)`,
    `sliceAngle = 360/count`; `.easeOut(duration: spinDuration)`.
  - On spin: after `spinDuration`, `landedIndex` is set (winner locks/highlights), then
    after `holdDuration`, `finish(winner)` → `onLanded`. Reduced-motion path skips the
    spin, sets the winner immediately, holds, then finishes.

## Part A — Hide the background list

When the wheel is presented, suppress the underlying screen's content (not the camera).

- `ContentView.swift`: while `showingCategoryWheel == true`, do not render
  `categoryPicker`'s content. The camera + 0.4 dim remain (they live in the root ZStack
  below the `switch`, unaffected). Simplest: gate the `.rank` → `categoryPicker` branch
  so it renders an `EmptyView`/`Color.clear` while the wheel is up, OR apply `.opacity(0)`
  to `categoryPicker` when `showingCategoryWheel`. Either is acceptable; the wheel's own
  `.transition(.opacity)` covers the swap. The `gameView` (post-selection) is not a
  concern — the wheel is only openable from the picker.
- `HomeView.swift`: while `showingGameWheel == true`, suppress the title + spin button +
  grid `VStack` content the same way. Camera + 0.4 dim (owned by `ContentView`'s root
  ZStack) remain visible.

No change to `SpinWheelView`'s 0.55 scrim. Net effect behind the wheel: camera + 0.4 dim
+ 0.55 scrim, no list.

## Part B — Synthesized tick + landing ding

### New component: `WheelAudio`

New file `BlindRanking/WheelAudio.swift`. A plain (non-View) class, no UI knowledge.
Registered in `project.pbxproj` in all FOUR spots (PBXBuildFile, PBXFileReference, group
children, Sources build phase), mirroring `SpinWheelView.swift` (`A1000006`/`A2000006`)
with new ids `A1000007` / `A2000007`.

Responsibilities:
- Own an `AVAudioEngine` + `AVAudioPlayerNode` (or equivalent) and two pre-rendered PCM
  buffers: a tick and a ding.
- Configure `AVAudioSession`: category `.ambient`, so audio **respects the silent
  switch**, mixes with other audio, and does not duck/interrupt. Activate on start.
- `start()` / `stop()` to set up and tear down the engine (called from the wheel's
  appear/disappear). All audio calls are best-effort: any thrown error is swallowed and
  results in silence — audio must never crash or block the wheel.
- `playTick()` and `playDing()` — schedule the corresponding buffer on the player node.

### Synthesized sounds (PCM buffers built at init)

- **Tick:** ~8–12ms. High-frequency damped sine (~1.0–1.4 kHz) with a fast exponential
  amplitude decay → a short dry "click", not a tone. Low amplitude.
- **Ding:** ~350–450ms. A pleasant decaying bell — a sine (optionally two notes, e.g. a
  rising third) with exponential decay → the landing payoff.

Exact frequencies/envelopes are tunable by ear on device; the spec fixes the shape
(short click vs. longer decaying chime), not final timbre.

### Tick scheduling (decelerating, matches the visual)

The spin crosses `N` boundaries over `spinDuration` on an ease-out curve:
- Reel: `N = reelLandingIndex = items.count * reelFullPasses + winner` (row boundaries).
- Pie: `N = round(5 * items.count) + (winner-related fraction)` — i.e. ~5 full
  revolutions worth of slice boundaries. Use `N = items.count * 5` as the boundary count
  (slices crossed in 5 turns); the exact winner offset is negligible for tick feel.

Boundary `k` (1…N) is reached when the eased progress equals `k/N`. With an ease-out
position curve `p(t)`, tick `k` fires at `t_k = spinDuration * p⁻¹(k/N)`. Use a cubic
ease-out position model `p(t) = 1 - (1 - t/T)^3` (close approximation of SwiftUI's
`.easeOut` bezier; precise visual match is already a tune-on-device item for landing).
Inverting: `t_k = T * (1 - (1 - k/N)^(1/3))`.

This makes ticks dense at the start and progressively sparser — the characteristic
decelerating tick.

**Minimum inter-tick floor:** drop ticks that would fire less than ~45ms after the
previous one (the early, very-fast boundaries), so the start reads as rapid ticking, not
a buzz. The floor is tunable.

Implementation: on spin start (non-reduced-motion), compute the tick times once and
schedule them via `DispatchQueue.main.asyncAfter` (consistent with the existing
`spin()`), or a timer. Each fires `playTick()`. They naturally stop at `spinDuration`.

### Ding timing

Play `playDing()` at `t = spinDuration` — the moment the winner locks and highlights,
before the 1s hold. One ding per spin.

### Reduced motion

No spin animation → no ticks. Play only `playDing()` when the winner is set (then the
existing ~1s hold, then `onLanded`). Consistent with "skip the spin".

### Wiring into `SpinWheelView`

- Hold a `WheelAudio` instance (e.g. `@State private var audio = WheelAudio()`).
- `.onAppear { audio.start() }`, `.onDisappear { audio.stop() }`.
- In `spin()`:
  - Non-reduced-motion: after picking `winner` and starting the animation, compute and
    schedule the tick times (per the model above) and schedule the ding at `spinDuration`.
  - Reduced-motion: schedule only the ding (immediately, or with the winner-set), no ticks.
- No change to the visual animation, the landing indices, or `finish()`.

## Edge cases

- Empty list: `spin()` is already guarded (`!items.isEmpty`); no audio path is reached.
- Single item: pie mode, lands quickly; ticks (if any) and ding still valid; must not
  crash.
- Audio engine fails to start (e.g. session error): swallow, run silently; wheel fully
  functional.
- Backgrounding mid-spin / dismiss mid-spin: cancel is disabled mid-spin (unchanged);
  `stop()` on disappear tears down the engine — any not-yet-fired tick closures that
  still fire are harmless no-ops on a stopped engine.

## Files

- **New:** `BlindRanking/WheelAudio.swift` — audio class; synth buffers; `.ambient`
  session; `start`/`stop`/`playTick`/`playDing`. No UI knowledge.
- **New (pbxproj):** register `WheelAudio.swift` — 4 spots, ids `A1000007`/`A2000007`.
- **Modify:** `BlindRanking/SpinWheelView.swift` — own a `WheelAudio`; appear/disappear
  lifecycle; schedule ticks + ding in `spin()` (both motion paths).
- **Modify:** `BlindRanking/ContentView.swift` — suppress `categoryPicker` content while
  `showingCategoryWheel`.
- **Modify:** `BlindRanking/HomeView.swift` — suppress home content while `showingGameWheel`.

## Testing / verification

No unit test target; verification is build-and-run on the physical device (iPhone
"Thorin16", id `00008140-00065C5A14D1801C`); simulator audio + black camera are
unreliable. Manual checks:

- Ranking → "Spin for me": background category grid disappears (camera/face still
  visible) when the reel opens; ticks fire rapidly then decelerate with the reel; a ding
  plays as it lands; then the game starts.
- Home forced test (flip a `soon` game `isAvailable: true`, then revert): grid disappears
  behind the pie wheel; ticks + ding; routes on landing.
- Silent switch ON → no sound; wheel still works and still hides the background.
- Reduce Motion ON → no ticks, ding only on landing; background still hidden.
- Cancel before spinning → no sound; background list returns.

## Known risk (verify-on-device)

Tick *feel* — the 45ms floor and the cubic-ease-out vs. SwiftUI-bezier approximation will
likely need one tuning pass on device. Tick/ding timbre (frequencies, envelopes,
amplitude) may also need adjustment by ear. Treat as a tuning loop, like the existing
landing-math item.

## Build / deploy

`xcodebuild` + `xcrun devicectl` to the device, as in the prior session. New
`WheelAudio.swift` requires the four-spot `project.pbxproj` edit (explicit file
references; not auto-synced). NOT a git repo — no commits.
