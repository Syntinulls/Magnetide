# Artifact Piles And Research Points Implementation Spec

## Overview

Artifacts are a special item type tied to the research system. They are recovered from a new artifact pile rarity during the magnet minigame, researched at the ship research station, and converted into research points. Research points are then spent in the station UI to unlock the next available upgrade or equipment item inside a linear unlock group.

This spec expands the existing `research_system_spec.md` and supersedes its earlier artifact acquisition rule where artifacts could appear as low-chance pulls inside normal salvage piles. Artifacts now come from artifact piles.

## Goals

- Add artifact piles as a new pile rarity/type in the run loot system.
- Make artifact piles smaller than normal salvage piles and structured around a guaranteed final artifact pull.
- Keep the pre-artifact phase dangerous by pulling trash and spawning enemies before the artifact appears.
- Convert completed artifact research into research points.
- Display research points in the station UI.
- Let players spend research points to unlock upgrades and equipment linearly within each unlock group.
- Refactor chance systems that currently depend on probabilities adding to `1.0` or `100.0` into unrestricted positive weight tables.

## Non-Goals

- No unique artifact-pile enemy types in the first pass. Artifact piles spawn the basic enemy for now.
- No final artifact art pass.
- No full research minigame redesign beyond awarding research points on completion.
- No branching unlock trees. Unlocks are linear inside their respective groups.
- No balancing-final research point economy. First-pass costs should be data-driven and easy to tune.

## Terminology

| Term | Meaning |
| --- | --- |
| Artifact | A special item that can be researched for research points. |
| Artifact pile | A new pile rarity/type that produces trash and enemies before yielding one final artifact. |
| Research points | A station progression currency earned by completing artifact research. |
| Unlock group | A linear progression lane such as weapons, ship upgrades, magnet upgrades, player upgrades, or future equipment families. |
| Weight | A positive decimal value used for relative random selection. Weights do not need to sum to `1.0` or `100.0`. |

## Artifact Item Rules

Artifacts remain `SalvageItem` instances at runtime so they can reuse magnet pulling, magnet-gun pickup, station placement, hover, outline, and item data behavior.

Artifact item data should include:

```gdscript
enum ItemKind { SALVAGE, ARTIFACT }

@export var item_kind: ItemKind = ItemKind.SALVAGE
@export var research_point_reward: int = 1
```

Rules:

- `item_kind == ARTIFACT` marks the item as researchable.
- `research_point_reward` is awarded only when research completes successfully.
- Artifacts should not break down into salvage components.
- Artifacts should not be processed by the salvage processing screen as normal salvage.
- Artifacts can use rarity for display, tuning, and table filtering, but artifact identity should override normal rarity tooltip color if the existing research spec color behavior is kept.

## Artifact Pile Behavior

Artifact piles are a new pile rarity/type, represented in code as either:

```gdscript
enum Rarity { COMMON, RARE, EPIC, LEGENDARY, ARTIFACT }
```

or, if implementation prefers separating rarity from behavior:

```gdscript
enum PileKind { SALVAGE, ARTIFACT }
```

The first pass should prefer the smallest change that fits the existing `SalvagePile.Rarity` and threat-weight flow. If artifact piles are authored as a rarity, they should still be handled by dedicated artifact-pile logic rather than normal salvage pile loot logic.

### Visual And Runtime Identity

Artifact piles should:

- be visibly smaller than normal salvage piles
- use a distinct placeholder sprite, tint, outline, or scale so they are readable during the run
- advertise their rarity/type to the activation minigame and threat system
- have their own pile data resource
- have their own weighted artifact loot table
- have their own trash pull count or pull sequence settings

### Pull Sequence

An artifact pile has a finite pull sequence:

1. The player completes the normal magnet activation flow for the pile.
2. Looting begins.
3. Until the final pull, every pull produces trash.
4. During the pre-artifact phase, enemies spawn from the artifact pile pressure rules.
5. The final pull produces exactly one artifact.
6. After the artifact is pulled, the artifact pile is exhausted and should not produce more items.

Recommended data:

```gdscript
@export_group("Artifact Pile")
@export var is_artifact_pile: bool = false
@export_range(0, 50, 1) var pre_artifact_trash_pulls: int = 4
@export var artifact_loot_table: LootTable = null
@export var artifact_enemy_spawn_profile: Resource = null
```

Implementation can use a fixed `pre_artifact_trash_pulls` first. A later pass can replace it with a weighted/min-max sequence length if the pacing needs variety.

### Timer And Abort Rules

Artifact piles should guarantee their artifact only if the player stays in the looting flow until the final pull.

- If the player aborts looting before the artifact pull, the artifact is lost with the pile.
- If the ship, magnet, or run fails before the artifact pull, no artifact is awarded.
- The departure timer should not cut off an artifact pile before its scripted final pull unless the player manually aborts or the run-ending condition fires.
- If keeping the existing timer is simpler for the first pass, artifact piles must tune their pull count and pull interval so the final artifact reliably appears before the timer expires.

The preferred implementation is for artifact piles to set a sequence-complete condition: once the final artifact is spawned, the pile marks itself exhausted and looting can end naturally or proceed into the existing post-loot flow.

### Enemy Pressure

Artifact piles create combat pressure before the artifact appears.

First pass:

- Spawn only the current basic enemy.
- Spawn enemies only while the artifact pile is actively being looted.
- Spawn enemies during trash pulls or on a timer during the pre-artifact phase.
- Do not spawn a unique enemy yet.

Future pass:

- Artifact piles may use unique enemy pools or scripted defenders.
- Enemy type can be selected from a weighted artifact enemy pool.
- Higher-value artifacts can increase enemy pressure or pre-artifact trash pulls.

Suggested first-pass hooks:

```gdscript
signal artifact_pile_pressure_started(pile: SalvagePile)
signal artifact_pile_pressure_ended(pile: SalvagePile)
signal artifact_pull_started(pile: SalvagePile)
signal artifact_pulled(item_data: SalvageItemData)
```

These allow the enemy spawner and UI to react without putting enemy ownership inside `SalvagePileData`.

## Research Completion And Research Points

The existing ship research station remains the place where artifacts are researched. The change is the reward on completion.

When research completes:

1. The station emits research completion with the artifact data.
2. The artifact's `research_point_reward` is read.
3. The player's persistent station/save state increments by that amount.
4. The artifact is consumed or marked researched according to the current research-station behavior.
5. The station UI refreshes its displayed research point total.

Suggested persistent state API:

```gdscript
var research_points: int = 0

func add_research_points(amount: int) -> void
func can_spend_research_points(amount: int) -> bool
func spend_research_points(amount: int) -> bool
```

Rules:

- Negative research point awards are invalid.
- Completing research on an artifact with `research_point_reward <= 0` should award `0` and warn in debug builds.
- Research points should persist across station visits and runs.
- Research points are not run loot and should not be affected by salvage processing.

## Station UI

Research points should be visible on the station screen as a core station currency.

Display rules:

- Show the current research point total in a persistent station UI area.
- The display should update immediately after research completes or points are spent.
- Use an icon or compact label that is readable alongside existing station resources.
- Avoid hiding research points only inside a popup. The player should be able to see the balance before opening unlock controls.

Possible first-pass label:

```text
RESEARCH: 12
```

If a dedicated icon exists later, the text can become icon plus value.

## Unlock Groups

Research points unlock the next available upgrade or equipment item in each group. Each group is linear and independent.

Example groups:

- weapons
- ship upgrades
- magnet upgrades
- player upgrades
- future equipment groups

Suggested data:

```gdscript
class_name ResearchUnlockGroupData
extends Resource

@export var group_id: StringName
@export var display_name: String
@export var entries: Array[ResearchUnlockEntryData]
```

```gdscript
class_name ResearchUnlockEntryData
extends Resource

@export var unlock_id: StringName
@export var display_name: String
@export var research_point_cost: int = 1
@export var target_resource: Resource = null
@export var target_upgrade_id: StringName
@export var starts_unlocked: bool = false
```

Persistent state should track:

```gdscript
var unlocked_research_ids: Array[StringName] = []
```

Rules:

- The first locked entry in a group is the only purchasable entry in that group.
- Later entries in the same group remain locked even if the player has enough research points.
- Earlier locked entries must be purchased first.
- Entries with `starts_unlocked == true` are available by default and do not block later entries.
- Unlocking equipment makes it available to equip or purchase according to the existing station equipment rules.
- Unlocking an upgrade makes the next upgrade level or upgrade row available according to the existing station upgrade rules.

## Unlock Button Behavior

Unlockable upgrades and equipment should show the required research point cost inside the unlock button.

Button text examples:

```text
UNLOCK 3 RP
```

```text
3 RP
```

Rules:

- The button is enabled only for the next locked entry in its group and only when the player has enough research points.
- If the entry is not next in its group, the button is disabled and should communicate that an earlier unlock is required.
- If the entry is next but the player lacks points, the button is disabled or uses the existing unaffordable styling.
- On click, call `spend_research_points(cost)`.
- If spending succeeds, mark the entry unlocked, refresh the station UI, and update equipment/upgrade availability.
- If spending fails, leave state unchanged.

The cost displayed in the button must be the research point cost, not a generic credit or salvage material cost.

## Weighted Chance Refactor

The project should migrate chance systems to relative weights.

### Weight Definition

Each authored outcome should have a positive decimal weight:

```gdscript
@export_range(0.001, 999999.0, 0.001) var weight: float = 1.0
```

The effective probability of an outcome is:

```text
outcome_probability = outcome_weight / sum(all_valid_outcome_weights)
```

This means designers can edit one outcome's raw weight without having to rebalance a table to sum to `1.0` or `100.0`. Normalized probabilities still change at roll time because every probability is relative to the current total.

### Invalid Weights

Rules:

- Authored weights should be positive.
- Entries with missing, zero, negative, `NaN`, or infinite weights are invalid.
- Invalid entries should be ignored for the roll and should emit a debug warning identifying the owning table/resource.
- If all entries are invalid, return a safe fallback and warn.

For systems that currently use omitted entries to mean unavailable, omit the entry instead of authoring `0`.

### Shared Weighted Roll Helper

Add a shared helper instead of duplicating weighted-roll code across systems.

Suggested location:

```text
_project/utils/weighted_random.gd
```

Suggested API:

```gdscript
static func roll_weighted(entries: Array, get_weight: Callable, rng: RandomNumberGenerator = null) -> Variant
static func get_total_weight(entries: Array, get_weight: Callable) -> float
static func get_probability(weight: float, total_weight: float) -> float
```

The helper should:

- filter invalid weights
- sum valid weights
- roll a random value from `0.0` to `total_weight`
- walk the valid entries cumulatively
- return the selected entry

### Systems To Migrate

Refactor all game loot/probability systems that currently assume probabilities must add to a fixed total.

Required pass:

| System | Current Concept | New Concept |
| --- | --- | --- |
| Pile rarity selection | common/rare/epic/legendary chance or fixed-sum weights | common/rare/epic/legendary/artifact relative weights |
| Salvage pile category selection | normal/trash/artifact percentages totaling `100` | category relative weights |
| Salvageable vs non-salvageable | percent/pity roll | two relative weights after pity modifies the salvageable weight |
| Salvage item loot tables | `chance` or rarity drop chance | relative `weight` |
| Trash/non-trash outcomes | percent chance | relative weights |
| Salvage/non-salvage outcomes | percent chance | relative weights |
| Artifact pile selection | not present | artifact pile relative weight in pile rarity table |

Enemy spawning already uses weighted entries in current specs/code and should be checked for compatibility with the shared helper, but it does not need behavior changes unless its implementation rejects non-fixed totals.

### Pile Rarity Weights

Threat level pile tables should gain artifact pile weight:

```gdscript
@export var common_weight: float = 0.0
@export var rare_weight: float = 0.0
@export var epic_weight: float = 0.0
@export var legendary_weight: float = 0.0
@export var artifact_weight: float = 0.0
```

The active pile rarity selection table is the current threat level's weights. Artifact piles become more or less common by changing only `artifact_weight`.

No table needs to add to `1.0`, `100.0`, or any other fixed total.

### Category Weights

Normal salvage piles should replace percent category fields with weights:

```gdscript
@export_group("Pull Category Weights")
@export var salvage_pull_weight: float = 1.0
@export var trash_pull_weight: float = 1.0
```

Artifact piles should not use the same normal category roll. Their pull sequence is scripted:

- pre-artifact pulls: trash
- final pull: artifact

If a future artifact pile needs varied pre-artifact rewards, it can add an artifact-pile-specific weighted prelude table.

### Salvageable Pity As Weight Modifier

The existing salvageable pity system can remain, but it should output a relative weight adjustment instead of requiring a final percent.

Recommended first-pass conversion:

```gdscript
salvageable_weight = base_salvageable_weight + (pull_count * salvageable_increment_weight)
salvageable_weight = minf(salvageable_weight, salvageable_max_weight)
non_salvageable_weight = base_non_salvageable_weight
```

Then roll between:

- salvageable
- non-salvageable

This preserves the current pity behavior while removing the requirement that the final result be a percentage.

## Data Migration Notes

Existing fields with names like `chance`, `percent`, or values expected to total `100.0` should be renamed where practical.

Preferred naming:

- `chance` -> `weight`
- `normal_item_percent` -> `salvage_pull_weight`
- `trash_percent` -> `trash_pull_weight`
- `artifact_percent` -> remove from normal piles, replaced by artifact pile rarity weight
- `salvageable_base_percent` -> `base_salvageable_weight`
- `salvageable_increment_percent` -> `salvageable_increment_weight`
- `salvageable_max_percent` -> `salvageable_max_weight`
- `trash_scrap_chance_percent` -> `trash_scrap_weight` plus an explicit `no_scrap_weight`

Compatibility can be temporary:

- Keep old exported fields for one migration pass if needed.
- Convert old percent values into starting weights by copying the same number.
- Remove validation that requires totals to equal `100`.
- Add warnings when old fields are used after the new fields exist.

## Affected Files

Likely implementation touch points:

| File | Change |
| --- | --- |
| `_project/items/salvage_item_data.gd` | Add or confirm artifact item kind and `research_point_reward`. |
| `_project/level/salvage/pile/salvage_pile_data.gd` | Add artifact pile sequence data and migrate category fields to weights. |
| `_project/level/salvage/salvage_spawner.gd` | Add artifact pile selection through rarity/type weights. |
| `_project/level/threat/threat_level_data.gd` | Add artifact pile weight to threat rarity tables. |
| `_project/ship/magnet/minigame/magnet_minigame.gd` | Handle artifact pile completion, final artifact pull, and timer behavior. |
| `_project/ship/magnet/magnet.gd` | Support artifact pile pull sequence and avoid normal salvage pity changes for artifact-pile trash/final artifact pulls. |
| `_project/level/enemies/enemy_spawner.gd` | Listen for artifact pile pressure or expose a method for basic enemy pressure during artifact piles. |
| `_project/ship/research_station.gd` | Award research points when artifact research completes. |
| `_project/app/save_data` or equivalent | Persist research points and unlocked research IDs. |
| `_project/app/screens/station_screen.gd` | Display research points and wire unlock buttons. |
| `_project/player/equipment/equipment_catalog_entry.gd` | Add research unlock metadata for equipment entries if this remains the equipment catalog source. |
| `_project/utils/weighted_random.gd` | Shared weighted random helper. |

## Suggested Implementation Order

1. Add the shared weighted random helper and unit/smoke tests for positive decimal weights.
2. Migrate pile rarity selection to the helper and add artifact pile weight to threat level data.
3. Add artifact pile data and placeholder artifact pile resource.
4. Replace normal pile category percent validation with weight-based category selection.
5. Implement artifact pile pull sequence: trash pulls, enemy pressure, final artifact pull, exhausted state.
6. Add `research_point_reward` to artifact item data.
7. Add research point storage and persistence to the app/save state.
8. Award research points from research station completion.
9. Display research points in the station UI.
10. Add linear research unlock group data and state.
11. Update station unlock buttons to show required research points and spend them.
12. Run a pass for remaining fixed-total chance systems and migrate them to weights.

## Acceptance Criteria

1. Artifact piles can be selected from the same pile-spawn flow as other pile rarities using relative weights.
2. Pile rarity weights do not need to add to `1.0` or `100.0`.
3. Artifact piles are visually smaller than normal piles.
4. Artifact piles pull only trash before the final artifact pull.
5. Artifact piles spawn basic enemies during the pre-artifact phase.
6. The final pull from an artifact pile always produces exactly one artifact if the player stays in the looting flow.
7. Artifact-pile trash and artifact pulls do not modify the normal salvageable pity counter.
8. Completing research on an artifact awards that artifact's configured research points.
9. Research point total persists and is visible on the station screen.
10. Unlock buttons show their required research point cost inside the button.
11. Each unlock group only allows the next locked entry to be unlocked.
12. Spending research points on an unlock subtracts the cost, marks the entry unlocked, and refreshes station UI state.
13. Increasing or decreasing one outcome's weight does not require editing the other outcomes to keep a fixed total.
14. All migrated weighted-roll systems ignore invalid weights and warn instead of crashing.

## Open Questions

1. Should artifact piles appear at every threat level, or only after a minimum threat level?
2. Should artifact pile chance increase with threat, difficulty, biome, or run duration?
3. Should researching duplicate artifacts award the full research point value, a reduced value, or no value after first discovery?
4. Should research points unlock upgrade access only, or should they also pay for the upgrade/equipment itself?
5. Should artifact pile enemy pressure be timer-based, pull-based, or both?
