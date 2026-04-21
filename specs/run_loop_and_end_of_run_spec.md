# Run Loop And End-Of-Run Specification

## Overview

This spec defines the first full implementation of the run loop wrapper around gameplay.

The current project already has:

- A playable `level.tscn`
- Enemy spawning
- Magnet looting
- Threat progression
- Basic UI for health, threat, and looting states

What it does not have yet is the outer run structure that:

- starts a run from a menu/app shell
- tracks run-level statistics
- ends the run for either success or failure
- shows a summary popup
- exits gameplay into a non-level screen so the next phase of the meta loop can begin

This document defines that system.

---

## Design Goals

1. Wrap gameplay in a reusable run/session flow instead of treating `level.tscn` as the entire application.
2. Support multiple runs per app session without restarting the project.
3. Keep the level scene reusable so future levels can be swapped in without rewriting the run flow.
4. Track run statistics in one authoritative place instead of scattering them across UI widgets and gameplay nodes.
5. Support exactly two run-ending outcomes for the first pass:
   - voluntary departure by the player
   - failure because the player or ship is destroyed
6. Make the voluntary end flow feel like existing in-world interaction by using a hold-`E` action on an object.
7. End the run immediately into a summary popup for now, while leaving room for future effects and animations.

---

## Current Project Context

### Startup Flow

The project currently boots directly into gameplay:

- `project.godot` uses `res://_project/level/level.tscn` as `run/main_scene`

That is fine for prototyping, but it prevents the project from cleanly supporting:

- a main menu
- a salvage processing screen
- a shop
- multiple runs in one session
- level selection in the future

### Autoload Assumptions

The current `Magnetide` autoload assumes the active gameplay level is always `get_tree().current_scene`.

That assumption will break once the app has non-level screens.

### Run State Ownership

Run-relevant state currently lives in multiple places:

- elapsed time is effectively owned by `CountdownTimer`
- ship storage exists on `Ship`
- kills are only implicitly knowable through enemy death
- end conditions are not surfaced through dedicated run lifecycle signals

For the first real run loop implementation, a dedicated run/session owner needs to collect and expose this data.

---

## Core Architecture

### 1. App Root

The project should gain a top-level app shell scene that becomes the new startup scene.

Responsibilities:

- own high-level screen routing
- show menus outside gameplay
- start a run
- unload a run
- receive the final run result
- transition to the next non-level screen after the run ends

The level scene should stop being the direct main scene of the application.

### 2. Level Definitions

Even though there is only one playable level right now, the structure should assume future expansion.

The run system should load a level through a small authored level-definition layer rather than hardcoding `level.tscn` everywhere.

A `LevelDefinition` should eventually own things like:

- id
- display name
- level scene
- future decoration/theme metadata
- future enemy profile overrides
- future salvage tables or modifiers

For the first pass, a single level definition can point to the existing `level.tscn`.

### 3. Run Session / Run Controller

Gameplay should be wrapped by a dedicated run owner.

Responsibilities:

- start and stop the run
- own elapsed run time
- track run statistics
- listen for end conditions
- freeze or stop gameplay systems when the run ends
- create a `RunResult` snapshot before the level unloads
- request the summary popup

This system should become the single source of truth for the run state.

### 4. Run Result

When the run ends, gameplay state must be converted into a durable result object that survives scene unload.

It should include at minimum:

- level id
- elapsed time
- end reason
- salvage item count
- enemies killed

It should also include the actual collected loot payload now, even if the next task uses it later.

That avoids losing the run inventory when the level scene is unloaded.

---

## Run Lifecycle

### Application Flow

The first full loop should be:

1. App boots into `AppRoot`
2. Player lands on a minimal main menu
3. Player starts a run
4. AppRoot loads the selected gameplay level inside the run flow
5. Run begins and statistics reset
6. Gameplay proceeds normally
7. Run ends from one of the valid end conditions
8. Summary popup appears immediately
9. Player confirms the popup
10. AppRoot unloads the level and opens a placeholder post-run screen

### Multiple Runs

The architecture should support repeated loops:

1. Start run
2. End run
3. Leave gameplay
4. Start another run

No full app restart should be required between runs.

---

## End Conditions

The first implementation supports exactly two categories of run-ending outcome.

### 1. Voluntary Departure

The player can choose to end the run intentionally.

This is the successful/manual end path.

### 2. Destruction Failure

The run ends immediately if either of the following reaches `0`:

- Player health
- Ship hull/integrity

For this first pass, magnet destruction is not itself a run-ending condition unless later design changes require it.

---

## Voluntary Departure Interaction

### Interaction Style

Voluntary departure should use the existing interaction language of the project:

- the player interacts with an in-world object using `E`
- the player must hold `E` for a set duration
- a progress popup or progress UI appears while the hold is in progress

This should not be implemented as a HUD-only “End Run” button.

### Departure Object

The level should contain dedicated departure interactables.

Examples of acceptable first-pass representations:

- two pylons mounted on the edge of the ship

For this feature, the chosen representation is:

- two pylons on the edge of the ship
- either pylon can be interacted with
- both pylons should trigger the same voluntary-departure flow

The important part is that voluntary departure is an authored world interaction tied to the ship, not a HUD-only control.

### Interaction Rules

The player must:

- be within interaction range
- hold `interact` (`E`) continuously
- complete the full hold duration to confirm departure

Either pylon should be valid for this interaction. The player does not need to use a specific left/right pylon. Both should behave identically and feed into the same shared departure request.

The departure interaction should be available at any time during a run, as long as the player is in range of either pylon and the run has not already ended.

If any of the following happens, the progress should cancel and reset:

- the player releases `E`
- the player leaves interaction range
- the run ends for another reason first
- the player is disabled or interrupted by a game state change

### Hold Progress UI

While the player is holding `E`, the game should show a progress popup/UI element.

Requirements:

- it must visibly communicate progress from `0` to `100%`
- it should only appear while the interaction is actively being held
- it should disappear immediately when cancelled or completed

The exact visual style is flexible for the first pass. It can be:

- a simple progress bar near the object
- a small screen-space popup
- a reused pattern similar to the existing repel hold progress behavior

The chosen behavior for this feature is:

- the hold progress UI is anchored in world space
- each pylon can display its own hold progress UI above itself
- the active progress display should appear above the pylon currently being used

### Completion Result

When the hold completes successfully:

- the voluntary departure sequence begins
- the end reason should be recorded as voluntary departure

The intended full presentation sequence is:

1. the ship deploys a force field surrounding the deck
2. the ship rises into the sky and exits offscreen
3. the end summary screen is triggered afterwards

For the current first-pass implementation, the game may skip these effects and open the end summary immediately, but the run-end architecture should leave room for this sequence to be inserted later without redesigning the departure interaction.

---

## Failure End Conditions

### Player Destruction

If the player's health reaches `0`, the run ends immediately.

Recorded end reason:

- `PLAYER_DESTROYED`

### Ship Destruction

If the ship's hull/integrity reaches `0`, the run ends immediately.

Recorded end reason:

- `SHIP_DESTROYED`

### Shared Rule

All end conditions should flow through one shared end-run API so the system cannot partially end twice in the same frame.

Recommended shape:

```gdscript
request_end_run(reason: RunEndReason) -> void
```

This method should be idempotent after the first successful call.

---

## End Summary Popup

When the run ends, a popup window should appear immediately over gameplay.

Future effects and animations can be added later, but the first pass should skip them entirely.

For voluntary departure specifically, the long-term intended behavior is that the popup appears after the departure presentation sequence completes:

- deploy force field around the deck
- ship ascends offscreen
- summary popup appears

For the first pass, this sequence may be bypassed and the popup may appear immediately after departure is confirmed.

### Required Contents

The popup must show:

- reason the run ended
- time elapsed
- number of salvage items collected
- enemies killed

### Button Behavior

The bottom button on the popup should:

- dismiss the popup
- exit the gameplay level
- send the player to a placeholder post-run/menu screen

This next screen is only a placeholder for now. The actual salvage processing flow will be implemented later.

### Reason Labels

The popup should convert internal reason enums into player-facing text such as:

- `Voluntary Departure`
- `Player Destroyed`
- `Ship Destroyed`

---

## Statistics Tracking

The run/session system should track statistics continuously while the run is active.

### Required Stats

#### Time Elapsed

- Starts when the run begins
- Stops when the run ends
- Should be owned by the run/session layer, not by a UI label

#### Salvage Items Collected

This stat should increase when loot is successfully committed into the ship's storage/result inventory.

For the first pass, “salvage items collected” means the current quantity of items in storage at the time the run ends.

This should not mean:

- every item ever touched during the run
- every item ever magnetized during the run
- a lifetime total of all items that were temporarily stored and later removed

It is specifically the currently stored item count when the result snapshot is created.

#### Enemies Killed

This stat should increase when an enemy dies.

The enemy spawner or another central gameplay listener should surface this cleanly to the run/session system.

### Stored Loot Payload

In addition to the displayed count, the run result should preserve the actual collected items.

This data should be available for the later salvage-processing screen.

Suggested payload:

- array of `SalvageItemData`
- or a dedicated result-entry resource if quantity/stacking metadata is needed later

---

## Runtime Integration

### Signals And Events

The first pass should expose explicit lifecycle signals rather than forcing the run controller to poll everything.

Recommended additions:

- `Player.destroyed`
- `Ship.destroyed`
- `EnemySpawner.enemy_killed`
- run/session lifecycle signals such as:
  - `run_started`
  - `run_ending`
  - `run_ended`

The existing `Ship.item_stored` signal should be reused for salvage stat tracking.

### Gameplay Freeze Behavior

When the run ends:

- player input should stop
- new enemy spawning should stop
- threat progression should stop
- magnet looting should stop
- timers owned by the run should stop

The goal is to freeze the run state cleanly before unloading gameplay.

The exact implementation can either:

- disable relevant systems directly
- or use pause-aware configuration if a full tree pause is desired later

For the first pass, direct system shutdown is preferred if it is simpler and less risky.

---

## UI Ownership

### Existing Gameplay UI

`GameUI` should remain the owner of normal in-run HUD elements.

### New UI Elements

The following new UI pieces are expected:

- a hold-progress popup/UI for the voluntary departure interaction
- a run summary popup for end-of-run reporting

These should be driven by the run/session layer rather than owning the underlying gameplay state themselves.

---

## Autoload Refactor Requirement

The current autoload should stop assuming `current_scene` is always the active level.

Instead, the app/run flow should explicitly register active references such as:

- active level
- active run controller
- active game UI
- ship
- player
- magnet

This is required before the project can safely add menus and post-run screens.

---

## File Impact

### Existing Files To Update

| File | Change |
|---|---|
| `project.godot` | Change startup scene from direct level boot to the new app shell |
| `_project/autoloads/magnetide.gd` | Refactor active-scene assumptions into explicit active references |
| `_project/level/level.tscn` | Integrate the level into the new run-loading flow and add the departure interactable |
| `_project/level/level.gd` | Optionally expose helpers for the run/session controller |
| `_project/player/player.gd` | Surface player destruction and support hold-`E` departure interaction flow |
| `_project/ship/ship.gd` | Surface ship destruction and continue exposing stored-item events |
| `_project/ship/magnet/magnet.gd` | Stop looting cleanly when the run ends |
| `_project/ship/magnet/minigame/magnet_minigame.gd` | Cooperate with run-end shutdown and not continue looting after the run is over |
| `_project/level/enemies/enemy_spawner.gd` | Surface enemy kill tracking and stop spawning when the run ends |
| `_project/ui/game_ui.tscn` | Host any new run-end and hold-progress UI |
| `_project/ui/game_ui.gd` | Wire runtime UI updates as needed for the new session flow |

### New Files Expected

| File | Purpose |
|---|---|
| `_project/app/app_root.tscn` | Top-level app shell scene |
| `_project/app/app_root.gd` | Screen routing and run start/finish orchestration |
| `_project/app/level_definition.gd` | Future-proof level metadata and scene reference |
| `_project/app/screens/main_menu.tscn` | First non-gameplay screen |
| `_project/app/screens/salvage_process_screen.tscn` | Placeholder post-run destination |
| `_project/run/run_controller.gd` | Owns active run state and end conditions |
| `_project/run/run_result.gd` | Durable post-run data snapshot |
| `_project/run/run_end_reason.gd` | Shared end reason enum/constants if desired |
| `_project/level/interactables/departure_interactable.gd` | World interaction for voluntary departure |
| `_project/ui/run_summary_popup.tscn` | End-of-run summary popup |
| `_project/ui/run_summary_popup.gd` | Populates and controls the summary popup |
| `_project/ui/hold_progress_popup.tscn` | Hold-`E` progress UI |
| `_project/ui/hold_progress_popup.gd` | Displays and updates voluntary-departure hold progress |

The exact folder layout can change, but the run/app-layer code should live outside the core level gameplay scripts so the ownership stays clear.

---

## Recommended Implementation Order

1. Add the app shell and switch startup away from direct `level.tscn` boot.
2. Refactor the `Magnetide` autoload to use explicit active references instead of `current_scene` assumptions.
3. Create the run controller and run result types.
4. Load the existing level through the run flow using a single level definition.
5. Move elapsed-time ownership into the run/session layer.
6. Surface gameplay signals for player destruction, ship destruction, item stored, and enemy killed.
7. Add the departure interactable and the hold-`E` progress popup.
8. Route voluntary departure through the shared end-run API.
9. Add the run summary popup and post-run transition button.
10. Add a placeholder post-run screen that receives the result and allows the project to leave gameplay cleanly.
11. Verify repeated start-run and end-run cycles without stale state.

---

## Resolved Decisions

1. The level scene should no longer be the app's direct startup scene.
2. The project should gain an outer app/menu shell before adding the salvage-processing phase.
3. The run controller should be the single source of truth for run timing and summary statistics.
4. There are exactly two end-condition categories in the first pass:
   - voluntary departure
   - destruction failure
5. Voluntary departure is an in-world hold-`E` interaction on an object, not a HUD button.
6. The voluntary-departure interaction must show a hold-progress popup/UI while the key is being held.
7. Voluntary departure is represented by two ship-edge pylons, and either pylon can be used to trigger the same hold-`E` interaction.
8. The long-term voluntary-departure presentation is: deploy deck force field, rise offscreen, then show the summary popup.
9. Voluntary departure can be triggered at any time during a run, provided the player is in range of either pylon.
10. The hold progress UI is anchored in world space above the active pylon.
11. “Salvage items collected” means the current quantity of items in ship storage when the run ends.
12. Failure happens when the player or ship reaches `0` health/integrity.
13. The run summary popup appears immediately when the run ends in the first pass, even though voluntary departure will later gain its full presentation sequence.
14. The popup button exits the gameplay scene and goes to a placeholder post-run screen.
15. The run result should preserve both summary numbers and the actual collected loot payload.

---

## Open Questions

No open questions remain for the first-pass run-end flow in this spec.
