@tool
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
var _threat_level_factors: Array[ThreatLevelData] = _create_default_threat_level_factors()

@export var threat_level_factors: Array[ThreatLevelData]:
	get:
		return _threat_level_factors
	set(value):
		_threat_level_factors = _normalize_threat_level_factors(value)

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


func _init() -> void:
	_threat_level_factors = _normalize_threat_level_factors(_threat_level_factors)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(true)
	call_deferred("_connect_countdown_timer")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
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


func get_level_factors(level: int = threat_level) -> ThreatLevelData:
	var clamped_level := clampi(level, 0, LEVEL_COUNT - 1)
	if clamped_level >= 0 and clamped_level < threat_level_factors.size():
		return threat_level_factors[clamped_level]
	return _create_default_threat_level_factors()[clamped_level]


func get_current_level_factors() -> ThreatLevelData:
	return get_level_factors(threat_level)


func get_pile_rarity_weights(level: int = threat_level) -> Dictionary:
	var factors := get_level_factors(level)
	if factors:
		return factors.get_pile_rarity_weights()
	return {}


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


static func _create_default_threat_level_factors() -> Array[ThreatLevelData]:
	return [
		_create_threat_level_data(95.0, 5.0, 0.0, 0.0, 1.0),
		_create_threat_level_data(85.0, 15.0, 0.0, 0.0, 1.5),
		_create_threat_level_data(70.0, 20.0, 10.0, 0.0, 2.0),
		_create_threat_level_data(60.0, 25.0, 13.0, 2.0, 3.0),
		_create_threat_level_data(0.0, 70.0, 22.0, 8.0, 4.0),
	]


static func _create_threat_level_data(common: float, rare: float, epic: float, legendary: float, artifact: float) -> ThreatLevelData:
	var data := ThreatLevelData.new()
	data.common_weight = common
	data.rare_weight = rare
	data.epic_weight = epic
	data.legendary_weight = legendary
	data.artifact_weight = artifact
	return data


static func _normalize_threat_level_factors(value: Array[ThreatLevelData]) -> Array[ThreatLevelData]:
	var defaults := _create_default_threat_level_factors()
	var normalized: Array[ThreatLevelData] = []

	for i in range(LEVEL_COUNT):
		if i < value.size() and value[i] != null:
			normalized.append(value[i])
		else:
			normalized.append(defaults[i])

	return normalized


func stop_for_run_end() -> void:
	set_process(false)
