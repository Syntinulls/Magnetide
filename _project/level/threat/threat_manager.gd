extends Node
class_name ThreatManager

signal threat_changed(new_value: float)
signal threat_level_changed(new_level: int)

const MAX_THREAT: float = 100.0
const LEVEL_COUNT: int = 5
const THREAT_SEGMENT_SIZE: float = 25.0
const DEFAULT_RUN_DURATION_SECONDS: float = 600.0
const DEFAULT_FINAL_MINUTE_SECONDS: float = 60.0

var _current_threat: float = 0.0
var _countdown_timer: CountdownTimer = null

var current_threat: float:
	get:
		return _current_threat
	set(value):
		var old_level := threat_level
		_current_threat = clampf(value, 0.0, MAX_THREAT)
		threat_changed.emit(_current_threat)
		var new_level := threat_level
		if new_level != old_level:
			threat_level_changed.emit(new_level)

var threat_level: int:
	get:
		if current_threat >= MAX_THREAT:
			return LEVEL_COUNT - 1
		return mini(int(current_threat / THREAT_SEGMENT_SIZE), LEVEL_COUNT - 2)

var threat_ratio: float:
	get:
		return current_threat / MAX_THREAT

var passive_threat_per_second: float:
	get:
		return MAX_THREAT / _get_time_to_max_threat()


func _ready() -> void:
	set_process(true)
	call_deferred("_connect_countdown_timer")


func _process(delta: float) -> void:
	if current_threat >= MAX_THREAT:
		return
	add_threat(passive_threat_per_second * delta)


func add_threat(amount: float) -> void:
	if amount <= 0.0:
		return
	current_threat += amount


func reset() -> void:
	current_threat = 0.0
	set_process(true)


func _connect_countdown_timer() -> void:
	var game_ui := Magnetide.game_ui
	if game_ui:
		_countdown_timer = game_ui.get_node_or_null("CountdownTimer") as CountdownTimer


func _get_time_to_max_threat() -> float:
	if not _countdown_timer:
		_connect_countdown_timer()
	if _countdown_timer:
		return _countdown_timer.time_until_final_stretch
	return maxf(DEFAULT_RUN_DURATION_SECONDS - DEFAULT_FINAL_MINUTE_SECONDS, 1.0)
