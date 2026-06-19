extends UpgradeableItemData
class_name StatUpgradeableItemData

enum TargetScope { LOADOUT, EQUIPMENT }
enum IncreaseMode { FLAT, PERCENT_OF_BASE }

@export var target_scope: TargetScope = TargetScope.LOADOUT
@export var target_property: StringName = &""
@export var amount_per_level: float = 0.0
@export var level_amounts: Array[float] = []
@export var increase_mode: IncreaseMode = IncreaseMode.FLAT


func get_current_effect_summary(state: Resource) -> String:
	var level := _get_state_level(state)
	if not _is_state_unlocked(state):
		return "Locked"
	var total := _get_total_amount(level)
	return _format_effect(total)


func get_next_level_gain_summary(state: Resource) -> String:
	var level := _get_state_level(state)
	if not _is_state_unlocked(state) or level >= max_level:
		return ""
	return "%s -> %s" % [
		_format_effect(_get_total_amount(level)),
		_format_effect(_get_total_amount(level + 1)),
	]


func get_delta_for_base(base_value: Variant, level: int) -> float:
	if typeof(base_value) != TYPE_INT and typeof(base_value) != TYPE_FLOAT:
		return 0.0
	var amount := _get_total_amount(level)
	if increase_mode == IncreaseMode.PERCENT_OF_BASE:
		return float(base_value) * amount
	return amount


func _get_total_amount(level: int) -> float:
	var applied_levels := clampi(level, 0, max_level)
	if not level_amounts.is_empty():
		var total := 0.0
		var count := mini(applied_levels, level_amounts.size())
		for index in range(count):
			total += level_amounts[index]
		return total
	return amount_per_level * float(applied_levels)


func _format_effect(amount: float) -> String:
	var property_name := String(target_property).replace("_", " ").capitalize()
	if increase_mode == IncreaseMode.PERCENT_OF_BASE:
		return "%s +%s%%" % [property_name, _format_number(amount * 100.0)]
	return "%s +%s" % [property_name, _format_number(amount)]


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value
