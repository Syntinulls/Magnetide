# Lever Minigame Modifiers

Every lever minigame attempt may roll a modifier that changes how the pull
plays: new zones, altered on-hit behavior, and consequences that reach outside
the panel. With no modifier rolled the minigame plays exactly as before. As part
of this feature the lever minigame moved out of `_project/level/magnet_minigame/`
into its own `_project/level/lever_minigame/` folder (scripts, scene, glow
materials, vignette shader, and sprites), keeping the two minigames separate;
`magnet_minigame/` keeps only the looting-cycle orchestrator and the warning
icon.

## Rolling

- `LeverModifierWeights` (`modifiers/lever_modifier_weights.gd`, authored as
  `modifiers/lever_modifier_weights.tres`, wired to the `modifier_weights`
  export in `lever_minigame.tscn`) holds three weighted pools: **none**,
  **positive**, and **negative**. Weights are relative float scalars, not
  percentages — a pool's chance is its weight over the total at that threat,
  derived at roll time by `WeightedRandom` (the same shape as
  `SalvageRarityWeights`).
- None and positive weights hold constant over threat. Only the negative pool
  scales: `negative_base_weight + negative_weight_per_stage × stage` (zero-based
  threat stage 0–9), so bad pulls get likelier as threat climbs without the good
  ones getting rarer in absolute weight.
- `roll_modifier(threat)` rolls the pool, then picks uniformly inside it. The
  none pool (or an empty winning pool) yields null — no modifier.
- **LeverMinigame orchestrates itself**: `start_minigame(threat_level)` rolls
  from its own `modifier_weights` export. MagnetMinigame is untouched — it still
  just starts the minigame and reacts to `minigame_completed`.

## Modifier architecture

`LeverModifierBehavior` (`modifiers/lever_modifier_behavior.gd`) is a Resource
strategy base; each modifier is a script subclass plus an authored `.tres`
carrying its tuning. The minigame never branches on modifier identity — all
modifier-specific zones, strings, colors, and rewards live in the subclass,
reaching the minigame through four hooks:

- `on_minigame_started(minigame, threat)` — before zones build; per-attempt
  state resets here (`.tres` instances are shared across attempts).
- `modify_zones(minigame, threat)` — after the base ratio layout exists, before
  any zone controls are built; insert special zones or tag existing ones.
- `handle_press(minigame, zone) -> bool` — first crack at every press; returning
  true consumes it and skips the default green/yellow/red routing.
- `on_minigame_closed(minigame, success)` — once, after the panel has closed and
  the presentation effects are unwound (never on cancel); outside-world
  consequences (scrap awards, spawns) go here.

Supporting minigame surface (public API): `show_info`, `flash_zone`,
`fail_minigame(text, color)` (the full red-fail treatment with custom text),
`scale_for_threat`, `get_zones`, `split_zone` (in-place carve that keeps `_zones`
sorted, since zone controls derive pixel widths from consecutive ratios), and
`get_focus_world_position` (the camera focus point just above screen center,
used as a pickup origin). `Zone` gained two generic fields: `custom_color`
(alpha-0 sentinel means "use the type color") and `icon` (a centered overlay
child of the zone control, so it inherits the reveal alpha and hit bounce — the
parent modulate also tints it toward the zone color, acceptable for the current
placeholder icons). `ZoneType` gained one generic `SPECIAL` entry rather than
per-modifier types; special zones are blue or purple by convention, carry
`pair_index -1`, never join `_pairs`, and reveal on the green beat of the setup
sequence.

With a modifier present the setup sequence is unchanged except the banner: the
modifier's `display_name`/`display_color` pops through the shared info label the
moment the panel opens, decaying on the standard timer or overwritten by the
3-2-1 countdown like any other info text.

## Bonus! (positive)

`modifiers/bonus_modifier_behavior.gd` / `.tres`. Banner "Bonus!" in blue.

- Adds one special blue zone with a centered icon, placed at the midpoint of a
  random **interior** red gap — a red zone whose array neighbors are both
  yellow, which structurally excludes the first/last red and lands the zone
  centered between two adjacent green clusters. Gaps narrower than 1.5× the
  authored zone width are skipped; if every gap is too narrow the widest one is
  used with the zone shrunk to 60% of it, and a board with no interior gaps
  (impossible at the current minimum of two pairs) leaves the modifier inert.
- Hitting it is optional — it is not a pair, so completion is untouched and
  letting it slip past costs nothing. The first press flashes the zone and pops
  "Bonus Hit!" in blue; repeat presses on it are consumed and ignored.
- If it was hit **and** the attempt succeeds, a scrap amount rolled between
  `scrap_min`/`scrap_max` is awarded after the panel closes: one
  `PlayerScrapCollector.collect_from(origin)` call per scrap from the minigame's
  focus point above screen center — the same fly-to-HUD pickup path the recycler
  uses (deliberately not `collect_recycled`, whose double-scrap roll is a
  recycler perk). A failed attempt forfeits the bonus.

## Mines! (negative)

`modifiers/mines_modifier_behavior.gd` / `.tres`. Banner "Mines!" in red.

- A threat-scaled count of yellow zones (`mines_min` at stage 0 to `mines_max`
  at stage 9, clamped to the yellows on the board) arm as mines, selected
  without replacement and marked with a centered icon.
- Pressing a mined yellow is treated exactly like pressing red — the full
  instant-fail treatment via `fail_minigame` — but reads "Boom!" instead of
  "MISS". Clean yellows still resolve as "CLOSE", and a mined pair stays
  winnable through its green or its other yellow.

## Lifecycle safety

The active modifier is nulled by `_reset_state` (so `cancel_minigame` — run-end
aborts included — can never award later) and after `on_minigame_closed` fires at
the end of the result linger. The close hook runs after `minigame_completed`
emits, so MagnetMinigame's handler has already restored player input and the
world is live when rewards land.
