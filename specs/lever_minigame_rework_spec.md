# Lever Minigame Rework

The activation minigame played when braking for salvage is rebuilt for better feel:
a crosshair reticle sweeps left-to-right at constant speed across a bar of visible
green/yellow/red zones, replacing the accelerating cog swept over pop-in markers.
The old implementation (`activation_minigame.gd`, fully code-built UI) is deleted;
the new one is `LeverMinigame` (`lever_minigame.gd` + authored `lever_minigame.tscn`
in `_project/level/magnet_minigame/`), a self-contained CanvasLayer scene instanced
in level.tscn that owns both the minigame UI and the whole activation presentation
(timescale slowdown, camera zoom, grayscale vignette).

## Mechanic

1. Flipping the lever during a salvage warning starts the minigame exactly as before
   (time slows to 0.01, grayscale/vignette fades in, player input disabled).
2. The bar opens **empty**. After a 0.5s hold the board is dealt on 0.5s beats:
   green zones, then the flanking yellows, then the red filler. One beat after
   the reds, a **3-2-1 countdown** plays (0.6s per digit, real time), and "Go!"
   pops in green (decaying like every other info text) as the sweep begins.
3. The crosshair reticle sweeps the bar left→right at a constant speed
   (0.35 bar-widths/s). Pressing `interact` evaluates the zone under the
   reticle center:
   - **Green** — that pair's light turns green, "PERFECT" pops in green.
   - **Yellow** — the pair's light turns yellow, "CLOSE" pops in yellow, and the
     reticle speed is multiplied by (1 + 0.1 × yellow hits): 1.1x at one yellow,
     1.2x at two, and so on for the rest of the sweep. Yellows never fail the
     attempt (the old threat-scaled yellow allowance is dropped; escalating
     speed is the only penalty).
   - **Red** — every light turns red, "MISS" pops in red, the reticle halts, and
     after 0.6s the minigame closes as a failure.
   - Letting the reticle fully pass an unresolved green+yellows cluster is an
     instant fail identical to pressing red.
   - A press inside an already-resolved pair's zones is ignored.
4. Reaching the right edge is a success by construction (every pair must have been
   resolved or the sweep would have already failed). The board lingers 0.75s
   (scene override), then closes and reports `minigame_completed(success)`.

## Zones and pairs

- Pair count = green zone count, threat-scaled 2→5 over threat stages 0→9
  (same `_scale_for_threat` lerp as before).
- Base zone widths at threat stage 0: green 4% of the bar, yellow 6% per side.
  Both shrink by the same threat-lerped factor (1.0 at stage 0 down to 1/3 at
  stage 9 — yellow ends at 2%, green at ~1.33%), keeping the green:yellow ratio
  constant while the growing zone count doesn't crowd out the red. Cluster
  width runs 0.16 at min threat down to ~0.053 at max.
- Green centers are rejection-sampled with a minimum center spacing of 0.20
  (> cluster width, so clusters never overlap and keep at least a 4% red gap)
  and an edge margin of 0.10. If sampling can't place every center in 100
  attempts, the centers fall back to deterministic even spacing. Note the
  spacing exactly fills the bar at max threat: 2·0.10 + 4·0.20 = 1.0, so
  5-pair boards always use the even-spacing fallback.
- Red zones fill all remaining space; zero-width segments are skipped.
- Zones are HBox children with a cosmetic 1px separation; child pixel widths are
  derived from the ratio boundaries, but hit detection uses the ratios, so the 1px
  gaps create no dead zones. Zone visuals: tiled hazard-stripe background inset 3px
  inside a `ui_border_4px_white` nine-patch; the whole zone control is modulated to
  the zone color (tinting stripes and border alike), with alpha 0 until its reveal
  step (hiding HBox children would collapse the layout).
- One result light per pair sits below the bar at the green zone's center x
  (off / green / yellow / red sprites).

## Authored scene

```
LeverMinigame (CanvasLayer 110, PROCESS_MODE_ALWAYS, script lever_minigame.gd)
├── VignetteLayer (CanvasLayer 100)
│   └── Vignette              full-rect ColorRect with the grayscale/vignette
│                             ShaderMaterial (authored, params start at 0)
├── InfoLabel                 750x34, 10px above the panel; countdown digits and
│                             PERFECT/CLOSE/MISS share it
└── OuterPanel                750x100, bottom edge at the anchor point
    ├── Fill                  #5f6969, inset 3px
    ├── InnerPanel            anchored 8px left/top/right, 56px high: InnerFill
    │                         #1e2323 (inset 3), ZoneRow (HBox, separation 1),
    │                         InnerBorder (ui_border_3px, margins 6), Reticle
    │                         (crosshair.png, code-driven x)
    ├── LightsRow             anchored below InnerPanel (4px gap), 24px high;
    │                         plain Control, lights positioned by code
    └── Border                ui_border_4px, margins 6
```

The scene is instanced in level.tscn as a root-level node beside MagnetMinigame
(`player_path` wired to `../Ship/Player`) and brings its own render layers: the
panel on canvas layer 110 (excluded from the grayscale), the vignette on 100
(above the HUD's layer 10, below the panel). Nothing minigame-related lives in
game_ui.tscn anymore.

Zone children and lights are runtime N-lists and stay code-generated (spec §8);
everything static is authored. Two structural notes: the lights row deviates from
the design notes' HBoxContainer because lights must sit at arbitrary zone-center
x positions, and the rows are anchored rather than VBox-managed because hidden
Containers defer layout — zones are built while the panel is still hidden, so
`ZoneRow.size` must be valid without a container sort. Nine-patch margins are 6
on all ui_border textures (1px transparent bleed + stroke + 1px to crop the
antialiased edge pixel).

## Info text

Every update kills the running tween and replays: center-pivot scale 0→1 over
0.18s TRANS_BACK/EASE_OUT, hold 1.5s, then scale→0 over 0.15s. The tween's
`speed_scale` is re-set to `1/Engine.time_scale` every frame so it runs at
wall-clock speed through the slowdown.

## Presentation ownership, placement, and camera

- **LeverMinigame owns the entire activation presentation**: the timescale
  slowdown (`activation_timescale` 0.01 over `timescale_slowdown_time` 1.0s,
  restored instantly on completion/cancel), the camera zoom, and the
  grayscale/vignette fade (`vignette_intensity` 0.8) — all exports on the
  minigame, all started by `start_minigame` and unwound by completion or
  `cancel_minigame`. `MagnetMinigame` only orchestrates the looting cycle:
  starts the minigame with the threat level, freezes player input and position,
  ratchets the lever on `pair_resolved`, and reacts to `minigame_completed`.
- The panel is HUD-canvas UI (crisp 750×100 authoring), but presented as a world
  object: the minigame computes its own zoom focus point (current horizontal
  view center at `zoom_focus_offset_y`, default -80, above the player from
  `player_path`) and every frame glues the panel's bottom-center to it through
  the canvas transform while matching layer `scale` to the camera zoom ratio.
  It zooms in with the world, scaling about its bottom-center, and ends
  bottom-centered on screen at the zoomed scale.
- Camera: activation zoom **1.5×** over **0.6s** TRANS_CUBIC (restore takes
  half); the zoom refocuses **vertically only** — the horizontal framing never
  moves. The camera is found via `get_viewport().get_camera_2d()`; original
  zoom/offset are captured at minigame start and restored after.

## Integration contract

- `start_minigame(threat_level)` and `cancel_minigame()` unchanged.
- `minigame_completed(success: bool)` unchanged (drives pile spawn, deceleration
  or cooldown in `MagnetMinigame`).
- `marker_hit_success(marker_index, total_markers)` → `pair_resolved(pair_index,
  total_pairs)`, still emitted on both green and yellow resolutions in left-to-right
  order; `MagnetMinigame._on_pair_resolved` ratchets the lever handle 1/total per
  pair and plays the generic/final pull sfx.
- Dead export `timescale_speedup_time` deleted (timescale restore was always
  instant).

## Deleted legacy

`activation_minigame.gd` (+`.uid`), sprites `bar.png`, `cog.png`,
`marker_animation.png`, `icon_chevron.png`, `icon_neutral.png`,
`icon_success.png`, `icon_failure.png` (+`.import`s), the game_ui.tscn script
overrides (`marker_appear_delay`, `cog_max_speed_ratio`, `cog_accel_time`), and
the ship anchor Marker2D. New sprites were renamed on intake
(`minigame_lever_*` → `crosshair/light_off/light_on_*/stripes_50`).
