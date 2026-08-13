# Damage Box

`combat/damage_box.gd` (`DamageBox extends Area2D`) is the dealing-side
counterpart to `Hitbox`: a Hitbox only ever *receives* damage; a DamageBox
*deals* it to any permissible Hitbox that passes into it. An enemy authors one
in its scene over the body part that hurts on contact (e.g. the charger's
head) and toggles `enabled` from its behaviors.

## Contract

- **Permissibility** is the area's `collision_mask` — point it at the target's
  Hitbox layer (the player's Hitbox is layer bit 4, value 8). The box itself
  sits on `collision_layer = 0` with `monitorable = false`; nothing detects it.
- **Damage amount** resolves from the owning enemy (`owner_path`):
  `EnemyData.damage * damage_scale` per hit, sent through the target Hitbox's
  `take_damage(amount, source)` with the enemy as source.
- **`enabled`** gates dealing, not detection: overlaps are tracked while
  disabled, so enabling mid-overlap counts as an entry and hits immediately.
  Hits are otherwise entry-triggered — a target sitting inside the box is not
  re-damaged until it leaves and re-enters.
- **`single_hit_per_activation`** caps the box at one hit per enable window;
  the spent flag clears on every `enabled` toggle. The charger uses this for
  its once-per-dash hit.
- **`dealt_damage(target_owner)`** fires after each hit so the owner can add
  side effects (the charger applies player knockback here).

## Usage notes

- Existing enemies are unaffected: the worm and mosquito keep their attack
  behaviors; a DamageBox is opt-in scene content plus whatever behavior code
  toggles `enabled`.
- For a periodic-contact enemy (damage while the target stays inside), add an
  interval re-hit mode when first needed — today's boxes are entry-only.
