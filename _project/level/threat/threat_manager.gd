@tool
extends Node
class_name ThreatManager

## Run-level threat state owner.
##
## Threat is a continuous 0-100 score driven only by passive gain at a constant
## rate. The bar is split into 10 equal segments (one per threat level). The run
## can only rise as far as the current Threat Level Cap; once threat fills the
## capped segment the run enters the Cap Reached decision state and a storm
## countdown begins. The cap can only be raised +1 by an explicit player action
## (the ship lever) once the cap has been reached.

signal threat_changed(new_value: float)
signal threat_level_changed(new_level: int)
## Emitted when threat fills the current cap segment and the decision state begins.
signal cap_reached()
## Emitted when the player advances; payload is the new cap stage index.
signal cap_raised(new_cap: int)
## Emitted when the Cap Reached state begins its storm countdown.
signal storm_countdown_started(seconds: float)
## Emitted when the storm countdown expires and the acid storm arrives.
signal storm_arrived()

const MAX_THREAT: float = 100.0
const LEVEL_COUNT: int = 10
const MAX_STAGE_INDEX: int = LEVEL_COUNT - 1
const THREAT_SEGMENT_SIZE: float = MAX_THREAT / float(LEVEL_COUNT)
## Target run length (seconds) to fill the whole bar with no decision delays:
## 20 minutes -> 5 points/minute -> 2 minutes per segment.
const DEFAULT_RUN_DURATION_SECONDS: float = 1200.0
const DEFAULT_STORM_COUNTDOWN_SECONDS: float = 60.0

const DEBUG_THREAT_ADD_AMOUNT: float = 20.0

## Passive threat gained per second. Constant for the whole run.
@export var passive_threat_per_second: float = MAX_THREAT / DEFAULT_RUN_DURATION_SECONDS
## Seconds the player has to decide once the threat cap is reached.
## TODO: temporarily 10s for debug — restore to DEFAULT_STORM_COUNTDOWN_SECONDS (60).
@export var storm_countdown_seconds: float = 10.0

var _current_threat: float = 0.0
var _threat_level_cap: int = 0
var _is_cap_reached: bool = false
var _storm_active: bool = false
var _storm_countdown_remaining: float = 0.0
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
		_set_current_threat(value)

## Current threat level as a zero-based stage index (0-9). Never exceeds the cap.
var threat_level: int:
	get:
		var raw := MAX_STAGE_INDEX
		if _current_threat < MAX_THREAT:
			raw = clampi(int(_current_threat / THREAT_SEGMENT_SIZE), 0, MAX_STAGE_INDEX)
		return mini(raw, _threat_level_cap)

## Highest threat level the run may currently reach (zero-based stage index).
var threat_level_cap: int:
	get:
		return _threat_level_cap

## True while threat is clamped at the cap and the decision state is active.
var is_cap_reached: bool:
	get:
		return _is_cap_reached

var is_storm_active: bool:
	get:
		return _storm_active

var storm_countdown_remaining: float:
	get:
		return _storm_countdown_remaining

var threat_ratio: float:
	get:
		return _current_threat / MAX_THREAT


func _init() -> void:
	_threat_level_factors = _normalize_threat_level_factors(_threat_level_factors)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _is_cap_reached:
		_tick_storm_countdown(delta)
		return
	if _current_threat >= _cap_ceiling():
		return
	add_threat(passive_threat_per_second * delta)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			add_threat(DEBUG_THREAT_ADD_AMOUNT)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y:
			raise_cap()
			get_viewport().set_input_as_handled()


func add_threat(amount: float) -> void:
	if amount <= 0.0:
		return
	current_threat = _current_threat + amount


## Player-facing threat level (1-10).
func get_player_threat_level() -> int:
	return threat_level + 1


## Player-facing threat level cap (1-10).
func get_player_threat_level_cap() -> int:
	return _threat_level_cap + 1


## True only when the cap has been reached and there is a higher level to unlock.
func can_raise_cap() -> bool:
	return _is_cap_reached and _threat_level_cap < MAX_STAGE_INDEX


## Raise the cap +1 (used by the advance/lever flow). Threat continues smoothly
## from its current value into the newly unlocked segment; it is not reset.
func raise_cap() -> void:
	if not can_raise_cap():
		return
	var old_level := threat_level
	_threat_level_cap += 1
	_is_cap_reached = false
	_storm_active = false
	_storm_countdown_remaining = 0.0
	cap_raised.emit(_threat_level_cap)
	var new_level := threat_level
	if new_level != old_level:
		threat_level_changed.emit(new_level)


func reset() -> void:
	_threat_level_cap = 0
	_is_cap_reached = false
	_storm_active = false
	_storm_countdown_remaining = 0.0
	_current_threat = 0.0
	threat_changed.emit(_current_threat)
	threat_level_changed.emit(threat_level)
	set_process(true)


func stop_for_run_end() -> void:
	set_process(false)


func get_level_factors(level: int = threat_level) -> ThreatLevelData:
	var clamped_level := clampi(level, 0, MAX_STAGE_INDEX)
	if clamped_level >= 0 and clamped_level < _threat_level_factors.size():
		return _threat_level_factors[clamped_level]
	return _create_default_threat_level_factors()[clamped_level]


func get_current_level_factors() -> ThreatLevelData:
	return get_level_factors(threat_level)


func get_pile_rarity_weights(level: int = threat_level) -> Dictionary:
	var factors := get_level_factors(level)
	if factors:
		return factors.get_pile_rarity_weights()
	return {}


func _set_current_threat(value: float) -> void:
	var ceiling := _cap_ceiling()
	var old_level := threat_level
	_current_threat = clampf(value, 0.0, ceiling)
	threat_changed.emit(_current_threat)
	var new_level := threat_level
	if new_level != old_level:
		threat_level_changed.emit(new_level)
	if not _is_cap_reached and _current_threat >= ceiling:
		_enter_cap_reached()


## Top of the current cap level's segment, where threat is clamped.
func _cap_ceiling() -> float:
	return minf(float(_threat_level_cap + 1) * THREAT_SEGMENT_SIZE, MAX_THREAT)


func _enter_cap_reached() -> void:
	_is_cap_reached = true
	_storm_active = false
	_storm_countdown_remaining = storm_countdown_seconds
	cap_reached.emit()
	storm_countdown_started.emit(_storm_countdown_remaining)


func _tick_storm_countdown(delta: float) -> void:
	if _storm_active:
		return
	_storm_countdown_remaining = maxf(_storm_countdown_remaining - delta, 0.0)
	if _storm_countdown_remaining <= 0.0:
		_storm_active = true
		storm_arrived.emit()


static func _create_default_threat_level_factors() -> Array[ThreatLevelData]:
	return [
		_create_threat_level_data(95.0, 5.0, 0.0, 0.0, 1.0),
		_create_threat_level_data(90.0, 10.0, 0.0, 0.0, 1.25),
		_create_threat_level_data(85.0, 15.0, 0.0, 0.0, 1.5),
		_create_threat_level_data(78.0, 18.0, 4.0, 0.0, 1.75),
		_create_threat_level_data(70.0, 20.0, 10.0, 0.0, 2.0),
		_create_threat_level_data(62.0, 23.0, 13.0, 2.0, 2.5),
		_create_threat_level_data(50.0, 30.0, 16.0, 4.0, 3.0),
		_create_threat_level_data(35.0, 38.0, 20.0, 7.0, 3.5),
		_create_threat_level_data(15.0, 50.0, 25.0, 10.0, 4.0),
		_create_threat_level_data(0.0, 60.0, 28.0, 12.0, 5.0),
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
