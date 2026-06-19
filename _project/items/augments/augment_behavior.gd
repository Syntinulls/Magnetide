extends Resource
class_name AugmentBehavior


func initialize_for_run(_context: Dictionary, _level: int) -> void:
	pass


func apply_to_loadout(_loadout: RunLoadout, _level: int) -> void:
	pass


func apply_to_equipment(_equipment_data: EquipmentData, _level: int) -> void:
	pass


func apply_to_level(_level_node: Node, _level: int) -> void:
	pass


func cleanup_after_run() -> void:
	pass


func get_current_effect_summary(_level: int) -> String:
	return ""


func get_next_level_gain_summary(_level: int, _max_level: int) -> String:
	return ""
