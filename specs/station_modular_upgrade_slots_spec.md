# Station Modular Upgrade Slots Specification

## Overview

This spec defines the next station screen iteration: a compact, reusable slot-based system for equipment, upgrades, and augments.

The current station screen has separate concepts for weapon equipping and stat upgrades:

- weapon selection is handled through a weapon-specific popup
- upgrades are hard-wired to named rows such as weapon damage, magnet pull, health, and shield
- upgrade UI rows are large and consume too much of the player page
- upgrade state is grouped by broad categories in `RunLoadout`, not owned by the thing being upgraded

The new model should make every visible station component a slot containing an upgradeable thing. Weapons, equipment, stat upgrades, and augments should share the same UI components and most of the same data flow.

---

## Goals

1. Make the station screen more compact while preserving readable icon-first controls.
2. Replace hard-coded upgrade rows with reusable slot UI components.
3. Let weapons, equipment, static stats, and augments all use one common "upgradeable item in a slot" model.
4. Support static slots for permanent systems such as health, shield, and magnet gun.
5. Support dynamic slots for swappable choices such as weapons and augments.
6. Generalize the current weapon equipment popup into a reusable dynamic slot selection popup.
7. Give every available slottable item its own current level, max level, and upgrade cost progression.
8. Add augments as modular passive abilities with unique behavior scripts.
9. Hide upgrade tick UI for anything whose `max_level` is `1`.

---

## Terminology

| Term | Meaning |
|---|---|
| Slot | A station UI location that can hold one upgradeable item. |
| Static Slot | A slot whose occupant cannot be swapped. Examples: player health, player shield, magnet gun. |
| Dynamic Slot | A slot whose occupant can be changed through a selection popup. Examples: weapon slot, augment slots. |
| Slottable Item | Any item that can appear in a slot: weapon, magnet tool, stat upgrade, augment, ship upgrade, etc. |
| Upgradeable | A slottable item with an `unlocked` flag, current level, max level, and per-level costs. Level `0` is the baseline item state and does not imply locked. `unlocked == false` means locked or not yet owned. |
| Augment | A passive slottable item that applies custom behavior through a behavior script. |
| Catalog Entry | An unlockable option shown in a dynamic slot selection popup. |

---

## Station Layout

The station screen should keep the existing two-page structure from `station_screen_spec.md`, but the player page needs a denser layout.

### Player Page

The left/player page should keep the player avatar as the center anchor.

Left side: equipment-oriented slots.

- dynamic weapon slot
- static magnet gun slot
- one dynamic player augment slot

Right side: upgrade/stat-oriented slots.

- static player health slot
- static player shield slot
- one dynamic player augment slot
- any player-facing passive stat upgrades

The guiding split is:

- left side is for equippable/player-carried things such as weapon and magnet gun
- right side is for upgrades, stats, and passive augment-style modifiers

Player augments should be split one per side. This keeps the two player augment slots visible without letting one side grow into another oversized upgrade block.

### Ship Page

The right/ship page should also use the same slot components when ship upgrades are introduced.

The ship page should split magnet-specific and ship-specific systems into left and right groups:

Left side: ship magnet slots.

- static ship magnet capacity slot
- static ship magnet health slot
- dynamic magnet augment slot

Right side: ship body/storage slots.

- static hull slot
- static storage slot
- dynamic ship augment slot

The magnet augment is for the ship magnet, not the player magnet gun, so it belongs on the ship page's left magnet-side group.

---

## Slot Counts

Required augment slots:

| Owner | Slots | Slot Type |
|---|---:|---|
| Player | 2 | Dynamic augment slots |
| Ship | 1 | Dynamic augment slot |
| Magnet | 1 | Dynamic augment slot |

Required equipment/stat slots:

| Slot | Owner | Type | Notes |
|---|---|---|---|
| Weapon | Player | Dynamic | Replaces current weapon-specific popup trigger. |
| Magnet Gun | Player | Static | Permanent tool, upgradeable. |
| Health | Player | Static | Permanent stat upgrade. |
| Shield | Player | Static | Permanent stat upgrade. |
| Hull | Ship | Static | Existing `ship_hull` upgrade target. |
| Storage | Ship | Static | Existing `ship_storage` upgrade target. |
| Magnet Capacity | Magnet | Static | Existing `ship_magnet_capacity` target. |
| Magnet Health | Magnet | Static | Existing `ship_magnet_health` target. |

---

## Compact Slot UI

Create one reusable station slot component that can render all slot types.

Suggested scene:

| File | Purpose |
|---|---|
| `_project/app/screens/station_upgrade_slot.tscn` | Compact slot card/row shared by equipment, upgrades, and augments. |
| `_project/app/screens/station_upgrade_slot.gd` | Binds slot definition, occupant, level state, upgrade action, and selection action. |

### Slot Visual Shape

Each slot should be compact enough to stack several items without taking over the page.

Recommended first-pass footprint:

- about `220-280 px` wide
- about `54-72 px` tall
- one icon bay around `44-56 px`
- compact name text
- compact level/cost area
- one small upgrade button
- one small change/equip button only for dynamic slots

The current large horizontal rows with five large vertical ticks should be replaced with a denser card or slim row treatment.

### Slot Contents

Every station slot should be able to show:

- occupant icon
- occupant name
- one short current-effect summary, such as `Damage 14`, `Health +15%`, `Shield Hits +1`, or `Pull Speed +10%`
- current level text, such as `Lv 2/5`
- upgrade ticks only when `max_level > 0`
- upgrade button only when `max_level > 0` and not maxed
- maxed state when `current_level >= max_level`
- locked or empty state for dynamic slots
- change/equip affordance for dynamic slots

The slot itself should provide enough visual information that the player can understand what is installed and what broad benefit it gives without opening a popup. Detailed costs, exact stat deltas, and multi-line effect explanations belong in hover/focus popups so the compact layout does not become bloated.

### Slot Upgrade Hover Popup

Every visible slot upgrade button, usually the arrow button, should show a detailed hover/focus popup.

Suggested file:

| File | Purpose |
|---|---|
| `_project/app/screens/station_upgrade_detail_popup.tscn` | Shared hover popup for slot upgrade buttons. |
| `_project/app/screens/station_upgrade_detail_popup.gd` | Displays level transition, required costs, affordability, and upgrade gains. |

The popup should appear when the mouse hovers the upgrade arrow or when the arrow receives controller/keyboard focus. It should hide when hover/focus leaves, when the slot changes, when a dynamic popup opens, when page panning starts, or after a route transition.

The popup should show:

- occupant name
- current level
- target level, shown as a transition such as `Lv 2 -> 3`
- max level, when useful
- required parts for the target level
- owned quantity versus required quantity for each part
- affordability state for each required part
- current stat/effect summary
- gained stat/effect summary for the target level
- final stat/effect preview after purchase
- maxed message when the item is already at max level

Example popup content:

```text
Rifle
Upgrade: Lv 2 -> 3

Requires
Gear: 4 / 3
Circuitry: 1 / 2

Gains
Damage: 13.2 -> 14.5 (+1.3)
Fire Rate: unchanged
```

For augments, the gains section should describe the behavior-level effect rather than only raw properties:

```text
Quick Capacitor
Upgrade: Lv 1 -> 2

Requires
Battery: 3 / 2
Processor: 0 / 1

Gains
Shield recharge delay: 6.0s -> 5.4s
```

The popup should be shared by all upgradeable slots. It should not contain weapon-only assumptions.

### Upgrade Tick Rule

If an occupant has `max_level == 0`, hide the tick container entirely.

Also hide:

- level text that implies progression
- upgrade button
- upgrade cost hover/action

The slot can still show a passive state such as `Installed`, `Equipped`, or `Active`.

### Suggested Tick Treatment

For items with `max_level > 0`, use a compact representation:

- short horizontal pips under the name
- or a tiny segmented bar
- or `Lv 2/5` text plus very small pips

The tick UI should scale to the occupant's true `max_level`, not assume five levels.

---

## Data Model

The current `RunUpgrade` resource can be evolved or wrapped, but the new system needs a more general concept than "an upgrade that targets a property."

### Project Folder Structure

The item system should be reorganized before or alongside the modular slot work so folder ownership stays clear.

Folder ownership:

| Folder | Purpose |
|---|---|
| `_project/app/screens/` | Pure station UI scenes and scripts. |
| `_project/run/` | Run progress, run loadout, save-facing slot state, selected item ids, and current item levels. |
| `_project/items/` | Generic item definitions and item behavior code. |
| `_project/items/salvage/` | Salvage items, salvage costs, salvage resources, salvage sprites, and salvage-specific item scripts. |
| `_project/items/equipment/` | Player equipment definitions, weapon/tool resources, weapon behavior scripts, and equipment-specific upgradeable item wrappers. |
| `_project/items/augments/` | Augment definitions, augment behavior scripts, and augment resources. |

Required folder migration:

1. Create `_project/items/salvage/`.
2. Move the current contents of `_project/items/` under `_project/items/salvage/`.
3. Move `_project/player/equipment/` to `_project/items/equipment/`.
4. Create `_project/items/augments/`.
5. Update resource paths, preloads, scene references, and `.tres` references affected by those moves.

After this migration, `items` means any authored item-like thing:

- salvage
- equipment
- augments

`RunLoadout` and other run/save resources should not own item definitions, upgrade definitions, or behavior scripts. They should store only the current run-facing state needed to start a run and persist player progress, such as:

- selected dynamic slot item ids
- current item levels
- current run loadout values
- run progress/results

### Upgradeable Item Definition

Introduce a resource that can be shared by equipment, stat upgrades, and augments.

Suggested script:

| File | Purpose |
|---|---|
| `_project/items/upgradeable_item_data.gd` | Base definition for anything that can occupy a station slot. |

Suggested fields:

```gdscript
@export var item_id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var max_level: int = 1
@export var level_costs: Array[Resource] = []
@export var tags: Array[StringName] = []
```

This base resource should not assume a target property. Property-based stat upgrades can be represented by a subclass or behavior resource.

Upgradeable item definitions should expose display helpers or data that let UI render both compact and detailed upgrade information:

```gdscript
func get_current_effect_summary(state: Resource) -> String:
	return ""

func get_next_level_gain_summary(state: Resource) -> String:
	return ""

func get_next_level_detail_lines(state: Resource) -> PackedStringArray:
	return PackedStringArray()
```

These helpers can be implemented directly on item definitions or delegated to item behavior resources. The important requirement is that the station UI does not need to know weapon-, stat-, or augment-specific math to describe what the next level does.

### Upgradeable Item State

Each available item needs its own persistent state.

This state belongs with run/save data because it stores only current player progress for authored item definitions. It should reference item ids, not contain item behavior or upgrade definition data.

Suggested script:

| File | Purpose |
|---|---|
| `_project/run/upgradeable_item_state.gd` | Save/runtime state for one upgradeable item. |

Suggested fields:

```gdscript
@export var item_id: StringName
@export var current_level: int = 0
@export var unlocked: bool = false
```

Rules:

- each weapon has its own level state
- each augment has its own level state
- each static stat upgrade has its own level state
- level state persists even when a dynamic item is not currently equipped
- `current_level` clamps between `0` and the item's `max_level`
- `unlocked` is the source of truth for whether an item is usable
- `current_level == 0` is the baseline unlocked state and means no upgrades have been purchased yet
- unlocking an item with research points sets `unlocked = true` and leaves `current_level = 0`
- default-unlocked items, including static slots such as player health, start with `unlocked = true` and `current_level = 0`
- locked static slots, such as player shield, start with `unlocked = false` and `current_level = 0`
- locked dynamic choices can also have `current_level = 0`; their `unlocked` flag remains `false` until researched
- `current_level` should never be used as the unlock check

### Slot Definition

Introduce a resource defining a station slot.

Suggested script:

| File | Purpose |
|---|---|
| `_project/items/upgrade_slot_definition.gd` | Defines a static or dynamic slot. |

Suggested fields:

```gdscript
enum SlotKind { STATIC, DYNAMIC }
enum SlotOwner { PLAYER, SHIP, MAGNET }
enum SlotCategory { EQUIPMENT, STAT, AUGMENT }

@export var slot_id: StringName
@export var display_name: String
@export var owner: SlotOwner
@export var category: SlotCategory
@export var kind: SlotKind
@export var static_item: Resource
@export var allowed_tags: Array[StringName] = []
@export var unlock_group: StringName = &""
```

Dynamic slots use `allowed_tags` to filter which catalog entries appear in their selection popup.

### Dynamic Slot State

Dynamic slots need to remember their selected occupant separately from item state.

This state also belongs with run/save data because it records the player's current slot selections.

Suggested script:

| File | Purpose |
|---|---|
| `_project/run/upgrade_slot_state.gd` | Persistent selected item for a dynamic slot. |

Suggested fields:

```gdscript
@export var slot_id: StringName
@export var equipped_item_id: StringName
```

Static slots can derive their occupant from the slot definition and may not need a saved `equipped_item_id`.

---

## Item Types

### Equipment

Existing `EquipmentData`, `WeaponData`, and `MagnetToolData` should be adapted to the upgradeable item model.

The existing `_project/player/equipment/` folder should move to `_project/items/equipment/`. Player scripts should reference equipment through the new item path after the migration.

Two approaches are acceptable:

1. Make equipment data extend or contain `UpgradeableItemData`.
2. Keep equipment data unchanged and create an upgradeable catalog wrapper around it.

The wrapper approach is safer for migration because weapon runtime code already expects `WeaponData` and `MagnetToolData`.

Suggested wrapper:

| File | Purpose |
|---|---|
| `_project/items/equipment/equipment_upgradeable_item_data.gd` | Upgradeable station definition that points at an `EquipmentData`. |

Suggested fields:

```gdscript
@export var equipment_data: EquipmentData
@export var stat_behaviors: Array[Resource] = []
```

Each weapon should have its own `item_id`, level, max level, and level costs.

### Static Stat Upgrades

Static stats such as health and shield should become upgradeable items with behavior that modifies a loadout property.

Suggested script:

| File | Purpose |
|---|---|
| `_project/items/stat_upgradeable_item_data.gd` | Upgradeable item that modifies one or more loadout/resource properties. |

This can replace the current hard-coded `RunLoadout.ensure_upgrade_state()` list over time.

### Salvage

Existing salvage item data, costs, resources, sprites, and salvage-specific scripts should move under `_project/items/salvage/`.

Examples after migration:

- `_project/items/salvage/salvage_item_data.gd`
- `_project/items/salvage/salvage_item_cost.gd`
- `_project/items/salvage/resources/gear.tres`
- `_project/items/salvage/sprites/part_gear.png`

Upgrade costs should continue to reference salvage item resources, but those resource paths should use the new salvage folder.

### Augments

Augments are passive slottable items. They can affect anything:

- player health
- player shield
- weapon damage
- weapon fire rate
- magnet pull behavior
- ship hull
- storage
- threat costs
- salvage outcomes
- cooldowns
- future systems

Each augment should have its own behavior script or behavior resource.

Most augment behaviors should be signal-driven at runtime. When a run starts, every equipped augment should be initialized, given the relevant run context, and connected to the signals it cares about. After that, the augment behavior should react to those signals and own any timers, cooldowns, counters, temporary state, or delayed effects it needs.

Suggested scripts:

| File | Purpose |
|---|---|
| `_project/items/augments/augment_data.gd` | Upgradeable augment definition. |
| `_project/items/augments/augment_behavior.gd` | Base behavior interface for passive augment effects. |

Suggested `AugmentData` fields:

```gdscript
@export var behavior: Resource
@export var owner_tags: Array[StringName] = []
```

Suggested behavior interface:

```gdscript
func initialize_for_run(context: Dictionary, level: int) -> void:
	pass

func apply_to_loadout(loadout: RunLoadout, level: int) -> void:
	pass

func apply_to_equipment(equipment_data: EquipmentData, level: int) -> void:
	pass

func apply_to_level(level_node: Node, level: int) -> void:
	pass

func cleanup_after_run() -> void:
	pass
```

Behavior methods should be optional. The augment application system should call only the hooks relevant to the current phase.

Runtime signal behavior should follow these rules:

- equipped augments initialize once per run start
- unequipped augments do not initialize or connect to runtime signals
- behavior resources connect only to the signals they need
- behavior resources disconnect or otherwise clean up when the run ends
- timers created by an augment behavior are owned and cleaned up by that behavior
- signal callbacks should use the augment's current level to scale effects
- passive stat-only augments may do all their work during loadout/equipment application and skip runtime signal hooks

The run context passed to augments should include stable references where available:

- `run_loadout`
- `level`
- `ship`
- `player`
- `magnet`
- `run_controller` or equivalent future run lifecycle object

Example signal-driven augment behaviors:

- on player damaged: gain temporary shield recharge speed
- on enemy killed: reduce current weapon cooldown
- on magnet activated: briefly increase pull strength
- on salvage collected: chance to duplicate a low-rarity part
- every few seconds during a run: emit a pulse that repairs a small amount of ship hull

### First Augment

Add one player augment for the first implementation: Regeneration.

Regeneration behavior:

- after the player has gone `X` seconds without taking damage, begin regenerating health
- regenerate at `Y` health per second
- stop regenerating when the player reaches max health
- reset the out-of-combat timer whenever the player takes damage
- do not regenerate while the player is dead, in a transition, or otherwise outside active run gameplay
- initialize at run start only when equipped in one of the player augment slots
- connect to the player damage signal, or equivalent future damage event, to track the last time damage was taken
- own any timer or process state needed for delay and healing ticks
- clean up signal connections and timers when the run ends

Regeneration upgrade scaling:

- `X` starts from an authored base out-of-combat delay
- `Y` starts from an authored base health-per-second value
- upgrades can reduce `X`, increase `Y`, or both
- the upgrade detail popup should show the exact delay and regen-rate changes for the next level
- the compact slot summary can use a short value such as `Regen 2 HP/s after 5s`

The two player augment slots share the same player augment pool. Regeneration can only be equipped in one player augment slot at a time. If Regeneration is already equipped in the other player augment slot, the popup should display that state with a distinct visual indicator, and selecting Regeneration should move it into the source slot.

Future augment concepts:

- reinforced suit: increases player health
- quick capacitor: reduces shield recharge delay
- tuned barrel: increases selected weapon fire rate
- magnetic condenser: increases magnet hold capacity
- cargo lattice: increases ship storage

---

## Catalog And Unlocks

The current `EquipmentCatalogEntry` should be generalized instead of remaining weapon-only.

Suggested replacement or evolution:

| File | Purpose |
|---|---|
| `_project/items/slottable_catalog_entry.gd` | Catalog entry for any dynamic slot option. |

Suggested fields:

```gdscript
@export var item_data: Resource
@export var locked: bool = false
@export var research_unlock_id: StringName = &""
@export var research_unlock_group: StringName = &""
@export var research_unlock_order: int = 0
@export var research_point_cost: int = 0
@export var unlock_cost: Array[Resource] = []
```

Rules:

- weapons and augments use the same catalog entry type
- dynamic slot popups filter entries by slot `allowed_tags`
- research point unlocking works the same way current locked weapons work
- continue storing research unlocks in `AppSaveData.unlocked_research_ids` for now so the save can directly answer what has been researched
- when a locked catalog entry is unlocked with research points, its item state is created or updated with `unlocked = true` and `current_level = 0`
- default-unlocked catalog entries should also ensure their item state starts with `unlocked = true` and `current_level = 0`
- item usability should be checked with the item state's `unlocked` flag, while `unlocked_research_ids` remains the broad researched-id record for now
- only the next locked item in a group should be unlockable when sequential unlock behavior is desired
- unlocking an item does not automatically equip it unless the final UI design says otherwise

---

## Generalized Dynamic Slot Popup

The current weapon equipment popup should become a reusable slot selection popup.

Suggested files:

| File | Purpose |
|---|---|
| `_project/app/screens/station_slot_select_popup.tscn` | Shared popup for selecting any dynamic slot occupant. |
| `_project/app/screens/station_slot_select_popup.gd` | Populates options, handles unlock/equip, and shows details. |
| `_project/app/screens/station_slot_option_row.tscn` | Compact row/card for one available dynamic option. |
| `_project/app/screens/station_slot_option_row.gd` | Displays option icon, level, lock/equipped state, and unlock action. |

### Popup Behavior

The popup should:

- open from any dynamic station slot
- show the current occupant
- list all compatible catalog entries
- show locked, unlocked, equipped in this slot, equipped in another slot, and unaffordable states
- allow research-point unlocking
- locked option rows show an inline `Unlock` button next to the item name
- hovering/focusing anywhere on an option row still shows the generic item detail panel
- clicking the inline `Unlock` button unlocks the entry only if its research cost can be paid
- locked entry names should not append unlock cost text such as `1 RP`; unlock details belong in the item detail panel
- equip unlocked items into the source slot
- if the chosen item is already equipped in a different compatible slot, unequip it from that other slot and equip it into the source slot
- close on outside click, page pan, route change, or successful equip

Dynamic slots that share an item pool, such as the two player augment slots, should use the same popup list. If an item in that shared pool is already equipped in the other slot, the option row needs a distinct visual indicator so the player understands selecting it will move the item rather than duplicate it.

The upgrade ticks and upgrade button associated with a dynamic slot should always describe and upgrade the item currently equipped in that slot. Popup option rows can show item level state for comparison, but item upgrades should only be purchased after the item is equipped into a slot.

### Popup Details Panel

The existing hovered-weapon stats panel should become a generic hovered-item details panel.

It should show:

- item name
- description
- current level and max level
- current effect summary
- next level effect summary when `max_level > 0` and not maxed
- upgrade cost if relevant
- unlock cost if locked

Weapon-specific stat formatting can live behind item/behavior methods instead of in `StationScreen`.

---

## Upgrade Purchasing

Upgrade purchasing should be driven by the selected occupant's item state.

Rules:

- the station slot upgrade button upgrades the occupant in that slot
- hovering/focusing the station slot upgrade button shows the shared upgrade detail popup
- the upgrade detail popup shows the exact level transition being purchased, such as `Lv 2 -> 3`
- the upgrade detail popup shows required parts, owned counts, affordability, current effects, gained effects, and final preview values
- every displayed RP or part cost should include owned and required counts, formatted as owned first and required second, such as `1 RP (2 / 1)` or `x1 Gear (0 / 1)`
- locked static slots hide upgrade ticks and the normal upgrade button until unlocked
- locked static slots show an unlock button instead; hovering/focusing it shows item name, description, gains without a `GAINS` header, and unlock cost
- dynamic popup entries should not expose upgrade purchase actions
- dynamic items can only be upgraded after they are equipped into a slot
- the slot upgrade ticks and upgrade button should always be tied to the currently equipped occupant
- each item has independent level and cost state
- level `0 -> 1` is the first normal parts upgrade after the item has been unlocked
- normal part-cost upgrades start at `0 -> 1`
- `level_costs` should map to normal upgrade transitions, not research unlocks; for example, index `0` can represent `1 -> 2`, index `1` can represent `2 -> 3`, and so on
- spending costs uses the existing storage-cost flow from `AppSaveData.spend_upgrade_cost()` or a generalized equivalent
- if the item is maxed, show maxed state and disable upgrade
- if the player cannot afford the next level, show unaffordable state and disable or reject purchase
- if `max_level == 0`, hide upgrade UI entirely

Recommended generalized save method:

```gdscript
func spend_item_level_cost(item_data: Resource, item_state: Resource) -> bool:
	pass
```

This should replace calling `spend_upgrade_cost(upgrade)` directly from `StationScreen`.

---

## Applying Effects

Effect application needs to happen in clear phases so static stats, equipment upgrades, and augments can combine predictably.

Recommended order inside `RunLoadout.prepare_for_run()`:

1. Ensure default slot and item state exists.
2. Reset loadout and equipment values back to base definitions.
3. Apply static stat upgradeable items.
4. Build selected equipment from dynamic equipment slots.
5. Apply equipment item levels to their own equipment data.
6. Apply equipped augment stat modifiers to loadout and equipment.
7. Build `player_equipment` runtime array.

Recommended order when a run starts:

1. Apply the prepared `RunLoadout` to the level, ship, magnet, and player.
2. Create or activate runtime instances for every equipped augment behavior.
3. Pass each equipped augment behavior its run context and current level.
4. Let each equipped augment behavior connect to the signals it needs.
5. Keep the behavior active until the run ends or the augment system is explicitly shut down.

Recommended order when a run ends:

1. Notify every active augment behavior that the run is ending.
2. Disconnect augment-owned signal connections.
3. Stop and free augment-owned timers or helper nodes.
4. Clear temporary runtime state.

Important rules:

- item level state belongs to the item, not to the slot
- dynamic slot selection only chooses which item is active
- unequipped dynamic items keep their levels
- augments should not permanently mutate base resource files
- runtime augment behavior should initialize only for equipped augments
- runtime augment behavior should be signal-driven where possible
- runtime augment behavior must clean up signal connections, timers, and temporary state at run end
- use duplicated runtime resources for modified weapons/tools, matching the current preview pattern

---

## Save Data

`AppSaveData` should persist:

- current run loadout
- slot states for dynamic selections
- item states for levels/unlocks
- research points
- unlocked research ids
- storage entries used to pay costs

Suggested additions to `RunLoadout` or a nested station progression resource:

```gdscript
@export var slot_states: Array[Resource] = []
@export var item_states: Array[Resource] = []
```

These arrays should store progress state only. They should reference authored item definitions by id and should not embed authored upgrade data, augment behavior resources, or equipment resources.

Open migration question:

- Should slot/item state live directly on `RunLoadout`, or should `RunLoadout` reference a separate `StationProgression` resource?

For the current project shape, keeping current level/slot-selection state on `RunLoadout` is the smaller migration. A future `StationProgression` resource may be cleaner once station systems grow beyond run prep.

---

## UI Refactor Targets

`StationScreen` should stop owning individual hard-coded rows such as:

- `_weapon_row`
- `_magnet_row`
- `_health_row`
- `_shield_row`
- `_weapon_upgrade_button`
- `_magnet_upgrade_button`
- `_health_upgrade_button`
- `_shield_upgrade_button`

Instead, it should own collections:

```gdscript
var _slot_views_by_id: Dictionary = {}
var _active_slot_popup_source: Resource = null
```

`StationScreen` should be responsible for:

- page panning
- high-level screen routing
- loading slot definitions
- instancing slot UI components
- opening/closing the generic dynamic slot popup
- refreshing save/loadout-driven UI

`StationUpgradeSlot` should be responsible for:

- rendering one slot
- rendering visible occupant name and short current-effect summary
- emitting `upgrade_requested(slot_id)`
- emitting `upgrade_hovered(slot_id, button)` or equivalent so the screen can show the shared upgrade detail popup
- emitting `upgrade_unhovered(slot_id)` or equivalent so the screen can hide the shared upgrade detail popup
- emitting `selection_requested(slot_id)` for dynamic slots
- hiding tick/upgrade UI for `max_level == 0`

`StationSlotSelectPopup` should be responsible for:

- filtering compatible catalog entries
- rendering option rows
- unlocking entries
- equipping selected entries
- showing hovered option details

---

## First-Pass Implementation Plan

1. Move current `_project/items/` contents into `_project/items/salvage/`.
2. Move `_project/player/equipment/` into `_project/items/equipment/`.
3. Create `_project/items/augments/`.
4. Update Godot resource paths, preloads, and scene references after the folder migration.
5. Add data resources for upgradeable item definitions, slot definitions, augment data, augment behavior, and catalog entries under `_project/items/`.
6. Add run/save state resources for current item levels and dynamic slot selections under `_project/run/`.
7. Create compact `StationUpgradeSlot` UI and replace the four current hard-coded station upgrade rows with slot instances.
8. Preserve existing weapon equip behavior by routing the weapon slot through the new dynamic slot popup.
9. Move weapon catalog rendering out of `StationScreen` and into the reusable popup.
10. Add player augment slot definitions and placeholder augment resources.
11. Add ship and magnet augment slot definitions, even if the ship page initially displays them as compact placeholders.
12. Generalize upgrade purchasing to operate on item data plus item state.
13. Migrate existing `RunUpgrade` levels into item states or provide a compatibility adapter during transition.
14. Update effect application so equipment, static stats, and augments apply through the new slot/item pipeline.
15. Verify the station screen at the target resolution with all player slots visible and no oversized upgrade rows.

---

## Migration Notes

The current system can be migrated gradually.

### Compatibility Layer

During migration, static items can wrap existing `RunUpgrade` definitions:

- `weapon_damage`
- `magnet_tool_pull`
- `player_health`
- `player_shield`
- `ship_hull`
- `ship_storage`
- `ship_magnet_capacity`
- `ship_magnet_health`

This lets UI become slot-based before the full effect pipeline is rewritten. This should be treated as a temporary compatibility bridge; final authored item/upgrade definitions should live under `_project/items/`, while run/save state keeps only current levels and selected ids.

### Weapon Slot

The weapon slot should be the first dynamic slot migrated because the current weapon popup already proves most of the interaction model.

Keep existing behavior:

- locked shotgun uses research points
- unlocked weapon can be equipped
- equipped weapon updates the run loadout

Change the implementation:

- popup is launched by dynamic slot id
- list entries come from generic slottable catalog entries
- current/equipped state is derived from slot state
- weapon level belongs to the weapon item state

### Upgrade Levels

Existing `RunUpgrade` levels already start at `0 / 5`, and the modular item-state model should preserve that as the baseline unlocked level.

New level semantics:

- `unlocked == false`: locked, unowned, or unavailable
- level `0`: unlocked baseline state with no purchased upgrades
- levels `1..max_level`: purchased upgrades above the baseline
- research-point unlocks set `unlocked = true` and keep the item at level `0`
- default-unlocked items start with `unlocked = true` and level `0`

Implementation notes:

- new save data does not need to support old upgrade semantics
- upgrade-cost lookup should treat the first normal parts upgrade as `0 -> 1`
- expose `get_display_level_text()` on item state/item data so UI consistently shows `Lv 0/5`, `Lv 1/5`, etc.

---

## Acceptance Criteria

1. Weapons, magnet gun, health, shield, and augments render through the same station slot UI component.
2. Dynamic slots open a generic selection popup instead of weapon-specific UI.
3. The weapon slot still supports locked research-point unlocks and equipping.
4. Static slots do not show a selection affordance.
5. Every available dynamic item keeps its own current/max level and upgrade costs.
6. Locked items have `unlocked == false` and cannot be equipped or upgraded.
7. Research-point unlocks set `unlocked = true` and leave the item at `current_level == 0`.
8. Default-unlocked items, including player health and shield, start with `unlocked == true` and `current_level == 0`.
9. Each slot visibly shows the occupant name, level when relevant, and a short current-effect summary.
10. Hovering or focusing a slot upgrade arrow shows a detailed upgrade popup.
11. The upgrade detail popup shows the target level transition, required parts, owned counts, affordability, gained stats/effects, and final preview values.
12. Dynamic popup entries do not expose upgrade purchase actions.
13. Dynamic items can only be upgraded after they are equipped into a slot.
14. The slot upgrade ticks and upgrade button always target the item currently equipped in that slot.
15. Shared-pool dynamic popups show when an item is already equipped in another slot.
16. Selecting an item already equipped in another compatible slot moves it to the source slot instead of duplicating it.
17. Unequipping or moving a dynamic item does not reset its level.
18. Augments exist as upgradeable slottable items with behavior scripts.
19. Equipped augment behaviors initialize when a run starts and receive run context plus their current level.
20. Equipped augment behaviors can connect to relevant runtime signals and react to those signals.
21. Equipped augment behaviors own and clean up their signal connections, timers, and temporary state when the run ends.
22. Unequipped augment behaviors do not initialize or connect to runtime signals.
23. Player has two augment slots, ship has one, and magnet has one.
24. Player augment slots are split one per side on the player page.
25. The magnet augment appears on the ship page's left ship-magnet group.
26. The ship page places ship magnet slots on the left and ship body/storage slots on the right.
27. The first implemented augment is Regeneration.
28. Regeneration starts healing after an out-of-combat delay since the last damage taken, heals at an authored health-per-second rate, and scales those values through upgrades.
29. The generic item folder is split into `salvage`, `equipment`, and `augments` subfolders.
30. Authored item definitions, catalog entries, equipment wrappers, and augment behaviors live under `_project/items/`, not `_project/run/`.
31. `RunLoadout` and run/save resources store current levels and slot selections, not authored upgrade data or behavior scripts.
32. Upgrade ticks and upgrade controls are hidden for items with `max_level == 0`.
33. The station player page is visibly more compact than the current large upgrade-row layout.
34. Existing storage-cost spending still works for item upgrades.
35. Existing run preparation still produces upgraded runtime equipment and loadout stats.

---

## Resolved Decisions

1. Dynamic slot items can only be upgraded after they are equipped into a slot.
2. Player augment slots are split one per side.
3. The magnet augment belongs on the ship page with the ship magnet slots.
4. The ship page uses the left side for ship magnet slots and the right side for ship body/storage slots.
5. Continue using `unlocked_research_ids` as the broad researched-id record for now.
6. A specific item state's `unlocked` flag is used when checking whether that item is usable.
7. The first implemented augment is Regeneration.
8. `_project/items/` becomes the umbrella for salvage, equipment, and augments.
9. `_project/run/` remains for run/loadout/progress state and should not own authored item definitions or behavior scripts.
