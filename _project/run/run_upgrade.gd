extends Resource
class_name RunUpgrade

## Mutable per-run save/state held by RunLoadout: what is equipped in every slot plus each item's
## upgrade progress. Definitions (levels, costs, effects) live in each item's UpgradeData — this
## carries only state. RunLoadout exposes these fields through delegating properties so consumers
## read `loadout.equipped_weapon` etc. transparently.

@export var equipped_weapon: WeaponData = null
@export var equipped_magnet_tool: MagnetToolData = null
@export var player_equipment: Array[HeldItemData] = []
@export var player_selected_equipment_index: int = 0
@export var player_augments: Array[AugmentData] = []
@export var ship_augments: Array[AugmentData] = []
@export var magnet_augments: Array[AugmentData] = []
## Per-item upgrade progress (UpgradeableItemState), keyed by item_id — weapons, the magnet gun,
## augments, and the static stat items.
@export var item_states: Array[Resource] = []
@export var slot_states: Array[Resource] = []
## Captured base values of loadout stats the upgrades modify, so re-applying is idempotent.
@export var upgrade_base_values: Dictionary = {}
