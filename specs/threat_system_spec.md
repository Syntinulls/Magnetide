# Threat System Specification

## Overview

The threat system is the run-level pressure director for Magnetide. Threat rises over the course of a run and controls:

- How many enemies can be active
- Which enemy types are allowed to spawn for the current difficulty
- Which salvage pile rarities can appear
- How likely rarer piles are to appear
- Which weather conditions are allowed or forced

The current project already has a threat bar UI and a placeholder `ThreatManager`, but neither currently drives gameplay. This spec defines the first full implementation of the system.

---

## Design Goals

1. Make every run escalate naturally without needing scripted waves.
2. Reward greed by increasing rewards and risk together.
3. Keep the threat bar readable: players should understand that more time, more magnet use, and greedier loot choices push the run into more dangerous states.
4. Use threat as a single source of truth for salvage rarity, enemy pressure, and weather.

---

## Core Model

### Threat Score

- Threat is a continuous run-level value from `0.0` to `100.0`.
- Threat never decays during a run.
- Threat resets only when a new run starts.
- Reaching `100.0` locks the run at maximum threat pressure until the run ends.

### Threat Levels

- Player-facing threat levels are **Level 1** through **Level 5**.
- Internally, code may still use a zero-based stage index (`0` to `4`) for arrays, UI assets, and existing data.
- Mapping:

| Threat Score | Level | Internal Stage Index |
|---|---|---|
| `0.0 - 24.999` | 1 | 0 |
| `25.0 - 49.999` | 2 | 1 |
| `50.0 - 74.999` | 3 | 2 |
| `75.0 - 99.999` | 4 | 3 |
| `100.0` | 5 | 4 |

### Threat Outputs

At all times, the active threat level determines:

- Enemy spawn profile
- Enemy type unlocks
- Pile rarity weights
- Available weather profile
- UI presentation for the current danger band

Threat does not directly spawn enemies or piles by itself. It provides the active ruleset that other run systems query.

---

## Threat Gain Sources

Threat increases from four sources:

| Source | Behavior | Notes |
|---|---|---|
| Time passing | Passive gain over the entire run | Always active while the run is live |
| Activating the magnet | Flat gain when a looting window begins | Represents noise/risk created by the ship magnet |
| Rarer piles | Additional gain based on the rarity of the currently looted pile | Applied on top of the base magnet activation gain |
| Special loot pickups | Some items add extra threat when collected | Example: alien eggs or similar volatile loot |

### Rules

1. Time-based threat is continuous and applies even while the magnet is idle.
2. Magnet threat is applied when looting actually begins, not when a pile merely spawns on screen.
3. Pile rarity threat is based on the rarity of the pile currently being looted.
4. Special loot threat is applied when the item is successfully collected into the ship/inventory, not when it merely appears.

### Tuning Ownership

Exact numeric gains should be data-driven and editable in inspector/resources, not hardcoded into gameplay scripts. The first implementation should expose at least:

```gdscript
@export var passive_threat_per_second: float
@export var magnet_activation_threat: float
@export var common_pile_threat_bonus: float
@export var rare_pile_threat_bonus: float
@export var epic_pile_threat_bonus: float
@export var legendary_pile_threat_bonus: float
```

For special loot, `SalvageItemData` should gain:

```gdscript
@export var threat_on_collect: float = 0.0
```

Most items stay at `0.0`. Only special risk items set this above zero.

---

## Threat Level Rules

The following level behaviors come directly from the design notes and should be treated as the authored defaults.

### Level 1

- Only the basic enemy type may spawn
- Enemies spawn only during active magnet looting
- Lowest enemy spawn rate
- Pile rarity split:
  - Common `95`
  - Rare `5`

### Level 2

- Unlock the next enemy type
- Enemies still spawn only during active magnet looting
- Spawn rate increases slightly
- Pile rarity split:
  - Common `85`
  - Rare `15`

### Level 3

- Unlock a new enemy type
- Enemies can now spawn even when the magnet is not active
- Spawn rate increases
- Pile rarity split:
  - Common `70`
  - Rare `20`
  - Epic `10`

### Level 4

- Unlock a new enemy type
- Spawn rate increases again
- Pile rarity split:
  - Common `60`
  - Rare `25`
  - Epic `13`
  - Legendary `2`

### Level 5

- Unlock a new enemy type
- Highest sustained spawn rate
- Pile rarity split:
  - Rare `70`
  - Epic `22`
  - Legendary `8`
- Common piles no longer appear

### Notes

- These pile values are weights, not guaranteed percentages after later filtering.
- If a rarity is omitted for a level, its weight is `0`.
- Enemy count and exact spawn timing remain tuned by data, but the unlock rules above are fixed design behavior.

---

## Enemy Spawning

### Purpose

Threat determines when the run is in a more dangerous state, but the actual enemy spawn profile is owned by the upcoming enemy spawner system. `ThreatManager` should not contain enemy pools, spawn timers, or enemy composition data.

### Ownership Boundary

- `ThreatManager` owns:
  - Current threat score
  - Current threat level
  - Signals when the threat level changes
- The enemy spawner owns:
  - Enemy pool definitions
  - Spawn cadence rules
  - Max concurrent enemy rules
  - Whether a given threat level allows idle spawning or magnet-only spawning
  - The actual enemy instantiation logic

Threat provides the current level. The enemy spawner decides what that level means for enemies.

### Enemy Spawner Responsibilities

- Track current living enemy count
- Ask `ThreatManager` for the active threat level
- Read its own authored spawn profile for that level
- Spawn from the set of enemy types unlocked for the current run difficulty and threat level
- Respect separate rules for:
  - Magnet-active spawns
  - Idle/background spawns

### Required Per-Level Enemy Profile Data

The enemy spawner system should define the following per threat level:

```gdscript
- max_concurrent_enemies: int
- allow_spawns_while_magnet_idle: bool
- magnet_spawn_interval_min: float
- magnet_spawn_interval_max: float
- idle_spawn_interval_min: float
- idle_spawn_interval_max: float
- enemy_pool: Array[WeightedEnemyEntry]
```

### Behavior Rules

1. Levels 1-2 only allow enemy spawning during magnet use.
2. Levels 3-5 allow spawning both during magnet use and during general run traversal.
3. Higher levels increase both allowed enemy variety and sustained pressure.
4. Threat chooses the roster. Run difficulty can still further modify counts/weights later.

### Difficulty Integration

The design notes call out "the enemies that will spawn (for that Difficulty)." To support that cleanly:

- Threat level should choose a stage within the active enemy spawner difficulty profile.
- The first implementation only needs one authored difficulty profile if no difficulty selector exists yet.
- The data layout should still support future difficulty variants without rewriting the threat system.

### Dependency Note

The enemy spawner system is the next feature planned after this threat spec. This threat spec should therefore treat enemy spawning as an external dependency:

- Threat must expose a reliable current level/state API for the enemy spawner to read
- The enemy spawner will define the enemy pool and enemy-specific threat rules for each level
- Threat implementation does not need to solve final enemy spawning authoring on its own

---

## Salvage Pile Rarity Selection

Threat controls which pile rarities may spawn and how often they appear.

### Rules

1. Salvage pile rarity is selected using the active threat level's weight table.
2. The current threat level is evaluated when a new pile is spawned for the run.
3. Higher threat levels shift the table toward rarer piles.
4. Level 5 removes Common piles entirely.

### Spawner Integration

The existing `SalvageSpawner` currently owns static rarity weights. That should be refactored so that:

- `ThreatManager` exposes the current rarity table
- `SalvageSpawner` queries those weights each time it needs to pick a pile rarity
- `MagnetMinigame` no longer uses its own fallback rarity table except as emergency debug fallback

### Rarity Bonus Threat

When a looting window begins, threat gain should be:

```text
magnet activation threat + rarity bonus for the active pile
```

This preserves the design goal that greedier salvage opportunities push the run forward faster.

---

## Weather System

### Scope

Threat owns weather eligibility, but weather effects should be applied by a separate controller so visuals, damage-over-time, and status effects stay isolated from threat bookkeeping.

### Initial Weather Set

The first full threat implementation only needs to support:

- `Clear`
- `Acid Rain`

### Acid Rain

Acid Rain is a run-ending pressure state.

- It slowly damages both the Ship and the Player over time.
- It lasts indefinitely once started.
- It does not expire naturally.
- It remains active until the run ends.

### Overtime Rule

When the run enters **Overtime**, Acid Rain is forced on immediately and remains active until run end.

This is not an optional weather roll. It is a hard state transition.

### Weather Selection Rule Before Overtime

Threat levels may define a weather pool, but for the initial implementation the authored default should remain effectively calm before Overtime unless additional weather types are introduced later.

That means:

- Levels 1-5 can expose weather data
- Pre-overtime authored defaults may simply resolve to `Clear`
- Overtime always overrides the current weather to `Acid Rain`

### Damage Tuning

Acid Rain damage values should be data-driven:

```gdscript
@export var player_damage_per_second: float
@export var ship_damage_per_second: float
```

---

## Overtime and Run Flow Integration

### Important Integration Clarification

The current project has a **departure timer** inside `magnet_minigame.gd`, but it does not yet have a broader run-level Overtime system. Right now, the looting window simply ends when the departure timer expires.

The threat system needs a run-level signal or controller for:

```gdscript
signal overtime_started()
signal run_started()
signal run_ended()
```

### Required Contract

1. Threat resets on `run_started`.
2. Passive threat gain begins on `run_started`.
3. Acid Rain is forced on when `overtime_started` fires.
4. All threat accumulation and weather damage stop on `run_ended`.

### Interim Implementation Guidance

If a separate run controller does not exist yet, the first implementation may temporarily let `Level` or `MagnetMinigame` emit these events. The contract above is the important part.

---

## UI Behavior

The existing threat bar UI should become a real readout for gameplay state, not just a fill meter.

### Current UI Assets

The scene already contains:

- A vertical bar
- A ticker
- Five level icons

### Required UI Behavior

1. Fill amount reflects current threat score from `0.0` to `100.0`.
2. Ticker position reflects the exact score, not just whole levels.
3. Active level color updates when the level changes.
4. The icon matching the current level should be visually emphasized.
5. Optional polish:
   - brief pulse on level-up
   - subtle shake or flash on large threat spikes

### Level Numbering

Because the art is currently arranged as five icons indexed `0-4`, UI code may continue using an internal stage index. Player-facing design language should still refer to Levels `1-5`.

---

## Data Model

### ThreatManager

`ThreatManager` remains the central state holder and signal source.

It should own:

```gdscript
- current_threat: float
- current_level: int              # 1-5
- current_stage_index: int        # 0-4
- passive_threat_per_second: float
- active_weather: WeatherType
- level_profile: ThreatDifficultyProfile
signal threat_changed(value: float)
signal threat_level_changed(level: int)
signal weather_changed(weather: int)
```

### ThreatDifficultyProfile (new Resource)

Holds the five authored level definitions for a run difficulty.

```gdscript
- levels: Array[ThreatLevelData]  # size 5
```

### ThreatLevelData (new Resource)

One resource per threat level.

```gdscript
- pile_rarity_weights: Dictionary
- weather_pool: Array[WeightedWeatherEntry]
```

### WeightedWeatherEntry (new Resource)

```gdscript
- weather_type: int
- weight: float
```

---

## File Impact

### Existing Files To Update

| File | Change |
|---|---|
| `_project/level/threat/threat_manager.gd` | Replace placeholder bar-only logic with full run-level threat state, passive gain, level mapping, and weather signals |
| `_project/level/threat/threat_ui.gd` | Show real level state, icon emphasis, and threat updates |
| `_project/level/level.gd` | Own or forward run lifecycle hooks if no dedicated run controller exists yet |
| `_project/level/salvage/salvage_spawner.gd` | Query threat-driven rarity weights instead of fixed local weights |
| `_project/ship/magnet/magnet.gd` | Stop owning a hardcoded threat penalty; report magnet-use events to threat |
| `_project/ship/magnet/minigame/magnet_minigame.gd` | Notify threat when looting starts and coordinate departure/overtime flow |
| `_project/items/salvage_item_data.gd` | Add optional `threat_on_collect` for special loot |
| `_project/.../enemy_spawner.gd` | Future dependency: this upcoming system will define enemy pool and per-level spawn rules using the threat level exposed by `ThreatManager` |

### New Files Expected

| File | Purpose |
|---|---|
| `_project/level/threat/threat_level_data.gd` | Resource for one threat level's rules |
| `_project/level/threat/threat_difficulty_profile.gd` | Resource containing the five threat levels for a difficulty |
| `_project/level/threat/weighted_weather_entry.gd` | Weighted weather pool entry |
| `_project/level/threat/weather_controller.gd` | Applies current weather effects such as Acid Rain |

---

## Implementation Order

1. Upgrade `ThreatManager` from placeholder meter to full threat state owner.
2. Refactor pile rarity selection to read from threat level data.
3. Add special loot threat support on `SalvageItemData`.
4. Build the enemy spawner system and have it read the current threat level from `ThreatManager` for enemy pool and spawn-rule selection.
5. Add the weather controller with `Clear` and `Acid Rain`.
6. Wire run lifecycle and Overtime events so Acid Rain can be forced correctly.
7. Finish the UI pass so the threat bar communicates the live level state clearly.

---

## Resolved Decisions

1. Threat is run-level and persistent for the whole run. It does not reset between magnet windows.
2. Threat never decays during a run.
3. Threat gain from magnet use is applied when looting begins, with an added bonus based on pile rarity.
4. Level 3 is the point where enemies begin spawning outside magnet use.
5. Level 5 removes Common piles from the spawn table entirely.
6. Acid Rain is forced by Overtime and lasts until the run ends.
7. Threat controls rulesets; dedicated directors/controllers should execute enemy and weather behavior.

---

## Open Question

The only remaining system-level ambiguity is what object will own the final run lifecycle (`run_started`, `overtime_started`, `run_ended`). This does not block threat implementation as long as the event contract in this spec is honored.
