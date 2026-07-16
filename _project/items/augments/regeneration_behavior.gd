extends AugmentBehavior
class_name RegenerationBehavior

## Effective tunables — the level-0 values, upgraded in place by the augment's AugmentUpgradeData
## effects (target BEHAVIOR) before a run and before each gain-summary computation.
@export var out_of_combat_seconds: float = 6.0
@export var health_per_second: float = 2.0

var _player: Player = null
var _seconds_since_damage: float = 0.0


func initialize_for_run(context: Dictionary, _level: int) -> void:
	cleanup_after_run()
	_player = context.get("player", null) as Player
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_signal("damaged") and not _player.damaged.is_connected(_on_player_damaged):
		_player.damaged.connect(_on_player_damaged)
	_seconds_since_damage = 0.0
	_player.set_process(true)


func cleanup_after_run() -> void:
	if _player != null and is_instance_valid(_player):
		if _player.has_signal("damaged") and _player.damaged.is_connected(_on_player_damaged):
			_player.damaged.disconnect(_on_player_damaged)
	_player = null
	_seconds_since_damage = 0.0


func tick(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.current_health <= 0.0:
		return
	_seconds_since_damage += delta
	if _seconds_since_damage < maxf(out_of_combat_seconds, 0.0):
		return
	_player.heal(maxf(health_per_second, 0.0) * delta)


func get_current_effect_summary(_level: int) -> String:
	return "Regen %s HP/s after %ss" % [
		Utils.format_number(maxf(health_per_second, 0.0)),
		Utils.format_number(maxf(out_of_combat_seconds, 0.0)),
	]


func _on_player_damaged(_amount: float, _source: Node) -> void:
	_seconds_since_damage = 0.0
