@tool
extends Node
class_name ThreatManager

## Run-level threat state owner and progression gate.
##
## Threat is a continuous 0-100 score driven only by passive gain at a constant
## rate, split into 10 equal segments (one per threat level). The run rises only as
## far as the current Threat Level Cap; filling the capped segment opens the
## interlevel window — the run's one departure opportunity — which resolves when the
## player continues (lever), departs (pylons), or the timer expires.
##
## At the levels an authored storm gates, continuing starts that storm instead of
## unlocking the next level immediately; the cap rises once the storm is cleared.
##
## This node owns every timer in the progression. The HUD renders the state it
## publishes and never drives it.

signal threat_changed(new_value: float)
signal threat_level_changed(new_level: int)
## The interlevel window opened. `is_storm_gate` is true when continuing starts a storm.
signal window_opened(seconds: float, is_storm_gate: bool)
## The window resolved (continued or departed) and is no longer accepting input.
signal window_closed()
## The cap rose; threat resumes building into the newly unlocked segment.
signal level_advanced(new_cap: int)
signal storm_started(storm: StormData)
signal storm_finished(storm: StormData)
## The authored storm list changed, so which boundaries are storm gates changed
## with it. The level's storms are injected after the HUD binds, so views that
## draw the gates need this to catch up.
signal storms_changed()

enum Phase {
	## Threat accumulating toward the cap ceiling.
	BUILDING,
	## Cap ceiling reached; the player is deciding.
	WINDOW,
	## A storm is running; threat is paused until it clears.
	STORM,
	## Reserved for the level 10 boss fight. Unused until the boss exists.
	BOSS,
}

const MAX_THREAT: float = 100.0
const LEVEL_COUNT: int = 10
const MAX_STAGE_INDEX: int = LEVEL_COUNT - 1
const THREAT_SEGMENT_SIZE: float = MAX_THREAT / float(LEVEL_COUNT)
## Reference run length (seconds) used to derive the passive rate: 10 segments of
## 2 minutes each. Actual run length is player-driven and not budgeted.
const DEFAULT_RUN_DURATION_SECONDS: float = 1200.0
const DEFAULT_WINDOW_SECONDS: float = 30.0

## Passive threat gained per second. Constant for the whole run.
@export var passive_threat_per_second: float = MAX_THREAT / DEFAULT_RUN_DURATION_SECONDS
## Seconds the player has to decide once a threat level fills.
@export var interlevel_window_seconds: float = DEFAULT_WINDOW_SECONDS

var _current_threat: float = 0.0
var _threat_level_cap: int = 0
var _phase: Phase = Phase.BUILDING
var _window_remaining: float = 0.0
var _window_is_storm_gate: bool = false
## True while the open window has nothing left to advance to (level 10): it stays
## open indefinitely so departing is still possible, and never auto-resolves.
var _window_is_terminal: bool = false
var _storms: Array[StormData] = []
var _active_storm: StormData = null
## While true, opening the window is deferred even though threat has filled the cap
## segment (driven by the magnet minigame so a window never opens mid-loot).
var _window_hold: bool = false
## While true, an expired window waits instead of auto-continuing, so a departure
## hold started in the last second still resolves.
var _departure_hold: bool = false
var _run_ended: bool = false

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

var phase: Phase:
	get:
		return _phase

## True only while the interlevel window is open — the run's one departure opportunity.
var is_departure_window_open: bool:
	get:
		return _phase == Phase.WINDOW

var is_storm_active: bool:
	get:
		return _phase == Phase.STORM

## True while the open window has no next level to unlock (level 10): depart only.
var is_terminal_window: bool:
	get:
		return _window_is_terminal

var window_seconds_remaining: float:
	get:
		return _window_remaining

var active_storm: StormData:
	get:
		return _active_storm

var threat_ratio: float:
	get:
		return _current_threat / MAX_THREAT


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match _phase:
		Phase.BUILDING:
			_tick_threat(delta)
		Phase.WINDOW:
			_tick_window(delta)
		_:
			pass


## Supply the run's authored storms (injected from the level definition). Determines
## which level boundaries are storm gates.
func set_storms(storms: Array[StormData]) -> void:
	_storms = storms.duplicate()
	storms_changed.emit()


func add_threat(amount: float) -> void:
	if amount <= 0.0:
		return
	current_threat = _current_threat + amount


## Player-facing threat level (1-10).
func get_player_threat_level() -> int:
	return threat_level + 1


## True if a storm gates the boundary after the given player-facing level (1-10).
func is_storm_gate_after(player_level: int) -> bool:
	return get_storm_after(player_level) != null


func get_storm_after(player_level: int) -> StormData:
	for storm in _storms:
		if storm != null and storm.gate_after_level == player_level:
			return storm
	return null


## Player-facing levels (1-10) that a storm gates, for the threat bar's markers.
func get_storm_gate_levels() -> PackedInt32Array:
	var levels := PackedInt32Array()
	for storm in _storms:
		if storm != null and not levels.has(storm.gate_after_level):
			levels.append(storm.gate_after_level)
	return levels


## True while the window is open and there is a further level to unlock.
func can_advance() -> bool:
	return _phase == Phase.WINDOW and not _run_ended and _threat_level_cap < MAX_STAGE_INDEX


## Resolve the window by continuing. At a storm gate this starts the storm and the
## cap rises only once it is cleared; otherwise the next level unlocks immediately.
func advance() -> void:
	if not can_advance():
		return

	var storm: StormData = null
	if _window_is_storm_gate:
		storm = get_storm_after(get_player_threat_level())

	_phase = Phase.BUILDING
	_window_remaining = 0.0
	_window_is_storm_gate = false
	_window_is_terminal = false
	window_closed.emit()

	if storm != null:
		_begin_storm(storm)
	else:
		_raise_cap()


## Defer (or release) opening the window. Driven by the magnet minigame so a window
## never opens mid-loot; threat still clamps at the ceiling while held.
func set_window_hold(held: bool) -> void:
	if _window_hold == held:
		return
	_window_hold = held
	if not held:
		_try_open_window()


## Report an in-progress departure hold. An expired window waits for the hold to
## resolve rather than auto-continuing, so a hold started in the last second still
## succeeds. Releasing the hold on an already-expired window continues at once.
func set_departure_hold(held: bool) -> void:
	if _departure_hold == held:
		return
	_departure_hold = held
	if not held and _phase == Phase.WINDOW and _window_remaining <= 0.0:
		advance()


## Called by the storm director once the last wave is cleared and the outro is done.
func notify_storm_finished() -> void:
	if _phase != Phase.STORM:
		return
	var storm := _active_storm
	_active_storm = null
	_phase = Phase.BUILDING
	storm_finished.emit(storm)
	_raise_cap()


func reset() -> void:
	_threat_level_cap = 0
	_phase = Phase.BUILDING
	_window_remaining = 0.0
	_window_is_storm_gate = false
	_window_is_terminal = false
	_active_storm = null
	_window_hold = false
	_departure_hold = false
	_run_ended = false
	_current_threat = 0.0
	threat_changed.emit(_current_threat)
	threat_level_changed.emit(threat_level)
	set_process(true)


func stop_for_run_end() -> void:
	_run_ended = true
	set_process(false)


func _tick_threat(delta: float) -> void:
	if _current_threat >= _cap_ceiling():
		return
	add_threat(passive_threat_per_second * delta)


func _tick_window(delta: float) -> void:
	if _window_is_terminal:
		return
	if _window_remaining <= 0.0:
		return
	_window_remaining = maxf(_window_remaining - delta, 0.0)
	if _window_remaining > 0.0:
		return
	# Expiry never overrides a decision already in progress.
	if _departure_hold:
		return
	advance()


func _set_current_threat(value: float) -> void:
	var ceiling := _cap_ceiling()
	var old_level := threat_level
	_current_threat = clampf(value, 0.0, ceiling)
	threat_changed.emit(_current_threat)
	var new_level := threat_level
	if new_level != old_level:
		threat_level_changed.emit(new_level)
	_try_open_window()


## Top of the current cap level's segment, where threat is clamped.
func _cap_ceiling() -> float:
	return minf(float(_threat_level_cap + 1) * THREAT_SEGMENT_SIZE, MAX_THREAT)


func _try_open_window() -> void:
	if _phase != Phase.BUILDING or _window_hold or _run_ended:
		return
	if _current_threat < _cap_ceiling():
		return
	_open_window()


func _open_window() -> void:
	_phase = Phase.WINDOW
	_window_is_terminal = _threat_level_cap >= MAX_STAGE_INDEX
	_window_is_storm_gate = (
		not _window_is_terminal and is_storm_gate_after(get_player_threat_level())
	)
	_window_remaining = 0.0 if _window_is_terminal else interlevel_window_seconds
	window_opened.emit(_window_remaining, _window_is_storm_gate)


func _begin_storm(storm: StormData) -> void:
	_active_storm = storm
	_phase = Phase.STORM
	storm_started.emit(storm)


func _raise_cap() -> void:
	if _threat_level_cap >= MAX_STAGE_INDEX:
		return
	var old_level := threat_level
	_threat_level_cap += 1
	level_advanced.emit(_threat_level_cap)
	var new_level := threat_level
	if new_level != old_level:
		threat_level_changed.emit(new_level)
