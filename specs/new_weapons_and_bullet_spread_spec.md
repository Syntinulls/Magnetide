# New Weapons (SMG, Sniper) & Bullet Spread

## Goal

Add two weapons — the **SMG** and the **Sniper** — and a new per-weapon
**bullet spread** stat that applies a random angular deviation to every bullet
fired. Re-order the weapon unlock chain to
`pistol → smg → shotgun → rifle → sniper`.

This spec covers weapon stats, the spread mechanic, and the unlock ordering.
The *cost values* for unlocking these weapons are defined by the research-point
rarity economy in `specs/research_point_rarities_spec.md` (this spec only sets
`research_unlock_order`).

## 1. Bullet spread

### Data model — new fields on `WeaponData`

`_project/items/equipment/weapon_data.gd` gains a spread group:

```gdscript
@export_group("Bullet Spread")
## Minimum spread cone width, in degrees. 0 = perfectly accurate.
@export_range(0.0, 90.0, 0.1, "degrees") var bullet_spread_min: float = 0.0:
	set(value):
		bullet_spread_min = maxf(value, 0.0)
## Maximum spread cone width, in degrees. Clamped to be >= bullet_spread_min.
@export_range(0.0, 90.0, 0.1, "degrees") var bullet_spread_max: float = 0.0:
	set(value):
		bullet_spread_max = maxf(value, 0.0)
```

Default spread is `0 / 0` (no deviation), matching every existing weapon that
does not opt in.

### Mechanic — two-stage roll, per bullet

Per the design: first roll a **spread magnitude** `S` uniformly in
`[min, max]`; then pick a **random angle** inside a cone of width `S`, i.e. in
`[-S/2, +S/2]`. So a rolled spread of 3° means the bullet can deviate up to
±1.5° from the aim line.

Add a helper on `WeaponData`:

```gdscript
## Per-bullet angular offset in radians. Rolls a spread magnitude in
## [min, max] degrees, then a random angle within that cone (±magnitude/2).
func roll_bullet_spread_offset() -> float:
	var lo := maxf(bullet_spread_min, 0.0)
	var hi := maxf(bullet_spread_max, lo)
	if hi <= 0.0:
		return 0.0
	var magnitude := randf_range(lo, hi)
	return deg_to_rad(randf_range(-magnitude * 0.5, magnitude * 0.5))
```

### Application point

Spread is applied in `Player.fire_weapon_projectile()`
(`_project/player/player.gd:510`) — the single chokepoint every shot passes
through, including each shotgun pellet. After the aim direction is normalized:

```gdscript
var bullet_direction := direction.normalized()
if bullet_direction.length_squared() <= 0.0001:
	bullet_direction = get_weapon_aim_direction()
bullet_direction = bullet_direction.rotated(weapon_data.roll_bullet_spread_offset())
```

Because each pellet calls `fire_weapon_projectile` separately, spread is rolled
**independently per bullet** (per pellet for the shotgun). The shotgun's own
even cone stays in `ShotgunFireBehavior`; its per-bullet spread is `0`, so the
two mechanics do not interfere. Spread stacks additively on top of any
fire-behavior cone should a future weapon set both.

### Per-weapon spread values

| Weapon | spread_min | spread_max | Rationale |
|---|---|---|---|
| Pistol | 0.0 | 0.0 | none |
| SMG | 4.0 | 9.0 | most of any weapon |
| Shotgun | 0.0 | 0.0 | none (cone via fire behavior) |
| Rifle | 0.5 | 2.0 | minimal |
| Sniper | 0.0 | 0.0 | none (pinpoint) |

## 2. New weapon: SMG

Folder `_project/items/equipment/smg/` (exists; currently holds only
`player_item_smg.png` + `.import`). Add `smg.tres` (`WeaponData`).

Design: fires **faster than the rifle**, does **less damage**, has the **most
spread** of any weapon. Uses the default bullet sprite (rifle's
`bullet_s_1.png`).

| Field | Value | Note |
|---|---|---|
| `damage` | 6.0 | below rifle's 10 (and pistol's 7) |
| `fire_rate` | 8.0 | above rifle's 5 (shots/sec) |
| `bullet_speed` | 1800.0 | matches rifle |
| `pierce` | 1 | default |
| `bullet_sprite` | `rifle/bullet_s_1.png` | default bullet, per request |
| `magazine_size` | 40 | high, suits spray |
| `reload_time` | 1.4 | |
| `bullet_spread_min` / `max` | 4.0 / 9.0 | most spread |
| `item_id` | `&"weapon_smg"` | |
| `display_name` | "SMG" | |
| `hotbar_icon` / `weapon_sprite` | `smg/player_item_smg.png` | |
| `muzzle_effect_type` | 2 (Rifle Flash) | matches other guns |
| `fire_behavior` | null | default single-shot |

`weapon_offset` / `weapon_rotation` / `muzzle_position` to be tuned in-editor to
fit `player_item_smg.png` (start from rifle's values).

## 3. New weapon: Sniper

Folder `_project/items/equipment/sniper/` (exists; holds
`player_item_sniper.png` + `.import`). Add `sniper.tres` (`WeaponData`).

Design: fires **as slow as the shotgun** (`fire_rate 1.0`), **pierce 4**, and
the **highest damage of any weapon so far** (shotgun is currently top at 15/hit).
No spread. Uses the default bullet sprite.

| Field | Value | Note |
|---|---|---|
| `damage` | 45.0 | highest single-hit in game |
| `fire_rate` | 1.0 | same as shotgun |
| `bullet_speed` | 2400.0 | fast, snappy round |
| `pierce` | 4 | per request |
| `bullet_sprite` | `rifle/bullet_s_1.png` | default bullet, per request |
| `magazine_size` | 5 | low, high-impact shots |
| `reload_time` | 2.0 | |
| `bullet_spread_min` / `max` | 0.0 / 0.0 | pinpoint |
| `item_id` | `&"weapon_sniper"` | |
| `display_name` | "Sniper" | |
| `hotbar_icon` / `weapon_sprite` | `sniper/player_item_sniper.png` | |
| `muzzle_effect_type` | 2 (Rifle Flash) | |
| `fire_behavior` | null | default single-shot |

Positioning fields tuned in-editor from rifle's values.

## 4. Unlock chain re-order

New order: **pistol → smg → shotgun → rifle → sniper**, all in the existing
`&"weapons"` `research_unlock_group`. Only `research_unlock_order` changes plus
the two new catalog entries. Dependency gating (each weapon requires the prior
one unlocked) already works off `research_unlock_order` — see
`specs/weapon_unlock_dependencies_spec.md`.

Edit the `EquipmentCatalogEntry` sub-resources in
`_project/app/screens/station/station_screen.tscn` (lines 23-43) and add two new
ones, then extend the `weapon_catalog` array (line 80):

| Weapon | `research_unlock_id` | `research_unlock_order` | `locked` |
|---|---|---|---|
| Pistol | `weapon_pistol` | 0 | false |
| SMG | `weapon_smg` | 10 | true |
| Shotgun | `weapon_shotgun` | 20 | true |
| Rifle | `weapon_rifle` | 30 | true |
| Sniper | `weapon_sniper` | 40 | true |

Per-rarity RP costs for each entry are defined in
`specs/research_point_rarities_spec.md`. The single-int `research_point_cost`
field is superseded by that spec's per-rarity cost fields.

The pistol remains the default weapon (`RunLoadout.DefaultWeaponData`); no change
there.

## Affected files

| File | Change |
|---|---|
| `_project/items/equipment/weapon_data.gd` | Add spread fields + `roll_bullet_spread_offset()`. |
| `_project/player/player.gd` | Apply spread offset in `fire_weapon_projectile`. |
| `_project/items/equipment/rifle/rifle.tres` | Set spread 0.5 / 2.0. |
| `_project/items/equipment/smg/smg.tres` | **New** WeaponData resource. |
| `_project/items/equipment/sniper/sniper.tres` | **New** WeaponData resource. |
| `_project/app/screens/station/station_screen.tscn` | Add SMG + Sniper catalog entries; re-order chain; extend `weapon_catalog`. |

Pistol and shotgun `.tres` keep default `0/0` spread — no edit needed unless we
choose to set them explicitly.

## Acceptance criteria

1. Every weapon exposes `bullet_spread_min` / `bullet_spread_max` (default 0/0).
2. Firing rolls spread per bullet: magnitude in `[min, max]`, angle in `±mag/2`.
3. A weapon with 0/0 spread fires perfectly straight (unchanged behavior).
4. SMG fires faster than the rifle, deals less damage, and visibly sprays.
5. Sniper fires at shotgun cadence, pierces 4, deals the most damage, dead-accurate.
6. Both new weapons use the default rifle bullet sprite.
7. Station weapon list unlocks in order pistol → smg → shotgun → rifle → sniper,
   each gated on the previous being unlocked.

## Open questions / tunables

1. Exact SMG/Sniper damage and fire-rate numbers are first-pass — flag any you
   want re-balanced.
2. Should spread also be reduced/removed by a future accuracy augment? (out of scope)
