extends Resource
class_name AugmentBehavior


func initialize_for_run(_context: Dictionary, _level: int) -> void:
	pass


func apply_to_loadout(_loadout: RunLoadout, _level: int) -> void:
	pass


func apply_to_equipment(_equipment_data: HeldItemData, _level: int) -> void:
	pass


func apply_to_level(_level_node: Node, _level: int) -> void:
	pass


func cleanup_after_run() -> void:
	pass


func get_current_effect_summary(_level: int) -> String:
	return ""
