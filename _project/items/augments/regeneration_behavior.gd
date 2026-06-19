extends AugmentBehavior
class_name RegenerationBehavior

@export var base_out_of_combat_seconds: float = 6.0
@export var out_of_combat_seconds_per_level: float = -0.5
@export var base_health_per_second: float = 2.0
@export var health_per_second_per_level: float = 0.75

var _player: Player = null
var _level: int = 0
var _seconds_since_damage: float = 0.0
var _process_node: Node = null


func initialize_for_run(context: Dictionary, level: int) -> void:
	cleanup_after_run()
	_level = maxi(level, 0)
	_player = context.get("player", null) as Player
	if _player == null or not is_instance_valid(_player):
		return
	if _player.has_signal("damaged") and not _player.damaged.is_connected(_on_player_damaged):
		_player.damaged.connect(_on_player_damaged)
	_process_node = _player
	_seconds_since_damage = 0.0
	_player.set_process(true)


func cleanup_after_run() -> void:
	if _player != null and is_instance_valid(_player):
		if _player.has_signal("damaged") and _player.damaged.is_connected(_on_player_damaged):
			_player.damaged.disconnect(_on_player_damaged)
	_player = null
	_process_node = null
	_seconds_since_damage = 0.0


func tick(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.current_health <= 0.0:
		return
	_seconds_since_damage += delta
	if _seconds_since_damage < get_out_of_combat_seconds(_level):
		return
	_player.heal(get_health_per_second(_level) * delta)


func get_current_effect_summary(level: int) -> String:
	return "Regen %s HP/s after %ss" % [
		_format_number(get_health_per_second(level)),
		_format_number(get_out_of_combat_seconds(level)),
	]


func get_next_level_gain_summary(level: int, max_level: int) -> String:
	if level >= max_level:
		return ""
	return "%s -> %s" % [
		get_current_effect_summary(level),
		get_current_effect_summary(level + 1),
	]


func get_out_of_combat_seconds(level: int) -> float:
	var upgraded := base_out_of_combat_seconds + out_of_combat_seconds_per_level * float(maxi(level, 0))
	return maxf(upgraded, 0.0)


func get_health_per_second(level: int) -> float:
	return maxf(base_health_per_second + health_per_second_per_level * float(maxi(level, 0)), 0.0)


func _on_player_damaged(_amount: float, _source: Node) -> void:
	_seconds_since_damage = 0.0


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value
