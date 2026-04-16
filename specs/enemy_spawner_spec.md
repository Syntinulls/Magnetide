# Enemy Spawner Specification

## Overview

This spec defines the first implementation of the enemy spawner system for Magnetide.

The current project already has:

- A working `Enemy` base scene and `EnemyData`
- Threat progression through `ThreatManager`
- An authored ring of level spawn zones under `Level/SpawnZones`

What it does not have yet is the system that turns threat and magnet state into actual enemy waves. This document defines that system.

---

## Design Goals

1. Keep enemy pressure driven by threat, not by hand-authored scripted encounters.
2. Make spawn direction readable by using the existing authored spawn zones around the play space.
3. Let magnet use change enemy composition immediately without needing a separate encounter system.
4. Keep spawn rules data-driven so new enemy types can be added without rewriting the spawner.
5. Support larger batches at higher threat without losing randomness.

---

## Authored Requirements

The following requirements come directly from the design notes and should be treated as the default intended behavior.

### Spawn Zones

- The level exposes a predefined set of enemy spawn zones.
- The enemy spawner may only spawn enemies inside those predefined zones.
- Each enemy type has its own allowed-zone list.
- An enemy can only spawn in zones that appear in its allowed-zone list.

### Threat-Driven Spawn Timer

- Threat level determines the global enemy spawn timer.
- The spawner runs one shared countdown, not a separate timer per enemy type.
- When that timer reaches `0`, the spawner performs one spawn selection pass and then resets the timer for the current threat level.

### Threat-Driven Enemy Pools

- The enemy selected on a spawn pass comes from a weighted enemy pool.
- The active pool depends on:
  - the current threat level
  - whether the magnet is in use
- Each threat level has two unique weighted pools:
  - one for magnet-active play
  - one for magnet-idle play

### Batch Size Rules

- Each enemy type has a maximum batch size that can vary by threat level.
- Example:
  - a worm may have max batch size `1` at threat level 1
  - that same worm may have max batch size `3` at threat level 2
- Batch size is a maximum, not a guaranteed count.
- When a batch is spawned, the actual count is a random integer from `1` to the current max batch size.

### Batch Count Rules

- Threat level also determines the maximum number of batches spawned on a single spawn pass.
- Example:
  - threat level 1 may allow a max batch count of `1`
  - threat level 3 may allow a max batch count of `3`
- Batch count is also a maximum, not a guaranteed count.
- When the global spawn timer expires, the spawner rolls a random batch count from `1` to the current threat level's max batch count.
- Each rolled batch repeats the normal spawn process:
  - choose an enemy type from the active weighted pool
  - choose a valid zone for that enemy type
  - roll that enemy type's batch size
- Batches spawned on the same pass may use:
  - the same enemy type or different enemy types
  - the same spawn zone or different spawn zones
- Each batch is resolved independently.

---

## Current Project Context

### Existing Spawn Zones

`_project/level/level.tscn` already contains a `SpawnZones` node with 16 authored `Area2D` children:

- `SpawnN`
- `SpawnNNE`
- `SpawnNE`
- `SpawnENE`
- `SpawnE`
- `SpawnESE`
- `SpawnSE`
- `SpawnSSE`
- `SpawnS`
- `SpawnSSW`
- `SpawnSW`
- `SpawnWSW`
- `SpawnW`
- `SpawnWNW`
- `SpawnNW`
- `SpawnNNW`

These should be treated as the canonical first-pass spawn zone set.

For the implementation, these zones should be assigned into an exported array on the enemy spawner root node rather than discovered implicitly at runtime from `Level/SpawnZones`.

### Existing Threat State

The current `ThreatManager` already exposes threat progression and a five-step internal threat index. The enemy spawner should read the active threat stage from `ThreatManager` and use that stage to:

- reset the global spawn timer
- resolve the number of batches to spawn on that pass
- choose the active weighted pool
- resolve each selected enemy's max batch size

### Existing Magnet State

The current `Magnet` node already exposes `is_active`. For the first implementation, "magnet in use" should mean:

- `Magnetide.magnet` exists
- `Magnetide.magnet.is_active == true`

If the magnet is missing, the spawner should treat the magnet as idle.

---

## Ownership Boundary

### ThreatManager Owns

- Current threat value
- Current threat level / stage index
- Signaling when threat changes

### EnemySpawner Owns

- Spawn timer countdown
- An exported spawn-zone array and zone-name lookup table
- Random point selection inside a chosen zone
- Enemy pool definitions
- Magnet-active versus magnet-idle pool selection
- Per-threat batch-count rules
- Per-enemy allowed-zone restrictions
- Per-enemy per-threat batch sizes
- Enemy scene instantiation
- Tracking living spawned enemies

Threat tells the spawner the current danger stage. The spawner decides what that stage means for enemy composition and cadence.

---

## Core Runtime Model

### 1. Global Countdown

The spawner maintains a single countdown timer:

- It decreases while the run is active.
- Its reset value is determined by the current threat level.
- If threat changes while the timer is running, the timer does not need to be recalculated immediately.
- The new threat level takes effect the next time the timer resets after a spawn attempt.

This keeps the system predictable and avoids timer jitter from small timing changes during a countdown.

### 2. Pool Resolution

When the timer reaches `0`, the spawner:

1. Reads the current threat stage.
2. Checks whether the magnet is active.
3. Selects the threat stage's matching weighted pool:
   - `magnet_active_pool`
   - `magnet_idle_pool`

### 3. Enemy Type Selection

The spawner performs a weighted roll against the active pool.

- Higher weight means a higher chance to be selected.
- Entries with weight `0` are ignored.
- Entries that cannot currently produce a valid spawn should be skipped and rerolled if possible.

An entry is invalid for the current spawn attempt if:

- it has no enemy definition
- it has no valid allowed spawn zones in the current level
- its max batch size for the current threat stage is `<= 0`

If no valid entries remain after filtering, the spawn attempt fails cleanly and the timer still resets.

### 4. Spawn Zone Resolution

After an enemy type is selected:

1. Read that enemy type's allowed-zone name list.
2. Resolve those names against the enemy spawner's exported spawn-zone array.
3. Choose one valid zone at random.
4. Spawn the entire batch from that zone.

For the first implementation, one spawn batch should come from one chosen zone. Each enemy in that batch may get its own random point inside the chosen zone.

### 5. Batch Size Resolution

After an enemy type is selected:

1. Read that enemy type's max batch size for the current threat stage.
2. Roll a random count from `1` to that max.
3. Spawn that many enemies.

If later pressure controls require limiting the total number of living enemies, the spawner may clamp the final count before instancing.

### 6. Batch Count Resolution

When the timer reaches `0`, the spawner should first resolve how many batches to spawn on that pass:

1. Read the current threat stage's max batch count.
2. Roll a random number from `1` to that max.
3. Repeat the normal pool-selection and zone-selection flow once per batch.

This means a single timer expiration can produce multiple batches, with each batch remaining small and readable on its own.

---

## Zone Selection Rules

### Zone Identity

For the first pass, zone identity should be based on the actual node names of the `Area2D` zones assigned to the enemy spawner, such as `SpawnN` or `SpawnSW`.

Enemy definitions should reference zones by those names.

This is preferred over a duplicated enum or direct node references inside enemy resources because:

- the spawner owns the final list of valid spawn zones for the level
- the level already has stable authored names
- it avoids keeping scene nodes and code enums in sync
- enemy spawn data can stay readable in the inspector

### Zone Sampling

Each spawn zone is an `Area2D` with a collision shape. The spawner should:

- resolve the zone node by name
- sample a random point inside that zone's collision shape
- use that point as the enemy's spawn position

The first implementation only needs to support the currently used rectangle-shaped zones in `level.tscn`.

### Invalid Zones

If an enemy type references a zone name that does not exist in the enemy spawner's exported zone array:

- that zone is ignored
- the spawn definition remains valid if at least one other allowed zone resolves successfully

If no allowed zones resolve, that enemy type is invalid for that spawn attempt.

---

## Data Model

The spawner should own its own authored resources rather than continuing to use the temporary enemy placeholders currently sitting on `ThreatLevelData`.

### EnemySpawnDefinition (new Resource)

One resource per spawnable enemy archetype.

Suggested fields:

```gdscript
extends Resource
class_name EnemySpawnDefinition

@export var id: StringName
@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData
@export var allowed_spawn_zones: PackedStringArray = PackedStringArray()
@export var max_batch_sizes_by_threat: PackedInt32Array = PackedInt32Array([1, 1, 1, 1, 1])
```

Notes:

- `enemy_scene` allows future enemies to use custom scenes if needed.
- `enemy_data` lets the spawner assign the correct stats/behavior resource on spawn.
- `allowed_spawn_zones` should contain zone names like `SpawnN` and `SpawnSE`.
- These names should match the names of zones assigned to the enemy spawner's exported zone array.
- `max_batch_sizes_by_threat` is indexed by threat stage `0-4`.

### WeightedEnemySpawnEntry (new Resource)

One weighted entry inside a threat-level pool.

```gdscript
extends Resource
class_name WeightedEnemySpawnEntry

@export var enemy: EnemySpawnDefinition
@export_range(0.0, 9999.0, 0.1) var weight: float = 1.0
```

### EnemySpawnThreatLevelData (new Resource)

One resource per threat stage.

```gdscript
extends Resource
class_name EnemySpawnThreatLevelData

@export var spawn_interval_seconds: float = 10.0
@export var max_batches_per_spawn: int = 1
@export var magnet_active_pool: Array[WeightedEnemySpawnEntry] = []
@export var magnet_idle_pool: Array[WeightedEnemySpawnEntry] = []
@export var max_concurrent_enemies: int = 0
```

`max_concurrent_enemies` is included as a practical safety valve for the implementation pass. If we decide not to enforce it immediately, the field can remain authored but unused until pressure tuning begins.

### EnemySpawnerProfile (new Resource)

Top-level resource for the spawner.

```gdscript
extends Resource
class_name EnemySpawnerProfile

@export var levels: Array[EnemySpawnThreatLevelData] = []
```

The first implementation should normalize this array to exactly five entries, matching the existing threat system.

### EnemySpawner Node Configuration

The runtime spawner node should expose its usable zones directly.

Suggested fields:

```gdscript
@export var spawn_zones: Array[Area2D] = []
@export var profile: EnemySpawnerProfile
```

At runtime, the spawner should build a lookup from `zone.name` to `Area2D` using this exported array.

This keeps level-specific zone wiring on the spawner scene/node, while enemy resources remain portable and only depend on zone names.

---

## Spawn Flow

Recommended runtime flow for one spawn attempt:

1. Countdown reaches `0`.
2. Read the current threat stage from `ThreatManager`.
3. Resolve whether the magnet is active.
4. Read that threat stage's `max_batches_per_spawn`.
5. Roll an actual batch count from `1..max_batches_per_spawn`.
6. For each batch:
7. Choose the matching pool for that threat stage.
8. Filter out invalid pool entries.
9. Roll one enemy type by weight.
10. Resolve that enemy type's allowed zone names against the spawner's exported zone array.
11. Choose one valid zone at random.
12. Read the max batch size for the threat stage.
13. Roll an actual enemy count from `1..max_batch_size`.
14. Clamp to remaining enemy capacity if concurrent limits are enabled.
15. Instance the chosen enemy scene for each spawn in the batch.
16. Assign its `EnemyData`.
17. Place each enemy at a sampled point inside the chosen zone.
18. Track the spawned enemies until they die or are freed.
19. Reset the global timer using the current threat stage's `spawn_interval_seconds`.

---

## Tracking Living Enemies

The spawner should maintain a living-enemy list for enemies it spawned.

Recommended rules:

- Add each spawned enemy to a tracked array.
- Remove it when the enemy emits `died` or when the instance is freed.
- Ignore manually placed debug enemies unless they are intentionally registered with the spawner.

This lets the spawner support `max_concurrent_enemies` cleanly without needing to query the entire scene tree every frame.

---

## Integration Notes

### Level Integration

The first implementation should add a dedicated enemy spawner node to `Level`.

It should own:

- `ThreatManager`
- an exported `spawn_zones` array populated from the authored level zones
- optionally the current magnet through `Magnetide.magnet`

The manually placed test `Enemy` in `level.tscn` should eventually be removed once the spawner is active.

### Threat Integration

This spec supersedes the temporary enemy placeholders currently living on `ThreatLevelData`:

- `enemy_count`
- `enemy_types`

Those values were always marked as placeholders and should not become the long-term source of truth for enemy spawning.

### Enemy Integration

The spawner should not own combat behavior. It only:

- decides which enemy archetype appears
- picks where it appears
- decides how many batches to resolve on that timer expiration
- decides how many instances appear in the batch

The spawned enemy's `EnemyData` continues to own combat stats and targeting behavior.

---

## File Impact

### Existing Files To Update

| File | Change |
|---|---|
| `_project/level/level.tscn` | Add the new enemy spawner node and eventually remove the one-off placed test enemy |
| `_project/level/level.gd` | Optional helper accessors if the spawner needs level-owned references |
| `_project/level/threat/threat_level_data.gd` | Remove or leave deprecated the temporary enemy placeholders |
| `_project/enemies/enemy.gd` | No behavior change required for spawning itself, but it should remain signal-compatible for spawner tracking |

### New Files Expected

| File | Purpose |
|---|---|
| `_project/level/enemies/enemy_spawner.gd` | Runtime spawner node |
| `_project/level/enemies/enemy_spawner_profile.gd` | Top-level resource for five threat stages |
| `_project/level/enemies/enemy_spawn_threat_level_data.gd` | Per-threat-level spawn rules |
| `_project/level/enemies/weighted_enemy_spawn_entry.gd` | Weighted pool entry |
| `_project/level/enemies/enemy_spawn_definition.gd` | Spawn-time data for one enemy archetype |

The exact folder can change, but the spawner should live under level/run systems rather than inside `_project/enemies/`, because it is a director/controller, not an enemy behavior.

---

## Recommended First Implementation Order

1. Create the spawner resources and normalize them to five threat stages.
2. Add the enemy spawner node with an exported `spawn_zones` array wired to the authored level zones.
3. Implement weighted pool selection for magnet-active and magnet-idle states.
4. Implement threat-based batch-count lookup and random batch roll.
5. Implement enemy batch size lookup and random per-batch enemy count roll.
6. Resolve allowed zone names against the spawner's exported zone array.
7. Spawn enemies into sampled points inside the selected zone.
8. Track living spawned enemies.
9. Add optional concurrent-enemy enforcement.
10. Replace the manually placed test enemy with authored spawner data.

---

## Resolved Decisions

1. The spawner uses the authored `SpawnZones` already present in `level.tscn`.
2. The enemy spawner root node owns an exported array of usable spawn zones.
3. Enemy types reference allowed spawn zones by name.
4. Threat level controls one global spawn timer.
5. Each threat level has two separate weighted pools: magnet-active and magnet-idle.
6. Each timer expiration can resolve one or more batches.
7. Each threat level also defines a maximum number of batches to spawn on a single timer expiration.
8. Actual batch count is random from `1` to the current threat level's maximum batch count.
9. Each spawned batch independently chooses its enemy type and spawn zone.
10. Each enemy type has a per-threat maximum batch size.
11. Actual spawned enemy count in a batch is random from `1` to that batch's current maximum batch size.
12. A single batch comes from one chosen spawn zone.

---

## Open Questions

These do not block implementation, but they are worth keeping visible:

1. Should the global spawn timer pause during cutscenes, activation slowdown, or other run interruptions, or only during a fully paused game state?
2. Should a failed spawn attempt because of concurrent-enemy cap still reset the timer normally, or retry sooner with a shorter fallback delay?
3. Should future spawn zones support weighted selection, or is uniform random among an enemy's valid zones enough?
