extends AugmentBehavior
class_name AdrenalineBehavior

## The lower the player's health, the more damage they deal. The bonus reaches its maximum at or
## below `max_bonus_health_ratio` health and falls off linearly to zero at full health.

## Health fraction (0-1) at or below which the full damage bonus applies.
@export_range(0.0, 1.0, 0.01) var max_bonus_health_ratio: float = 0.10
## Effective max damage bonus (percent) at low HP — the level-0 value, upgraded in place by the
## augment's AugmentUpgradeData effects (target BEHAVIOR).
@export var max_damage_bonus_percent: float = 25.0

var _player: Player = null


func initialize_for_run(context: Dictionary, _level: int) -> void:
	cleanup_after_run()
	_player = context.get("player", null) as Player
	_update_damage_multiplier()


func cleanup_after_run() -> void:
	if _player != null and is_instance_valid(_player):
		_player.outgoing_damage_multiplier = 1.0
	_player = null


func tick(_delta: float) -> void:
	_update_damage_multiplier()


func _update_damage_multiplier() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.outgoing_damage_multiplier = 1.0 + get_damage_bonus_fraction(_get_health_ratio())


func _get_health_ratio() -> float:
	if _player == null or not is_instance_valid(_player) or _player.max_health <= 0.0:
		return 1.0
	return clampf(_player.current_health / _player.max_health, 0.0, 1.0)


## Actual damage bonus as a fraction (e.g. 0.5 = +50%) given the current health ratio.
func get_damage_bonus_fraction(health_ratio: float) -> float:
	var falloff := 0.0
	var span := 1.0 - max_bonus_health_ratio
	if span > 0.0:
		falloff = clampf((1.0 - health_ratio) / span, 0.0, 1.0)
	elif health_ratio <= max_bonus_health_ratio:
		falloff = 1.0
	return maxf(max_damage_bonus_percent, 0.0) / 100.0 * falloff


func get_current_effect_summary(_level: int) -> String:
	return "Up to +%s%% damage at low HP" % Utils.format_number(maxf(max_damage_bonus_percent, 0.0))
