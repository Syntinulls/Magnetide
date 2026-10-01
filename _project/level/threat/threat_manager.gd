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
## At level 10 the window is the boss gate when the level has a boss (continuing
## starts the fight), and a depart-only terminus when it does not.
##
## This node owns every timer in the progression. The HUD renders the state it
## publishes and never drives it.

signal threat_changed(new_value: float)
signal threat_level_changed(new_level: int)
## The interlevel window opened; `gate` says what continuing leads to.
signal window_opened(seconds: float, gate: GateKind)
## The window resolved (continued or departed) and is no longer accepting input.
signal window_closed()
## The cap rose; threat resumes building into the newly unlocked segment.
signal level_advanced(new_cap: int)
signal storm_started(storm: StormData)
signal storm_finished(storm: StormData)
signal boss_started()
## The authored storms or boss availability changed, so which boundaries are gates
## changed with them. Level content is injected after the HUD binds, so views that
## draw the gates need this to catch up.
signal gates_changed()

enum Phase {
	## Threat accumulating toward the cap ceiling.
	BUILDING,
	## Cap ceiling reached; the player is deciding.
	WINDOW,
	## A storm is running; threat is paused until it clears.
	STORM,
	## The level-10 boss fight is running; threat stays full until the run ends.
	BOSS,
}

## What resolving the interlevel window by continuing leads to.
enum GateKind {
	## The next threat level unlocks.
	PLAIN,
	## An authored storm runs, then the next level unlocks.
	STORM,
	## The level's boss fight starts (level 10 only).
	BOSS,
	## Nothing further: level 10 with no boss. Depart only; never expires.
	TERMINAL,
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
var _window_gate: GateKind = GateKind.PLAIN
var _storms: Array[StormData] = []
var _boss_available: bool = false
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

## What continuing leads to for the open window (meaningless while no window is open).
var window_gate: GateKind:
	get:
		return _window_gate

## True while the open window has nothing to continue into (level 10, no boss). It
## stays open indefinitely so departing is still possible, and never auto-resolves.
var is_terminal_window: bool:
	get:
		return _phase == Phase.WINDOW and _window_gate == GateKind.TERMINAL

var is_boss_active: bool:
	get:
		return _phase == Phase.BOSS

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
	gates_changed.emit()


## Whether the level has a boss (injected from the level definition). Decides if the
## level-10 window is the boss gate or the depart-only terminus.
func set_boss_available(available: bool) -> void:
	if _boss_available == available:
		return
	_boss_available = available
	gates_changed.emit()


func is_boss_available() -> bool:
	return _boss_available


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


## True while the window is open and continuing leads somewhere.
func can_advance() -> bool:
	return _phase == Phase.WINDOW and not _run_ended and _window_gate != GateKind.TERMINAL


## Resolve the window by continuing. At a storm gate this starts the storm and the
## cap rises only once it is cleared; at the boss gate it starts the boss fight;
## otherwise the next level unlocks immediately.
func advance() -> void:
	if not can_advance():
		return

	var gate := _window_gate
	var storm: StormData = null
	if gate == GateKind.STORM:
		storm = get_storm_after(get_player_threat_level())

	_phase = Phase.BUILDING
	_window_remaining = 0.0
	_window_gate = GateKind.PLAIN
	window_closed.emit()

	match gate:
		GateKind.STORM:
			if storm != null:
				_begin_storm(storm)
			else:
				_raise_cap()
		GateKind.BOSS:
			_begin_boss()
		_:
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


## Debug entry point: jump the run to the given player-facing threat level (1-10).
## Resolves any open window or running storm state and restarts threat at the
## start of that level's segment. Storm actors already spawned are not cleaned
## up -- intended for jumping levels while threat is building.
func debug_set_threat_level(player_level: int) -> void:
	var stage := clampi(player_level - 1, 0, MAX_STAGE_INDEX)
	var was_window := _phase == Phase.WINDOW
	var storm := _active_storm
	var old_level := threat_level
	_phase = Phase.BUILDING
	_window_remaining = 0.0
	_window_gate = GateKind.PLAIN
	_active_storm = null
	_threat_level_cap = stage
	if was_window:
		window_closed.emit()
	if storm != null:
		storm_finished.emit(storm)
	_current_threat = stage * THREAT_SEGMENT_SIZE
	threat_changed.emit(_current_threat)
	if threat_level != old_level:
		threat_level_changed.emit(threat_level)
	level_advanced.emit(_threat_level_cap)


## Debug entry point: start the boss fight now, as if the level-10 boss gate had been
## continued through. Threat jumps to full; any open window or running storm is
## resolved first (storm actors are not cleaned up).
func debug_start_boss() -> void:
	if _run_ended or _phase == Phase.BOSS:
		return
	debug_set_threat_level(LEVEL_COUNT)
	_current_threat = MAX_THREAT
	threat_changed.emit(_current_threat)
	_begin_boss()


func reset() -> void:
	_threat_level_cap = 0
	_phase = Phase.BUILDING
	_window_remaining = 0.0
	_window_gate = GateKind.PLAIN
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
	if _window_gate == GateKind.TERMINAL:
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
	if _threat_level_cap >= MAX_STAGE_INDEX:
		_window_gate = GateKind.BOSS if _boss_available else GateKind.TERMINAL
	elif is_storm_gate_after(get_player_threat_level()):
		_window_gate = GateKind.STORM
	else:
		_window_gate = GateKind.PLAIN
	_window_remaining = 0.0 if _window_gate == GateKind.TERMINAL else interlevel_window_seconds
	window_opened.emit(_window_remaining, _window_gate)


func _begin_storm(storm: StormData) -> void:
	_active_storm = storm
	_phase = Phase.STORM
	storm_started.emit(storm)


func _begin_boss() -> void:
	_phase = Phase.BOSS
	boss_started.emit()


func _raise_cap() -> void:
	if _threat_level_cap >= MAX_STAGE_INDEX:
		return
	var old_level := threat_level
	_threat_level_cap += 1
	level_advanced.emit(_threat_level_cap)
	var new_level := threat_level
	if new_level != old_level:
		threat_level_changed.emit(new_level)
