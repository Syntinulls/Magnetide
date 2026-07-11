# Research Points by Rarity (Common / Rare / Epic)

## Goal

Split the single research-point currency into **three rarities** — common, rare,
and epic — matching the three artifact rarities. Completing research on an
artifact awards a point of that artifact's rarity. Unlock costs are expressed
per rarity (and may require several rarities at once, e.g. 1 common + 1 rare),
letting late-game items demand more and rarer points.

Supersedes the single-currency model in
`specs/artifact_piles_and_research_points_spec.md`.

## Terminology

| Term | Meaning |
|---|---|
| Research rarity | One of `COMMON`, `RARE`, `EPIC` (reuses `SalvageItemData.ItemRarity`). |
| Common/Rare/Epic RP | Three separate persistent currency balances. |
| Rarity color | `COMMON 5af03c`, `RARE 7ebaff`, `EPIC e17dff` (already in `SalvageItemData.ITEM_RARITY_COLORS`). |

`LEGENDARY` exists in the rarity enum but artifacts only mint common/rare/epic
(`ArtifactPools`), so only those three currencies exist. Any legendary award
falls back to epic (see award routing).

## 1. Persistent storage — `AppSaveData`

`_project/app/app_save_data.gd` currently has `@export var research_points: int`.
Replace with three balances plus a rarity-keyed API.

```gdscript
@export var research_points_common: int = 0
@export var research_points_rare: int = 0
@export var research_points_epic: int = 0
```

Rarity-keyed accessors (rarity is a `SalvageItemData.ItemRarity` int; legendary
maps to epic):

```gdscript
func get_research_points(rarity: int) -> int
func add_research_points(rarity: int, amount: int) -> void          # amount > 0
func can_spend_research_points(rarity: int, amount: int) -> bool
func spend_research_points(rarity: int, amount: int) -> bool        # single-rarity
```

Multi-rarity cost helpers (used by every unlock that can require more than one
rarity — all/deduct atomically):

```gdscript
## cost is a rarity->amount map, e.g. {COMMON: 1, RARE: 1}.
func can_afford_research_cost(cost: Dictionary) -> bool
func spend_research_cost(cost: Dictionary) -> bool   # checks all, then deducts all, else no-op
```

`reset` (new game, `setup(..., true)`) zeroes all three. `is_default()` checks
all three are 0.

### Save migration (one pass)

Old saves serialize `research_points: int`. On load, Godot drops the now-unknown
property, so its value would be lost. To preserve progress, keep a **legacy**
`research_points` export for one migration pass and fold it into common in
`setup()`:

```gdscript
@export var research_points: int = 0   # legacy; migrated to common then zeroed

# in setup():
if research_points > 0:
	research_points_common += research_points
	research_points = 0
```

This is a live migration path (not dead code); remove the legacy field in a
later cleanup once saves have rolled over. No `res://` paths change, so
`_migrate_legacy_resource_paths()` is untouched.

## 2. Award routing — research completion

Artifacts already carry their rarity (`ArtifactPools.make_artifact` sets
`data.rarity` and `data.research_point_reward`). Route the reward to the matching
bucket.

`_project/ship/research/research_station.gd` — `_award_research_points()`
(lines 140-156) changes its final call from
`save_data.add_research_points(reward)` to:

```gdscript
save_data.add_research_points(item_data.rarity, reward)
```

`reward` still comes from `item_data.research_point_reward` (the per-rarity
reward configured on `ArtifactPools`). A common artifact grants
`common_research_reward` common RP, rare → rare, epic → epic. Legendary (not
minted today) routes to epic via the accessor's fallback.

## 3. Station UI — three-currency readout (top-right)

Replace the single "RESEARCH: N" label built in
`StationScreen._ensure_research_points_display()` (station_screen.gd:821-848)
with a **single horizontal row** of three icon+number pairs, left→right:
**common, rare, epic**. The icon precedes each number.

- Icon texture: `res://_project/ui/sprites/ui_icon_research_point.png`
  (`uid://0qevonhftyj2`, currently unused). `preload` as a `Texture2D` const.
- Each icon is a `TextureRect` with `modulate` set to that rarity's color from
  `SalvageItemData.ITEM_RARITY_COLORS` (established tint pattern — see the
  `LOCKED_ENTRY_MODULATE` usage at station_screen.gd:1546).
- Numbers use the same font/outline styling as the current label.
- Layout: an `HBoxContainer` inside the existing top-right `ResearchPointsPanel`
  (widen `custom_minimum_size` / offsets to fit three pairs). Anchored
  `PRESET_TOP_RIGHT` as today.

`_refresh_research_points_display()` (lines 874-881) updates all three numbers
from `get_research_points(COMMON/RARE/EPIC)`. Keep the existing refresh call
sites (`_ensure...` and `_refresh_loadout_ui`).

## 4. Research completion screen — icon + RP combo

`ResearchStationUI._build_final_result_text()` (research_station_ui.gd:500-509)
currently prints `"RESEARCH POINTS: %d\n..."` as plain text. The completion
("RESEARCH COMPLETE") overlay must show the **rarity icon + reward** for the
artifact just researched.

- Determine rarity from `artifact_data.rarity`; reward from
  `artifact_data.research_point_reward`.
- Render the `ui_icon_research_point.png` icon tinted to the rarity color,
  immediately preceding the reward number, on the results overlay.
- Since the overlay body is a text label today, either (a) switch that line to a
  small `HBox` (icon `TextureRect` + label) inserted into `_build_result_overlay`
  (lines 344-379), or (b) if the label supports BBCode, embed the icon via an
  inline image. Option (a) is preferred for reliable tinting.
- Failures/time lines remain as-is below the RP line.

## 5. Unlock costs — per rarity, multi-rarity capable

### Data model

`EquipmentCatalogEntry` (`_project/items/equipment/equipment_catalog_entry.gd`)
and `SlottableCatalogEntry` (`_project/items/slottable_catalog_entry.gd`) replace
the single `research_point_cost: int` with three per-rarity costs:

```gdscript
@export var research_cost_common: int = 0
@export var research_cost_rare: int = 0
@export var research_cost_epic: int = 0
```

Add a helper returning the non-zero costs as a rarity->amount map for the save
API and for display:

```gdscript
func get_research_cost() -> Dictionary   # {COMMON: n, RARE: n, EPIC: n} omitting zeros
```

`get_unlock_cost_text()` builds from this map (see display below).

### Static (non-catalog) slots — Player Shield

`StationScreen` constants (lines 84-86) replace the single
`PLAYER_SHIELD_RESEARCH_POINT_COST := 1` with a rarity map, e.g.
`const PLAYER_SHIELD_RESEARCH_COST := {COMMON: 2}`, consumed the same way.

### Purchase logic

Wherever the code today calls `can_spend_research_points(cost)` /
`spend_research_points(cost)` for an unlock — catalog entries
(`_can_unlock_catalog_entry` 1703-1712, `_unlock_catalog_entry` 1715-1729) and
the shield (`_unlock_static_slot` 718-741) — switch to
`can_afford_research_cost(map)` / `spend_research_cost(map)`. Affordability means
**every** required rarity is covered; spending deducts all atomically.

### Unlock requirement display (popups)

The requirement UI in the slot/upgrade popups shows **one text row per required
rarity** — no icons here. Each row reads `Nx <Rarity> RP` (e.g. `1x Common RP`,
`1x Rare RP`). An unlock costing multiple rarities lists one row per rarity.

Coloring communicates affordability **per rarity**: each row is colored green
when the player's balance of *that* rarity covers its amount, red when it does
not (reusing the existing green/red "requirement met" coloring). This lets the
player see exactly which rarity they are short on.

- `_format_research_point_cost_text()` (lines 2167-2172) → returns the
  multi-line, per-rarity, per-row colored text (was `"%d RP (%d / %d)"`).
- `_build_unlock_requirement_bbcode()` (1037-1048) and
  `_build_catalog_status_row()` (1023-1033) consume that formatter.
- The per-entry Unlock button label (`get_unlock_cost_text` /
  `_configure_dynamic_entry_button` 1571-1587) shows the same multi-rarity cost
  (compact form acceptable, e.g. `1x Common, 1x Rare`).

Rarity display names come from a simple map; row/affordability colors reuse the
existing requirement-met colors. No `ui_icon_research_point.png` in these
requirement rows (icons are used only in the top-right readout §3 and the
completion screen §4).

## 6. Cost assignment (first-pass economy)

Costs escalate in quantity and rarity as progression deepens; some items require
multiple rarities. All values are data-driven and easy to tune.

### Weapons (chain: pistol → smg → shotgun → rifle → sniper)

| Weapon | Common | Rare | Epic |
|---|---|---|---|
| Pistol | — (default, unlocked) | — | — |
| SMG | 1 | — | — |
| Shotgun | 1 | 1 | — |
| Rifle | 2 | 1 | — |
| Sniper | — | 2 | 1 |

### Augments & static slots

| Unlockable | Common | Rare | Epic |
|---|---|---|---|
| Regeneration (player augment) | 1 | — | — |
| Adrenaline (player augment) | 2 | — | — |
| Increased Recycling (player augment) | 1 | 1 | — |
| Player Shield (static slot) | 2 | — | — |

These are applied to the corresponding catalog sub-resources in
`station_screen.tscn` and the shield constant. Numbers are first-pass; adjust
freely.

## Affected files

| File | Change |
|---|---|
| `_project/app/app_save_data.gd` | Three RP balances, rarity-keyed + multi-rarity API, legacy migration. |
| `_project/ship/research/research_station.gd` | Route award by `item_data.rarity`. |
| `_project/ship/research/research_station_ui.gd` | Completion overlay: rarity icon + reward. |
| `_project/app/screens/station/station_screen.gd` | Three-icon top-right readout; per-rarity cost checks/spend; rarity-aware requirement text; shield cost map. |
| `_project/app/screens/station/station_screen.tscn` | Per-rarity cost fields on all catalog entries; new SMG/Sniper entries (see weapons spec). |
| `_project/items/equipment/equipment_catalog_entry.gd` | Per-rarity cost fields + `get_research_cost()`. |
| `_project/items/slottable_catalog_entry.gd` | Same per-rarity cost fields + helper. |

## Acceptance criteria

1. Save data holds three independent balances that persist across runs; a
   pre-existing save's old points migrate into common.
2. Completing a common/rare/epic artifact awards 1 point of that rarity.
3. Station top-right shows three icon+number pairs (common, rare, epic,
   left→right), each icon tinted to its rarity color, in a single row.
4. The research completion screen shows the rarity-tinted RP icon next to the
   reward earned.
5. Unlock requirements display the rarity of each required point, colored by
   whether the player can afford that rarity.
6. An unlock requiring multiple rarities (e.g. shotgun = 1 common + 1 rare)
   only becomes purchasable when **all** required balances are covered, and
   deducts all of them atomically on purchase.
7. Every unlockable in the game has per-rarity costs assigned per §6.

## Open questions / tunables

1. Cost tables in §6 are first-pass — confirm or adjust the numbers.
2. Should the legendary artifact rarity ever be minted and, if so, get its own
   fourth currency? (currently folded into epic; out of scope)
3. Icon-vs-text for the requirement rows where horizontal space is tight —
   pick per final layout.
