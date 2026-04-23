# Salvage Processing Screen Specification

## Overview

This spec defines the real post-run salvage-processing screen that replaces the current placeholder `SalvageProcessScreen`.

It is the follow-up feature to the placeholder destination described in `run_loop_and_end_of_run_spec.md`.

The purpose of this screen is to:

- let the player manually break down every salvageable item recovered during the run
- visually deposit the resulting components into storage
- preserve direct/non-salvageable loot from the run
- present a final combined results popup before returning to the main menu

This screen is the last interactive end-of-run step before the player leaves the run loop and returns to non-gameplay navigation.

---

## Design Goals

1. Make salvaging feel tactile and satisfying instead of resolving instantly in a menu.
2. Preserve a clear sense of progress by processing one salvageable item at a time.
3. Keep the final payout readable by separating the on-screen breakdown process from the final aggregated results popup.
4. Reuse the run's stored loot snapshot instead of reaching back into unloaded gameplay state.
5. Keep the animation rules deterministic and data-driven enough to tune without rewriting the whole screen.

---

## Authored Requirements

The following behavior comes directly from the design notes and should be treated as the intended first implementation.

### High-Level Flow

1. The screen opens on the first salvageable item, shown large in the center of the screen.
2. A storage icon sits in the lower-left corner and represents the player's inventory destination.
3. Top text shows:
   - the current salvage item index out of the total number of salvageable items
   - the current item's display name
4. The player must click the centered salvage item a rarity-based number of times to break it down.
5. On each click, the item reacts with a small rotation and a pulse inward.
6. On the final click, the item pops and its components burst outward, pause briefly, then steer into the storage icon.
7. Each arriving component makes the storage icon pulse/rotate and pushes a temporary stacked label above the icon.
8. After a short delay, the next salvageable item slides in from the right and the loop repeats.
9. After the last salvageable item resolves, a final popup shows the full collected result list:
   - direct/non-salvageable items from the run
   - components produced by salvaging
10. The player can then return to the main menu.

### Rarity-Based Click Counts

- `COMMON`: `2` clicks
- `RARE`: `3` clicks
- `EPIC`: `4` clicks
- `LEGENDARY`: `5` clicks

These counts are fixed for the first pass and should not be randomized.

---

## Current Project Context

### Existing Placeholder

`_project/app/screens/salvage_process_screen.tscn` and `_project/app/screens/salvage_process_screen.gd` currently implement a static placeholder panel with:

- a short text summary
- a `Start Another Run` button
- a `Main Menu` button

That placeholder should be replaced by the interactive screen described in this document.

### Existing Run Data

`RunResult` currently preserves:

- end reason
- elapsed time
- enemies killed
- salvage item count
- `stored_loot: Array[SalvageItemData]`

This is the correct ownership boundary: the salvage screen should consume the `RunResult` payload and not depend on the gameplay level still being loaded.

### Existing Salvage Item Data

The current `SalvageItemData` resources already imply two useful categories:

- items with a non-empty `components` array, which can be broken down on the salvage screen
- items with no salvage outputs, which should go straight to the final result list

In the current resources, component-like/direct-result items also typically set `is_component = true`, but the first-pass salvage-screen classification should be based on whether the item actually has breakdown outputs.

Recommended first-pass rule:

- if `item_data.components.is_empty()` is `false`, the item enters the on-screen salvage queue
- if `item_data.components.is_empty()` is `true`, the item bypasses the on-screen salvage loop and is counted directly into final results

This avoids coupling the screen to the ambiguous `is_component` naming while still matching the current authored data.

---

## Ownership And Flow Boundary

This spec assumes the earlier run-end flow remains intact:

1. The run ends.
2. The existing gameplay-side run summary popup appears.
3. The player continues past that popup.
4. `AppRoot` opens the salvage processing screen with the `RunResult`.

This spec governs only the salvage-processing screen itself and the final results popup shown inside that screen.

It does not require removing the current gameplay summary popup.

---

## Screen Layout

### Root Composition

The salvage processing screen should be a full-screen `Control`-based screen with three main layers:

1. A background/backdrop layer
2. A HUD/layout layer for labels, storage icon, and popup containers
3. A motion/stage layer for the centered salvage item and spawned flying components

It is acceptable for the implementation to mix `Control` and `Node2D` children if that makes the animated stage work cleaner.

### Top HUD

At the top center of the screen, show:

- a progress label such as `SALVAGE 2 / 6`
- a current item name label such as `AIR CONDITIONER`

The progress count should include only salvageable items that actually enter the click-to-breakdown loop.

Direct/non-salvageable items should not increase the top progress total.

### Center Stage

The active salvageable item appears large and centered on the screen.

Requirements:

- one active salvage item at a time
- clearly clickable
- no other salvage item visible on stage during the active state
- click input disabled while transitions or component-flight animations are in progress

### Storage Anchor

This spec assumes the storage icon sits in the lower-left corner of the screen.

That choice resolves the conflicting lower-left/lower-right wording in the design notes by treating the lower-right reference as a typo for the first pass.

The storage anchor contains:

- the storage icon sprite
- a local target point used by flying components
- a temporary stacked-label container that grows upward above the icon

---

## Data Model Requirements

### Input Payload

The screen accepts one `RunResult`.

On setup it should derive three collections:

1. `salvage_queue`
   - all stored loot entries whose `components` array is non-empty
2. `direct_result_items`
   - all stored loot entries whose `components` array is empty
3. `final_result_counts`
   - the aggregated quantity map that will eventually feed the final popup

### Final Result Aggregation

The final popup should list actual post-processing gains, not original salvageable shells.

That means:

- salvageable source items are consumed by the salvage screen flow
- their resulting components are added to `final_result_counts`
- direct/non-salvageable items are added to `final_result_counts` immediately on screen setup

If the player collected:

- `Air Conditioner`
- `Radio`
- `Battery`

and the first two break down while `Battery` is a direct final item, then the final popup should show:

- all resulting components from `Air Conditioner`
- all resulting components from `Radio`
- `Battery`

It should not show `Air Conditioner` or `Radio` as final output items unless a later design explicitly changes salvage rules.

### Determinism Rule

The salvage screen should not create new randomness that can diverge from the run result after gameplay has ended.

For the current first pass, that means:

- the breakdown result of a salvageable item is exactly its authored `components` array

If future systems introduce randomized salvage outputs, those resolved outputs must be written into `RunResult` before the gameplay scene unloads. The salvage screen should then animate the pre-resolved outputs rather than rerolling anything locally.

---

## Runtime State Machine

The screen should behave like a small authored state machine.

Suggested states:

- `SETUP`
- `ITEM_ENTER`
- `WAITING_FOR_CLICKS`
- `ITEM_POP`
- `COMPONENTS_RESTING`
- `COMPONENTS_FLYING`
- `BETWEEN_ITEMS`
- `RESULTS_POPUP`
- `COMPLETE`

### State Responsibilities

#### `SETUP`

- receive `RunResult`
- split loot into salvage queue versus direct-result items
- seed the final result map with direct-result items
- if `salvage_queue` is empty, skip straight to the results popup
- otherwise prepare the first active item

#### `ITEM_ENTER`

- spawn or reveal the next salvage item offscreen to the right
- slide it into the center stage
- update the top labels
- reset click counters and input gating
- enter `WAITING_FOR_CLICKS` when motion completes

#### `WAITING_FOR_CLICKS`

- accept click input only on the active item
- count clicks toward the rarity requirement
- play the per-click reaction animation
- on the final click, disable further input and enter `ITEM_POP`

#### `ITEM_POP`

- hide or destroy the source salvage item shell
- spawn one stage token per resulting component
- assign each spawned token an outward resting target around the center
- begin the burst/disperse motion
- enter `COMPONENTS_RESTING` once the burst completes

#### `COMPONENTS_RESTING`

- keep the components paused at their outward positions for a fixed `1.0` second
- after the pause, start the storage-seeking flight and enter `COMPONENTS_FLYING`

#### `COMPONENTS_FLYING`

- update each component token until it reaches the storage icon target
- when a token reaches the storage target:
  - add its item to `final_result_counts`
  - pulse/rotate the storage icon
  - create or update a temporary stacked label above the icon
  - queue-free the token
- when all tokens are gone, enter `BETWEEN_ITEMS`

#### `BETWEEN_ITEMS`

- wait `1.0` second after the last component lands
- if more salvageable items remain, start the next `ITEM_ENTER`
- otherwise open the final results popup and enter `RESULTS_POPUP`

#### `RESULTS_POPUP`

- show the combined post-salvage result list
- allow the player to return to the main menu

---

## Interaction Rules

### Click Target

Only the centered salvage item itself should count clicks.

Clicks on empty stage space should do nothing.

### Input Locking

The player must not be able to click ahead while:

- the item is entering
- the pop is resolving
- components are resting
- components are flying
- the results popup is open

### No Failure State

The first pass does not include:

- misclick penalties
- timed failure
- alternative salvage outcomes
- keyboard/controller mash alternatives

This is a deterministic finish-the-sequence interaction, not a skill test.

---

## Per-Click Item Reaction

Each click before the final pop should make the active salvage item feel stressed but still intact.

Required behavior per click:

- a slight rotation
- a pulse inward by shrinking briefly before settling back

Recommended feel:

- alternate or randomly vary the tilt direction per click
- keep the amplitude small enough that the item remains readable
- let the item settle back before the next click

This animation should be authored/tweened, not physics-driven.

---

## Pop And Component Burst

### Spawn Rule

On the final click, create one visible token per resulting component in the current salvage item's breakdown payload.

If a salvage item yields duplicate components, duplicate visible tokens should still be spawned so the player sees the actual volume of recovered parts.

### Outward Disperse

The spawned component tokens should:

- originate from the salvage item's center
- scatter outward to different nearby resting positions
- finish in a readable ring or loose arc around the center item location

The spread should feel punchy but not chaotic. Tokens should remain on-screen and not overlap the top HUD or storage anchor excessively.

### Rest/Hesitation

After the outward motion completes, the tokens pause at rest for `1.0` second before beginning their flight to storage.

This pause is important because it gives the player a moment to register what dropped before everything leaves the stage.

---

## Component Flight To Storage

### Motion Style

Components should not move in a straight-line lerp.

They should travel toward the storage icon by steering:

- turning gradually toward the target
- accelerating as they travel
- curving into the final destination

This creates a more alive, magnetized/inventory-seeking feel than a simple tween.

### Recommended First-Pass Motion Model

Each flying component token should track:

- current position
- current velocity
- current forward direction
- acceleration
- maximum speed
- turn speed

The update rule should:

1. compute the desired direction toward the storage target
2. rotate the token's current movement direction toward that desired direction by a capped turn rate
3. increase speed over time
4. move using the resulting velocity

The exact numbers should be exported/tunable on the screen script rather than hardcoded deep in helper nodes.

### Arrival Rule

When a component token enters a small arrival radius around the storage target:

- treat it as collected immediately
- trigger storage-icon feedback
- update temporary labels
- add the component to aggregated final results
- free the token

---

## Storage Icon Feedback

Every collected component should make the storage icon react.

Required feedback per arrival:

- a slight rotation
- a pulse outward by scaling up briefly

This reaction should be small and quick so it can play repeatedly without becoming visually noisy when several components arrive close together.

---

## Temporary Stacked Labels

### Purpose

The storage-anchor labels are not the final inventory list.

They are short-lived confirmation callouts that appear as items are deposited.

### Behavior

When components arrive at storage, labels should stack upward above the storage icon.

Each label should:

- show quantity and item name
- fade away on its own
- be removed from the stack after fading

As labels are added or removed, the stack should smoothly reposition so the active labels remain readable.

### Label Content

Recommended text format:

- `+1 Battery`
- `+2 Copper Wires`

The exact typography can vary, but the quantity should always be explicit.

### Aggregation Rule

For the first pass, labels may be created one per arriving item or merged into nearby like-item arrivals over a short time window, as long as:

- the player can clearly tell what entered storage
- the final result counts remain exact

The final popup is the authoritative total. The floating label stack is feedback, not the canonical inventory display.

---

## Final Results Popup

### Trigger

After the last salvageable item finishes processing and the final inter-item delay completes, open a popup window over the salvage screen.

### Contents

The popup should show the full post-salvage result list:

- all direct/non-salvageable items gathered during the run
- all components recovered through this salvage process

Recommended contents:

- title
- scrollable or vertically stacked item list
- quantity per item
- optional total unique-item count

### List Rules

The final list should be aggregated by item type.

If the player ends with three `Battery` items from any combination of direct loot and salvage outputs, the popup should show one entry for `Battery` with quantity `3`.

The screen should not show the original salvageable shell items in this popup unless those items were also direct-result items in the run payload.

### Empty-State Rule

If the player somehow reaches the salvage screen with no final items at all, the popup should show a clear empty state such as:

- `No materials recovered`

### Exit Behavior

The popup must provide a `Return To Main Menu` action.

That action should emit back to `AppRoot`, which then returns the player to the main menu screen.

This spec does not require a `Start Another Run` button on the final popup.

---

## Edge Cases

### No Salvageable Items

If `RunResult.stored_loot` contains only direct-result items:

- the salvage loop is skipped
- the final results popup opens immediately

### No Direct-Result Items

If the run contains only salvageable items:

- `final_result_counts` starts empty
- all final results come from the salvage process itself

### Duplicate Salvageables

If multiple identical salvageable source items were collected:

- each source item is processed separately in the click-to-breakdown loop
- the top progress still advances one source item at a time
- the final popup aggregates all identical resulting components together

### Large Output Counts

If one salvage item yields many components, the burst layout should still clamp tokens to sensible on-screen resting positions.

The first pass does not need complex crowd avoidance, but it should avoid unreadable full overlap.

---

## UI And Scene Structure Guidance

Suggested scene responsibilities:

- `SalvageProcessScreen`
  - owns the overall state machine
  - owns result aggregation
  - owns top-label updates
  - owns transition timing
- `SalvageComponentToken` scene or helper node
  - owns one flying component's sprite and steering state
- `SalvageResultsPopup`
  - owns final aggregated list presentation and exit button
- `FloatingLootLabel` scene or helper node
  - owns one fading stacked label above the storage icon

The exact node structure can change, but the state machine should stay centralized in the salvage screen rather than distributing sequencing logic across many unrelated nodes.

---

## File Impact

### Existing Files To Update

| File | Change |
|---|---|
| `_project/app/screens/salvage_process_screen.tscn` | Replace the placeholder layout with the real salvage-processing screen layout |
| `_project/app/screens/salvage_process_screen.gd` | Implement queue setup, screen state machine, click handling, animation sequencing, and popup routing |
| `_project/app/app_root.gd` | Continue routing `RunResult` into the salvage screen and handle the final main-menu exit signal |
| `_project/run/run_result.gd` | Add helper accessors or richer result payload only if needed for deterministic future salvage outputs |

### New Files Expected

| File | Purpose |
|---|---|
| `_project/app/screens/salvage_component_token.gd` | Steering/flying logic for one recovered component token |
| `_project/app/screens/salvage_component_token.tscn` | Visual scene for one flying component token |
| `_project/app/screens/salvage_results_popup.gd` | Final aggregated results popup controller |
| `_project/app/screens/salvage_results_popup.tscn` | Final aggregated results popup layout |
| `_project/app/screens/floating_loot_label.gd` | One fading stacked label above the storage icon |
| `_project/app/screens/floating_loot_label.tscn` | Visual scene for one floating loot label |

These helper scenes are recommended, not mandatory. A simpler single-script implementation is acceptable if it remains readable.

---

## Recommended Implementation Order

1. Replace the placeholder salvage screen layout with the permanent full-screen structure.
2. Split `RunResult.stored_loot` into salvage queue versus direct-result items.
3. Build the final aggregated result map and verify the no-salvageable fast path.
4. Implement the centered-item enter transition and top-label updates.
5. Implement rarity-based click counting and per-click item reaction animation.
6. Implement source-item pop behavior and outward component burst spawning.
7. Implement steering flight into the storage icon and per-arrival storage feedback.
8. Implement the temporary stacked-label system above the storage icon.
9. Implement next-item sequencing and end-of-queue handling.
10. Implement the final results popup and route its exit action back to `AppRoot`.
11. Verify duplicate items, all-direct-item runs, and zero-item runs.

---

## Resolved Decisions

1. The salvage screen consumes `RunResult` and never depends on the gameplay scene still being loaded.
2. Only items with authored salvage outputs enter the interactive salvage loop.
3. Items with no salvage outputs bypass the interactive loop and go straight into final results.
4. Click counts are fixed by rarity: `2/3/4/5` for `COMMON/RARE/EPIC/LEGENDARY`.
5. Only one salvageable source item is active on screen at a time.
6. The top progress count tracks only salvageable source items.
7. The current item's components pause for `1.0` second before flying to storage.
8. After all components land, the screen waits `1.0` second before bringing in the next salvageable item.
9. The storage icon anchor is placed in the lower-left corner for the first pass.
10. The final popup shows actual post-salvage gains, not the original salvageable shells.
11. The final popup must provide a `Return To Main Menu` action.
12. The current gameplay-side run summary popup is not removed by this spec.

---

## Open Questions

No blocking design questions remain for the first-pass salvage processing screen in this spec.
