extends AugmentBehavior
class_name RegenerationBehavior

## Effective tunables — the level-0 values, upgraded in place by the augment's AugmentUpgradeData
## effects (target BEHAVIOR) before a run and before each gain-summary computation.
@export var out_of_combat_seconds: float = 6.0
@export var health_per_second: float = 2.0

## Healing lands in one whole health_per_second chunk each second (not smeared
## per frame), so the heal popups the player sees match the stat's number.
const HEAL_TICK_SECONDS := 1.0

var _player: Player = null
var _heal_tick_elapsed: float = 0.0


func initialize_for_run(context: Dictionary, _level: int) -> void:
	cleanup_after_run()
	_player = context.get("player", null) as Player
	if _player == null or not is_instance_valid(_player):
		return
	_player.set_process(true)


func cleanup_after_run() -> void:
	_player = null
	_heal_tick_elapsed = 0.0


## Reads the player's own out-of-combat clock rather than tracking its own, so
## every damage source — including storm drain, which never lands as a discrete
## hit — suppresses regeneration without this behavior knowing about any of them.
func tick(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.health.current_health <= 0.0:
		return
	if _player.health.seconds_since_damage < maxf(out_of_combat_seconds, 0.0):
		_heal_tick_elapsed = 0.0
		return
	_heal_tick_elapsed += delta
	if _heal_tick_elapsed >= HEAL_TICK_SECONDS:
		_heal_tick_elapsed -= HEAL_TICK_SECONDS
		_player.heal(maxf(health_per_second, 0.0))


func get_current_effect_summary(_level: int) -> String:
	return "Regen %s HP/s after %ss" % [
		Utils.format_number(maxf(health_per_second, 0.0)),
		Utils.format_number(maxf(out_of_combat_seconds, 0.0)),
	]
