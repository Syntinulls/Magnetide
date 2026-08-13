# Repair Gun — Design Spec

Status: **implemented alongside this spec**. The repair gun is the ship-healing
counterplay the storm system reserved space for (see
[storm_event_system_spec.md](storm_event_system_spec.md), "Ship drain" notes).

---

## 1. Goal

A new held equipment tool that lets the player **spend in-run scrap to restore ship
integrity** mid-run. It is:

- **Station-unlockable** — a locked static slot in the **Equipment** column of the
  station player page, unlocked with Research Points (like the shield).
- **Upgradeable** — shield-style leveling: the unlock grants a base **level 0** gun,
  then **5 purchasable upgrade levels** (salvage parts + banked scrap).
- **Hotbar slot 3** — appended to the runtime equipment after weapon and magnet tool,
  and absent entirely while locked.

## 2. Stats

Three stats, all on `RepairGunData` (base = level 0) and raised by the upgrade track
(`_project/upgrades/repair_gun/repair_gun.tres`):

| Stat | Meaning | L0 | L1 | L2 | L3 | L4 | L5 |
|------|---------|----|----|----|----|----|----|
| `repair_amount` | Ship integrity restored per completed cycle (raw units, capped at max) | 10 | 14 | 18 | 22 | 26 | 30 |
| `repair_rate` | Repair cycles per second (progress bar speed) | 0.5 | 0.64 | 0.78 | 0.92 | 1.06 | 1.2 |
| `repair_cost` | **In-run** scrap consumed per completed cycle | 1 | 1 | 1 | 2 | 2 | 3 |

`beam_range` (raycast distance from the muzzle) is a non-upgraded tuning export.
All numbers are placeholders tuned in the `.tres` files.

The cost deliberately climbs **slower than +1 per level**. Spending in-run scrap
reduces the end-of-run banked payout (the run result reads the same counter) —
intended: repairs trade meta-currency for survival.

## 3. Use loop

While the repair gun is selected and **LMB is held**:

1. Raycast layer 1 from the muzzle along the aim direction, `beam_range` px,
   areas-only (`collide_with_bodies = false` skips the ship's `Boundaries` body),
   `hit_from_inside = true`. Accept only a `Hitbox` whose owner is the **Ship** —
   the magnet hitbox is excluded and skipped via an exclude-and-recast loop.
2. **Gates** — all must hold, else the beam is down: hull hit, in-run scrap
   ≥ `repair_cost`, ship integrity < max.
3. While gated-on: beam VFX active, and the shared player progress bar (caption
   `"Repairing"`) advances at `repair_rate`. On reaching 100%: spend
   `repair_cost` in-run scrap, apply `repair_amount` integrity (green heal popup),
   reset the bar, keep looping while held.
4. **Release / any gate fails mid-hold:** progress resets to **0** (unlike reload,
   which persists) and the beam dissipates. Re-acquiring while still held restarts
   from 0.
5. **Switching equipment, run end, or UI capturing input:** instant hide, progress
   reset — no dissipation.

Inside-hull case: aiming steeply down can start the ray inside the hull polygon
(the interior floor sits below the polygon's top edge). `hit_from_inside` reports
a `normal == Vector2.ZERO` hit at the ray origin; the contact point is then the
muzzle itself.

## 4. Beam VFX contract (`repair_beam.tscn`)

Authored scene, instanced under the Player root (`top_level = true`, world coords):

- `Beam` — `Line2D`, tiling strip texture (`effect_beam_1.png`), muzzle → contact.
  Hidden **immediately** on stop.
- `Shine` — `AnimatedSprite2D` (8-frame loop, `effect_shine_1.png`) at the beam
  start. **Always follows the muzzle**, including while dissipating.
- `Contact` — `AnimatedSprite2D` (6-frame loop, `effect_contact_1.png`) at the
  raycast hit point while active. On dissipation it **freezes at the last hit
  point**.
- Dissipation: both sprites stop looping and hide when their current animation
  pass completes (the `MuzzleEffect` self-stop-on-`animation_looped` pattern).

The shine sprite *is* the start-point effect, so `muzzle_effect_type = None`.

## 5. Data & persistence

- `RepairGunData extends HeldItemData` (`_project/items/repair_gun/repair_gun_data.gd`);
  instance `repair_gun.tres` (`item_id = &"repair_gun"`).
- Upgrade track: `WeaponUpgradeData` with `UpgradeEffect.Target.REPAIR_GUN` effects
  (enum value appended at the end — `.tres` files store targets as raw ints).
- Level lives in `RunUpgrade.item_states` keyed by `item_id`; the unlock in
  `slot_states` keyed by `slot_id = &"repair_gun"` — both already serialized, no
  save-shape change.
- `RunLoadout._build_runtime_equipment()` appends the upgraded preview only when
  the slot is unlocked — the unlock→presence bridge.
- In-run scrap spending: `RunController.spend_scrap_metal()`, reached via
  `Magnetide.run`.
- Ship healing: new `Ship.repair()` clamped to `max_health`, green
  `DamageNumber` popup.
