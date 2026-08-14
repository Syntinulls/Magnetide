# Flamethrower & Status Effects

Two features that land together: a minimal, extendable status-effect system
(first effect: Burning), and the Flamethrower weapon whose flame projectiles
apply it. Also extends the shared `Projectile` with optional, data-driven
configuration that other weapons can adopt later.

## Projectile extensions (`_project/combat/projectile.gd`)

All new config keys are optional and default to the previous behavior, so
existing call sites (weapons, mosquito needles) are unaffected.

| Config key | Backing | Meaning |
|---|---|---|
| `destroy_on_contact` | `bool = true` | When false, exhausting pierce stops further damage but does not destroy the projectile — it flies on until its lifetime expires. Pierce still caps how many enemies the projectile can damage. |
| `contact_effect` | `PackedScene = null` | StatusEffect scene applied to each enemy the projectile damages. Never consumes the projectile (unlike `impact_effect`, which does). |
| `projectile_behavior` | `ProjectileBehavior = null` | Motion/tick strategy resource, duplicated per projectile. |
| `collision_size` | `Vector2 = (32, 12)` | Size of the projectile's rectangular collision shape. |
| `inherited_velocity` | `Vector2 = ZERO` | Shooter movement velocity at fire time, added to the projectile's motion for its whole flight. Opt-in per weapon and per axis via `WeaponData.inherit_shooter_velocity_x` / `_y` (only the flamethrower enables it, horizontal only). |
| `sprite` (extended) | now also accepts `SpriteFrames` | Builds an `AnimatedSprite2D` visual instead of a `Sprite2D`. |

Lifetime is now tracked per-frame (`_elapsed`) instead of a one-shot
SceneTreeTimer, so behaviors receive the projectile's elapsed lifetime.

### `ProjectileBehavior` (`_project/combat/projectile_behavior.gd`)

Strategy resource mirroring the enemy move/attack behavior pattern; the
projectile duplicates the authored resource so per-projectile state (spin,
phase timers) is never shared across shots.

- `setup(projectile)` — roll per-projectile state.
- `get_velocity(projectile, elapsed) -> Vector2` — default: `direction * speed`
  (linear, no acceleration). The gravity branch (grenades) takes priority over
  behaviors.
- `tick(projectile, elapsed, delta)` — per-frame visual/lifecycle hook.

## Status effects (`_project/effects/`)

`StatusEffect extends Node2D` (`_project/effects/status_effect.gd`): a timed
effect that lives as a **direct child of its receiver** (the enemy). Node
parenting gives lifecycle for free — the effect dies with its receiver and
needs no registry or Enemy API changes; damage is applied by duck-typing
`take_damage`, exactly like projectiles do.

- Identity: `effect_id: StringName`. `apply_to(target)` scans the target's
  direct children; a live match is `refresh()`ed (timer re-rolled — effects
  never stack) and the incoming instance discards itself.
- Self-ticks in `_process` on `tick_interval` using the drift-free `-=`
  accumulator pattern (see `regeneration_behavior.gd`). First tick lands one
  interval after application.
- Duration is rolled in `[duration_min, duration_max]` per application.
- `source` carries the originator (the player for weapon-applied effects) so
  enemy target-switching reacts to burn ticks as it would to direct hits.
- Expiry path: `_expire()` runs once (also triggered by the receiver's `died`
  signal, so visuals never ride the enemy death pop) → `_on_expired()`, whose
  default frees the node; overrides fade visuals first and then free.
- Overridable hooks: `_apply_tick()`, `_on_started()`, `_on_refreshed()`,
  `_on_expired()`.

### Burning (`_project/effects/burning/`)

`BurningEffect extends StatusEffect`, authored scene `burning_effect.tscn`
(root exports: `effect_id = &"burning"`, tick 1.0s, duration 6–8s,
`damage_per_tick = 2`). Each tick calls the receiver's full `take_damage`
(damage number + flash + SFX at 1 Hz is intended feedback).

VFX: the scene's hidden `FlameTemplate` (`AnimatedSprite2D`,
`burning_flame_sprite_frames.tres`, 10 frames of 112×112 from
`effect_flame_1_s.png`) is duplicated `flame_count` times. Each flame loops:
ignite at a random offset within `flame_offset_radius`, random fixed rotation,
grow to `flame_max_scale`, burn briefly, shrink to zero, re-ignite elsewhere.
Expiry fades all flames out and frees the effect.

## Flamethrower (`_project/items/weapons/flamethrower/`)

`flamethrower.tres` (WeaponData) — no custom fire behavior; the cone comes from
the standard random spread roll, the flame look from a `FlameProjectileBehavior`
sub-resource.

| Stat | Value | Notes |
|---|---|---|
| damage | 2 | per flame, single hit (pierce 1) |
| fire_rate | 11/s | highest in game |
| bullet_speed | 1500 | burst speed; falloff caps effective reach ~450 px |
| bullet_lifetime | 0.85s | flames expire mid-air, not on contact |
| destroy_on_contact | false | flames pass through the enemy they damage |
| contact_effect | `burning_effect.tscn` | applied to each damaged enemy |
| bullet_spread | 6–12° | rifle/SMG-style random cone |
| collision size | 28×28 | round-ish puff |
| magazine / reload | 100 fuel / 1.8s | standard reload flow |
| fire_sfx | `[null]` | deliberate: a single null stream ships the weapon silent instead of triggering the machine-gun fallback; replace with a flame loop when the asset lands |

`FlameProjectileBehavior` (`flame_projectile_behavior.gd`): full speed for
`burst_duration` (0.12s), then a sharp cubic decay to `min_speed` (100) over
`falloff_duration` (0.5s). Tick: sprite scale grows from 0 toward
`max_visual_scale` as the flame decelerates (scale tracks 1 − speed ratio);
modulate follows `color_ramp` over normalized lifetime (yellow-white → yellow →
orange → dark gray, alpha fading toward the tail); per-flame random spin
direction and speed (2–5 rad/s).

Projectile visual: `flame_projectile_sprite_frames.tres`, 10 frames of 224×224
from `effect_flame_1.png`, looping.

Registration: station catalog (`research_unlock_id = &"weapon_flamethrower"`,
order 60, locked, 2 rare + 2 epic), debug panel weapons list, shared weapon
upgrade track.
