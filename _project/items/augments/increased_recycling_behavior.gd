extends AugmentBehavior
class_name IncreasedRecyclingBehavior

## When a trash item is recycled, grants an extra chance to award double scrap.
## The chance grows with the augment level.

## Double-scrap chance (percent) at the lowest augment level.
@export var base_double_scrap_chance_percent: float = 25.0
## Additional double-scrap chance (percent) gained per augment level.
@export var double_scrap_chance_percent_per_level: float = 5.0
## Hard cap on the double-scrap chance (percent) regardless of level.
@export var double_scrap_chance_cap_percent: float = 50.0

var _player: Player = null


func initialize_for_run(context: Dictionary, level: int) -> void:
	cleanup_after_run()
	_player = context.get("player", null) as Player
	if _player != null and is_instance_valid(_player):
		_player.recycler_double_scrap_chance_percent = get_double_scrap_chance_percent(maxi(level, 0))


func cleanup_after_run() -> void:
	if _player != null and is_instance_valid(_player):
		_player.recycler_double_scrap_chance_percent = 0.0
	_player = null


## Double-scrap chance (percent) for a given augment level.
func get_double_scrap_chance_percent(level: int) -> float:
	var chance := base_double_scrap_chance_percent + double_scrap_chance_percent_per_level * float(maxi(level, 0))
	return minf(chance, double_scrap_chance_cap_percent)


func get_current_effect_summary(level: int) -> String:
	return "%s%% chance for double scrap" % _format_number(get_double_scrap_chance_percent(level))


func get_next_level_gain_summary(level: int, max_level: int) -> String:
	if level >= max_level:
		return ""
	return "%s%% -> %s%% double scrap" % [
		_format_number(get_double_scrap_chance_percent(level)),
		_format_number(get_double_scrap_chance_percent(level + 1)),
	]


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value
