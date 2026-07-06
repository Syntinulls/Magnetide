# Mosquito Enemy

A flying, ranged enemy that flies in horizontally, hovers at a fixed distance
from the player, and fires needle projectiles. The first enemy in the game that
attacks at range.

## Behavior summary

- **Spawn**: only from the left/right spawn zones (`SpawnW/WNW/WSW`, `SpawnE/ENE/ESE`)
  so it drifts in from a screen edge. Eligible whether or not the magnet is active
  (`can_spawn_magnet_active` and `can_spawn_magnet_idle` both true). Unlocks at
  threat level 2.
- **Approach**: flies toward the player until it reaches `hover_distance`.
- **Hover + fire**: once inside `hover_distance` it holds position and runs the
  windup → shoot → recover loop, keeping it in the first/third quarter of the
  screen (between the ship at center and the edge it entered from).
- **Hysteresis**: it will not resume approaching until the player pulls beyond
  `hover_distance + resume_margin`. This is the "move marginally away to make it
  chase again" rule and prevents boundary jitter.

## Structure (modular system)

The mosquito subclasses `Enemy` rather than reusing the generic `enemy.tscn`,
because it needs a second sprite (the wings) and shared hover state. Everything
else rides the existing behavior-resource system.

```
enemies/mosquito/
├── mosquito.gd                            Enemy subclass: wings, flip, hover hysteresis
├── mosquito.tscn                          WingBack + body Sprite + WingFore + Hitbox
├── mosquito_move_behavior.gd              approach-only MoveBehavior
├── mosquito_attack_behavior.gd            windup/shoot/recover AttackBehavior, fires needle
├── mosquito_data.tres                     EnemyData (stats + behavior subresources)
├── mosquito_spawn_profile.tres            zones, threat, magnet eligibility
├── mosquito_sprite_frames.tres            BODY frames: idle/move/windup/attack/death
├── mosquito_wing_back_sprite_frames.tres  BACK wing: fly (4-frame) + dead
├── mosquito_wing_fore_sprite_frames.tres  FORE wing: fly (4-frame) + dead
└── sprites/                               source art (256x192 canvas; wing sheets 1024x192)
```

- `mosquito.gd` owns `is_holding_position()`; both behaviors read it. The move
  behavior only runs while approaching (the base `Enemy` state machine hands off
  to ATTACK once holding begins), and `MosquitoAttackBehavior.can_attack()` is
  gated on the same flag.
- **Wings** are two sibling `AnimatedSprite2D` layers, `WingBack` (drawn before
  the body) and `WingFore` (drawn after), both always playing the 4-frame `fly`
  flap; on death they swap to their single `dead` frame. Every wing frame shares
  the body's 256x192 canvas, but the body art shifts within that canvas between
  states (idle/windup/shoot/death), so `mosquito.gd` re-anchors both wings each
  frame via `wing_frame_offsets` — a map of body-animation-name → per-frame
  `Vector2` — to keep them pinned to the body's wing joint. The offset's x is
  mirrored when the mosquito faces right.
- **Facing** uses horizontal flipping, not rotation: the art faces right, so the
  body and both wings set `flip_h` when the target is on the left. `mosquito.gd`
  overrides `face_current_target()` so the shared behaviors get flip for free.
- **Needle** reuses `combat/projectile.gd` (`Projectile.spawn`) with the
  `enemy_2_projectile_needle` texture (up-pointing, matching the projectile
  sprite convention). Its `collision_mask` includes the player Hitbox layer. It
  spawns from a `Muzzle` (`Marker2D`) marker on the scene, whose local x is
  mirrored with the flip so it stays at the mouth in both facings.

## Collision wiring

The player's damage-receiving `Hitbox` was `collision_layer = 0` (nothing could
hit it — melee enemies call `take_damage` directly). It is now on **layer bit 4
(value 8)**, and the needle projectile's `collision_mask` is 8. Player bullets
(mask 4) still ignore the player. If more enemy projectiles are added, keep them
on this same mask convention.

## Remaining work

The art, sprite frames, needle texture, and flipping are wired. Left to tune:

1. **Wing offsets**: fill `Mosquito.wing_frame_offsets` on the `mosquito.tscn`
   root — one `PackedVector2Array` per body animation (`idle`, `move`, `windup`,
   `attack`, `death`) describing how far to shift the wings so they stay pinned to
   the body's wing joint on that state's frame. Empty = no shift.
2. **Extra body frames**: each body state is currently a single static frame. If
   multi-frame windup/shoot animations are added later, extend
   `mosquito_sprite_frames.tres` and the matching per-frame entries in the offset
   arrays.
3. **Tuning**: `hover_distance`, `resume_margin`, `windup_time`, `recover_time`,
   `needle_speed`, hitbox size, and stats are placeholder values.
