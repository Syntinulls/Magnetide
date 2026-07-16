extends AugmentBehavior
class_name IncreasedRecyclingBehavior

## When a trash item is recycled, grants an extra chance to award double scrap.

## Effective double-scrap chance (percent) — the level-0 value, upgraded in place by the augment's
## AugmentUpgradeData effects (target BEHAVIOR).
@export var double_scrap_chance_percent: float = 25.0

var _player: Player = null


func initialize_for_run(context: Dictionary, _level: int) -> void:
	cleanup_after_run()
	_player = context.get("player", null) as Player
	if _player != null and is_instance_valid(_player):
		_player.recycler_double_scrap_chance_percent = maxf(double_scrap_chance_percent, 0.0)


func cleanup_after_run() -> void:
	if _player != null and is_instance_valid(_player):
		_player.recycler_double_scrap_chance_percent = 0.0
	_player = null


func get_current_effect_summary(_level: int) -> String:
	return "%s%% chance for double scrap" % Utils.format_number(maxf(double_scrap_chance_percent, 0.0))
