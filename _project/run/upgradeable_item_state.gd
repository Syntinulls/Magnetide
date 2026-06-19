extends Resource
class_name UpgradeableItemState

@export var item_id: StringName = &""
@export var current_level: int = 0:
	set(value):
		current_level = maxi(value, 0)
@export var unlocked: bool = false:
	set(value):
		unlocked = value


func is_unlocked() -> bool:
	return unlocked


func unlock() -> void:
	unlocked = true


func increase_level(max_level: int, amount: int = 1) -> bool:
	var previous_level := current_level
	current_level = clampi(current_level + amount, 0, maxi(max_level, 0))
	if current_level != previous_level:
		unlocked = true
	return current_level != previous_level
