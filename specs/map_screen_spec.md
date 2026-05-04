# Map Screen Specification

## Overview

This spec defines the first blockout for the map screen.

The map screen is a simple level or planet select screen that sits between the station screen and the start of a run. For now, there is one playable unlocked level with the working name `Wasteland`, plus locked placeholder destinations.

The first implementation should focus on:

- showing one selected level as a large banner
- showing the direct previous and next destinations as darkened side banners when available
- cycling between level banners with left and right arrows
- showing the level name and threat icons
- starting the selected level
- returning to the station without starting a run

The attached draft is a layout reference only. The first in-game pass should use the existing dark, readable out-of-run UI style already used by the station and salvage screens.

---

## Design Goals

1. Give the player a clear pre-run destination after pressing the station map button.
2. Keep the first pass simple enough to support one playable level while already showing how multiple destinations will cycle.
3. Make each level feel like a selectable place by using a portrait-format visual banner rather than a text-only list.
4. Reuse the existing app flow and `LevelDefinition` concept instead of hardcoding level scenes in the screen.
5. Keep threat display informational for now, with deeper tuning and unlock rules deferred.

---

## Current Project Context

The project already has:

- `AppRoot`, which owns high-level routing.
- `StationScreen`, which emits `map_requested` from its map button.
- `LevelDefinition`, which currently stores `level_id`, `display_name`, and `level_scene`.
- One authored gameplay level scene.
- A single default level entry in `app_root.tscn`, currently displayed as `Scrap Yard`.

The map screen should become the route target for the station map button. The station should stop starting runs directly once the map screen exists.

Recommended first routing target:

1. App boots to the main menu.
2. `New Game` or `Continue` opens `StationScreen`.
3. Pressing the station map button opens `MapScreen`.
4. `MapScreen` displays the selected level banner.
5. Pressing the launch/start button starts a run using the selected `LevelDefinition`.
6. Pressing back returns to `StationScreen`.
7. Completing the run still routes to salvage processing, then back to the station.

---

## Screen Model

### Level Carousel

The map screen owns a selected level index.

For the first pass:

- the level list contains three entries
- entry `0` is unlocked and launches `Wasteland`
- entries `1` and `2` are locked placeholders named `???`
- left and right arrows move through all visible entries
- arrows disable at the first and last visible entry
- the selected level index starts at `0`
- pressing start launches the selected level only if it is unlocked

Future behavior:

- left arrow selects the previous visible level
- right arrow selects the next visible level
- level selection clamps at the first and last visible level
- arrows disable at the ends of the list
- locked levels can be displayed but not launched

### Main Banner

The center of the screen is dominated by a portrait-format level banner.

The direct previous and direct next levels should also be visible as portrait-format side banners to the left and right of the selected level when those entries exist. Side banners are presentation-only previews:

- they use the same banner/card format as the selected level
- they are smaller or visually secondary compared to the selected banner
- they are darkened to show they are not currently selected
- the previous side banner is hidden at the first visible level
- the next side banner is hidden at the last visible level

Required contents:

| Element | Purpose |
|---|---|
| Background image | Shows the level/planet theme |
| Level name | Displays the selected level name |
| Threat icons | Communicates expected danger |
| Left arrow | Moves to previous level when available |
| Right arrow | Moves to next level when available |
| Start/Launch button | Starts the selected level |
| Back button | Returns to the station |

The banner background can use placeholder art in the first pass. A cropped screenshot or temporary wasteland illustration is acceptable until final map art exists. The image should crop within the banner frame rather than resizing the banner itself.

---

## First Level

The initial selectable level is:

| Field | Value |
|---|---|
| Working name | `Wasteland` |
| Level id | `wasteland` |
| Scene | existing gameplay level scene |
| Availability | unlocked by default |
| Threat display | placeholder icons |

Implementation note:

- update the current default level display name from `Scrap Yard` to `Wasteland`
- prefer using `LevelDefinition.display_name` for the banner title
- add any extra map-specific presentation fields to `LevelDefinition` or a companion resource only when the map screen needs them

---

## Visual Layout

### First-Pass Composition

The screen should be full-screen and simple:

- dark background
- centered portrait banner occupying most of the middle of the screen
- direct previous portrait banner visible to the left of the selected banner when available
- direct next portrait banner visible to the right of the selected banner when available
- side banners darkened relative to the selected banner
- left arrow placed outside the previous/selected banner group
- right arrow placed outside the next/selected banner group
- level name placed at the banner's bottom-left
- threat icons placed at the banner's bottom-right
- start button below the banner
- back button in the top-left or bottom-left

The layout should preserve a clear first read:

1. selected level image
2. selected level name
3. threat icons
4. start action
5. back action

### Style

The map screen should match the out-of-run UI language:

- dark, high-contrast presentation
- chunky readable buttons
- large click targets
- restrained panel borders and glow
- no paper-white sketch styling
- no dense meta-progression menus in the first pass

The banner can be more illustrative than the station panels because this screen is about choosing a destination.

---

## Threat / Difficulty Icons

The draft includes a small row of icons under the level name.

For the first pass, these icons are informational only and represent threat.

Threat display rules:

- show a maximum of 3 threat icons
- full-color icons represent the selected level's threat rating
- white unfilled icons represent remaining threat capacity and should remain visible on dark banner backgrounds
- `Wasteland` can use a placeholder threat rating until final tuning exists

Examples:

| Threat Rating | Display |
|---:|---|
| 1 | 1 full-color icon, 2 white unfilled icons |
| 2 | 2 full-color icons, 1 white unfilled icon |
| 3 | 3 full-color icons |

Suggested first-pass options:

- reuse existing threat icon art if it reads well at this scale
- use simple placeholder warning or hazard icons if the existing threat art does not read clearly at this scale
- show a fixed placeholder count for `Wasteland`

The exact meaning can be deferred, but the spec should reserve the concept:

| Display | Meaning |
|---|---|
| Fewer filled icons | Lower expected danger |
| More filled icons | Higher expected danger |
| Disabled/empty icons | Unfilled danger capacity |

Future integrations may map these icons to:

- starting threat
- enemy spawner profile
- planet difficulty
- loot richness
- weather severity
- unlock tier

Later versions of the screen should also be able to show richer selected-level details, such as run modifiers, weather, salvage profile, or enemy preview. Those details are out of scope for the first blockout.

---

## Interaction Model

### Select Previous / Next

When multiple levels exist:

- left arrow moves to the previous level
- right arrow moves to the next level
- the direct previous and direct next levels are visible beside the selected level when available
- pressing an arrow tweens the carousel in that direction before committing the new selected level
- after the tween, the newly selected level is centered and its direct neighbors update
- the left arrow is disabled on the first visible level
- the right arrow is disabled on the last visible level
- input should be locked during any transition animation

With only one level:

- arrows may remain visible but disabled
- arrows may play a small disabled feedback state
- arrows must not start a run or leave the screen

Current placeholder level list:

| Index | Name | State | Deploy |
|---:|---|---|---|
| 0 | `Wasteland` | unlocked | enabled |
| 1 | `???` | locked | disabled |
| 2 | `???` | locked | disabled |

### Start Selected Level

Pressing the start/launch button should:

- emit the selected `LevelDefinition`
- let `AppRoot` start the run
- clear the map screen when gameplay loads

If the selected level is locked:

- the level remains visible in the carousel
- the banner and/or level details should appear greyed out
- the start/launch/deploy button is disabled
- arrows remain usable if there are other visible levels

Suggested signal:

```gdscript
signal start_requested(level_definition: LevelDefinition)
```

### Back To Station

Pressing the back button should:

- return to `StationScreen`
- preserve current save/loadout state
- not start a run

Suggested signal:

```gdscript
signal station_requested
```

### Input Readiness

The first pass can be mouse-first, but should not block controller support.

Recommended focus order:

1. back button
2. left arrow
3. banner or level details
4. right arrow
5. start/launch button

---

## Data Requirements

The current `LevelDefinition` is enough to start the first pass:

```gdscript
@export var level_id: StringName
@export var display_name: String
@export var level_scene: PackedScene
```

Likely future fields:

```gdscript
@export var banner_texture: Texture2D
@export_range(1, 3) var threat_icons: int = 1
@export var short_description: String = ""
@export var locked: bool = false
```

These fields should not be added until implementation needs them. If the team wants to avoid growing `LevelDefinition`, create a small map presentation resource instead.

For the first blockout, placeholder values can live directly on `MapScreen`.

---

## Scene Structure Guidance

Suggested scene responsibilities:

| Scene / Script | Responsibility |
|---|---|
| `MapScreen` | Owns selected index, banner updates, arrows, route signals |
| `MapLevelBanner` | Optional reusable level card/banner if multiple levels arrive soon |
| `MapDifficultyIcons` | Optional helper for rendering filled/empty threat icons |

The first implementation can keep everything in one scene if it stays small.

---

## File Impact

### New Files Expected

| File | Purpose |
|---|---|
| `_project/app/screens/map_screen.tscn` | Full-screen level/planet select screen |
| `_project/app/screens/map_screen.gd` | Level selection, banner setup, arrow handling, route signals |

### Existing Files To Update Later

| File | Change |
|---|---|
| `_project/app/app_root.gd` | Add route to open map screen from station and start selected level from map |
| `_project/app/app_root.tscn` | Export/assign the map screen scene and update the default level display name to `Wasteland` |
| `_project/app/level_definition.gd` | Optionally add banner/difficulty presentation fields later |
| `_project/app/screens/station_screen.gd` | Change map button behavior from direct run start to map-screen route request |
| `_project/app/screens/station_screen.tscn` | No required layout change unless the map button copy/icon needs adjustment |

---

## Recommended Implementation Order

1. Rename the default level presentation from `Scrap Yard` to `Wasteland`.
2. Create `map_screen.tscn` as a full-screen `Control`.
3. Add the banner, level name, placeholder threat icons, left/right arrows, start button, and back button.
4. Add `map_screen.gd` with a one-entry level list and selected index.
5. Add `map_screen_scene` routing to `AppRoot`.
6. Change the station map button to open the map screen instead of starting a run directly.
7. Wire the map start button to call `AppRoot.start_run(selected_level, current_loadout)`.
8. Verify that map back returns to the station and run completion still returns through salvage processing.

---

## Resolved Decisions

1. The map screen is a separate app screen, not an overlay inside gameplay.
2. The station map button should route to the map screen once it exists.
3. The first selectable level is `Wasteland`.
4. The first pass has one unlocked playable level and two locked placeholder destinations.
5. Levels are shown as portrait-format banners with clipped/cropped background art.
6. Direct previous and direct next levels are visible as darkened side banners when available.
7. Left and right arrows are part of the layout and tween the carousel through visible destinations.
8. Arrows disable at the first and last visible level instead of wrapping.
9. Locked levels remain visible, but appear greyed out and cannot be launched.
10. Threat icons are informational placeholders in the first pass.
11. Threat display uses a maximum of 3 icons, with full-color icons for filled threat and white icons for unfilled threat.
12. Starting a run should use the selected `LevelDefinition`.
13. The map screen must support returning to the station without starting a run.
14. Future map data should build from `LevelDefinition` or a small companion presentation resource.
15. Run modifiers, weather, salvage profile, and enemy previews are desirable future selected-level details, but not part of the first blockout.

---

## Open Questions

1. What final banner art should represent `Wasteland`?
2. What exact placeholder threat rating should `Wasteland` show in the first implementation?
