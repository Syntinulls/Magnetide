# Lever Minigame: Modifier-Owned Boards

The lever minigame's board — which zones exist, how wide they are, and what has to
be hit — used to be hardcoded in `_build_zones`: a threat-scaled count of green
zones, each flanked by two yellows, with red filling the rest. A modifier could
only decorate that board afterwards. That ceiling is gone: the rolled
`LeverModifierBehavior` now builds the board, composing it from primitives the
minigame exposes. With no modifier rolled the minigame builds the same standard
board it always did.

## Objectives replace pairs

`Pair` (one green plus its two yellows) generalised into `Objective`: a required
hit somewhere on the bar, plus the result light that reports it.

```gdscript
class Objective:
	var resolved: bool
	var light_center_ratio: float   # where the light sits under the bar
	var deadline_ratio: float       # crossing this unresolved is a miss
	var light: TextureRect
	var light_glow: ShaderMaterial
```

`Zone.objective_index` points a zone at the objective it answers to, or -1 for one
that answers to none (every red, and the optional SPECIAL zones modifiers
scatter). Nothing about the miss check or the win condition changed — they were
already written against this shape. The signal `pair_resolved` became
`objective_resolved(objective_index, total_objectives)`; `MagnetMinigame` still
ratchets the lever 1/total per resolve.

An objective is no longer one-zone-one-light: Gate's key run is several zones
answering to a single objective whose light is centered under the whole run.

## Board building

`_build_zones` is now three steps:

1. `modifier.build_board(minigame, threat)` — or `build_default_board` when no
   modifier rolled. Places only the zones that mean something.
2. `_close_board()` — sorts the zones left-to-right and fills every span nobody
   claimed with red, out to the end of the bar. Red is never a board builder's
   problem, and `_zones` is guaranteed sorted and contiguous for the pixel build.
3. `modifier.modify_zones(minigame, threat)` — decorates the finished layout
   (icons, carved-in SPECIAL zones) before any control exists.

Public primitives a board builder composes:

| Method | |
|---|---|
| `build_default_board(threat, pair_min, pair_max)` | The standard clusters, with the count range as an argument so a modifier can cap it lower. |
| `append_zone(type, start, end, objective_index := -1) -> Zone` | Any order; `_close_board` sorts. Zero-width zones are dropped. |
| `add_objective(light_center_ratio, deadline_ratio) -> int` | Returns the index zones pass back. |
| `generate_centers(count, spacing_ratio, edge_margin_ratio)` | Rejection sampling with an even-spacing fallback. |
| `get_zone_width_scale(threat)` / `lerp_for_threat(threat, min, max)` / `scale_for_threat(threat, min, max)` | Threat curves, so a custom board tightens with threat the same way the default one does. |
| `get_interior_red_zones()` / `insert_special_zone(target, width, color, icon)` | Placing an optional zone in a gap between clusters, never in the edge reds. Shared by Bonus and Recover. |
| `resolve_objective(zone, perfect)` | Lighting an objective from `handle_press`, for zones that are not green or yellow. |
| `set_zone_icon(zone, texture)` / `set_zone_icon_modulate(zone, color)` | Changing an icon mid-attempt. |

## Two new hooks

`build_board` and `modify_zones` are joined by:

- `on_countdown_finished(minigame, threat)` — the "Go!" moment, where a modifier
  locks in anything it was teasing during setup.
- `on_process(minigame, real_delta)` — every frame the minigame is active, at
  wall-clock delta (the activation slowdown is already divided out).

## Zone tint

A zone control's `modulate` now carries reveal alpha only; the zone colour moved
to `self_modulate` on the stripes and border individually (`Zone.tint_targets`).
An icon is still a child of the control, so it inherits the reveal and the hit
bounce, but it is no longer tinted toward the zone colour — Recover tells its two
kinds apart by icon and Gate colours its keys, and both need the icon's own
colour to read true.

## Recover! (positive)

`modifiers/recover/`. Banner in blue.

- Builds the default board capped at `cluster_max` (3) rather than the minigame's
  5, so a Recover pull is shorter than a normal one at the same threat.
- Scatters a threat-scaled 1–2 blue SPECIAL zones through the interior red gaps,
  each rolling a kind — player health or ship integrity — and taking that kind's
  icon. Optional: no objective, so skipping one costs nothing.
- Every zone hit pays out after a successful attempt, `Player.heal` or
  `Ship.repair`, at an amount lerped between the kind's stage-0 and stage-9
  exports. A failed attempt forfeits them all.

## Invert! (positive)

`modifiers/invert/`. Banner in green.

- Only `build_board` is overridden: each cluster is a wide yellow flanked by two
  narrow greens instead of a narrow green flanked by two wide yellows. Only the
  positions swap — each colour keeps the width it is authored at — so the perfect
  windows move to the cluster edges and the forgiving middle sits where the green
  used to be. Count, threat scaling, lights, and the win condition are unchanged.

## Ambush! (negative)

`modifiers/ambush/`. Banner in red.

- Standard board with a threat icon on every red zone. The pull itself plays
  exactly as normal; the whole consequence is off-panel.
- Any failure spawns a single enemy batch once the panel has closed, via
  `EnemySpawner.spawn_batch_for_storm` — the same call the storm controller
  makes, which bypasses the concurrency cap and per-profile cooldown. Batch size
  lerps between the stage-0 and stage-9 exports; which enemies can appear scales
  for free, since the spawner's profiles gate themselves by threat level (note
  they speak the player-facing 1–10 value, while the minigame hooks speak the
  zero-based 0–9 stage).

## Gate! (negative)

`modifiers/gate/`. Banner in purple.

- Replaces the board outright: a threat-scaled 2–4 blue key zones in a run on the
  left, one purple gate zone on the right, red everywhere else. Two objectives —
  the whole key run answers to the first, whose light is centered under it and
  whose deadline is the last key's right edge; the gate answers to the second.
  All of them are `SPECIAL`, so the default press routing ignores them and
  `handle_press` owns them completely.
- Threat adds keys and nothing else. Alone among the boards, Gate's zones hold
  their authored width at every stage rather than narrowing with threat: a key is
  read by the colour of the icon inside it, and the icon is sized by the zone it
  sits in, so a zone that shrank with threat would shrink the tell with it. The
  widths are set so the icon fills the bar's height instead.
- The gate's colour is drawn in `on_minigame_started` and shown fixed from the
  moment its padlock appears, so it is settled before the countdown begins and
  the player has the whole countdown to take it in. Only the keys cycle: through
  zone reveal and the countdown, `on_process` steps their icons through the
  candidate colours on staggered offsets.
- On "Go!", `on_countdown_finished` deals each key a different colour, swapping
  the gate's into the slot of the key that will open it — with fewer keys than
  candidates a plain shuffle could otherwise leave the gate's colour off the
  board entirely, leaving the pull unwinnable. That key is the only one that
  opens it.
- Hitting the right key resolves the keys objective and flips the gate's padlock
  from closed to open; hitting the gate after that resolves the second and wins
  the pull at the end of the bar. A wrong key fails instantly with its own text,
  and a red press or either deadline slipping past fails through the normal path.
- The candidate colour list caps the key count: every key must take a different
  one.

## Per-modifier folders

Each modifier now owns a folder under `modifiers/` (`bonus/`, `mines/`,
`recover/`, `invert/`, `ambush/`, `gate/`), matching `enemies/worm/` and
`effects/burning/`, so a modifier's sprites live with it. `LeverModifierBehavior`
and `LeverModifierWeights` stay at the `modifiers/` root. Registration is still an
inspector edit to `lever_modifier_weights.tres`.

The closed and open padlock sprites moved to `_project/common/sprites/icon_lock.png`
and `icon_lock_open.png`: with the threat bar, the station's upgrade slots, and
Gate all drawing them, they have consumers in three different concepts.
