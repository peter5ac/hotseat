# Hot Seat

An iOS app of camera-filter "games" for pre-teens (ages 7–14). Think TikTok's filter/game
experience **with the video, posting, accounts, and social feed stripped out** — just the
front-camera-as-background play, made safe for kids who aren't allowed on TikTok itself.

The front camera is the canvas: UI sits over a live selfie feed, creating a "hot seat" vibe
when the device is passed around at sleepovers, FaceTime calls, and family game nights.
Nothing is recorded, uploaded, or shared. There are no accounts, no network, no analytics.

## Current state

The app currently ships **one game: Hot Take.** Players see items from a category one
at a time (the "blind" mechanic — you don't know what's next) and tap to assign each to a
top-5 slot. More games/filters are intended to be added later.

## Tech

- SwiftUI, iOS 17+, Swift 5. Universal (iPhone + iPad), all orientations.
- Live front camera via `AVFoundation` (`AVCaptureSession` + `AVCaptureVideoPreviewLayer`).
- Bundle id `com.audrey.HotSeat`, display name "Hot Seat". Open `HotSeat.xcodeproj`.

## Files

- `HotSeat/HotSeatApp.swift` — app entry point.
- `HotSeat/ContentView.swift` — all game UI plus `GameViewModel`, the `RankCategory`
  data, and category picker. State is driven by `@Observable GameViewModel`.
- `HotSeat/CameraPreviewView.swift` — `UIViewRepresentable` wrapping the front-camera
  preview layer used as the background.
- `HotSeat/HomeView.swift` — game picker home screen with game tiles and spin wheel.
- `HotSeat/SpinWheelView.swift` — pie/reel spin wheel for random game selection.
- `HotSeat/WheelAudio.swift` — synthesized tick/ding audio for the spin wheel.
- `PRODUCT.md` — product brief: audience, brand personality, design principles.

## Product guardrails (from PRODUCT.md)

- **Grab and go**: zero onboarding, zero accounts. Pick and play.
- **The face is the content**: the camera background is the social layer, not decoration.
  The dimming overlay over the feed is load-bearing for contrast.
- **Two kinds of play**: expressive games (Hot Take) have no scores/winners/timers;
  skill games (Speed Tap, Lane Dodge) may have scores/lives/fail states but stay
  per-session only — no leaderboards, no persistence, no accounts.
- **Pass-the-phone ready**: large tap targets, legible at arm's length.
- Anti-references: generic quiz apps, EdTech, and social-media feed mechanics. Avoid all three.

## Build / run

Use XcodeBuildMCP simulator tools (preferred over `xcodebuild` shell calls). Camera preview
is black in the simulator — the live feed only appears on a physical device.

## Context dump for Gemini (`/arch`)

When asked to produce a context dump (e.g. "give me the arch dump" or `/arch`), generate a
self-contained markdown block the user can paste into Gemini. The block should contain:

1. **Product summary** — audience, core concept, guardrails (from PRODUCT.md above).
2. **Tech stack** — SwiftUI, iOS 17+, Swift 5, AVFoundation front-camera, no network/persistence.
3. **Architecture** — View + ViewModel per game, shared `CameraPreviewView` as background,
   `HomeView` → game navigation, `SpinWheelView` for random selection.
4. **Current games/modules** — list every `*View.swift` / `*ViewModel.swift` pair with a
   one-line description of what it does. Derive descriptions from file names and current code.
5. **Shared infrastructure** — `MotionTracker`, `VisualFeedback`, `WheelAudio`, camera layer.
6. **Interaction patterns already in use** — face tracking (ARKit expressions), device motion,
   tap targets, pass-the-phone multiplayer.
7. **Constraints** — no network, no persistence, no accounts, no recording, camera-as-background
   is mandatory, large tap targets, works on iPhone + iPad.

Run `find HotSeat -name "*.swift" | sort` and read file headers as needed to keep the list
current. Output the dump inside a fenced markdown code block so it's easy to copy.

## CLI Build & Deployment (Target: Thorin16)

Since the custom XcodeBuildMCP device workflows are disabled, use direct CLI commands using
xcodebuild and xcrun devicectl to build, install, and run apps on the physical phone 'Thorin16'.

1. Find the UDID for Thorin16 if needed:
   ```
   xcrun devicectl list devices --hide-default-columns --columns Name --columns UDID
   ```

2. Build the app for the physical device destination:
   ```
   xcodebuild build -project HotSeat.xcodeproj -scheme HotSeat -configuration Debug -destination "platform=iOS,name=Thorin16"
   ```

3. Install the compiled .app payload using modern CoreDevice utilities:
   ```
   xcrun devicectl device install app --device "Thorin16" build/Debug-iphoneos/HotSeat.app
   ```

4. Launch the application process directly on the device:
   ```
   xcrun devicectl device process launch --terminate-existing --console --device "Thorin16" com.audrey.HotSeat
   ```

5. After install completes, read and display the build timestamp:
   ```
   cat HotSeat/BuildTimestamp.swift
   ```
   The Run Script build phase ("Generate Build Timestamp") writes the current Unix epoch
   into `HotSeat/BuildTimestamp.swift` before compilation. Always show this timestamp
   (dd/mm/yy HH:mm:ss) to the user after a successful device install so they know which
   build is running. The file is git-ignored — do not commit it.
