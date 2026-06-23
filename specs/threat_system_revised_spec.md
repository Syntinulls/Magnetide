# Threat System (Revised) Specification

## Status

This document revises the original [threat_system_spec.md](threat_system_spec.md). It supersedes that spec's UI model, level count, and progression model. Where this document is silent, the original spec's resolved decisions still apply (e.g. threat-driven rarity selection ownership, weather/Acid Rain damage being applied by a separate controller).

The biggest changes from the original spec are:

- Threat levels go from **5** to **10**.
- The threat bar is **horizontal, top-center**, not a vertical side meter.
- Progression is now **gated by a player-controlled Threat Level Cap** instead of flowing continuously to maximum.
- Reaching the cap triggers a **decision point**: advance (pull the lever, play a transition cutscene), wait and die to the storm, or depart the run.

---

## Overview

Threat remains the run-level pressure director for Magnetide. It still controls:

- Salvage pile rarity distribution
- Enemy spawn rate and enemy type unlocks
- Research minigame difficulty

What changes is **how far threat is allowed to rise** and **how the player progresses between threat levels**. Threat no longer drifts unattended to the top of the run. Instead, each threat level is a deliberate stop the player chooses to leave, trading safety for greed.

---

## Design Goals

1. Make threat escalation an explicit player decision, not just the passage of time.
2. Give every threat level a clear "should I push deeper or cash out?" beat.
3. Keep the bar instantly readable at the top of the screen: where am I, how far can I currently go, and how close is the storm.
4. Preserve threat as the single source of truth that other systems (salvage, enemies, research) query for their current difficulty band.

---

## Core Model

### Threat Levels

- Player-facing threat levels are **Level 1** through **Level 10**.
- Every run starts at **Level 1**.
- Internally, code may continue to use a zero-based stage index (`0`–`9`) for arrays, per-level data, and UI segments.
- Level 1 occupies the **first** segment of the bar; Level 10 occupies the **tenth (last)** segment.

| Player Level | Internal Stage Index | Bar Segment |
|---|---|---|
| 1 | 0 | 1st |
| 2 | 1 | 2nd |
| … | … | … |
| 10 | 9 | 10th |

> Migration note: the existing code is built around 5 levels (`ThreatManager.LEVEL_COUNT = 5`, `THREAT_SEGMENT_SIZE = 25.0`, five `ThreatLevelData` entries, five UI icons). These must expand to **10**. The enemy spawner's five `EnemySpawnThreatLevelData` entries are not merely expanded — they are replaced entirely by the per-enemy model described in *Enemy Spawner Refactor*.

### Threat Score and Segments

- Threat is a continuous run-level value from `0.0` to `100.0` (kept as a float).
- The bar is divided into 10 equal segments of `10.0` points each. The boundary between segment *N* and *N+1* is the threshold for Level *N+1*.
- Threat is driven **only by passive gain at a constant rate** (see *Threat Gain*).
- Threat never decays during a run.
- Threat resets only when a new run starts.

### Threat Level Cap

The cap is the new central mechanic.

- The **Threat Level Cap** is the highest threat level the run is currently allowed to reach.
- The starting cap is **Level 1**. At cap 1 the run can fill the Level 1 segment but can never cross into Level 2.
- Threat accumulates normally (see *Threat Gain Sources*) until it reaches the **top of the current cap level's segment**, where it is clamped.
- When threat reaches the top of the capped segment, the run enters the **Cap Reached** decision state (below).
- The cap can only ever be raised by **+1**, by explicit player action, and only once the run has actually reached the current cap.

### Reaching the Cap → Decision State

When threat fills to the top of the current cap level, the run enters a held decision state with three exits:

1. **Advance** — the player pulls the ship lever to raise the cap by +1 and continue into the next threat level. This triggers a transition cutscene.
2. **Die to the storm** — if the player does nothing, the acid storm arrives and will destroy the player/ship (run ends as a destruction failure).
3. **Depart** — the player voluntarily ends the run (existing departure pylon flow), banking what they have collected.

### Cap Reached State Behavior

While in the Cap Reached state:

- **No new salvage piles spawn.** Already-spawned piles may still resolve, but the spawner stops producing new ones.
- A **60-second storm countdown** starts and is displayed, counting down to the arrival of the acid storm.
- The **ship lever switches function** to the "advance to next threat level" interaction (see *Lever*, below). Pulling it raises the cap +1 and plays the transition cutscene.
- **Enemies still spawn**, and their spawn rate may increase while the player lingers in this state.
- If the countdown reaches zero, the **acid storm arrives** and continually drains the health of the player, ship, **and magnet** at a slow, constant rate until the run ends. This is the lethal pressure that punishes indecision.

### Acid Storm

- The storm begins the moment the 60-second countdown hits `0` and the player has not advanced or departed.
- It applies a slow, constant health drain to the player, the ship, and the magnet simultaneously.
- For the first pass, a basic constant drain is sufficient. Visually, it can be communicated with a **green acid/poison vignette** overlaid on the screen.
- Once the storm is active, the player's only remaining options are: continue to the next threat level (lever), die, or depart.

### Final Level (Level 10)

Level 10 is the terminal threat level. For this implementation it behaves exactly like the previous levels' Cap Reached state **except the lever is disabled**: reaching Level 10 starts the final 60-second storm countdown, and the only exits are dying to the storm or departing via the pylons.

> Future (not in scope yet): reaching the end of the tenth segment will eventually trigger a **boss enemy**, and defeating it will put the run into an **endless mode**. This is planned for later and does not change the first-pass behavior above.

---

## Threat Gain

This is a major change from the original spec. **Threat now increases only from passive gain at a single constant rate.** Magnet activation, pile rarity, and special-loot (`threat_on_collect`) no longer contribute to the threat bar — those gain sources are removed from the threat model.

### Rate Derivation

The constant rate is derived from a target maximum run length:

- Target: a **20-minute** run to reach max threat (Level 10) if the player advances at every cap with no delay.
- Bar total: **100.0** points across 10 segments → **10.0 points per segment**.
- Each segment should take **2 minutes** to fill → **5.0 points/minute** ≈ **0.0833 points/second**.

```text
passive_threat_per_second = 100.0 / (20 * 60) ≈ 0.0833
```

This rate is **constant for the whole run** and does not vary by level or with the countdown timer. (This replaces the original `ThreatManager.passive_threat_per_second` getter that derived the rate from the countdown timer's `time_until_final_stretch`.)

### Clamping and Advancing

- Accumulated threat is **clamped at the top of the current cap level's segment**. Once clamped, the run is in the Cap Reached state rather than continuing to rise.
- When the player advances (lever pull → cutscene), the cap is raised by +1 and threat **continues smoothly from its current clamped value** into the newly unlocked segment. It is not reset to the new level's floor.

---

## Threat Outputs (Scaling)

Threat continues to scale three systems, now across 10 levels instead of 5. The **current threat level** (not the cap) is the value these systems read.

### 1. Salvage Pile Rarity Distribution

- Each threat level defines a pile rarity weight table (existing `ThreatLevelData` → `get_pile_rarity_weights()`).
- `SalvageSpawner` already queries `ThreatManager.get_pile_rarity_weights()`; this continues, but the authored table must expand to 10 levels.
- In the **Cap Reached** state, the spawner stops producing new piles regardless of weights.

### 2. Enemy Spawn Rate and Type

This revision also **inverts the enemy spawner's data model** (see *Enemy Spawner Refactor* below). Instead of one spawn profile per threat level (which duplicates enemy entries across the levels that share them), each enemy owns a single profile that declares the **threat level it unlocks at**. The spawner holds one flat list of all enemies and filters by the current threat level at spawn time.

- The `EnemySpawner` reads the current threat level via `ThreatManager.threat_level` and selects from the enemies whose required threat level is satisfied.
- Spawn cadence and concurrency scale with threat at the spawner level (not per enemy), so "spawn rate increases with threat" needs no duplicated data.
- In the **Cap Reached** state, enemies keep spawning and the rate may escalate (a spawner-level rate multiplier) to pressure the player toward a decision.

### 3. Research Minigame Difficulty

- The research minigames already scale by `threat_level` (e.g. [alignment_a_minigame.gd](../_project/ui/research/minigames/alignment_a_minigame.gd) uses `_threat_level` for drift speed, heat build rate, and cool delay).
- With the range now 1–10, those scale factors should be re-tuned so the new wider range still produces a sensible difficulty curve rather than 2× the previous ceiling.

---

## UI Behavior

The threat UI is fully reworked from the current vertical side bar with five icons into a horizontal top-center bar with ten segments.

### Layout

- A **horizontal bar anchored to the top-center** of the screen.
- Longer than the current bar, divided into **10 visible segments**, one per threat level.

### Background Gradient

- The bar background is a **smooth 3-color gradient** transitioning evenly across its length: **green → red → purple**.
- The gradient is continuous (not per-segment banding); green sits at the low/safe end, purple at the high/lethal end, red in the middle.

### Ticker

- A **vertical ticker** tracks the current threat level along the bar.
- The ticker displays the **current threat level number (1–10)** centered on it.
- The ticker position reflects the continuous threat score, so it advances smoothly within a segment, not just on whole-level changes.

### Cap Indication

- The portion of the bar **beyond the current cap is darkened** to show it is currently unreachable.
- When the cap is raised (+1), the next segment lightens to its normal gradient color, visually opening the path forward.

### Cap Reached / Storm State

- When the run enters the Cap Reached state, the UI surfaces the **60-second storm countdown** by repurposing the existing [countdown_timer.gd](../_project/ui/countdown_timer.gd) (which already defaults `final_stretch_seconds = 60.0`).
- The countdown is positioned **centered at the top of the screen, below the threat bar + ticker** — close to where it lived before, but leaving enough vertical space for the bar and ticker above it.
- It should read as an urgent, distinct state from normal play.
- When the storm arrives (countdown hits `0`), the screen shows a **green acid/poison vignette** while the constant health drain is active.

### Asset Impact

- The current art is a vertical bar (`threatbar_bar.png`, `threatbar_progress.png`), a ticker (`threatbar_ticker_*.png`), and five level icons (`threat_0..4_*.png`). New art is needed for: the horizontal bar + 3-color gradient background, the segmented 10-level fill, the numbered vertical ticker, and the darkened-cap treatment. The five level icons are no longer used in their current form.

---

## Progression Flow (End-to-End)

1. Run starts. Threat = floor of Level 1, cap = Level 1.
2. Threat accumulates and the ticker advances within the Level 1 segment.
3. Threat reaches the top of the cap segment → **Cap Reached** state:
   - New pile spawns stop.
   - 60s storm countdown starts and displays (below the bar, top-center).
   - The ship lever switches function to the "advance" interaction.
   - Enemies keep spawning (rate may rise).
4. Player chooses one of:
   - **Advance**: pull the lever → cap raises +1 → transition cutscene → threat continues smoothly into the next segment (segment un-darkens, lever reverts to movement, ticker continues).
   - **Depart**: use the departure pylons → run ends voluntarily (existing flow).
   - **Do nothing**: storm countdown hits 0 → acid storm drains player/ship/magnet health (green vignette) → destruction failure ends the run.
5. Repeat from step 2 at the new level, until either the player leaves or the run ends at Level 10 (where the lever is disabled).

---

## Run Flow Integration

This revision leans on systems that already exist in the project:

- **Lever**: the advance interaction uses the **exact same lever** centered in the ship — [magnet_lever.gd](../_project/ship/magnet/magnet_lever.gd), which normally controls ship movement (braking / acceleration for the looting flow). Its **function switches** each time the threat cap is hit: in the Cap Reached state, pulling the lever advances to the next threat level (raise cap +1 → transition cutscene). After advancing, the lever **reverts to its original movement/looting function**. At Level 10 the lever is disabled entirely.

- **Transition cutscene**: the [run_controller.gd](../_project/run/run_controller.gd) already owns a multi-stage cutscene system (tweening level speed, ship/camera, fades) for departure. The threat-advance transition cutscene should follow the same authoring pattern, owned by the run controller or a dedicated transition controller, so it can be inserted without rewriting the threat manager.

- **Storm / Acid Rain**: the storm is the original spec's Acid Rain weather state, now triggered by the Cap Reached countdown expiring rather than a global overtime. It applies a slow constant health drain to the player, ship, **and magnet**, shown via a green vignette. It is applied by a separate storm/weather controller, not by `ThreatManager`.

- **Run lifecycle / end conditions**: storm death routes through the existing destruction-failure end condition (`request_end_run`), departure through the existing voluntary-departure pylon flow ([run_loop_and_end_of_run_spec.md](run_loop_and_end_of_run_spec.md)).

---

## Enemy Spawner Refactor (Per-Enemy Threat Profile)

The enemy spawner's threat integration is inverted from **per-threat-level** to **per-enemy**.

### Problem With the Current Model

Today the spawner owns one profile per threat level:

- `EnemySpawnerProfile` holds `levels: Array[EnemySpawnThreatLevelData]` (one entry per threat level).
- Each `EnemySpawnThreatLevelData` holds its own `magnet_active_pool` / `magnet_idle_pool` of `WeightedEnemySpawnEntry`.
- The same enemy is therefore **listed again in every level it can appear in**. Because most enemies remain spawnable once unlocked, their data is duplicated across all higher levels. Expanding from 5 to 10 levels makes this duplication worse.

### New Model

The spawner instead owns a **single flat list of all enemies in the game**, where each enemy carries its own threat profile declaring when and how it spawns.

- `EnemySpawner` owns `enemy_profiles: Array[EnemySpawnProfile]` — every enemy, listed exactly once.
- Each enemy's profile declares the **required threat level** (a numerical value, 1–10) at or above which the enemy is eligible to spawn, plus that enemy's specific spawn conditions.
- No threat level stores its own enemy list, so there is no duplication. A threat level's roster is *derived* by filtering the flat list against the current threat level.

### Per-Enemy Profile Contents

Each `EnemySpawnProfile` (the evolution of today's `EnemySpawnDefinition` + the `weight` from `WeightedEnemySpawnEntry`) should declare:

```gdscript
- id: StringName
- enemy_scene: PackedScene
- enemy_data: EnemyData
- allowed_spawn_zones: PackedStringArray
- min_threat_level: int            # required threat level to be eligible (1-10)
- max_threat_level: int = 0         # optional upper bound; 0/unset = no cap (never phases out)
- spawn_weight: float               # relative weight among eligible enemies
- can_spawn_magnet_active: bool      # eligible during active magnet looting
- can_spawn_magnet_idle: bool        # eligible during idle/background traversal
- max_batch_size: int                # max spawned per batch for this enemy
```

This folds the previous `WeightedEnemySpawnEntry.weight` into the profile and replaces the per-threat `max_batch_sizes_by_threat` array with a single per-enemy value (batch scaling, if still desired, can be a spawner-level multiplier rather than a per-enemy-per-level table).

### Spawner-Level (Not Per-Enemy) Threat Scaling

Spawn cadence and concurrency still scale with threat, but they belong to the spawner, not to each enemy — so they are authored once, not duplicated:

- `spawn_interval` by threat (a compact tuning curve or formula over levels 1–10).
- `max_concurrent_enemies` by threat.
- Cap Reached escalation multiplier.

The original spec's magnet-only-vs-idle progression (e.g. early levels spawn only during magnet use) is now expressed per enemy via `can_spawn_magnet_active` / `can_spawn_magnet_idle` combined with `min_threat_level`, rather than by separate per-level pools.

### Selection Algorithm

At each spawn pass the spawner:

1. Reads the current threat level from `ThreatManager`.
2. Builds the **eligible set**: profiles where `min_threat_level <= current_level` (and `current_level <= max_threat_level` if a cap is set), the magnet-active/idle flag matches the current context, and at least one allowed spawn zone is valid.
3. Weighted-rolls among the eligible set using `spawn_weight`.
4. Spawns up to `max_batch_size`, respecting the spawner-level `max_concurrent_enemies` for the current threat.
5. Schedules the next pass using the spawner-level `spawn_interval` for the current threat (with the Cap Reached multiplier applied while in that state).

### Resource Changes

- **New / renamed:** `EnemySpawnProfile` — the per-enemy threat profile (absorbs `EnemySpawnDefinition` and the `weight` field).
- **Removed:** `EnemySpawnerProfile` (per-level container) and `EnemySpawnThreatLevelData` (per-level pools). `WeightedEnemySpawnEntry` is removed once `spawn_weight` lives on the profile.
- **`EnemySpawner`:** owns the flat `enemy_profiles` list + the spawner-level threat-scaling curves; its `_get_valid_pool_entries` / `_get_current_level_data` logic is replaced by the eligibility filter above.

---

## In-Run Event Text Display

The run needs proper **event text displays** to communicate progression and run stages, instead of the current ad-hoc icon+timer widgets. This is a single, generalized banner/label component reused across every in-run event.

### Goal

One reusable event-text component drives all timed/announced in-run events with a consistent visual language, rather than each system shipping its own bespoke icon+label combo.

### Behaviors

- **Storm countdown (threat cap reached):** when the threat level cap is reached, the storm countdown displays as event text reading **`STORM IMMINENT IN Xs`**, where `X` counts down with the timer. This is the text form of the repurposed [countdown_timer.gd](../_project/ui/countdown_timer.gd) described above.
- **Magnet departure timer:** the same generalized text replaces the existing **icon + timer combo on the right of the screen** for the magnet minigame departure timer ([departure_icon.gd](../_project/ui/departure_icon.gd) / [departure_timer_ui.gd](../_project/ship/magnet/departure_timer_ui.gd), which currently render `"Departure in %.1fs"`). It should read as an event countdown in the same style (e.g. `DEPARTING IN Xs`).
- **Salvage warning:** when the flashing warning icon signifying an oncoming salvage pile begins on the right ([warning_icon.gd](../_project/ship/magnet/minigame/warning_icon.gd), `Phase` YELLOW/ORANGE/RED), the event text shows an announcement such as **`SALVAGE DETECTED`**.

### Requirements

- A generalized event-text element (label, optionally with countdown formatting and urgency styling) that any in-run system can drive.
- Supports both **announcement** text (`SALVAGE DETECTED`) and **countdown** text (`STORM IMMINENT IN Xs`, `DEPARTING IN Xs`).
- Replaces the current per-feature icon+timer widgets (`WarningIcon`, `DepartureIcon` / `departure_timer_ui.gd`) as the source of on-screen event communication. The underlying timing/phase logic in those systems can remain; only their presentation is unified into the event-text display.
- Exact placement of each event-text instance can match where its predecessor lived (storm: top-center below the bar; magnet timer/salvage warning: right side) unless a single shared location is preferred during implementation.

---

## Interactable Visual Indicators (Separate Step)

> This is a **standalone step** in the implementation, independent of the threat changes. It standardizes how *all* interactables in the game communicate availability and controls.

The game currently lacks consistent interactable feedback — e.g. [departure_pylon.gd](../_project/ship/departure_pylon.gd) has a `_set_highlight()` that is a no-op stub. We need a standardized visual-indicator system applied to every interactable.

### Two Standardized Indicators

1. **Highlight when interactable** — an interactable becomes highlighted when it is available to interact with, triggered either by **mouse hover** or by **player proximity**, depending on the interactable's interaction model.
2. **Control prompt** — a keybind prompt appears in the **bottom-center of the screen** (in the `game_ui` scene) showing the action, e.g.:
   - `HOLD [E] DEPART` for the departure pylons
   - `[E] BRAKE` for the lever (triggers the lever / looting minigame)
   - `[LMB] PICK UP` when hovering over salvage items with the magnet gun

### Multiple Simultaneous Prompts

Multiple interactables can be available at once (e.g. pressing `[LMB]` on a salvage item while also standing near the lever). In that case, the control prompts **stack vertically** in the bottom-center prompt area, one line per available interactable.

### Requirements

- A shared interactable interface/contract so every interactable can declare: its highlight state, its prompt text, and its input hint (`[E]`, `HOLD [E]`, `[LMB]`, …).
- A central prompt host in `game_ui` ([game_ui.gd](../_project/ui/game_ui.gd) / `game_ui.tscn`), anchored bottom-center, that collects currently-available prompts and stacks them vertically.
- Highlight visuals standardized across interactables (the existing `DeparturePylon._set_highlight()` stub becomes a real implementation; the lever, salvage items, etc. adopt the same highlight treatment).
- Prompts appear/disappear in lockstep with availability (in range / hovered / not blocked by run state), mirroring the gating already present in `departure_pylon.gd` (`_can_interact`) and `magnet_lever.gd` (`set_available`, in-range).
- The lever's prompt should reflect its **current function** (e.g. `[E] BRAKE` normally vs. an advance prompt while in the Cap Reached state).

### Affected Interactables (initial set)

| Interactable | Trigger | Example Prompt |
|---|---|---|
| Departure pylons ([departure_pylon.gd](../_project/ship/departure_pylon.gd)) | Proximity | `HOLD [E] DEPART` |
| Ship lever ([magnet_lever.gd](../_project/ship/magnet/magnet_lever.gd)) | Proximity | `[E] BRAKE` (normal) / advance prompt (cap reached) |
| Salvage items ([salvage_item.gd](../_project/items/salvage/salvage_item.gd)) | Hover (magnet gun) | `[LMB] PICK UP` |

---

## Data Model Changes

### ThreatManager

`ThreatManager` remains the central state holder and signal source. Required changes:

- `LEVEL_COUNT` → `10`; `MAX_THREAT` stays `100.0`; `THREAT_SEGMENT_SIZE` → `10.0`.
- `threat_level` getter returns `0`–`9` (player-facing 1–10).
- Replace the countdown-timer-derived `passive_threat_per_second` getter with a **constant** `≈ 0.0833` (`100.0 / 1200.0`). Expose it as a tunable `@export` so the 20-minute target can be retuned.
- Add a **cap** concept:

```gdscript
var threat_level_cap: int          # current cap, starts at level 1 (stage 0)
func can_raise_cap() -> bool        # true only when threat has reached the cap
func raise_cap() -> void            # +1 cap, used by the advance/lever flow
var is_cap_reached: bool            # true while threat is clamped at the cap
```

- Threat accumulation clamps to the top of `threat_level_cap`'s segment instead of `MAX_THREAT`.
- New signals for the decision state:

```gdscript
signal cap_reached()                # threat hit the current cap; enter decision state
signal cap_raised(new_cap: int)     # player advanced
signal storm_countdown_started(seconds: float)
signal storm_arrived()              # countdown expired; force Acid Rain
```

(Existing `threat_changed` / `threat_level_changed` remain.)

### Per-Level Data

- `ThreatLevelData` ([threat_level_data.gd](../_project/level/threat/threat_level_data.gd)) authored list grows to 10 entries; `_create_default_threat_level_factors()` and `_normalize_threat_level_factors()` updated accordingly. (This is salvage-rarity data and stays per-level.)
- Enemy data does **not** grow to 10 per-level entries — it moves to the per-enemy model (see *Enemy Spawner Refactor*). `EnemySpawnThreatLevelData` / `EnemySpawnerProfile` are removed, not expanded.

### Cap-State Spawn Behavior

- `SalvageSpawner` gains a "freeze new spawns" mode entered when `ThreatManager.is_cap_reached` is true.
- `EnemySpawner` optionally reads a cap-state rate multiplier / escalation rule.

---

## File Impact

### Existing Files To Update

| File | Change |
|---|---|
| [_project/level/threat/threat_manager.gd](../_project/level/threat/threat_manager.gd) | 10 levels, cap state machine, clamp-to-cap, new signals, storm countdown trigger |
| [_project/level/threat/threat_ui.gd](../_project/level/threat/threat_ui.gd) | Horizontal top-center bar, numbered vertical ticker, darkened-cap rendering, storm countdown surfacing |
| [_project/level/threat/threat_ui.tscn](../_project/level/threat/threat_ui.tscn) | New horizontal layout, 10 segments, gradient background, repositioned ticker; remove 5-icon layout |
| [_project/level/threat/threat_level_data.gd](../_project/level/threat/threat_level_data.gd) | Authored data extended to 10 levels |
| [_project/level/salvage/salvage_spawner.gd](../_project/level/salvage/salvage_spawner.gd) | Stop spawning new piles in the Cap Reached state |
| [_project/level/enemies/enemy_spawner.gd](../_project/level/enemies/enemy_spawner.gd) | Own a flat `enemy_profiles` list; replace per-level pool lookup with the per-enemy eligibility filter; add spawner-level threat cadence/concurrency curves + cap-state escalation |
| [_project/level/enemies/enemy_spawn_definition.gd](../_project/level/enemies/enemy_spawn_definition.gd) | Evolve into `EnemySpawnProfile`: add `min_threat_level` / `max_threat_level`, `spawn_weight`, magnet-active/idle flags, `max_batch_size`; drop `max_batch_sizes_by_threat` |
| [_project/level/enemies/enemy_spawner_profile.gd](../_project/level/enemies/enemy_spawner_profile.gd) / [enemy_spawn_threat_level_data.gd](../_project/level/enemies/enemy_spawn_threat_level_data.gd) / [weighted_enemy_spawn_entry.gd](../_project/level/enemies/weighted_enemy_spawn_entry.gd) | **Removed** — per-level container, per-level pools, and the weighted entry are superseded by the per-enemy profile |
| [_project/ship/magnet/magnet_lever.gd](../_project/ship/magnet/magnet_lever.gd) | Support "advance threat level" interaction while in Cap Reached state |
| [_project/run/run_controller.gd](../_project/run/run_controller.gd) | Own/trigger the threat-advance transition cutscene; route storm death and advance through run flow |
| [_project/ui/research/minigames/alignment_a_minigame.gd](../_project/ui/research/minigames/alignment_a_minigame.gd) | Re-tune threat scale factors for a 1–10 range |
| [_project/ui/countdown_timer.gd](../_project/ui/countdown_timer.gd) | Repurpose as the 60s storm countdown event text (`STORM IMMINENT IN Xs`); reposition below the threat bar, top-center |
| [_project/ship/magnet/magnet.gd](../_project/ship/magnet/magnet.gd) | Take storm health drain alongside player and ship |
| [_project/ui/departure_icon.gd](../_project/ui/departure_icon.gd) / [_project/ship/magnet/departure_timer_ui.gd](../_project/ship/magnet/departure_timer_ui.gd) | Replace icon+timer combo with the generalized event-text display |
| [_project/ship/magnet/minigame/warning_icon.gd](../_project/ship/magnet/minigame/warning_icon.gd) | Drive the `SALVAGE DETECTED` event text instead of standalone icon flashing |
| [_project/ui/game_ui.gd](../_project/ui/game_ui.gd) / `game_ui.tscn` | Host the event-text display and the bottom-center control-prompt stack |
| [_project/ship/departure_pylon.gd](../_project/ship/departure_pylon.gd) | Implement real highlight + register `HOLD [E] DEPART` prompt |
| [_project/items/salvage/salvage_item.gd](../_project/items/salvage/salvage_item.gd) | Hover highlight + register `[LMB] PICK UP` prompt |

### New Files (likely)

| File | Purpose |
|---|---|
| `_project/level/threat/storm_controller.gd` (or weather controller) | Owns the storm: applies constant player/ship/magnet drain + green vignette once the countdown expires |
| `_project/level/threat/threat_transition.gd` | Optional: the advance/level-up transition cutscene, if not folded into `run_controller.gd` |
| `_project/ui/event_text_display.gd` (+ scene) | Generalized in-run event text (announcements + countdowns) reused by storm, departure, and salvage warnings |
| `_project/ui/control_prompt.gd` / `_project/ui/control_prompt_stack.gd` (+ scenes) | Standardized control-prompt element and the bottom-center vertical stack host |
| `_project/interactables/interactable.gd` (interface/contract) | Shared contract for highlight state, prompt text, and input hint |

---

## Recommended Implementation Order

1. Expand `ThreatManager` to 10 levels and add the cap state machine + signals (no UI yet).
2. Expand the authored salvage-rarity data (`ThreatLevelData`) to 10 entries.
3. Refactor the enemy spawner to the per-enemy model: introduce `EnemySpawnProfile` (with `min_threat_level` etc.), give `EnemySpawner` a flat `enemy_profiles` list + spawner-level threat cadence/concurrency curves, replace the per-level pool lookup with the eligibility filter, and remove the per-level enemy resources.
4. Clamp threat to the cap and emit `cap_reached`; freeze salvage spawns in that state.
5. Wire the storm countdown and force Acid Rain on expiry → destruction failure.
6. Wire the lever advance interaction → `raise_cap()` → transition cutscene → resume.
7. Rework the threat UI: horizontal bar, gradient, 10 segments, numbered ticker, darkened cap, storm countdown readout.
8. Re-tune research minigame difficulty scaling for the 1–10 range.
9. Build the generalized in-run event text display and migrate the storm countdown (`STORM IMMINENT IN Xs`), magnet departure timer, and salvage warning (`SALVAGE DETECTED`) onto it.
10. **(Separate step)** Build the standardized interactable visual-indicator system: shared interactable contract, hover/proximity highlights, and the bottom-center control-prompt stack (`HOLD [E] DEPART`, `[E] BRAKE`, `[LMB] PICK UP`), with vertical stacking when multiple prompts are active.
11. Verify a full run: fill → cap → advance through multiple levels, plus the storm-death and departure exits; confirm enemy spawning, event text, and interactable prompts behave correctly throughout.

---

## Resolved Decisions

1. Threat levels are 1–10; runs start at Level 1.
2. The threat bar is horizontal, top-center, with 10 segments and a smooth green→red→purple gradient background.
3. A vertical ticker tracks the current level and displays its number (1–10).
4. The Threat Level Cap starts at 1 and can be raised by +1 only by player action, only after the run has reached the current cap.
5. Reaching the cap freezes new salvage pile spawns, starts a 60-second storm countdown, and switches the ship lever to the "advance" interaction.
6. Enemies continue spawning (and may escalate) while in the Cap Reached state.
7. The three exits from the Cap Reached state are: advance (lever + cutscene), die to the storm, or depart.
8. Segments beyond the current cap are darkened.
9. Threat continues to scale salvage rarity, enemy spawn rate/type, and research minigame difficulty across the new 1–10 range.
10. **(O5)** Threat is driven by passive gain only, at a constant `100.0 / 1200s ≈ 0.0833` pts/sec — magnet/loot/special-loot no longer add threat. The bar is `100.0` points; each of the 10 segments is `10.0` points / 2 minutes; a no-delay run reaches max in 20 minutes.
11. **(O2)** On advance, threat continues smoothly from its current value into the new segment after the cutscene; it is not reset.
12. **(O3)** The storm countdown repurposes the existing `countdown_timer.gd`, positioned top-center below the threat bar + ticker.
13. **(O4)** The advance lever is the exact same center-ship movement lever; its function switches when the cap is hit and reverts after advancing.
14. **(O1)** At Level 10 the lever is disabled; behavior is otherwise identical to a normal Cap Reached state (final 60s storm timer, exits are die or depart).
15. When the storm arrives, it drains player, ship, and magnet health at a slow constant rate, shown via a green acid/poison vignette.
16. In-run events are communicated through a single generalized event-text display. The storm countdown reads `STORM IMMINENT IN Xs`; it replaces the magnet departure icon+timer combo and the salvage warning icon (which announces `SALVAGE DETECTED`).
17. All interactables share a standardized visual-indicator system: a highlight on hover/proximity, plus a bottom-center control prompt in `game_ui` (e.g. `HOLD [E] DEPART`, `[E] BRAKE`, `[LMB] PICK UP`). When multiple interactables are available at once, their prompts stack vertically. This is implemented as a separate step.
18. The enemy spawner uses a **per-enemy threat profile** model, not per-threat-level profiles. The spawner owns one flat list of all enemies; each enemy declares its required threat level (1–10) and spawn conditions. Spawn cadence and concurrency scale with threat at the spawner level. This removes the duplicated enemy data of the old per-level model.

---

## Open Questions

- **Future (not blocking):** reaching the end of Level 10 will eventually trigger a boss enemy, and defeating it will start an endless mode. Out of scope for this implementation.
- **Tuning:** enemy spawn-rate escalation curve while lingering in the Cap Reached state is left to data tuning, not fixed here.
