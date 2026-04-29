extends Resource
class_name RunUpgrade

enum TargetScope { LOADOUT, EQUIPPED_WEAPON, EQUIPPED_MAGNET_TOOL }
enum IncreaseMode { FLAT, PERCENT_OF_BASE }

@export var upgrade_id: StringName = &""
@export var display_name: String = ""
@export var current_level: int = 0:
	set(value):
		current_level = clampi(value, 0, max_level)
@export var max_level: int = 5:
	set(value):
		max_level = maxi(value, 1)
		current_level = clampi(current_level, 0, max_level)
@export var amount_per_level: float = 0.0
@export var level_amounts: Array[float] = []
@export var target_scope: TargetScope = TargetScope.LOADOUT
@export var target_property: StringName = &""
@export var increase_mode: IncreaseMode = IncreaseMode.FLAT
@export var upgrade_costs: Array[Resource] = []


func is_maxed() -> bool:
	return current_level >= max_level


func increase_level(amount: int = 1) -> bool:
	var previous_level := current_level
	current_level = clampi(current_level + amount, 0, max_level)
	return current_level != previous_level


func get_total_amount() -> float:
	if not level_amounts.is_empty():
		var total := 0.0
		var level_count := mini(current_level, level_amounts.size())
		for index in range(level_count):
			total += level_amounts[index]
		return total
	return amount_per_level * float(current_level)


func get_amount_per_level_text() -> String:
	if not level_amounts.is_empty():
		return _get_level_amounts_text()
	if increase_mode == IncreaseMode.PERCENT_OF_BASE:
		return "+%s%% / level" % _format_number(amount_per_level * 100.0)
	return "+%s / level" % _format_number(amount_per_level)


func get_level_text() -> String:
	return "%d / %d" % [current_level, max_level]


func get_next_level_cost() -> Resource:
	if is_maxed():
		return null
	if current_level < 0 or current_level >= upgrade_costs.size():
		return null
	return upgrade_costs[current_level]


func get_next_level_cost_text() -> String:
	if is_maxed():
		return "MAX LEVEL"

	var next_cost := get_next_level_cost()
	if next_cost == null:
		return "No cost"
	if next_cost.has_method("get_display_text"):
		return String(next_cost.call("get_display_text"))
	return str(next_cost)


func get_next_level_gain_text(stat_name: String = "") -> String:
	if is_maxed():
		return "MAX LEVEL"

	var amount := _get_next_level_amount()
	var stat_suffix := "" if stat_name.is_empty() else " %s" % stat_name
	if increase_mode == IncreaseMode.PERCENT_OF_BASE:
		return "+%s%%%s" % [_format_number(amount * 100.0), stat_suffix]
	return "+%s%s" % [_format_number(amount), stat_suffix]


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not String(upgrade_id).is_empty():
		return String(upgrade_id).capitalize()
	return "Upgrade"


func get_value_with_upgrade(base_value: Variant) -> Variant:
	if typeof(base_value) != TYPE_INT and typeof(base_value) != TYPE_FLOAT:
		return base_value

	var base_number := float(base_value)
	var total_amount := get_total_amount()
	var increase := total_amount
	if increase_mode == IncreaseMode.PERCENT_OF_BASE:
		increase = base_number * total_amount

	var upgraded_value := base_number + increase
	if typeof(base_value) == TYPE_INT:
		return int(round(upgraded_value))
	return upgraded_value


func get_delta_from_base(base_value: Variant) -> float:
	if typeof(base_value) != TYPE_INT and typeof(base_value) != TYPE_FLOAT:
		return 0.0
	return float(get_value_with_upgrade(base_value)) - float(base_value)


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value


func _get_next_level_amount() -> float:
	if not level_amounts.is_empty():
		var next_level := clampi(current_level, 0, level_amounts.size() - 1)
		return level_amounts[next_level]
	return amount_per_level


func _get_level_amounts_text() -> String:
	var first_amount := level_amounts[0]
	var uses_fixed_amount := true
	for amount in level_amounts:
		if not is_equal_approx(amount, first_amount):
			uses_fixed_amount = false
			break

	if uses_fixed_amount:
		if increase_mode == IncreaseMode.PERCENT_OF_BASE:
			return "+%s%% / level" % _format_number(first_amount * 100.0)
		return "+%s / level" % _format_number(first_amount)

	var next_level := clampi(current_level, 0, level_amounts.size() - 1)
	var next_amount := level_amounts[next_level]
	if increase_mode == IncreaseMode.PERCENT_OF_BASE:
		return "NEXT: +%s%%" % _format_number(next_amount * 100.0)
	return "NEXT: +%s" % _format_number(next_amount)
