# Boss System

## Status

Framework implemented; **no boss content yet**. The level's `LevelDefinition.boss_scene` is
empty, so threat level 10 still ends in the depart-only terminus until the first boss is
authored and assigned. Every part of the pipeline below was exercised end to end with a
throwaway boss during development.

## Overview

A boss is fought once per level, at the level-10 gate. Every boss shares one structure:

- a **root** (`Boss`) that owns the fight's lifecycle, the boss's total health, its current
  **phase**, and a **state machine** of authored `BossState` nodes;
- one or more **parts** (`BossPart`), each with its own health pool, hitbox, contact damage,
  visuals and optional internal state, reacting to the root's state and phase;
- a **health bar** showing total health with a marker where each phase begins;
- a **reward** (scrap + salvage items) collected automatically on defeat;
- **cutscenes** before the fight, between phases (optional) and after it, played by a
  reusable in-run cutscene system that the run's departure sequence also uses.

## Decisions

| Question | Decision |
|---|---|
| Boss health vs part health | Total = sum of every *counted* part's pool. The boss dies exactly when its last counted part is destroyed. `BossPart.counts_toward_boss_health = false` opts a part out (respawning shield, decoy). |
| Phases | Slices of total health: `BossPhaseData.start_health_ratio` (phase 0 = 1.0, strictly decreasing). |
| Trigger | Filling level 10 opens the interlevel window as a **boss gate** (`ThreatManager.GateKind.BOSS`): lever with confirm, or timer expiry, starts the fight; pylons still depart. A level with no boss keeps the depart-only `TERMINAL` window. |
| After defeat | Reward → outro cutscene → the run ends as `RunResult.EndReason.BOSS_DEFEATED`, which plays the departure cutscene and keeps loot like a voluntary departure. |
| Placeholder boss | None shipped. |

## Runtime flow

```
ThreatManager: level 10 fills, boss available
  window_opened(gate = BOSS) ── lever confirm / expiry ──► advance() ─► Phase.BOSS, boss_started
RunController: boss_started → BGM BOSS
MagnetMinigame: boss_started → salvage spawns frozen
BossEncounter: boss_started
  1. ambient spawning off, ambient enemies despawn, Level.tween_level_speed(0)
  2. instance boss scene at BossData.spawn_viewport_ratio (DORMANT), bind BossHealthBar
  3. play intro_cutscene → boss.activate()          (ACTIVE, phase 0 entry_state)
  4. boss.phase_transition_started(i) → play phases[i].transition_cutscene → boss.finish_phase_transition()
  5. boss.defeated → award reward, unbind bar → play outro_cutscene → encounter_finished
RunController: encounter_finished → request_end_run(BOSS_DEFEATED) → departure cutscene → salvage
```

## Boss (`bosses/boss.gd`)

- **Lifecycle** `DORMANT → ACTIVE ⇄ TRANSITIONING → DEFEATED`. DORMANT takes no damage (intro).
  Combat states tick only while ACTIVE.
- **Signals**: `health_changed(current, maximum)`, `phase_transition_started(index)`,
  `phase_changed(index)`, `defeated`.
- **Damage**: every part hit goes through `apply_part_damage(part, amount, source) -> float`,
  the one place that applies lifecycle gating, debug invulnerability,
  `invulnerable_during_transition`, and `clamp_damage_at_end`, which stops one burst from
  skipping a phase. It returns the amount that landed.
- **Phase crossing**: the boss exits its state, enters TRANSITIONING, calls every part's
  `_on_boss_phase_changed`, and emits `phase_transition_started`. The encounter plays the
  cutscene and then calls `finish_phase_transition()`. The boss never plays cutscenes itself.
- **States**: `BossState` children of a `States` node; the node name is the id for
  `transition_to(id)`. A phase opens in its `entry_state`.
- **Hooks**: `_on_phase_entered`, `_on_part_destroyed`, `_on_defeated`.
- **Debug**: `debug_set_phase`, `debug_kill`, `debug_destroy_part`, `debug_set_invulnerable`,
  `debug_set_frozen`.

## BossPart (`bosses/boss_part.gd`)

- **Scene contract**: optional `Visual` (Node2D carrying `combat/hit_flash.gdshader`), a `Hitbox`
  child (`owner_path` → part, on the Enemies layer), and any `DamageBox`es beneath it (outside
  nested parts). The boxes are collected automatically and start disabled.
- **Combat contract**:
  - `take_damage` → boss → damage number + flash + hit sfx.
  - `get_contact_damage()` (the DamageBox contract).
  - `get_hitbox()`, `set_attacks_enabled()`.
- `died` fires when the pool empties. The name matters: `StatusEffect` ends itself on
  `died`, so burning stops with the part.
- **Destruction**:
  - The hitbox stops being detectable at once, so projectiles don't spend pierce on wrecks.
  - `_play_destruction_sequence()` is awaited; the default is a flash, plus a fade when the
    part will be hidden.
  - Then `destroyed_mode` applies:
    - `HIDE_AND_DISABLE`: hidden, attacks off.
    - `DISABLE_ONLY`: visible wreck, attacks off.
    - `STAY_ACTIVE`: keeps attacking.
- **Hooks**: `_on_boss_state_changed`, `_on_boss_phase_changed`, `_on_boss_lifecycle_changed`,
  `_on_part_state_changed` (fired by the optional `part_state`), `_on_damaged`.
- Parts are not in the `enemies` group, so the spawner, kill-all, and enemy-targeting augments
  ignore them.

## Data

- `BossData`: `boss_id`, `display_name`, `phases`, `reward`, `intro_cutscene`, `outro_cutscene`,
  `spawn_viewport_ratio`.
- `BossPhaseData`: `display_name`, `start_health_ratio`, `entry_state`, `transition_cutscene`,
  `invulnerable_during_transition`, `clamp_damage_at_end`.
- `BossRewardData`: `scrap_metal`, `guaranteed_items`, `loot_rolls` against
  `loot_pools`/`rarity_weights` (the same `SalvageLootPools`/`SalvageRarityWeights` the piles
  use), and `salvageable_chance`.
  - Scrap flies from the boss to the HUD counter.
  - Items go through `RunController.award_bonus_loot()` into the departure payload, with a
    loot label over the player.
- `LevelDefinition.boss_scene`: injected by `RunController` into `ThreatManager.set_boss_available()`
  and `BossEncounter.set_boss_scene()`.

## Health bar (`hud/boss_health_bar/`)

Instanced in `game_ui.tscn` under `BossHealthBarAnchor`, below the event text; reached via
`Magnetide.boss_health_bar`. It shows the name, a phase label, the total-health bar, and one
marker per phase boundary, built at runtime from `Boss.get_phase_start_ratios()`. It is bound
and unbound by `BossEncounter`. It fades with the rest of the HUD during cutscenes.

## Cutscene system (`cutscene/`)

- `CutsceneBehavior` (Resource): subclass per cutscene and override the coroutine
  `play(director, context)`. `skip_to_end()` applies the final state when cutscenes are skipped.
  - Session options: `hide_hud`, `letterbox`, `lock_player`, `protect_player_and_ship`,
    `hold_session_at_end` (for cutscenes that end the run).
- `CutscenePlayer` (in `level.tscn`, `Magnetide.cutscenes`):
  - `play(cutscene, extra_context)` wraps the script in the session.
    - The HUD fades via `GameUI.set_hud_hidden`; the pause menu and event text stay.
    - The player is locked via `Player.set_cinematic_lock`, which is separate from
      `input_enabled` so gameplay systems and cutscenes can't undo each other.
    - The player and ship are protected.
    - Letterbox bars slide in.
  - Everything is restored at the end.
  - The context carries `player`, `ship`, `level`, plus `boss` from the encounter.
  - Awaitable API:
    - `wait`
    - `camera_move_to` / `camera_zoom_to` / `camera_shake` / `camera_reset`
    - `move_actor_to`, `walk_player_to`, `play_animation`, `tween_level_speed`
    - `show_caption`, `fade_out` / `fade_in`, `set_letterbox`
  - The overlay sits on canvas layer 9, below the HUD layer, so the pause menu draws over it.
- `LevelCamera` (`level/level_camera.gd`):
  - The level writes `rest_position` on resize; a posed camera isn't snapped back.
  - `tween_position`, `tween_zoom`, `shake`, `reset`.
- The departure sequence is `run/departure_cutscene_behavior.gd` + `.tres`; its timing and
  motion tuning are exports.

## Debug panel

- **Boss group** (run-only):
  - Summon (dropdown from the panel's exported `boss_scenes`, empty until the first boss).
  - Kill, Damage (lands as a real hit), Go To Phase, Force State and Destroy Part (dropdowns
    built from the live boss).
  - Invulnerable and Freeze AI toggles.
- **World group**: Skip Cutscenes, which persists across runs.
- **Readout**: `Boss: name  P i/n  state  HP cur/max`.

## Authoring a boss

1. `bosses/<name>/<name>.tscn`:
   - The root script extends `Boss`, with `data` set to `<name>_data.tres`.
   - Parts are `BossPart` subclasses, each with `Visual`, `Hitbox` (owner_path `..`) and
     DamageBoxes.
   - A `States` node holds one `BossState` subclass per behavior state.
2. `<name>_data.tres`: phases (entry states by node name), reward, cutscenes (`CutsceneBehavior`
   subclasses in the boss folder).
3. Assign the scene to the level's `LevelDefinition.boss_scene` and add it to the debug
   panel's `boss_scenes`.
4. Balance: the boss is tuned for max upgrades at threat 10 (`balance_sheet.md`, philosophy rule 1).

## Open points

- Should the boss bar stay visible during phase-transition cutscenes? Today it fades with the
  HUD; a per-cutscene exclusion would be a small addition to `GameUI.set_hud_hidden`.
- Should enemy-group augments (Electrified Hull, Enemy Repulsion, Kinetic Repulsion) affect
  boss parts?
- Should there be a player-facing cutscene skip? Pausing mid-cutscene is allowed.
- Event-triggered phases ("part X destroyed") alongside health slices.
- Visible reward delivery (items flying into storage) instead of labels + payload.
- `lever_minigame.gd` still tweens the camera's zoom/offset itself. It is self-contained and
  compensates for time scale, and `LevelCamera.shake` owns `offset` only while shaking, so the
  two must not overlap.
