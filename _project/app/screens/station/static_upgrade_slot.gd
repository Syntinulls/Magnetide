extends UpgradeSlot
class_name StaticUpgradeSlot

## An upgrade slot holding one fixed item — a static stat (StatItemData) or the magnet gun. Its
## upgrade track lives on `item.upgrade_data`; progress is tracked per item_id in the loadout.

@export var item: ItemData = null


func get_upgrade_id() -> StringName:
	return item.item_id if item != null else &""


func _authored_max() -> int:
	return item.get_max_level() if item != null else max_level
