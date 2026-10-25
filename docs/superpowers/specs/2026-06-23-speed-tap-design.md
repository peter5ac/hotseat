# Speed Tap — Design Spec

## Overview

A hand-eye coordination game where a sequence of emojis flashes at the top of the screen
and the player taps them in order from a fixed grid at the bottom before a timer runs out.
Each success lengthens the sequence and shortens the timer. Failure ends the round with a
game-over card.

Camera background with dim overlay, same as Hot Take.

## Core Loop

1. A themed set of 6 emojis is selected (random or player-chosen).
2. A target sequence appears at the top (starting at 3 emojis, drawn from the 6).
3. A timer bar begins shrinking.
4. Player taps emojis from the grid in the correct order.
5. Correct tap: that position in the sequence dims/checks. Move to next.
6. Wrong tap: brief shake/flash feedback. No penalty beyond lost time.
7. All tapped correctly before timer expires → success → next round.
8. Timer expires → game over.

## Difficulty Ramp

| Round | Sequence length | Timer |
|-------|----------------|-------|
| 1     | 3              | 5.0s  |
| 2     | 4              | 4.7s  |
| 3     | 5              | 4.4s  |
| n     | n + 2          | max(2.0, 5.0 - (n-1) × 0.3) |

Timer floors at 2.0s.

## Themed Emoji Sets

Each session uses one theme. Examples:

- Fruits: 🍎 🍌 🍇 🍊 🍓 🍒
- Animals: 🐶 🐱 🐸 🦊 🐼 🐵
- Sports: ⚽ 🏀 🏈 🎾 ⚾ 🏐
- Weather: ☀️ 🌧️ ⛈️ 🌈 ❄️ 🌪️
- Space: 🚀 🌙 ⭐ 🪐 ☄️ 👽
- Ocean: 🐙 🦈 🐠 🐚 🦀 🐳
- Food: 🍕 🍔 🌮 🍩 🍿 🧁

Theme selected randomly at game start. No picker screen — just jump in.

## UI Layout

All over the standard camera + 0.4 opacity black overlay.

### Top — Target Sequence

- Horizontal row of emoji, centered.
- Already-tapped emojis: reduced opacity + subtle checkmark overlay.
- Current target: normal opacity, slightly scaled up or underlined.
- Upcoming: normal opacity.

### Middle — Timer Bar

- Full-width horizontal bar, shrinks from left to right.
- Color shifts from white → warm (orange/red) as time runs low.
- No numeric display — visual pressure only.

### Bottom — Tap Grid

- 3×2 grid (3 columns, 2 rows) in portrait.
- 2×3 grid (2 columns, 3 rows) in landscape — or keep 3×2 and let it adapt.
- Large tap targets (same pass-the-phone-ready principle as the rest of the app).
- Emoji centered in each cell, cells are rounded-rect material cards matching the app's style.
- Grid positions are FIXED for the duration of the session (no shuffling).

### Header

- Back button (chevron.left + "Games") returns to home screen.
- Optional: small round indicator showing current round number.

## Game Over

Card overlay (same style as Hot Take's "That's your top 5"):

- "Time's up!" heading
- Subtitle: "You made it X rounds" (contextual, not competitive)
- Two buttons:
  - "Again" — restarts with same theme, resets to round 1
  - "New round" — returns to home screen (or picks a new random theme and restarts)

## Success Transition

Brief celebratory moment between rounds:

- Flash "Nice!" or similar for ~0.5s
- Next sequence appears automatically

Keep it fast — the energy should feel continuous, not interrupted.

## Navigation & Integration

- Home screen game entry: `Game(id: "speedTap", name: "Speed Tap", emoji: "⚡", icon: nil, isAvailable: true)`
- `AppScreen` enum gains `.speedTap` case
- `ContentView` routes to `SpeedTapView` when screen is `.speedTap`
- `HomeView` wheel `onLanded` handler adds `"speedTap"` case

## File Structure

- `HotSeat/SpeedTapView.swift` — main game view (timer, sequence display, grid, game-over)
- `HotSeat/SpeedTapViewModel.swift` — game state (`@Observable`): current round, sequence,
  timer management, tap validation, theme data

## Constraints

- No state persisted between sessions.
- No scores, leaderboards, or streaks.
- Timer is a mechanic, not a competitive element.
- Wrong taps have no explicit penalty beyond time cost.
- Sequences are randomly generated from the 6-emoji set each round (may repeat emojis within a sequence).
