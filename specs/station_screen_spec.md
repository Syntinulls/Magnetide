# Station Screen Specification

## Overview

This spec defines the first blockout for the station screen, the player's main non-run hub after docking at a space station.

The station screen is the first major step toward the game's outside-of-run experience. It should become the place where a new game begins after the player leaves the main menu.

It should eventually become the place where the player:

- reviews ship and player status
- manages storage and recovered materials
- inspects and upgrades ship/player systems
- opens station services and menus
- opens the map screen to choose a level or planet for the next run

The first implementation should focus on the screen structure, visual hierarchy, and navigation behavior rather than final data hookups.

---

## Design Goals

1. Establish the station as a full-screen hub, not a small popup over gameplay.
2. Use the provided sketches as layout references only, while matching the existing salvage processing screen's color palette, scale, spacing, and readable game-UI feel.
3. Support two full-sized station pages placed horizontally next to each other.
4. Make left/right panning feel like moving across one continuous station interface.
5. Keep the first pass data-light so upgrade, storage, and station-service systems can be attached later.
6. Define reusable UI regions so the right screen can be filled in without reworking the left screen.

---

## Authored Requirements

The following behavior comes directly from the current design notes and sketch references.

1. The station screen consists of two full viewport-sized screens arranged side by side.
2. The player can pan between the left and right screen using an on-screen button.
3. The pan should slide the camera or viewport horizontally instead of instantly swapping screens.
4. The left screen contains the currently drafted layout.
5. The right screen is visually similar to the left screen but will contain different information later.
6. The station screen needs a spec before full implementation so its components and visual elements are outlined clearly.

---

## Current Project Context

The project already has an outer app flow:

- `AppRoot` owns high-level routing.
- `MainMenu` currently starts a run directly.
- The run summary leads into `SalvageProcessScreen`.
- The salvage processing screen should return to `StationScreen` after the player reviews the final salvage results.

The station screen should become the first non-run destination after choosing `New Game` from the main menu. Starting a run should move out of the main menu and into the station flow.

Recommended first routing target:

1. App boots to main menu for now.
2. The main menu shows a `New Game` button.
3. Pressing `New Game` opens `StationScreen`.
4. For now, the station screen's map button starts a run directly.
5. Completing a run opens `SalvageProcessScreen`.
6. Finishing the salvage/results flow returns to `StationScreen`.
7. Later, the map button opens a map/planet-selection screen where the run start is chosen.

Storage handoff note:

- retrieved run items should eventually populate player storage when returning to the station
- this requires an overall save/state container and is deferred from the current routing blockout

### Future Save Flow

The save system is future scope and should not be implemented for the first station blockout.

Long-term assumptions:

- the game has only one save slot
- the save is managed automatically
- players cannot create multiple saves
- pressing `New Game` overwrites the existing save
- when the game is reopened, a `Continue` button appears only if an existing save is present
- if no save exists, `New Game` is the only game-start/save-related action shown

First-pass main menu behavior:

- show `New Game` instead of the old direct `Start Run` button
- keep normal non-save actions such as `Exit`
- do not implement save detection
- do not implement `Continue`
- do not implement save overwrite behavior

---

## Screen Model

### Two-Page Layout

The station screen is one continuous horizontal surface with two page-sized regions:

| Region | Position | Purpose |
|---|---:|---|
| Left Station Page | `0, 0` | Player screen / primary station hub layout shown in the sketches |
| Right Station Page | `viewport_width, 0` | Ship screen |

Both pages should be authored at full viewport size. The visible camera/window shows one page at a time.

### Pan Behavior

The screen should expose a single horizontal page index:

- `0`: left page
- `1`: right page

Pressing the page navigation button should tween the visible camera or page container to the other page.

Requirements:

- input should be locked while a pan tween is active
- popup menus should close or block panning unless a later design says otherwise
- the player should never see empty space beyond either page
- the pan duration should be tunable
- the pan should use ease-in-out motion
- the top bar should stay fixed on screen while the station pages pan underneath it
- the shared storage panel and bottom-right storage detail popup should stay fixed on screen while the station pages pan underneath them
- the bottom-left stats panel should stay fixed on screen while the station pages pan underneath it
- clicking a page pan button should immediately clear the shared stats panel
- the stats panel content should be repopulated only after panning completes, reflecting the active page: player stats on the player page, ship stats on the ship page
- the right-edge pan button on the left page should hide once clicked and while the right page is active
- the right page should expose a mirrored left-edge pan button that returns to the left page

### Implementation Shape

Two implementation approaches are acceptable:

1. A `Control` root with a wide page container whose `position.x` is tweened.
2. A `Node2D`/`Camera2D` presentation where the camera slides between two authored screen anchors.

For a UI-heavy Godot screen, the first pass should prefer a `Control` root and moving page container unless there is a strong reason to use `Camera2D`.

---

## Shared Visual Language

The sketches are layout references, not color or rendering references. Their black-on-white presentation should not drive the in-game station style.

The station blockout should instead mimic the existing salvage processing screen's visual language so the out-of-run screens feel connected while custom station art is still pending.

### First-Pass Style

- dark full-screen backdrop similar to `SalvageProcessScreen`
- muted blue-gray panel/glow colors rather than white paper backgrounds
- high-contrast light text and icon silhouettes
- large readable labels, with important headings allowed to use salvage-screen-like oversized type
- chunky icon-first controls and generous hit targets
- panel divisions that preserve the sketch layout without copying the black-line art style literally
- selected/active states using brighter fills, outlines, scale, or glow rather than hand-drawn brackets only
- placeholder art is acceptable, but it should sit inside the existing game's dark UI presentation

### Scale Reference

The station screen should feel comparable in size and readability to the salvage processing screen:

- full-screen `Control` composition
- outer margins in the same general range as the salvage screen's HUD/storage anchors
- primary item/service icons large enough to read instantly
- secondary icons and progress blocks compact but not tiny
- bottom panels tall enough for readable stat/storage/detail content at the target game resolution

The station screen can be denser than salvage processing because it is a hub/menu, but it should not become a thin desktop-style UI.

### Long-Term Style Targets

The final custom art pass should preserve the following qualities:

- tactile station-console feeling
- compact information density
- readable icon-first controls
- visible separation between station view, upgrades, storage, and detail panels
- consistency with the salvage processing screen's dark, punchy out-of-run presentation

---

## Left Page Layout

The left page is the drafted station hub page from the provided images.

### Page Regions

| Region | Approximate Location | Purpose |
|---|---|---|
| Top Menu Button | fixed top-left | Opens global pause/menu options |
| Map Button | fixed top-center | Starts a run for now; later opens the map/planet-selection screen |
| Upgrade Cost Popup | near hovered upgrade button | Shows the cost for the hovered upgrade button |
| Upper Station Area | upper 60 percent | Character, upgrade entries, station actions |
| Bottom Info Area | lower 40 percent | Fixed stats, shared storage, and hovered-item details |
| Page Pan Button | right edge | Moves to the right station page |

### Top Menu Button

The top-left button should be a small rectangular button labeled `Menu` for the blockout.

The top menu button lives in the fixed top bar, outside the horizontally panning page container.

Expected future contents:

- settings
- save/quit
- return to title
- controls

First-pass behavior may be stubbed with no action or a placeholder popup.

### Map Button

The top-center icon is the map button. It should use a galaxy icon.

The map button lives in the fixed top bar, outside the horizontally panning page container.

Blockout requirements:

- centered horizontally on the current page
- visually distinct from upgrade and storage icons
- clickable
- eventually routes to a future map screen where the player selects a level or planet to start a run at

First-pass behavior:

- emit a run-start request through `AppRoot`
- start the existing run directly
- skip the map screen until it is designed later

Future behavior:

- emit a map-screen route request instead of starting a run directly
- let the map/planet-selection screen own level choice and run start

### Upgrade Cost Popup

The small cost window in the sketch is not a persistent resource display. It appears when the player hovers over any upgrade button.

The sketch includes:

- money cost, example `350`
- second upgrade requirement or resource count, example `0/3`

Behavior:

- appears on hover/focus of an upgrade up-arrow/plus button
- hides when the upgrade button is no longer hovered/focused
- shows the cost of that specific upgrade
- should position near the hovered upgrade button without covering it
- can share one reusable popup instance across all upgrade buttons

First-pass contents:

- credits cost
- secondary requirement/cost placeholder
- optional disabled/unaffordable state

### Player Avatar

The center of the upper station area contains a simple standing player silhouette.

Purpose:

- anchors the scene as a docked/player-facing hub
- separates left-side and right-side upgrade groups
- reinforces that the player is between runs

First-pass behavior:

- static visual only
- no movement input required
- no collision or gameplay behavior

### Left Upgrade Group

The left side of the upper station area contains two horizontal upgrade rows.

Drafted rows:

1. Weapon slot row
2. Magnet gun slot row

Each row contains:

- a large icon/button showing the current equipment piece or upgrade icon
- five slim vertical tick markers that represent the current level
- an upgrade button shown as an up arrow/plus
- upgrade-cost hover popup support on the upgrade button

Layout requirement:

- the left upgrade group should be container-driven, with the category icon beside a vertical stack of equipment rows
- each equipment row should use horizontal layout for the equipment icon, tick markers, and upgrade button
- equipment icon buttons should use the same normalized footprint as the player health and shield icon buttons
- the weapon category icon should sit directly to the left of the weapon equipment slot, aligned with the weapon row rather than centered across the full group
- when horizontally positioning the left and right upgrade groups around the player sprite, ignore the left-side weapon category icon and balance only the actual upgrade row content: equipment icon, tick markers, and upgrade button

Weapon slot row:

- shows the currently equipped weapon
- clicking the weapon icon toggles the weapon equipment popup
- selecting another equippable weapon from that popup equips it and closes the popup

Magnet gun slot row:

- shows the magnet gun
- static equipment slot
- cannot be swapped
- can be upgraded through its upgrade button
- does not open the weapon equipment popup

Selection brackets:

- omitted from the current blockout
- may return later as a selection treatment after the weapon equipment popup layout is finalized
- if the magnet gun slot later gains its own detail popup, it should use the same bracket language

Weapon slot category icon:

- the small icon beside the left upgrade group should be a gun icon
- it signifies that the selected row/group is the weapon slot category

### Right Upgrade Group

The right side of the upper station area contains two more horizontal upgrade rows.

Drafted rows:

1. Player health upgrade row, shown with a cross icon
2. Player shield upgrade row, shown with a shield icon

Each row follows the same structure as the left upgrade group:

- large square icon
- five slim vertical tick markers for current level
- upgrade button
- upgrade-cost hover popup support on the upgrade button

Layout requirement:

- the right upgrade group should use a vertical stack of horizontal upgrade rows
- row spacing should be controlled by container separation rather than individual child offsets
- the left and right upgrade row content should sit with matching horizontal gaps from the player sprite

### Page Pan Button

The ship-like button on the right side of the upper station area is the page pan button, not the launch/undock button.

Left page behavior:

- sits at the right edge of the left page
- uses a ship icon
- pressing it hides the button and pans to page index `1`

Right page behavior:

- mirrored button appears on the left side of the right page
- uses a player icon
- pressing it hides the button and pans back to page index `0`

Blockout behavior:

- only the button for the offscreen destination should be visible on the active page
- the inactive page's mirrored button should become visible after the pan completes
- both buttons should be disabled while panning

---

## Bottom Info Area

The bottom band is separated from the upper station area by the space station or docking-area ground line. For now this should be represented as a simple horizontal line.

It contains three major panels.

Layout behavior:

- the bottom-left stats panel is shared/static and does not pan
- clicking a page pan button immediately clears the stats panel
- the stats panel is repopulated when panning completes
- the player page shows player stats in this slot
- the ship page shows ship stats in this slot
- the storage panel is shared/static and does not pan
- the bottom-right storage detail popup is shared/static and does not pan

### Stats Panel

Location:

- bottom-left

Purpose:

- show stats for the currently active station page

Draft content from sketch:

- title `Stats`
- several short stat lines

Expected stat entries:

- player health
- player shield
- other player-facing combat or run-prep stats as needed

First-pass blockout can use placeholder text lines.

### Storage Panel

Location:

- bottom-center

Purpose:

- house all items retrieved from runs

Draft content from sketch:

- title `Storage`
- large bordered empty area
- small item icon in the top-left of the storage area

Storage behavior:

- scrollable list/grid of square item icons
- one slot per unique item in storage
- each slot should be a reusable `StationStorageSlot` scene with its own item data, quantity, and hover signals
- storage slots should be dynamically instantiated from the current storage item list rather than hand-authored in the station screen scene
- the number of slots is dynamic and matches the number of unique stored items
- infinite unique-item slots are allowed through scrolling
- infinite quantity is allowed on each slot
- item quantities should be represented on the item slot when greater than one

The panel should be wider than the stats panel because storage will likely become a frequent management surface.

### Detail / Description Panel

Location:

- bottom-right

Purpose:

- show details for the currently hovered storage item slot

Draft content from sketch:

- small large-icon area on the left
- text block on the right/top
- larger text description below
- vertical scrollbar on the far right

First-pass requirements:

- hidden when no storage item is hovered
- include an icon area matching the hovered storage item icon
- include a title/name area matching the hovered storage item name
- include a body text area for hovered item stats
- include a visible scrollbar track or reserved scroll area

The body text should support:

- rarity
- weight
- parts breakdown, if the item has one
- description
- any other storage-item-specific stats

For the blockout, it may display static placeholder details while preserving the hover-only behavior.

---

## Weapon Equipment Popup

The second sketch shows the weapon equipment popup opened from the weapon slot in the left upgrade group.

This popup is only for equipping a weapon in the weapon slot. It should not open when clicking the magnet gun slot, because the magnet gun is static and can only be upgraded.

### Trigger Rules

The weapon equipment popup should:

- open when the player clicks the weapon equipment icon in the left upgrade group
- behave as a toggled popup, not as a hover popup
- stay open while the player moves through the weapon list
- close when the player clicks the weapon equipment icon again, clicks outside the popup, equips a weapon, presses a back/close action, or pans to the other page

Selection brackets are omitted from the current blockout while the popup layout is still being tuned.

### Popup Placement

The popup appears over the upper station area, anchored near the left upgrade group and selected weapon icon.

It consists of two major panels:

1. Left equipment panel
2. Right hovered-weapon stats panel

The popup overlaps the upgrade area but should not cover the bottom info panels.

### Left Equipment Panel

The left equipment panel is split into two vertical sections:

1. Current equipped weapon section
2. Equippable weapons list section

#### Current Equipped Weapon Section

This section represents the currently equipped weapon.

The current weapon icon should remain visible underneath the popup. To support that, the icon area of this popup section should use negative space, a cutout, or transparent panel treatment so the equipped item icon underneath shows through.

For the first blockout, it is acceptable to render the weapon equipment popup underneath the selected equipment icon and reserve an icon-sized bay in the popup panel. The selected equipment icon should draw above the popup, making the reserved bay read as negative space.

Below the exposed icon area, show the current weapon's stats:

- item name
- rarity
- damage
- firing rate
- other weapon-specific stats as needed

#### Equippable Weapons List Section

This section is a scrollable vertical list of possible weapons to equip.

Each weapon entry should show:

- weapon icon
- enough visual state to indicate whether it is unlocked, equipped, or locked

Unlocked weapon behavior:

- hovering/focusing an unlocked weapon shows that weapon in the right stats panel
- clicking an unlocked weapon equips it and closes the popup

Locked weapon behavior:

- locked weapons are greyed out
- each locked weapon displays an unlock button in the bottom-right of its entry
- clicking the locked weapon itself should not equip it
- unlock button behavior can be stubbed until the unlock system exists

### Right Hovered-Weapon Stats Panel

The right panel is a popup window for the weapon equipment popup.

It appears when hovering/focusing one of the weapons in the equippable weapons list and shows that hovered weapon's stats.

Expected contents:

- hovered weapon icon or name
- rarity
- damage
- firing rate
- other weapon-specific stats as needed
- locked/unlock requirements, if the hovered weapon is locked

This panel should hide or show an empty state when no weapon list entry is hovered.

---

## Ship Page Layout

The right page is the ship screen. It should be blocked out as a sibling page with a similar structure to the player screen.

For the first blockout, the ship screen should differ from the player screen in only two major ways:

- the center sprite is the ship instead of the player
- the left and right upgrade groups are omitted until the ship-specific groups are designed

### Required First-Pass Elements

The ship page should include:

- top menu button or shared menu affordance
- map button or page-specific header/action icon
- centered ship sprite
- ship stats appear in the shared fixed bottom-left stats panel after panning to the ship page
- shared fixed storage and storage detail panels remain visible while viewing the ship page
- page pan button pointing back to the left page

### Placeholder Content

Until the final right-page information is attached, use clearly labeled placeholder regions:

- `Station Services`
- `Contracts`
- `Shipyard`
- `Market`
- `Intel`

These labels are not final UI copy. They exist to preserve space and make the two-page navigation testable.

### Future Content Candidates

The ship page may eventually contain:

- ship-specific left and right upgrade groups
- contracts or mission selection
- station shop
- shipyard services
- crew or NPC interactions
- sector map
- run preparation details
- station reputation and faction information

No first-pass implementation should hardcode these categories as final systems.

---

## Interaction Model

### Selection

Selectable elements should include:

- upgrade row icons
- upgrade buttons
- map button
- storage entries
- weapon popup list entries
- locked-weapon unlock buttons
- page pan buttons

Selecting a station element should update the appropriate UI surface unless the selection immediately opens a popup or starts navigation.

Specific rules:

- hovering an upgrade button shows the upgrade cost popup
- clicking the weapon equipment icon toggles the weapon equipment popup
- clicking the magnet gun icon does not open the weapon equipment popup
- hovering a storage item shows the bottom-right storage detail panel
- hovering a weapon in the equipment popup shows the right hovered-weapon stats panel
- clicking an unlocked weapon in the equipment popup equips it and closes the popup
- clicking the map button starts a run directly in the first implementation
- later, clicking the map button routes to the future map/planet-selection screen

### Hover / Focus States

For mouse and controller readiness, the screen should eventually distinguish:

- normal
- hovered/focused
- selected
- disabled
- purchased/complete
- unaffordable

The blockout only needs visible normal and selected states.

### Input Locking

Input should be locked during:

- horizontal page pan tween
- purchase/upgrade confirmation animation, if added
- route transition out of the station screen

Popup-local input should not accidentally trigger page-level controls behind the popup.

### Controller Readiness

The screen can be mouse-first for the initial blockout, but the layout should not prevent controller support.

Recommended future focus order:

1. top menu
2. map button
3. left upgrade rows
4. right upgrade rows
5. page pan buttons
6. bottom stats/storage/detail interactables
7. popup options when a popup is open

---

## Data Placeholders

The station screen should be able to render before final meta-progression data exists.

Suggested placeholder data:

- upgrade cost popup credits: `350`
- upgrade cost popup secondary requirement: `0 / 3`
- upgrade levels: tick marker counts
- storage entries: one or more known item/component icons with quantities
- player stats: health, shield, and placeholder stat lines
- weapon popup entries: equipped weapon, unlocked weapon options, and at least one locked weapon with an unlock button
- storage hover detail: generic hovered item name, rarity, weight, parts breakdown, and description

The first implementation should avoid inventing permanent save data structures unless needed for the blockout.

---

## Scene Structure Guidance

Suggested scene responsibilities:

| Scene / Script | Responsibility |
|---|---|
| `StationScreen` | Owns page panning, selected state, popup visibility, route signals |
| `StationPage` | Optional helper for one full-sized page layout |
| `StationUpgradeRow` | Reusable icon, tick markers, upgrade button row |
| `StationUpgradeCostPopup` | Hover popup for upgrade button costs |
| `StationBottomPanel` | Optional grouped bottom info area |
| `StationWeaponEquipPopup` | Toggled weapon equipment popup |
| `StationWeaponStatsPopup` | Hovered-weapon stats panel inside the weapon equipment popup |
| `StationStorageGrid` | Future storage item grid/list |
| `StationStorageSlot` | Reusable square item slot with setup data and hover signals |
| `StationStorageDetailPanel` | Hovered storage item details |

The first pass can keep these as one scene if that is faster, but upgrade rows and the popup are likely worth extracting once behavior is added.

---

## File Impact

### New Files Expected

| File | Purpose |
|---|---|
| `_project/app/screens/station_screen.tscn` | Full station hub screen with two horizontal pages |
| `_project/app/screens/station_screen.gd` | Page panning, selection, hover popups, weapon popup, and route signal logic |
| `_project/app/screens/station_upgrade_row.tscn` | Reusable upgrade row blockout |
| `_project/app/screens/station_upgrade_row.gd` | Upgrade row display and pressed/selected signals |
| `_project/app/screens/station_upgrade_cost_popup.tscn` | Hover popup for upgrade button costs |
| `_project/app/screens/station_upgrade_cost_popup.gd` | Cost display and positioning logic |
| `_project/app/screens/station_weapon_equip_popup.tscn` | Weapon equipment popup shown in the second sketch |
| `_project/app/screens/station_weapon_equip_popup.gd` | Equipped weapon section, equippable list, hover stats, equip/close behavior |
| `_project/app/screens/station_storage_slot.tscn` | Reusable square storage item slot |
| `_project/app/screens/station_storage_slot.gd` | Slot setup, quantity display, and item hover/unhover signals |
| `_project/app/screens/station_storage_detail_panel.tscn` | Hover detail panel for storage items |
| `_project/app/screens/station_storage_detail_panel.gd` | Storage item detail display |

### Existing Files To Update Later

| File | Change |
|---|---|
| `_project/app/app_root.gd` | Add route to open the station screen and handle the station map button as a first-pass run-start request |
| `_project/app/app_root.tscn` | Preload or instance the station screen as part of app routing |
| `_project/app/screens/main_menu.gd` | Replace direct run start with `New Game` routing into the station screen |
| `_project/app/screens/main_menu.tscn` | Replace the direct `Start Run` button with `New Game` while keeping normal menu actions such as `Exit` |
| `_project/app/screens/salvage_process_screen.gd` | Route completed salvage results back to the station screen |
| `_project/app/screens/salvage_results_popup.gd` | Emit a station-return request from the final results button |
| `_project/app/screens/salvage_results_popup.tscn` | Label the final results button as `Return To Station` |
| `_project/ui/magnetide_theme.tres` | Add station-specific theme styles if needed |
| Future map screen files | Receive the map button route and handle level/planet selection |

The station screen spec does not require immediate changes to run gameplay or item resources. Persisting returned salvage into player storage is deferred until the overall save/state container exists.

---

## Recommended Implementation Order

1. Create `station_screen.tscn` as a full-screen `Control`.
2. Add a two-page container sized to `2x` the viewport width.
3. Block out the left page according to the provided sketch.
4. Block out the right page with matching structure and placeholder content.
5. Add page pan buttons and tweened horizontal movement.
6. Add reusable upgrade row scenes or equivalent grouped controls.
7. Add the bottom stats, storage, and detail panels.
8. Add the upgrade-cost hover popup for upgrade buttons.
9. Add the weapon equipment popup from the second sketch.
10. Create a reusable storage slot scene and dynamically populate the storage grid.
11. Wire storage item hover to the bottom-right storage detail panel.
12. Update the main menu to show `New Game` and route it to the station screen.
13. Wire the station map button to start the existing run directly for now.
14. Wire the salvage results flow to return to the station screen.
15. Verify both pages scale to the target game resolution without overlapping text or controls.

---

## Resolved Decisions

1. The station screen is a non-run app screen, not an overlay inside gameplay.
2. It is one continuous two-page screen arranged horizontally.
3. The left page is the primary drafted page shown in the sketches.
4. The right page should be blocked out now but filled with final content later.
5. Navigation between pages should be animated by sliding horizontally.
6. The ship icon on the right side of the left page is the page pan button, not a launch button.
7. The mirrored right-page pan button should use a player icon and return to the left page.
8. The top-center galaxy icon is the map button.
9. The cost box in the sketch is an upgrade-cost hover popup, not a persistent resource display.
10. The bottom band should remain persistent in structure across the left and right pages.
11. The bottom-right detail panel appears only when hovering a storage item slot.
12. The storage panel contains a scrollable dynamic list of square item slots, one per unique stored item.
13. Storage item slots should be reusable scenes that are instantiated dynamically from storage data.
14. The popup shown in the second sketch is specifically the weapon equipment popup.
15. The weapon equipment popup only opens from the weapon slot, not the static magnet gun slot.
16. The right-side upgrade rows are player health and player shield.
17. The right page is the ship screen.
18. The ship screen uses a centered ship sprite instead of the centered player sprite.
19. Ship-specific upgrade groups are omitted from the first blockout.
20. The first-pass main menu uses `New Game` instead of direct `Start Run`, while keeping normal menu actions such as `Exit`.
21. Pressing `New Game` opens the station screen.
22. The map button starts a run directly until the map/planet-selection screen exists.
23. The future save system will use one automatically managed save slot, with `New Game` overwriting it and `Continue` appearing only when a save exists.
24. After the salvage results flow, the player returns to the station screen.
25. Run loot should eventually be merged into player storage before returning to the station, but this is deferred until save/state exists.
26. The first pass should prioritize visual/component blockout over permanent data architecture.

---

## Open Questions

1. What is the exact target resolution for final station layout authoring?
2. What exact upgrade costs and secondary requirements should each upgrade button display?
3. What final content belongs on the right page?
4. Should station page panning be button-only, drag/swipe, keyboard/controller shoulder buttons, or all of these?
5. What is the final unlock behavior and cost model for locked weapons in the weapon equipment popup?
6. What stats should every weapon entry show in the popup list versus the hovered-weapon stats panel?
