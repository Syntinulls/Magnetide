# Floater Enemy

A slow, tanky enemy that targets the ship only. It drifts to the ship target point nearest its
spawn and coils there, then bursts. The burst hurts the hull and anyone standing close, and
fans pines over the upper half-circle. It then retreats off screen. It is the first enemy whose
threat is to the hull rather than to the player: ignored, it always lands its hit, so the
counterplay is killing it during its approach. It unlocks at threat level 4 and is the next
enemy encountered after the charger.

## Behavior summary

The full loop runs once: **drift → coil → explode → retreat**.

- **Spawn**: left/right edge zones only (`SpawnW`, `SpawnWNW`, `SpawnWSW`, `SpawnE`,
  `SpawnENE`, `SpawnESE`). No top, bottom or corner zones. It is eligible whether or not the
  magnet is active. It unlocks at threat 4, spawns one per batch, and has a 24 s cooldown.
  It is not in any storm.
- **Target**: `valid_targets = ["ship"]` with `target_point_selection_mode = CLOSEST`. The
  base Enemy resolves the point in `_ready`, at the spawn position, and with DEFAULT switching
  it only re-acquires if the point becomes invalid. So the point nearest the spawn sticks.
- **Drift**: flies straight at the point at `movement_speed` (90 px/s), with a sine bob of
  ±`bob_amplitude` (14 px) over `bob_period` (2 s).
  - The bob is added to the velocity, not to the sprite, because the base hit shake owns the
    `Visual` offset.
  - Each Floater starts on a random bob phase.
- **Coil**: begins when within `attack_range` (40 px, which must exceed the bob amplitude).
  - It stops and plays the single-frame `coil` pose.
  - `Visual.scale.y` squashes to `coil_squash_scale` (0.7) over 0.45 s with an elastic
    ease-out, for the bounce.
  - It holds for `coil_duration` (1.0 s).
  - Once coiling starts the Floater is committed (`can_attack` stays true), so it never
    drops back to drifting.
- **Explode** (one frame), in this order:
  1. The body springs back to full height (back ease, 0.15 s).
  2. `floater_explosion.tscn` spawns at the Floater with the burst damage
     (`EnemyData.damage` × threat scale). The scene is an inherited variant of
     `combat/explosion.tscn` whose `collision_mask` is the player Hitbox only.
  3. The ship takes the burst through `deal_damage_to_current_target()`.
     - This happens directly, not through the explosion's area query: the magnet hitbox
       shares the ship's layer and forwards its damage to the hull, so an area hit could
       land twice.
     - The ship is always hit. The player is hit only inside the 130 px blast.
  4. Pines launch as `pine_count` (6) projectiles, evenly spaced over `pine_arc_degrees`
     (180°) centered straight up.
     - Their angles are 180°, 144°, 108°, 72°, 36° and 0°, both horizontals included.
     - Each flies at 900 px/s under 1200 px/s² gravity.
     - Each does `pine_damage` (8) × threat scale on contact with the player Hitbox, and
       does not explode.
  5. The placeholder burst sound plays (the shotgun shot).
  6. The Floater calls `Enemy.retreat()`.
- **Retreat**: the base Enemy's RETREAT state.
  - It swaps to the `retreat` animation, which uses the `enemy_5_retreat_flap` sheet (the
    plain `enemy_5_retreat` sheet is unused for now).
  - The hitbox is disabled.
  - It hops up gently (`retreat_up_velocity_range`) and falls off screen under the death
    sequence's gravity, turning at most ±0.4 rad/s (`retreat_rotation_velocity_range`)
    instead of the death tumble.
  - It does not emit `died`, so it is not a kill and does not alert allies. It frees itself
    below the viewport.
- **Killed before bursting**: the normal death — the `dead` frame, the spinning pop and a kill.

## Structure

```
enemies/floater/
├── floater.gd                  Enemy subclass: coil squash / release tweens on Visual
├── floater.tscn                Visual/Sprite + Hitbox (80x100); no DamageBox
├── floater_move_behavior.gd    straight drift + sine bob MoveBehavior
├── floater_attack_behavior.gd  coil → explode AttackBehavior (explosion, ship hit, pines, sfx)
├── floater_explosion.tscn      combat/explosion.tscn variant masking the player Hitbox
├── floater_data.tres           EnemyData (stats, ship targeting, behavior exports)
├── floater_spawn_profile.tres  side zones, threat 4, magnet eligibility, 24 s cooldown
├── floater_sprite_frames.tres  idle/move (fly, 4 frames) / coil / retreat (retreat_flap) / death
└── sprites/                    source art (128x128 frames; pine 26x36, pointing up)
```

### Shared pieces this added

- **`Enemy` RETREAT state**:
  - `retreat()` leaves the fight alive. Death and retreat share `_leave_fight()` (clear the
    target, tear down the behaviors, disable the hitbox) and one fall (`_launch_fall` /
    `_process_fall`).
  - Each passes its own launch and spin ranges. The retreat ranges live in `EnemyData`'s
    "Retreat" group.
- **`combat/explosion.*`**: the grenade launcher's blast, moved to `combat/` now that it has
  two users.
  - The class is renamed `Explosion`.
  - Its `collision_mask` picks who the blast hurts: the grenade's scene masks enemies, and
    the Floater's variant masks the player.
- **`combat/fire_color_ramp.tres`**: the flamethrower's flame gradient, extracted so the
  explosion can share it.
  - The explosion samples it once per frame at `frame / frame_count`, running yellow-white
    → orange → half-faded grey.
  - Sampling stops short of 1.0, so the last frame is still visible.

## Balance

See `specs/balance_sheet.md` §3.1–3.2. In short:
- 150 HP base, about 2.1× the charger.
- A 55 burst: 89 at threat 4, just over half an on-schedule 160 HP player.
- 8 per pine.

## Remaining work

1. **Explosion sound**: the shotgun shot is a placeholder.
2. **Retreat art**: `enemy_5_retreat.png` is unused; `retreat_flap` stands in.
3. **Tuning**: blast radius (the grenade's 130 px), drift speed, coil time and pine ballistics
   are first-pass values.
