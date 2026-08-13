# Charger Enemy

A slow flying enemy that orbits the player at range, then dashes straight
through them, dealing contact damage and knocking the player back. The first
enemy whose threat is positional — it telegraphs, commits to a line, and ends
up on the player's far side. Unlocks at threat level 3, the next enemy
encountered after the mosquito.

## Behavior summary

The full loop: **approach → orbit → pause → windup → charge → decelerate →
orbit** (repeat).

- **Spawn**: same left/right spawn zones as the mosquito, eligible whether or
  not the magnet is active. Unlocks at threat level 3, one per batch.
- **Approach**: flies toward the player until inside `engage_distance` (550 —
  a constant picked so the orbit ring sits just past the ship's edge when the
  player stands at ship center; shorter than the mosquito's 1000 hover
  distance).
- **Orbit**: circles the player along an arc — player at the center, tangential
  velocity plus a radial correction holding the radius captured on entry. Each
  orbit rolls a random direction (CW/CCW) and a random arc length between
  `arc_distance_min` and `arc_distance_max`.
- **Pause**: hangs still for `pause_time` after finishing the arc.
- **Windup**: holds the single-frame charge pose for `windup_time` (sub-second)
  while *still tracking* the player — the dash direction locks only when the
  windup ends.
- **Charge**: accelerates hard (0 → `charge_speed` in ~0.35 s) along the frozen
  direction for `charge_distance_multiplier` (2.0) × the distance to the player
  at windup start, so it passes through the player and ends at roughly its
  starting range on the far side. Braking starts early by the predicted
  braking distance (`v / decel_damping`), so the dash settles at its target
  distance instead of overshooting by the braking tail. `charge_timeout` is a
  failsafe for dashes wedged against terrain.
- **Decelerate**: exponential damping (max → stopped in ~0.45 s), then pivots
  back to tracking and starts a new orbit (or re-approaches if the player fled).
- **Dash hit**: a square DamageBox (see `specs/damage_box.md`) over the
  charger's head is enabled only while charging; the player passing into it takes one hit of
  damage and is knocked back along the dash direction. The box is
  single-hit-per-activation, so one dash can never hit twice, and the hit
  never interrupts or alters the dash.

## Structure (modular system)

```
enemies/charger/
├── charger.gd                   Enemy subclass: head-tip rotation facing, charge flag, knockback
├── charger.tscn                 Visual/Sprite + Hitbox (250x110) + head DamageBox (72x72 at (94, 0))
├── charger_move_behavior.gd     approach/orbit/pause/windup/charge/decelerate MoveBehavior
├── charger_data.tres            EnemyData (stats + move behavior; attack slot is the base no-op)
├── charger_spawn_profile.tres   zones, threat 3, magnet eligibility
├── charger_sprite_frames.tres   idle / move (fly_s 4-frame) / charge (fly frame 3) / death
└── sprites/                     source art (260x130 frames)
```

- `charger.gd` owns `is_charging()`: `begin_charge()`/`end_charge()` (called by
  the move behavior's charge state) raise the flag and toggle the head
  DamageBox in lockstep.
- **Facing** eases the whole body's rotation toward the player every frame so
  the head tip comes to point at them — exponential smoothing at
  `turn_damping` per second, so it turns smoothly (including the 180° pivot
  after each dash) rather than snapping or locking on. The art faces right by
  default (`(1, 0)`), so the aim angle is the rotation target. The aim ray
  originates from the head tip — the right center of the 260x130 sprite,
  `head_tip_offset` — not the body center. When the windup ends, the dash
  direction locks to the smoothed body facing (not the raw aim), so the launch
  continues the turn without a snap. From dash launch through deceleration the
  rotation stays frozen on the dash line; tracking resumes when the next orbit
  begins.
- **Animations**: `fly_s` (the streamlined 4-frame sheet) is the normal
  approach/orbit flight (`move`); the `charge` pose is a single frame (frame 3)
  of the 6-frame `fly` sheet, shown from windup through deceleration.

## Dash damage (DamageBox)

The dash's contact hit rides the DamageBox concept (`specs/damage_box.md`)
instead of the ATTACK state — the charger's attack-behavior slot holds the
base no-op `AttackBehavior` (deliberately not left null, which would fall back
to the default stop-and-melee behavior):

- The head box (72x72 at local `(94, 0)`, rotating with the body) has
  `collision_mask = 8` (the player Hitbox layer) and
  `single_hit_per_activation = true`.
- `begin_charge()` enables it and `end_charge()` disables it, so it can only
  hit during the dash itself — never while orbiting or braking. `end_charge`
  runs from the charge state's `on_exit_state`, which also fires via behavior
  teardown on death and via `on_enter_move`'s reset, so a charger killed or
  interrupted mid-dash cannot leak an enabled box.
- The base never enters ATTACK (`can_attack` is always false), so the dash is
  physically uninterruptible by its own hit.

## Player knockback contract

`Player.apply_knockback(impulse: Vector2)` is the first player knockback
mechanism. The horizontal component is stored in `_knockback_velocity_x`,
re-added on top of the per-frame input velocity (which the player rewrites
every physics tick) and decayed by `knockback_damping`; the vertical component
is a one-time `velocity.y` impulse that gravity resolves. It is called
separately from `take_damage` so the push lands even when a shield absorbs the
hit. The charger listens to its DamageBox's `dealt_damage(target_owner)`
signal and duck-types `apply_knockback` on the struck owner, so non-player
targets are silently unaffected.

## Remaining work

1. **Tuning**: `engage_distance`, orbit speeds/arcs, dash speed/timings,
   damage, health, hitbox size, and knockback strength are placeholder values.
2. **Charge polish**: the windup and dash share one static frame; fly frames
   0–2 could become an animated windup later. No dash SFX/trail yet.
