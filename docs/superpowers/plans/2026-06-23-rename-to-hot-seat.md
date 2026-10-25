# Rename: BlindRanking → Hot Seat (app) / Hot Take (rank game)

## Summary

The app becomes **Hot Seat** (umbrella for all games). The existing ranking game
becomes **Hot Take** (one game inside the app). The current app icon (`icon-1024.png`)
moves to an in-app asset used by the Hot Take game tile. A new Hot Seat app icon
(`~/Desktop/HotSeat.png`, already 1024x1024 PNG) replaces it in the AppIcon asset catalog.

---

## Phase 1 — Asset reorganization

| # | Action | Detail |
|---|--------|--------|
| 1 | Copy existing icon to a new image set | Create `Assets.xcassets/HotTakeIcon.imageset/` containing a copy of `icon-1024.png` and a `Contents.json` referencing it. This becomes the in-app tile icon for the Hot Take game on the home screen. |
| 2 | Replace the AppIcon with the new Hot Seat icon | Copy `~/Desktop/HotSeat.png` to `Assets.xcassets/AppIcon.appiconset/icon-1024.png` (overwrite). Already 1024x1024 PNG — no conversion needed. `Contents.json` already points to that filename. |

---

## Phase 2 — Rename source directory and Xcode project

| # | Action | Detail |
|---|--------|--------|
| 3 | Rename directory `BlindRanking/` → `HotSeat/` | `mv BlindRanking HotSeat` |
| 4 | Rename Xcode project | `mv BlindRanking.xcodeproj HotSeat.xcodeproj` |
| 5 | Update `project.pbxproj` | Find/replace all occurrences of `BlindRanking` → `HotSeat` (file refs, group names, product names, target names, build config list comments). |
| 6 | Update `xcschememanagement.plist` | Replace scheme references from `BlindRanking` → `HotSeat`. |
| 7 | Update `contents.xcworkspacedata` | Uses `location = "self:"` — no BlindRanking reference, so no change needed. |
| 8 | Change bundle identifier | `com.audrey.HotTake` → `com.audrey.HotSeat` (in `project.pbxproj` build settings, both Debug and Release). |
| 8b | Change display name | `INFOPLIST_KEY_CFBundleDisplayName` from `"Hot Take"` → `"Hot Seat"` (both Debug and Release). |

---

## Phase 3 — Rename Swift files and types

| # | Action | Detail |
|---|--------|--------|
| 9 | Rename `BlindRankingApp.swift` → `HotSeatApp.swift` | Also rename the `@main struct BlindRankingApp` → `HotSeatApp`. |
| 10 | Update `HomeView.swift` — game list | Change `Game(id: "rank", name: "Blind Ranking", emoji: "🏆", ...)` → `Game(id: "hotTake", name: "Hot Take", emoji: "🏆", ...)`. Add an `icon` property (optional `String` for the image set name) and set it to `"HotTakeIcon"` for this game. |
| 11 | Update `HomeView.swift` — game tile | If the game has an `icon`, show `Image("HotTakeIcon")` in the tile instead of (or alongside) the emoji. |
| 12 | Update `SpinWheelView.swift` preview | The preview references `"Blind Ranking"` in a `WheelItem` label — change to `"Hot Take"`. |
| 13 | Update `project.pbxproj` file reference | `BlindRankingApp.swift` → `HotSeatApp.swift` (path and comment annotations). |

---

## Phase 4 — Documentation updates

| # | Action | Detail |
|---|--------|--------|
| 14 | Update `CLAUDE.md` | Replace "Blind Ranking" with "Hot Take" where referring to the game. Replace project file references (`BlindRanking.xcodeproj` → `HotSeat.xcodeproj`, `BlindRanking/` → `HotSeat/`, `BlindRankingApp.swift` → `HotSeatApp.swift`). Change display name to "Hot Seat", bundle id to `com.audrey.HotSeat`. |
| 15 | Update `PRODUCT.md` | Replace app name / game name references as appropriate. |

---

## Phase 5 — Verification

| # | Action | Detail |
|---|--------|--------|
| 16 | Build via XcodeBuildMCP | Open `HotSeat.xcodeproj`, build for simulator, confirm no errors. |
| 17 | Run in simulator | Verify home screen shows "Hot Take" tile with the icon, the game plays normally, and the app displays as "Hot Seat". |

---

## Notes

- `WheelAudio.swift` and `CameraPreviewView.swift` have no "BlindRanking" references — no changes needed.
- `contents.xcworkspacedata` uses `location = "self:"` — no rename needed.
- Display name is set explicitly via `INFOPLIST_KEY_CFBundleDisplayName`, so the product name (`HotSeat` with no space) won't matter for what users see on the home screen.
