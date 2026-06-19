# Research System Implementation Spec

## Overview

The research system lets the player convert unknown artifacts into future unlocks. In the first implementation pass, artifacts can be pulled from salvage piles, carried with the magnet gun, placed onto the ship's research station, locked in place, and automatically marked researched after a debug duration of 5 seconds.

This pass intentionally does not implement unlock rewards, research minigames, station UI, or persistence beyond the runtime item reference held by the table.

Update: artifact pile acquisition, research point rewards, station unlock spending, and the weight-based chance refactor are specified in `specs/artifact_piles_and_research_points_spec.md`. That newer spec supersedes the artifact-acquisition details in this first-pass document.

## Goals

- Add artifacts as a new special salvage item type.
- Let salvage piles roll artifacts at a low, pile-rarity-specific chance.
- Give artifacts a unique tooltip color and a placeholder visual.
- Add functionality to the existing ship research station.
- Let the player place a held artifact onto the research station using the magnet gun.
- Lock the placed artifact so it cannot be picked up, hovered, outlined, or affected by physics.
- Auto-complete research after 5 seconds for debugging.

## Non-Goals

- No real research minigames yet.
- No upgrade/equipment unlock graph yet.
- No permanent save/load of researched artifacts yet.
- No station-screen research UI yet.
- No art-final research station sprite pass.

## Existing Systems To Reuse

- `SalvageItem` already owns runtime item state, collision, tooltip naming/color helpers, magnet-gun grabbing, storage placement, and locked cutscene behavior.
- `SalvageItemData` already owns item name, rarity, sprite, area, hitbox, weight, and breakdown parts.
- `SalvagePileData.roll_item()` already performs pile loot rolls and salvageable/non-salvageable selection.
- `Magnet._spawn_item_from_pile()` already creates `SalvageItem` instances from pile roll dictionaries.
- `Player` already owns magnet-gun held item, hover, outline, tooltip, repel, and storage placement decisions.
- `Ship` already exposes storage placement APIs to `Player`, so research station placement should follow the same pattern.

## Artifact Item Data

### `SalvageItemData`

Add an item kind flag:

```gdscript
enum ItemKind { SALVAGE, ARTIFACT }

@export_group("Research")
@export var item_kind: ItemKind = ItemKind.SALVAGE
```

Add a convenience property:

```gdscript
var is_artifact: bool:
	get:
		return item_kind == ItemKind.ARTIFACT
```

Artifacts should still use the existing rarity field for any future weighting/filtering, but tooltip color should come from artifact type rather than rarity.

Suggested artifact tooltip color:

```gdscript
const ARTIFACT_COLOR: Color = Color("4fffe8")
```

### Placeholder Artifact Resource

Create:

- `_project/items/resources/artifacts/unknown_artifact.tres`

Suggested values:

- `item_name = "Unknown Artifact"`
- `item_kind = ARTIFACT`
- `rarity = RARE` or `EPIC`
- `sprite = res://_project/items/salvage/sprites/part_powercore.png`
- `area = Vector2(96, 96)`
- `weight = 1.25`
- `parts = []`

Rationale: `part_powercore.png` reads as mysterious/valuable, exists already, and avoids introducing final-art assumptions. Later, this can be replaced with a dedicated artifact sprite.

## Salvage Pile Artifact Rolls

### `SalvagePileData`

Change pile pulls to use a 3-way category distribution before any item table is rolled:

- Normal salvage/non-salvage items
- Trash items
- Artifacts

The three category chances should add to 100%. If the roll lands on the normal salvage/non-salvage category, the existing salvageable vs. non-salvageable pity roll runs afterward.

Add an artifact section and make the normal item category explicit:

```gdscript
@export_group("Pull Categories")
@export_range(0.0, 100.0, 0.1) var normal_item_percent: float = 79.0
@export_range(0.0, 100.0, 0.1) var trash_percent: float = 20.0
@export_range(0.0, 100.0, 0.1) var artifact_percent: float = 1.0

@export_group("Artifacts")
@export var artifact_loot_table: LootTable = null
```

Add helpers:

```gdscript
func get_category_percent_total() -> float:
	return normal_item_percent + trash_percent + artifact_percent

func has_valid_category_distribution() -> bool:
	return absf(get_category_percent_total() - 100.0) <= 0.01

func can_roll_artifact() -> bool:
	return artifact_percent > 0.0 and artifact_loot_table != null
```

During implementation, either warn and normalize if the category total is not 100%, or clamp authoring through editor tooling later. The first pass should at minimum `push_warning()` when a pile resource is misconfigured.

### Roll Order

Pile pulls should now roll in two stages:

1. Roll one category from the 3-way distribution: normal item, trash, or artifact.
2. If the category is artifact, roll from `artifact_loot_table` and return an artifact result.
3. If the category is trash, roll a trash sprite and return a trash result.
4. If the category is normal item, run the existing salvageable/non-salvageable pity roll.
5. Roll from `salvageable_loot_table` or `non_salvageable_loot_table` based on that sub-roll.

Only the normal item branch should interact with the salvageable pity counter:

- Salvageable normal item: reset pity.
- Non-salvageable normal item: increment pity.
- Trash: no pity change.
- Artifact: no pity change.

Artifact result dictionary:

```gdscript
{
	"item": artifact_item,
	"is_artifact": true,
	"is_trash": false,
	"is_salvageable": false,
}
```

Artifacts should use their own loot table so future artifact-specific resources can be added without mixing research items into the regular salvage tables.

### Initial Category Percentages

Use low debug-tunable values:

| Pile Rarity | Normal Item | Trash | Artifact |
| --- | ---: | ---: | ---: |
| Common | 24.0% | 75.0% | 1.0% |
| Rare | 48.0% | 50.0% | 2.0% |
| Epic | 76.5% | 20.0% | 3.5% |
| Legendary | 90.0% | 5.0% | 5.0% |

Each pile rarity resource should reference an artifact loot table containing `unknown_artifact.tres`. The table structure can be expanded later with distinct artifacts.

## Runtime Artifact Behavior

### `SalvageItem`

Add artifact helpers:

```gdscript
var is_artifact: bool:
	get:
		return item_data != null and item_data.is_artifact
```

Update:

- `get_rarity_color()` returns `SalvageItemData.ARTIFACT_COLOR` for artifacts.
- `get_display_name()` uses `item_data.item_name`, so artifacts show `Unknown Artifact`.
- `can_be_grabbed` returns false when the item is research-locked.

Add locked research state:

```gdscript
var _is_locked_for_research: bool = false

var is_locked_for_research: bool:
	get:
		return _is_locked_for_research
```

Add:

```gdscript
func lock_for_research(target_pos: Vector2, research_parent: Node = null) -> void
```

Expected behavior:

- Clear magnet/storage/falling/repel state.
- Set `_is_held_by_gun = false`.
- Set `_is_locked_for_research = true`.
- Clear any outline with `set_outlined(false)`.
- Reparent to the research station item root if supplied.
- Teleport to the table anchor global position.
- Disable collision shape.
- Freeze physics in kinematic mode.
- Set gravity and velocities to zero.
- Use a stable `z_index` that renders the artifact above/near the table.

Do not call `set_physics_process(false)` unless the item will only ever be consumed. Keeping physics process enabled but inert makes future "remove from station" behavior easier.

## Research Station Scene

Use the authored research station scene:

- `_project/ship/research_station.gd`
- `_project/ship/research_station.tscn`

Required scene shape:

```text
ResearchStation (Area2D, script ResearchStation)
├── AnimatedSprite2D
├── CollisionShape2D
├── UIAnchor (Marker2D)
├── ArtifactAnchor (Marker2D)
├── ResearchedItemsRoot (Node2D)
└── HighlightOutline (Line2D)
```

The station's `CollisionShape2D` is the placement area. `HighlightOutline` should be a white `Line2D` rectangle matching that shape.

### `ResearchStation` API

Signals:

```gdscript
signal artifact_placed(item: SalvageItem)
signal research_started(item: SalvageItem)
signal research_completed(item_data: SalvageItemData)
signal artifact_cleared(item_data: SalvageItemData)
```

Exports:

```gdscript
@export var debug_research_duration: float = 5.0
```

State:

```gdscript
var _current_artifact: SalvageItem = null
var _is_researching: bool = false
var _research_timer: Timer = null
```

Public methods:

```gdscript
func is_point_in_placement_area(global_point: Vector2) -> bool
func can_accept_item(item: SalvageItem) -> bool
func set_highlighted(enabled: bool) -> void
func place_artifact(item: SalvageItem) -> bool
func has_artifact() -> bool
func get_current_artifact() -> SalvageItem
```

`can_accept_item()` should require:

- The item is valid.
- The item is an artifact.
- The item is not already locked for research.
- The station has no current artifact.
- The station is not researching.

`place_artifact()` should:

1. Validate with `can_accept_item()`.
2. Store `_current_artifact = item`.
3. Call `item.lock_for_research($ArtifactAnchor.global_position, $ResearchedItemsRoot)`.
4. Hide highlight.
5. Emit `artifact_placed`.
6. Start debug research.

Debug research:

- Start a one-shot timer for `debug_research_duration`.
- Emit `research_started`.
- On timeout, emit `research_completed(_current_artifact.item_data)`.
- For this first pass, consume the artifact with `queue_free()` and clear `_current_artifact`, so the station can be tested repeatedly.
- Emit `artifact_cleared`.

## Ship Integration

Update `_project/ship/ship.tscn`:

- Instance `research_station.tscn` as a child of `Ship`.
- Position it over the existing research station/table art.
- Tune `CollisionShape2D` and `ArtifactAnchor` in editor.

Update `_project/ship/ship.gd`:

```gdscript
@onready var _research_station: ResearchStation = get_node_or_null("ResearchStation") as ResearchStation

func get_research_station_at_point(global_point: Vector2) -> ResearchStation
func can_accept_research_item(item: SalvageItem) -> bool
func place_research_item(item: SalvageItem) -> bool
func clear_research_station_highlight() -> void
```

`get_research_station_at_point()` should return the station only if the global point is inside the placement area.

If the table is missing, these methods should fail quietly and return `false`/`null`, matching the current defensive style in `Player`.

## Player Magnet-Gun Integration

Update `_project/player/player.gd`.

Add state:

```gdscript
var _hovered_research_station: ResearchStation = null
```

While holding an item and after it has reached the magnet-gun anchor:

1. Get mouse global position.
2. Ask the ship for a research station at that point.
3. If the held item is an artifact and the station can accept it, highlight the station.
4. Clear highlight when the mouse leaves, item is no longer held, item is not an artifact, or station cannot accept.
5. On left click, prefer research placement over storage if both zones overlap.
6. If placement succeeds, clear `_held_item`, repel state, and muzzle effect.

Suggested flow inside the existing held-item branch:

```gdscript
_process_research_station_hover(mouse_pos)

if Input.is_action_just_pressed("shoot"):
	if _try_place_held_item_on_research_station():
		return
	if ship_node and ship_node.is_point_in_storage_area(mouse_pos) and ship_node.can_accept_storage_item(_held_item):
		_place_item_in_storage(mouse_pos)
```

The current non-held item hover/tooltip system should not need special artifact logic beyond the `SalvageItem` color/name changes.

## Outline And Hover Rules

Artifact hovering in the world:

- Same as current salvage items.
- Tooltip text: `Unknown Artifact`.
- Tooltip color: artifact color.
- White item outline while hoverable.

Research table hovering:

- Only while the magnet gun is holding an artifact.
- Only after the artifact reaches the gun anchor.
- White table outline while placement is valid.

Placed artifact:

- No hover tooltip.
- No white item outline.
- Cannot be picked up by the magnet gun.
- No physics movement.
- Stays at the table anchor until debug research consumes it.

## Acceptance Criteria

1. Artifacts can be rolled from common, rare, epic, and legendary piles using data-driven chances.
2. Artifact rolls do not change the salvageable pity counter.
3. An artifact appears as a normal pullable `SalvageItem` with a distinct tooltip color.
4. Non-artifact items do not highlight the research station and cannot be placed on it.
5. Holding an artifact over the research station highlights the station in white.
6. Left-clicking while highlighted removes the artifact from the magnet gun and places it at the table anchor.
7. The placed artifact cannot be grabbed, hovered, outlined, repelled, or moved by physics.
8. After 5 seconds, the table emits completion, consumes the artifact, clears its internal reference, and can accept another artifact.
9. Existing storage placement still works for normal salvage items and artifacts when not placed on the research station.

## Suggested Implementation Order

1. Extend `SalvageItemData` with item kind and artifact color.
2. Add `unknown_artifact.tres`.
3. Extend `SalvagePileData` with artifact chance/table and update pile rarity resources.
4. Update `Magnet._spawn_item_from_pile()` so artifacts bypass pity changes.
5. Add artifact and research-lock behavior to `SalvageItem`.
6. Update `ResearchStation` scene/script.
7. Add the table instance and wrapper methods to `Ship`.
8. Add held-artifact table hover and placement to `Player`.
9. Run a smoke test from pile pull through table completion.

## Future Extension Points

- Replace debug timer with three ordered research minigame stages.
- Add `ResearchArtifactData` or unlock metadata once unlock design is ready.
- Persist discovered/researched artifacts in `AppSaveData`.
- Add a research station UI panel showing current stage/progress.
- Add completion effects, SFX, and item-specific reveal text.
