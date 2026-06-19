extends Resource
class_name UpgradeSlotState

@export var slot_id: StringName = &""
@export var equipped_item_id: StringName = &""
@export var unlocked: bool = false


func is_unlocked() -> bool:
	return unlocked


func unlock() -> void:
	unlocked = true
