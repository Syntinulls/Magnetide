# Storm Event System Specification

## Status

This document revises the in-run threat progression model defined in
[threat_system_revised_spec.md](threat_system_revised_spec.md). It supersedes that spec's
**Cap Reached / Acid Storm** model: the per-level lethal storm countdown, the storm-as-death-timer,
and the lever-driven advance cutscene. Everything else in that spec — 10 threat levels, the
horizontal top-center bar, the threat-level cap, passive-only threat gain, the per-enemy spawn
profile model, the event-text display, and the interactable highlight/prompt system — still stands
and is the foundation this builds on.

Per §6 of [project_organization.md](project_organization.md) the replaced systems are **deleted**,
not kept alongside the new ones. There is no "old acid storm" path after this change.

---

## Overview

Today, every threat level ends the same way: threat fills the capped segment, a countdown starts,
and an acid storm arrives that drains the player and ship to death unless they pull the lever or
depart. The storm is a punishment for indecision — it is never *content*, only a timer.

This revision splits that single beat into two distinct beats:

1. **The interlevel window** — a short, low-pressure 30-second decision break that happens after
   *every* threat level. It is the only moment in a run where the player may end the run.
2. **The storm** — a fixed, authored combat encounter (waves of enemies + a weather effect) that
   gates the run at three specific points. It is content the player fights through, not a timer
   they outrun.

The result is a run with a legible shape: three acts of three threat levels each, separated by two
storms, terminating in a third storm and then the level-10 boss.

```
L1  L2  L3 ][STORM 1][ L4  L5  L6 ][STORM 2][ L7  L8  L9 ][STORM 3][ L10 (boss)
  ^   ^   ^            ^   ^   ^            ^   ^   ^            ^
  30s interlevel window after every level (storm windows at 3, 6, 9)
```

Run length is deliberately **not** budgeted. The previous spec's 20-minute target was an estimate
used to derive the passive threat rate, not a rule; with storms and windows added, a run now lasts
as long as the player takes to progress through it, and longer runs are an intended outcome.

---

## Design Goals

1. **Make threat escalation content, not attrition.** A storm is something you beat, not something
   you flee. Clearing one should feel earned.
2. **Give the run a readable structure.** Three storms at fixed, visible points means the player can
   see the whole run's shape from the threat bar on level 1 and plan a target depth.
3. **Concentrate the departure decision into one deliberate moment.** Ending a run is currently
   possible at any time; that makes it a background thought rather than a choice. Confining it to
   the window turns "how deep do I go?" into a recurring, discrete commitment.
4. **Never take control away from the player.** Routine advances lose their cutscene entirely, and
   storm entry is a sequence the player plays through, not one they watch.
5. **Keep the storm authored, not procedural.** Waves are hand-tuned encounter design (`.tres`),
   not another threat-scaled random table.

---

## Core Model

### Phases

`ThreatManager` gains an explicit phase machine, replacing the current `_is_cap_reached` /
`_storm_active` boolean pair.

```gdscript
enum Phase { BUILDING, WINDOW, STORM, BOSS }
```

| Phase | Threat gain | Level speed | Salvage spawns | Ambient enemy spawns | Pylons | Lever |
|---|---|---|---|---|---|---|
| `BUILDING` | accumulating | normal | yes | yes | **disabled** | brake / depart (magnet) |
| `WINDOW` | paused (clamped) | normal | frozen | yes, normal rate | **enabled** | `[E] CONTINUE` |
| `STORM` | paused | **halted** | frozen | **suspended** | **disabled** | disabled |
| `BOSS` | paused | TBD | TBD | TBD | TBD | TBD |

`BOSS` is reserved now so the level-10 terminus does not require reworking the phase machine later.
See *Level 10* below.

### Threat Levels and Storm Gates

Threat levels remain **1–10** with the same 100-point bar and 10-point segments. What changes is
what sits at a segment boundary.

| Boundary (after level) | Gate |
|---|---|
| 1, 2, 4, 5, 7, 8 | interlevel window only |
| **3, 6, 9** | interlevel window **→ storm** |
| 10 | boss fight (TBD, out of scope) |

The gate set is **not hardcoded**. Each authored `StormData` declares the level it gates
(`gate_after_level`), and `ThreatManager` derives the gate set by scanning the level's authored
storm list (§9 of the org spec — content lives in data, not in a `match` on level numbers).

### Run Flow (End-to-End)

1. Run starts at level 1, cap 1, phase `BUILDING`.
2. Threat accumulates until it fills the capped segment and clamps.
3. Phase → `WINDOW`. A 30-second timer starts, the announcement appears, the pylons arm, the lever
   switches to `CONTINUE`.
4. The window resolves one of three ways:
   - **Wait** — the timer expires and the run auto-advances.
   - **Lever** — the player advances immediately, skipping the remaining time.
   - **Pylons** — the player departs; run ends via the existing voluntary-departure flow.
5. On advance:
   - **Non-storm gate** → cap +1, announcement `THREAT LEVEL N`, phase → `BUILDING`. No cutscene.
   - **Storm gate** → phase → `STORM`. The storm runs to completion, then cap +1 and phase →
     `BUILDING`.
6. Repeat from step 2 until the player departs, dies, or reaches level 10.

### Level 10

Clearing storm 3 raises the cap to 10. Threat then builds through the level-10 segment and reaches
the top of the bar, which is the boss trigger.

The boss is out of scope. **Interim behavior:** reaching the level-10 ceiling opens a window that
offers **depart only** — no lever advance, no storm — so the run has a defined terminus instead of
clamping forever. The `BOSS` phase value is reserved but unused until the boss exists.

---

## The Interlevel Window

### Behavior

- Duration: **30 seconds** (`@export var interlevel_window_seconds`).
- Owned and ticked by **`ThreatManager`**, not the UI (see *Timer Ownership* below).
- Threat gain is paused; threat is already clamped at the segment ceiling, so nothing moves.
- New salvage piles stop spawning (existing `SalvageSpawner` freeze behavior, re-pointed at the new
  phase flag).
- Ambient enemies keep spawning at the **normal rate** for the current level. The
  `cap_state_spawn_rate_multiplier` escalation is **deleted** — the window is a breather, and
  escalating pressure during a fixed 30-second timer only punishes a player who is walking to the
  pylons.
- The window will not open mid-loot. The existing `MagnetMinigame` → `ThreatManager.set_cap_hold()`
  deferral is kept and renamed `set_window_hold()`.

### Why the player would ever wait

The three options are not three outcomes — waiting and pulling the lever both advance. The window's
real purpose is **"finish what you're doing before the next level":** bank stored salvage, kill the
enemies on your deck, spend research points, reload, or walk to the pylons. The lever exists for the
player who is already done. Waiting costs nothing beyond the ambient enemies already present, and
that is intended — the window is a breather, not a third pressure state.

### Advancing

- **Non-storm gate:** a single lever press advances. A mispress costs at most 30 seconds (the window
  would have auto-advanced anyway), so a confirmation step is pure friction.
- **Storm gate:** the lever keeps its **two-press confirm**. The first press raises the floating
  `ENTER STORM?` label on the lever; the second commits. Here the confirm means something, because
  entering a storm is irreversible.

Lever control prompt text by state:

| State | Prompt |
|---|---|
| `BUILDING`, magnet idle | `[E] BRAKE` |
| `BUILDING`, magnet active | `[E] DEPART` |
| `WINDOW`, non-storm gate | `[E] CONTINUE` |
| `WINDOW`, storm gate | `[E] ENTER STORM` |
| `STORM` | *(none — lever disabled)* |

### Departure Hold Takes Priority Over Expiry

A departure hold in progress **suspends the window's resolution**. If the countdown reaches zero
while the player is holding `[E]` on a pylon, the window does not auto-advance — it waits for the
hold to complete (departing the run) or to be released (advancing immediately).

This means a hold started with one second left still succeeds. The countdown is a prompt to decide,
not a guillotine on a decision already made.

Visually, expiry with a hold in flight clears the announcement's **subtext line** — the countdown
and the options list both vanish — leaving only the headline (`STORM IMMINENT`). The player sees
that time is up and that only the action already underway can still resolve.

---

## Departure Gating and the "Armed Pylons" Problem

### The gating rule

The departure pylons are interactable **only while the phase is `WINDOW`**. Outside the window:
interaction, hold-to-depart, highlight, and control prompt are all off. There is no mid-storm
bailout — the window immediately before a storm is the offer, and taking the gate is the commitment.

The clean implementation point already exists. `DeparturePylon._can_interact()` calls
`Magnetide.run.can_accept_departure_request()`, and `_process` feeds that same boolean into
`Ship.set_departure_pylon_active()`, which drives **both** the shared generator outline **and** the
`&"end_run"` control prompt. So extending the single choke point:

```gdscript
# run_controller.gd
func can_accept_departure_request() -> bool:
	return not _is_run_ending and _threat != null and _threat.is_departure_window_open
```

turns off interaction, highlight, and prompt together, with no per-call-site gating.

### The discovery problem

Gating alone creates a worse experience than the current always-on pylons: a player who has never
successfully departed has no way to learn that the pylons *ever* work. Proximity-triggered feedback
(the existing highlight + prompt) cannot solve this, because it only fires if the player happens to
walk to the pylons during the 30 seconds. This also runs straight into the established
control-prompt/highlight invariant: a prompt that only appears on proximity needs the object to
advertise itself first.

The pylons therefore need a **persistent, world-space, at-a-distance state change** for the duration
of the window. The solution is three layers, in priority order.

**1. Diegetic power-up on the pylons (primary).**
The pylons are dormant machinery that visibly energizes when departure is possible. `ShipGens` (the
`AnimatedSprite2D` the ship already outlines for pylon hover) gets an `inert` and an `armed`
animation; `departure_pylon.tscn` — today just an `Area2D` + `CollisionShape2D` + `UIAnchor` with no
art of its own — gains authored FX children (a beam/corona `Sprite2D`, a `PointLight2D`, optionally a
`GPUParticles2D`) driven by an `AnimationPlayer` with `power_up` / `armed_loop` / `power_down` tracks.
Tinted to `Player.DEPART_BAR_COLOR` so the arm color, the hold bar, and the departure beat are one
visual language. A rising hum on arm, a power-down whine on close.

This is the load-bearing layer: visible from anywhere on the ship for the whole window, it teaches
the association in one run, costs no screen real estate, and layers cleanly under the existing white
`CompositeOutline` hover highlight (arm = "possible", outline = "you're in range").

**2. Announcement subtext.** The second line of the event text lists both live options in words, for
the player who has not yet decoded the visual language (see *Announcement Text* below).

**3. Existing control prompts, gated.** `&"end_run"` (`HOLD [E] END RUN`, priority 10) and
`&"lever"` (priority 5) already stack bottom-center. No new work beyond the gating. Answers "which
key" where the player already looks.

Rejected: floating world-space labels over the lever and pylons — `MagnetLever` has that pattern
already, but three floating labels plus a two-line announcement plus two stacked prompts is too many
simultaneous text elements for one 30-second beat.

### Window close

The power-down must be as legible as the power-up. A player who mistimes a departure needs to
understand the window *closed*, not that they mis-aimed the interaction. Same FX in reverse plus a
distinct audio cue.

---

## Storms

A storm is an authored encounter: **a weather/environment effect plus an ordered list of waves.**

All three storms are **acid storms** for now, differing only in wave count, wave composition, and
the threat-scaled difficulty of their enemies. Distinct weather identities for storms 2 and 3 are
planned as later content; the data model below is built so that replacing them is authoring work
rather than a code change.

### Storm Lifecycle

Storm entry is a **sequence, not a cutscene** — the player keeps full control throughout. Nothing
locks input, moves the camera, or walks the player anywhere.

1. **Intro** (`intro_seconds`, ~2s): the announcement shows the storm's display name; the weather
   effect fades in; ambient enemy spawning is suspended; `level_speed` tweens to 0 so the ship halts
   and the parallax stops; BGM switches to the storm category.
2. **Waves**: each wave runs to completion, then a short gap, then the next.
3. **Outro** (`outro_seconds`, ~2.5s): announcement `STORM CLEARED`; weather fades out; `level_speed`
   tweens back to normal; ambient spawning resumes; BGM returns to the in-run category.
4. Cap +1, phase → `BUILDING`, threat resumes accumulating into the newly unlocked segment.

Halting the ship is what makes the storm read as *weathering something in place*. It also
diegetically explains why salvage stops appearing and gives the intro and outro a purpose beyond a
text beat.

There is **no departure window after a storm**. The next window comes at the end of the newly
unlocked level.

### Wave Execution

- A wave is a list of **batches**. Each batch is `{profile, count}` — a specific enemy type and how
  many of it.
- Batches spawn **sequentially**, `batch_interval_seconds` apart, reusing the enemy spawner's
  existing batch placement (zone sampling, lateral spread, per-enemy threat stat scaling).
- A wave is **complete when every enemy it spawned is gone** (killed or despawned). Then
  `next_wave_delay_seconds` elapses and the next wave begins.
- Wave spawns **bypass** `EnemySpawner.max_concurrent_by_level`. The wave's authored counts are the
  encounter; a concurrency clamp would silently make waves smaller than authored and would stall
  completion tracking.
- Ambient enemies alive when the storm starts persist and can be killed, but **do not count** toward
  the wave's remaining total. Only director-spawned enemies are tracked.
- Wave enemies **scale with the current threat level** through the existing
  `EnemySpawner._threat_stat_scale`. This is the intended difficulty ramp and is why three
  mechanically identical acid storms still escalate: the same authored wave is meaningfully harder
  at level 9 than at level 3. `StormData.enemy_stat_level` overrides the scaling level when a
  specific storm needs to break the curve.

### Wave Stall Prevention

If a wave enemy never reaches the player, the wave never completes and — with departure disabled —
the run soft-locks. The fix is a **general enemy rule**, not a storm-specific timeout: an enemy is
expected to reach the screen within a reasonable time of spawning, and one that stays out of bounds
past that is despawned.

- `Enemy` gains an out-of-bounds despawn timer: while the enemy is outside the viewport (plus a
  margin), a timer accumulates; on reaching its limit the enemy frees itself. Time on screen resets
  it.
- The tunables (`out_of_bounds_despawn_seconds`, margin) live on `EnemyData` alongside the existing
  `death_pop_despawn_margin`, which already establishes this pattern — `Enemy._is_below_viewport()`
  is the precedent to generalize.
- The storm director treats `tree_exited` without `died` as removal, so a despawned enemy
  **decrements** the wave counter rather than stalling it.

This benefits ambient spawning too: a stuck or wandered-off enemy currently occupies a
`max_concurrent_by_level` slot forever.

### Weather Damage and Its Counterplay

Storm weather drain is **greatly reduced** from the current values (5 hp/s player, 8 hp/s ship),
which existed to kill in seconds. A storm now lasts minutes and is meant to be survived. The drain
is a soft clock that punishes slow wave clears, not the threat itself.

Acid drain is a **progression gate answered by healing, applied between storms rather than during
them.** The player is expected to leave a storm at roughly 40–60% health; healing — the Regeneration
augment now, the repair gun once it exists — is what recovers that during the following threat levels
so the *next* storm can be entered at full health. A run without healing therefore ratchets downward
across the three storms, which is the intended pressure.

That intent has a direct consequence: **healing must not counteract drain while the storm is
running.** Regeneration currently would. `RegenerationBehavior` heals after 6 seconds without a
`damaged` signal, and `Player.apply_storm_damage()`
([player.gd:1675](../_project/player/player.gd#L1675)) bypasses `damaged` entirely — so during any
quiet gap between waves the augment would tick and undo the drain, and the player would exit the
storm near full health instead of 40–60%.

**Fix: give `Player` a single authoritative "time since last damage" counter** that both
`take_damage()` and `apply_storm_damage()` reset, and have `RegenerationBehavior` read it instead of
connecting to a signal:

```gdscript
# player.gd
var seconds_since_damage: float          # ticked in _process, zeroed by both damage paths
```

`apply_storm_damage()` keeps bypassing the shield, the damage number, and the damage flash — it is a
continuous DoT, not a discrete hit, and per-frame flashes would be unreadable. It only additionally
zeroes the counter.

This removes the fragility rather than documenting it: any future environmental damage source
suppresses regeneration automatically, with no signal-connect lifecycle in the behavior resource.
`RegenerationBehavior` is the **only** subscriber to `Player.damaged`, so once it reads the counter
the signal has no consumers and is deleted along with it (§6 — unused signals are dead code).

**There is no repair gun and no ship healing of any kind yet.** `regeneration.tres` is player-only,
so `ship_drain_per_second` has no counterplay at all and ship damage is permanent for the rest of the
run. Keep ship drain at or near zero until the repair gun ships, and put the drain on the player
where regeneration provides an answer.

Exact numbers are playtest tuning and are not fixed here.

---

## Announcement Text

`EventTextDisplay` becomes a **two-line** component: a headline naming what is currently happening,
and a subtext line carrying live detail. The display shows one entry at a time (highest priority);
in-run events are sequential by construction and do not overlap.

It is a **shared, multi-writer surface.** Any in-run system may post to it through the public API
without knowing about the others. The contract:

- Every writer owns a **source key** and touches only its own entry. Entries are keyed by source, so
  two systems can hold entries simultaneously without clobbering each other.
- The display renders the **highest-priority** live entry. Priority is a tiebreak for the rare
  overlap, not the primary ordering — run events are sequential by design.
- A writer **clears its own source** when its event ends. Nothing else cleans up after it, and a
  stale entry will keep displaying.
- The display holds no timers, no state machine, and no knowledge of what any source means.

| Moment | Headline | Subtext |
|---|---|---|
| Window, non-storm gate | `NEW THREATS APPROACHING` | `24s   ·   [E] LEVER — CONTINUE   ·   [E] PYLONS — DEPART` |
| Window, storm gate | `STORM IMMINENT` | `24s   ·   [E] LEVER — ENTER STORM   ·   [E] PYLONS — DEPART` |
| Window expired, hold in flight | *(unchanged)* | *(cleared)* |
| Advance, non-storm | `THREAT LEVEL 4` | — |
| Storm intro | `ACID STORM` | — |
| Wave incoming | `WAVE 3 / 4` | `INCOMING IN 4s` |
| Wave active | `WAVE 3 / 4` | `REMAINING - 7` |
| Storm cleared | `STORM CLEARED` | — |
| Magnet departure | `DEPARTING` | `12s` |
| Salvage warning | `SALVAGE DETECTED` | — |

The headline stays stable across a wave's incoming → active transition; only the subtext changes.

### Timer Ownership

`EventTextDisplay` currently runs its own countdowns and calls back into the model when they finish:
`GameUI` listens for `countdown_finished(&"storm")` and calls `ThreatManager.trigger_storm()`, and
`MagnetMinigame` both reads `get_remaining(&"departure")` and departs off `countdown_finished`. In
both cases a HUD node owns run-state timing, which is why `GameUI.stop_for_run_end()` has to
defensively clear the `&"storm"` entry to stop its own HUD from storming a departing run.

**The display becomes a pure view with no timers and no signals.** Each system owns its own clock —
`ThreatManager` the window countdown, `StormController` the wave gaps, `MagnetMinigame` the
departure timer — and pushes formatted text.

```gdscript
func show_message(source: StringName, text: String, subtext: String = "",
		priority: int = 0, style: int = Style.NORMAL) -> void
func set_subtext(source: StringName, subtext: String) -> void
func clear(source: StringName) -> void
```

**Deleted:** `start_countdown()`, `get_remaining()`, the `countdown_finished` signal, and
`_process`. Fixing the magnet departure timer's ownership is a prerequisite of this rework, not
optional cleanup — it is the same inversion and it shares the same API.

### Writers

| Source | Owner | Posts | Priority |
|---|---|---|---|
| `&"threat_window"` | `ThreatManager` (via `GameUI`) | window headline + countdown/options subtext; `THREAT LEVEL N` | 100 |
| `&"storm"` | `StormController` | storm intro, per-wave headline + subtext, `STORM CLEARED` | 100 |
| `&"departure"` | `MagnetMinigame` | `DEPARTING` + remaining-seconds subtext | 50 |
| `&"salvage"` | `MagnetMinigame` | `SALVAGE DETECTED` | 30 |

`&"threat_window"` and `&"storm"` share a priority because they are strictly sequential — the window
clears before the storm posts.

---

## Data Model

### New Resources — `_project/level/threat/storms/`

```gdscript
# storm_data.gd
class_name StormData extends Resource
@export var id: StringName
@export var display_name: String = "ACID STORM"      # announcement headline
@export_range(1, 10) var gate_after_level: int = 3   # storm runs when this level's window resolves
@export var waves: Array[StormWave] = []
@export var weather: StormWeatherEffect              # null = waves only, no environment effect
@export var intro_seconds: float = 2.0
@export var outro_seconds: float = 2.5
## Threat level used for wave enemies' health/damage scaling. 0 = use the current threat level.
@export_range(0, 10) var enemy_stat_level: int = 0
```

```gdscript
# storm_wave.gd
class_name StormWave extends Resource
@export var batches: Array[StormWaveBatch] = []
@export var batch_interval_seconds: float = 3.0
@export var next_wave_delay_seconds: float = 5.0
```

```gdscript
# storm_wave_batch.gd
class_name StormWaveBatch extends Resource
@export var profile: EnemySpawnProfile               # reuses the authored per-enemy profile
@export_range(1, 99) var count: int = 3
## Zones to spawn in. Empty = use profile.allowed_spawn_zones.
@export var spawn_zones: PackedStringArray = PackedStringArray()
```

### Weather as a Behavior Resource

Weather is modeled on the **enemy behavior system**, not as a flat tunable bag. A drain-plus-vignette
struct handles acid rain but nothing else — the effects planned for storms 2 and 3 (magnet cutting
out, reduced visibility, lateral wind on the player and loose salvage) are behavior, and a tunables
resource would be rewritten within one storm of shipping.

`EnemyBehavior` ([enemy_behavior.gd](../_project/enemies/behaviors/enemy_behavior.gd)) is the shape
to mirror: a `Resource` with `setup()` / `teardown()` / `physics_tick()` against a target.

```gdscript
# storm_weather_effect.gd  —  base
class_name StormWeatherEffect extends Resource
func setup(level: Node) -> void: pass
func teardown(level: Node) -> void: pass
func tick(level: Node, delta: float) -> void: pass
```

```gdscript
# acid_rain_weather.gd  —  first (and currently only) subclass
class_name AcidRainWeather extends StormWeatherEffect
@export var player_drain_per_second: float = 0.0
@export var ship_drain_per_second: float = 0.0
@export var magnet_drain_per_second: float = 0.0
@export var vignette_color: Color = Color(0.22, 0.85, 0.18, 0.42)
@export var vignette_fade_seconds: float = 1.0
```

`StormController` calls `setup` / `tick` / `teardown` and knows nothing about acid specifically.

### Level Definition Owns the Content

`LevelDefinition` is the resource that distinguishes one playable level from another and is
currently near-empty. Both storms and the enemy roster move onto it and are **injected at runtime**,
in preparation for multiple levels:

```gdscript
# level_definition.gd
@export var level_id: StringName = &"default_level"
@export var display_name: String = "Default Level"
@export var level_scene: PackedScene
@export var storms: Array[StormData] = []
@export var enemy_profiles: Array[EnemySpawnProfile] = []
```

`RunController.start_run()` already receives the `LevelDefinition`, and `_bind_runtime()` already
resolves `StormController` and `EnemySpawner` off the level. Injection happens there:

```gdscript
_storm_controller.set_storms(_level_definition.storms)
_enemy_spawner.set_enemy_profiles(_level_definition.enemy_profiles)
```

The corresponding `@export var enemy_profiles` on `EnemySpawner` and the roster authored into
`level.tscn` are **removed** — a level's content is defined by its definition, not by whichever scene
happens to instance the spawner.

### ThreatManager Changes

```gdscript
enum Phase { BUILDING, WINDOW, STORM, BOSS }

signal threat_changed(new_value: float)              # unchanged
signal threat_level_changed(new_level: int)          # unchanged
signal window_opened(seconds: float, is_storm_gate: bool)
signal window_closed()
signal level_advanced(new_cap: int)
signal storm_started(storm: StormData)
signal storm_finished(storm: StormData)

@export var interlevel_window_seconds: float = 30.0

var phase: Phase
var is_departure_window_open: bool                   # phase == WINDOW
var window_seconds_remaining: float
func set_storm_gates(storms: Array[StormData]) -> void
func is_storm_gate_after(level: int) -> bool
func get_storm_after(level: int) -> StormData
func can_advance() -> bool
func advance() -> void                               # lever confirm AND window expiry
func set_window_hold(held: bool) -> void             # magnet minigame: don't open mid-loot
func set_departure_hold(held: bool) -> void          # pylon: don't resolve mid-hold
```

**Renames (old → new).** No aliases are kept.

| Old | New |
|---|---|
| `cap_reached` | `window_opened(seconds, is_storm_gate)` |
| `cap_raised(new_cap)` | `level_advanced(new_cap)` |
| `storm_countdown_started(seconds)` | folded into `window_opened` |
| `storm_arrived` | `storm_started(storm)` |
| `is_cap_reached` | `is_departure_window_open` (semantics narrowed) |
| `can_raise_cap()` | `can_advance()` |
| `raise_cap()` | `advance()` |
| `set_cap_hold()` | `set_window_hold()` |
| `storm_countdown_seconds` | `interlevel_window_seconds` |

**Deleted:** `trigger_storm()`, `is_storm_active` (superseded by `phase`).

### StormController — Rewritten

`StormController` stops being "the thing that drains you to death" and becomes the storm's director.
It owns the active `StormData`, the current wave index, the set of enemies it spawned, the
batch/wave/gap timers, the weather effect lifecycle, and the storm's announcement text.

The vignette construction in the current `storm_controller.gd` (`_build_vignette`, `_fade_vignette`)
moves to `AcidRainWeather`, and per §8 of the org spec the vignette itself should become an authored
node rather than a node tree built in code.

### EnemySpawner Changes

The director must not reimplement batch spawning (§6 — a helper duplicated in a second file moves to
a shared home).

```gdscript
func set_enemy_profiles(profiles: Array[EnemySpawnProfile]) -> void

## Spawn `count` enemies of `profile` as one batch, ignoring threat eligibility, magnet
## context, per-profile cooldown, and the concurrency cap. Returns the spawned enemies so
## the caller can track wave completion.
func spawn_batch_for_storm(profile: EnemySpawnProfile, count: int,
		zone_names: PackedStringArray, stat_level: int) -> Array[Enemy]

## Suspend/resume the ambient spawn pass without stopping the node.
func set_ambient_spawning_enabled(enabled: bool) -> void
```

**Deleted:** `cap_state_spawn_rate_multiplier` and its use in `_current_spawn_interval()`; the
`@export var enemy_profiles` roster (now injected).

### MagnetMinigame — Ownership Cleanup

`MagnetMinigame` currently owns the threat-advance cutscene, listens for `cap_reached`, drives
`MagnetLever.set_advance_mode()`, and calls `raise_cap()`. That is threat-progression orchestration
living inside the looting minigame, and it is the reason the advance flow spans three owners with no
coordinator.

With the cutscene gone, this all moves out:

- **Deleted:** `_play_advance_cutscene()`, `_on_advance_confirmed()`, `_walk_player_to_lever()`,
  `_advance_fade()`, `_ensure_advance_fade_overlay()`, the `AdvanceFadeLayer` canvas, and the entire
  `@export_group("Advance Cutscene")` block.
- **Kept:** `set_window_hold()` per-frame sync and the spawn freeze on window open.
- **Changed:** the departure timer becomes self-owned (see *Timer Ownership*).
- **Moved to `ThreatManager`:** `MagnetLever.set_advance_mode()` toggling and the `advance_confirmed`
  → advance wiring.

---

## Threat Bar UI

### Storm Gate Icon

`ThreatUI` currently draws a single `LockIcon` at the cap boundary. It gains a **storm icon**
(`_project/hud/threat/sprites/threatbar_icon_storm.png`) shown in place of the lock when the cap
boundary is a storm gate — i.e. when `ThreatManager.is_storm_gate_after(cap_level)` is true.

The existing `_position_lock_icon()` math already places the icon at
`_locked_overlay.position.x + (reachable / segments) * _locked_overlay.size.x`, so this generalizes
to a `_position_gate_icon(boundary_index, texture)` with no new geometry work.

**Note on the dip:** `_position_lock_icon()` drops to `lock_icon_dip_y` at the central boundary
(`reachable * 2 == segment_count`, i.e. after level 5). Storm gates sit after levels 3, 6, and 9 —
never 5 — so the storm icon always uses the flat `lock_icon_y`. The dip case remains for the plain
lock icon at cap 5.

### Persistent Gate Markers

Design goal 2 wants the run's shape legible from level 1. Beyond swapping the icon at the *current*
cap boundary, draw **dim, non-interactive storm markers at all three gate boundaries** (3|4, 6|7,
9|10) for the whole run, on top of the locked overlay. The player sees "there are three storms and
they are there" before the first one arrives. The same `_position_gate_icon` handles them.

### During a Storm

The ticker parks at the gate boundary (threat is paused) and the gate's storm icon animates — pulse,
flicker, or a subtle shake — so the bar reads as "held at the gate, storm in progress" rather than
"frozen / broken".

---

## Audio

| Event | Behavior |
|---|---|
| `storm_started` | BGM → `BgmPlayer.Category.STORM` |
| `storm_finished` | BGM → `BgmPlayer.Category.IN_RUN` |
| Window open / close | **No category change.** A 30-second track switch either side of a decision beat would thrash. |
| Pylons arm / disarm | One-shot sting (rising hum / power-down whine), which doubles as the window's audio identity |

---

## File Impact

### New Files

| File | Purpose |
|---|---|
| `_project/level/threat/storms/storm_data.gd` | `StormData` — identity, gate level, waves, weather |
| `_project/level/threat/storms/storm_wave.gd` | `StormWave` — batches + pacing |
| `_project/level/threat/storms/storm_wave_batch.gd` | `StormWaveBatch` — `{profile, count, zones}` |
| `_project/level/threat/storms/storm_weather_effect.gd` | `StormWeatherEffect` behavior base |
| `_project/level/threat/storms/acid_rain_weather.gd` | `AcidRainWeather` — drain + vignette |
| `_project/level/threat/storms/storm_1.tres` … `storm_3.tres` | The three authored acid storms |
| `_project/level/threat/storm_controller.tscn` | Director scene (vignette authored, not built in code — §8) |
| `_project/hud/threat/sprites/threatbar_icon_storm.png` | Storm gate icon |
| `_project/ship/departure_pylon/sprites/` | Armed-pylon FX art |

### Modified Files

| File | Change |
|---|---|
| [threat_manager.gd](../_project/level/threat/threat_manager.gd) | Phase machine; owns the window timer; gate lookup from injected storms; departure-hold suspension; signal renames; delete `trigger_storm` |
| [storm_controller.gd](../_project/level/threat/storm_controller.gd) | Rewritten as the wave director; weather delegated to `StormWeatherEffect` |
| [enemy_spawner.gd](../_project/enemies/spawning/enemy_spawner.gd) | `set_enemy_profiles`, `spawn_batch_for_storm`, `set_ambient_spawning_enabled`; delete `cap_state_spawn_rate_multiplier` and the authored roster |
| [enemy.gd](../_project/enemies/enemy.gd) | Out-of-bounds despawn timer (generalizes `_is_below_viewport`) |
| [enemy_data.gd](../_project/enemies/enemy_data.gd) | `out_of_bounds_despawn_seconds` + margin tunables |
| [player.gd](../_project/player/player.gd) | `seconds_since_damage` counter reset by `take_damage` **and** `apply_storm_damage`; delete the now-unsubscribed `damaged` signal |
| [regeneration_behavior.gd](../_project/items/augments/regeneration_behavior.gd) | Read `Player.seconds_since_damage` instead of connecting to `damaged`; drop the connect/disconnect lifecycle |
| [level_definition.gd](../_project/level/level_definition.gd) | `storms` + `enemy_profiles` arrays |
| [salvage_spawner.gd](../_project/salvage/salvage_spawner.gd) | Freeze condition re-pointed from `is_cap_reached` to phase `!= BUILDING` |
| [magnet_minigame.gd](../_project/level/magnet_minigame/magnet_minigame.gd) | Delete the advance cutscene and advance-mode ownership; self-owned departure timer; keep window hold + spawn freeze |
| [magnet_lever.gd](../_project/ship/magnet/magnet_lever.gd) | Advance mode driven by `ThreatManager`; single-press at normal gates, `ENTER STORM?` confirm at storm gates |
| [departure_pylon.gd](../_project/ship/departure_pylon/departure_pylon.gd) | Armed/inert visual state; report hold state to `ThreatManager` |
| `departure_pylon.tscn` | Authored FX nodes + `AnimationPlayer` (`power_up` / `armed_loop` / `power_down`) |
| [ship.gd](../_project/ship/ship.gd) | `ShipGens` inert/armed animation; keep hover outline as a separate layer |
| [run_controller.gd](../_project/run/run_controller.gd) | Inject storms + enemy profiles from the level definition; `can_accept_departure_request()` gates on the window; signal renames; BGM |
| [game_ui.gd](../_project/hud/game_ui.gd) | Renders window text; owns no timers and no model callbacks |
| [event_text_display.gd](../_project/hud/event_text_display.gd) + `.tscn` | Two-line layout; timers and `countdown_finished` deleted |
| [threat_ui.gd](../_project/hud/threat/threat_ui.gd) + `.tscn` | Storm gate icon; persistent gate markers; storm-active animation |
| [level.tscn](../_project/level/level.tscn) | Remove the authored `enemy_profiles` roster and the `storm_countdown_seconds = 60.0` override |

---

## Recommended Implementation Order

1. **`ThreatManager` phase machine.** Replace the cap-reached booleans with `Phase`, move the window
   countdown into the manager, add the new signals and the gate-lookup API. Storms not wired yet — a
   storm gate behaves like a normal gate. Rename call sites across the spawners, `ThreatUI`,
   `GameUI`, `MagnetMinigame`, and `RunController` in the same change.
2. **Remove the advance cutscene** from `MagnetMinigame`; move lever advance-mode ownership onto the
   manager. At this point the run plays as 10 levels separated by 30-second windows, no storms.
3. **`EventTextDisplay` two-line rework**, including moving the departure timer's clock into
   `MagnetMinigame` and deleting the display's timers and signal.
4. **Departure gating** + the hold-priority rule. Verify the highlight and `&"end_run"` prompt go
   dark outside the window, and that a hold started at 1s still succeeds.
5. **Armed pylon visuals.** This is the discoverability work and should land before storms so the
   window is fully readable on its own.
6. **`LevelDefinition` injection** for `enemy_profiles` (storms follow in step 7). Doing the enemy
   roster first proves the injection path against an existing system.
7. **Storm data model** — the four resource scripts, `AcidRainWeather`, and one placeholder
   `storm_1.tres` with two short waves, injected from the level definition.
8. **`EnemySpawner` storm API** (`spawn_batch_for_storm`, `set_ambient_spawning_enabled`).
9. **`StormController` rewrite:** wave/batch sequencing, completion tracking, gap timers, wave
   announcement text, ship halt/resume, weather lifecycle. Includes the `Player.seconds_since_damage`
   refactor so drain suppresses regeneration for the duration of the storm.
10. **Enemy out-of-bounds despawn** on `Enemy`/`EnemyData`, and the director's `tree_exited`
    handling. Do this before authoring real waves — it is a soft-lock guard, not polish.
11. **Threat bar:** storm gate icon, persistent gate markers, storm-active animation.
12. **Author storms 2 and 3** (3 / 4 / 5 waves as a starting point) and tune composition, pacing, and
    drain.
13. **Verify a full run:** all nine windows, all three exits from a window, all three storms cleared,
    death during a storm, departure from a storm window, and a hold that starts in the last second.
    Confirm the window never opens mid-loot, that regeneration is suppressed for the whole storm, and
    that it resumes and recovers the lost health during the threat levels that follow.

---

## Resolved Decisions

1. Storms replace the acid-storm-as-death-timer entirely. Three storms gate the run after levels 3,
   6, and 9; the gate set is derived from authored data, not hardcoded.
2. Every threat level ends in a 30-second interlevel window with three exits: wait (auto-advance),
   lever (advance now), pylons (depart). Storm gates use the same window with different text.
3. Non-storm advances have **no cutscene**. Storm entry is a sequence that never restricts player
   input: the ship halts, the announcement plays, then waves begin.
4. Departure is possible **only** during the window. No mid-storm bailout, and no window after a
   storm clears.
5. A departure hold in progress suspends window resolution — a hold started with one second left
   still succeeds. At expiry the announcement's subtext clears, leaving the headline.
6. All three storms are acid storms for now, differing by wave count and threat-scaled difficulty.
   Distinct weather for storms 2 and 3 is later content.
7. Weather is a **behavior resource** (`StormWeatherEffect` + `AcidRainWeather`) modeled on
   `EnemyBehavior`, not a flat tunable struct.
8. Acid drain is greatly reduced from current values. Healing (the Regeneration augment now, the
   repair gun later) answers it **between** storms, not during them: the player exits a storm at
   ~40–60% and recovers across the following threat levels. Healing is suppressed while drain is
   active, via a `Player`-owned time-since-damage counter that both damage paths reset.
9. The ship halts (`level_speed` → 0) for the duration of a storm.
10. Ambient enemy spawning continues at the normal rate during a window and is **suspended** during a
    storm. Waiting out a window has no additional cost.
11. Only director-spawned enemies count toward a wave's remaining total. Pre-existing ambient enemies
    persist but do not block wave completion.
12. Wave stalls are prevented by a **general enemy rule**: an enemy that stays out of bounds too long
    after spawning is despawned, and despawns decrement the wave counter.
13. Wave enemies scale with the current threat level; `StormData.enemy_stat_level` overrides it.
14. The lever advances on a single press at normal gates and requires a two-press `ENTER STORM?`
    confirm at storm gates. Prompt text varies by state.
15. `EventTextDisplay` is a two-line pure view — headline plus subtext — owning no timers and no
    model callbacks. It is a shared, source-keyed, multi-writer API: each system owns its own clock,
    posts to its own source, and clears it when done.
16. Storms **and** the enemy roster live on `LevelDefinition` and are injected into
    `StormController` / `EnemySpawner` at runtime, in preparation for multiple levels.
17. Threat bar: the lock icon becomes a storm icon at storm gates, with dim persistent markers at all
    three gate boundaries for the whole run.
18. BGM switches on storm start/end only; the window gets audio stings rather than a track change.
19. Run length is not budgeted. The player dictates run duration; longer runs are an intended
    outcome, and the previous spec's 20-minute target no longer applies.
20. Level 10 is the boss (TBD). A `BOSS` phase is reserved; the interim terminus is a depart-only
    window at the level-10 ceiling.

---

## Remaining Gaps

- **Storm 2 and 3 weather identities.** Deferred content. Candidates worth prototyping against the
  `StormWeatherEffect` interface: an ion storm (magnet tool cutting out, forcing weapon play), a
  whiteout (heavy screen-edge occlusion), high winds (lateral force on the player and loose salvage).
- **Drain numbers.** Playtest tuning. Constrained by the fact that the ship has no healing at all
  until the repair gun exists — until then, ship drain should be at or near zero.
- **Wave composition.** 3 / 4 / 5 waves is a starting point, not a design. This is `.tres` authoring
  and belongs in the editor.
- **Boss fight.** Entirely out of scope; only the phase value and the interim terminus are specified.
