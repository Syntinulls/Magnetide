extends AugmentBehavior
class_name AdrenalineBehavior

## The lower the player's health, the more damage they deal. The bonus reaches
## its maximum at or below `max_bonus_health_ratio` health and falls off linearly
## to zero at full health.

## Health fraction (0-1) at or below which the full damage bonus applies.
@export_range(0.0, 1.0, 0.01) var max_bonus_health_ratio: float = 0.10
## Damage bonus (percent) at the lowest augment level, when at max_bonus_health_ratio.
@export var base_max_damage_bonus_percent: float = 25.0
## Additional max damage bonus (percent) gained per augment level.
@export var max_damage_bonus_percent_per_level: float = 5.0
## Hard cap on the max damage bonus (percent) regardless of level.
@export var max_damage_bonus_cap_percent: float = 50.0

var _player: Player = null
var _level: int = 0


func initialize_for_run(context: Dictionary, level: int) -> void:
	cleanup_after_run()
	_level = maxi(level, 0)
	_player = context.get("player", null) as Player
	_update_damage_multiplier()


func cleanup_after_run() -> void:
	if _player != null and is_instance_valid(_player):
		_player.outgoing_damage_multiplier = 1.0
	_player = null
	_level = 0


func tick(_delta: float) -> void:
	_update_damage_multiplier()


func _update_damage_multiplier() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.outgoing_damage_multiplier = 1.0 + get_damage_bonus_fraction(_level, _get_health_ratio())


func _get_health_ratio() -> float:
	if _player == null or not is_instance_valid(_player) or _player.max_health <= 0.0:
		return 1.0
	return clampf(_player.current_health / _player.max_health, 0.0, 1.0)


## Max damage bonus (percent) at a given level, before the health falloff.
func get_max_damage_bonus_percent(level: int) -> float:
	var bonus := base_max_damage_bonus_percent + max_damage_bonus_percent_per_level * float(maxi(level, 0))
	return minf(bonus, max_damage_bonus_cap_percent)


## Actual damage bonus as a fraction (e.g. 0.5 = +50%) given level and health ratio.
func get_damage_bonus_fraction(level: int, health_ratio: float) -> float:
	var falloff := 0.0
	var span := 1.0 - max_bonus_health_ratio
	if span > 0.0:
		falloff = clampf((1.0 - health_ratio) / span, 0.0, 1.0)
	elif health_ratio <= max_bonus_health_ratio:
		falloff = 1.0
	return get_max_damage_bonus_percent(level) / 100.0 * falloff


func get_current_effect_summary(level: int) -> String:
	return "Up to +%s%% damage at low HP" % _format_number(get_max_damage_bonus_percent(level))


func get_next_level_gain_summary(level: int, max_level: int) -> String:
	if level >= max_level:
		return ""
	return "+%s%% -> +%s%% max damage" % [
		_format_number(get_max_damage_bonus_percent(level)),
		_format_number(get_max_damage_bonus_percent(level + 1)),
	]


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value
