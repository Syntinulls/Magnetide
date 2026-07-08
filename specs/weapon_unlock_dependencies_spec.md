# Weapon Unlock Dependencies

## Goal

Weapons in the station's player-weapon dynamic slot unlock in a fixed sequence.
Each weapon depends on the previous weapon in the chain being unlocked first, so
the player spends Research Points (RP) to unlock weapons one row at a time.

The pistol is the first weapon: unlocked by default and equipped at the start of a
new game. Rifle depends on pistol, shotgun depends on rifle, and so on.

## Data model

The chain reuses the existing `EquipmentCatalogEntry` fields — no new fields:

- `research_unlock_group` (defaults to `&"weapons"`): entries in the same group
  form one ordered chain. Each augment sits in its own single-item group, so
  augments have no dependencies and are unaffected by this feature.
- `research_unlock_order`: orders the chain. Pistol `0`, rifle `10`, shotgun `20`.
- `locked` / `research_point_cost`: pistol is `locked = false`; every later weapon
  is `locked = true` with an RP cost.

A weapon's **dependency** is the entry immediately before it in its group by
`research_unlock_order`. The first entry in a group has no dependency. An equipped
weapon is always treated as unlocked (`RunLoadout._ensure_equipped_defaults` marks
the equipped weapon's item state unlocked), so a save made before a weapon was
gated never shows its active weapon as locked.

## Three visual states (weapons list entry)

1. **Unlocked** — normal icon, white/green name, trailing level readout.
2. **Locked, dependencies met** — greyed icon + greyed name, trailing **Unlock**
   button, *enabled* (clickable). Pressing it spends RP when affordable. This is
   the single "next" weapon in the chain.
3. **Locked, dependencies not met ("hidden")** — icon rendered as a solid-black
   silhouette, name replaced with `???`, trailing Unlock button *disabled*. The
   detail panel is masked the same way (no name, stats, or description revealed).

Unlocking the current "next" weapon reveals the following one: its dependency is
now met, so it moves from state 3 to state 2.

Sorting by `research_unlock_order` keeps unlocked entries, then the single
unlockable entry, then the hidden entries, in that order down the list.

## Implementation notes

- `StationScreen._are_catalog_entry_dependencies_met(entry)` finds the in-group
  predecessor and returns whether it is unlocked (or none exists).
- `StationScreen._is_catalog_entry_hidden(entry)` = locked AND deps not met.
- Enabling/affordability of the Unlock action still flows through the existing
  `_can_unlock_catalog_entry` / `_is_next_locked_catalog_entry`, which already
  gate on "first locked in group" (equivalent to deps met) plus RP affordability.

The mechanic is currently applied to weapons only; augments remain single-item
groups and therefore always render in state 1 or 2.
