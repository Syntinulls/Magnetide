extends Node2D
class_name Boss

## Root of a boss: owns the fight's lifecycle, its total health, its phase, and the
## state machine that drives its parts.
##
## Total health is the sum of every counted BossPart's pool, so the boss is defeated
## exactly when its last counted part is destroyed, and each phase is a slice of that
## total (BossPhaseData.start_health_ratio). All part damage passes through
## apply_part_damage(), the one place that applies invulnerability and phase clamps.
##
## Combat states are BossState children of the `States` node, ticked only while the
## boss is ACTIVE. Crossing into a new phase suspends them (TRANSITIONING) and emits
## phase_transition_started; whoever runs the encounter plays the phase's transition
## cutscene, if any, and then calls finish_phase_transition(). The boss never plays
## cutscenes itself. Subclasses add boss-wide behavior through the _on_* hooks.

signal health_changed(current: float, maximum: float)
## The boss crossed into phase `index` and is waiting for finish_phase_transition().
signal phase_transition_started(index: int)
## Phase `index` began (after its transition, or on activate() for the first phase).
signal phase_changed(index: int)
signal defeated

enum Lifecycle {
	## Spawned but not fighting (e.g. during the intro cutscene); takes no damage.
	DORMANT,
	ACTIVE,
	## Between phases; states are suspended until finish_phase_transition().
	TRANSITIONING,
	DEFEATED,
}

@export var data: BossData

var lifecycle: Lifecycle = Lifecycle.DORMANT
var parts: Array[BossPart] = []

var _phase_index: int = 0
var _states: Dictionary = {}
var _current_state: BossState = null
var _invulnerable: bool = false
var _frozen: bool = false
var _run_ended: bool = false

@onready var _states_root: Node = get_node_or_null(^"States")


func _ready() -> void:
	add_to_group("bosses")
	if data == null:
		push_warning("Boss %s has no BossData assigned." % name)
	_collect_parts(self)
	for part in parts:
		part.boss = self
	if _states_root:
		for child in _states_root.get_children():
			var state := child as BossState
			if state:
				state.boss = self
				_states[StringName(state.name)] = state


func _physics_process(delta: float) -> void:
	if lifecycle != Lifecycle.ACTIVE or _frozen or _run_ended or _current_state == null:
		return
	_current_state.physics_tick(delta)


# -- Fight lifecycle -----------------------------------------------------------

## DORMANT → ACTIVE: the first phase begins in its entry state.
func activate() -> void:
	if lifecycle != Lifecycle.DORMANT:
		return
	_phase_index = 0
	_set_lifecycle(Lifecycle.ACTIVE)
	_begin_phase()


## TRANSITIONING → ACTIVE: the phase announced by phase_transition_started begins.
func finish_phase_transition() -> void:
	if lifecycle != Lifecycle.TRANSITIONING:
		return
	_set_lifecycle(Lifecycle.ACTIVE)
	_begin_phase()
	# Damage taken with clamps off can already reach the next phase.
	_check_health_thresholds()


## Switch combat state. Ignored unless the boss is ACTIVE.
func transition_to(state_id: StringName) -> void:
	if lifecycle != Lifecycle.ACTIVE:
		return
	var next := _states.get(state_id) as BossState
	if next == null:
		push_warning("Boss %s has no state '%s'." % [name, state_id])
		return
	var from := get_current_state_id()
	if _current_state:
		_current_state.exit(state_id)
	_current_state = next
	for part in parts:
		part._on_boss_state_changed(from, state_id)
	_current_state.enter(from)


func stop_for_run_end() -> void:
	_run_ended = true
	set_physics_process(false)
	for part in parts:
		part.stop_for_run_end()


# -- Health ------------------------------------------------------------------

func get_max_health() -> float:
	var total := 0.0
	for part in parts:
		if part.counts_toward_boss_health:
			total += part.max_health
	return total


func get_current_health() -> float:
	var total := 0.0
	for part in parts:
		if part.counts_toward_boss_health:
			total += part.current_health
	return total


func get_health_ratio() -> float:
	var maximum := get_max_health()
	return get_current_health() / maximum if maximum > 0.0 else 0.0


## The one damage path for parts: returns how much of `amount` actually landed after
## lifecycle gating, invulnerability, the part's remaining pool, and the current
## phase's end clamp.
func apply_part_damage(part: BossPart, amount: float, _source: Node = null) -> float:
	if amount <= 0.0 or part == null or part.is_destroyed or _run_ended or _invulnerable:
		return 0.0
	match lifecycle:
		Lifecycle.DORMANT, Lifecycle.DEFEATED:
			return 0.0
		Lifecycle.TRANSITIONING:
			var phase := get_phase()
			if phase == null or phase.invulnerable_during_transition:
				return 0.0

	var applied := minf(amount, part.current_health)
	if part.counts_toward_boss_health:
		var phase := get_phase()
		var next := data.get_phase(_phase_index + 1) if data else null
		if phase and next and phase.clamp_damage_at_end and lifecycle == Lifecycle.ACTIVE:
			var floor_health := next.start_health_ratio * get_max_health()
			applied = minf(applied, maxf(get_current_health() - floor_health, 0.0))
	if applied <= 0.0:
		return 0.0
	_damage_part(part, applied)
	return applied


## Called by a part as its pool empties, before its destruction sequence plays.
func notify_part_destroyed(part: BossPart) -> void:
	_on_part_destroyed(part)


# -- Phases & states -----------------------------------------------------------

func get_phase_index() -> int:
	return _phase_index


func get_phase() -> BossPhaseData:
	return data.get_phase(_phase_index) if data else null


func get_phase_count() -> int:
	return data.get_phase_count() if data else 0


## Where each phase begins, as fractions of total health, in phase order.
func get_phase_start_ratios() -> PackedFloat32Array:
	var ratios := PackedFloat32Array()
	if data:
		for phase in data.phases:
			ratios.append(phase.start_health_ratio if phase else 1.0)
	return ratios


func get_current_state_id() -> StringName:
	return StringName(_current_state.name) if _current_state else &""


func get_state_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in _states:
		ids.append(id)
	return ids


func get_display_name() -> String:
	return data.display_name if data and not data.display_name.is_empty() else String(name)


# -- Debug -------------------------------------------------------------------

## Damage counted parts down to phase `index`'s start and transition straight into
## it (skipping the phases between). Only moves forward.
func debug_set_phase(index: int) -> void:
	var phase := data.get_phase(index) if data else null
	if phase == null or index <= _phase_index or lifecycle != Lifecycle.ACTIVE:
		return
	_drain_counted_health_to(phase.start_health_ratio * get_max_health())
	_exit_current_state()
	_begin_phase_transition(index)


func debug_kill() -> void:
	if lifecycle != Lifecycle.ACTIVE and lifecycle != Lifecycle.TRANSITIONING:
		return
	_drain_counted_health_to(0.0)
	_defeat()


## Destroy one part outright, ignoring invulnerability and phase clamps.
func debug_destroy_part(part: BossPart) -> void:
	if part == null or part.is_destroyed or lifecycle != Lifecycle.ACTIVE:
		return
	_damage_part(part, part.current_health)


func debug_set_invulnerable(invulnerable: bool) -> void:
	_invulnerable = invulnerable


func debug_is_invulnerable() -> bool:
	return _invulnerable


## Freeze stops state ticking; parts' own processing is unaffected.
func debug_set_frozen(frozen: bool) -> void:
	_frozen = frozen


func debug_is_frozen() -> bool:
	return _frozen


# -- Hooks for subclasses ----------------------------------------------------

## Phase `index` just began; its entry state is about to be entered.
func _on_phase_entered(_index: int) -> void:
	pass


func _on_part_destroyed(_part: BossPart) -> void:
	pass


func _on_defeated() -> void:
	pass


# -- Internals ---------------------------------------------------------------

func _damage_part(part: BossPart, amount: float) -> void:
	part.apply_approved_damage(amount)
	health_changed.emit(get_current_health(), get_max_health())
	_check_health_thresholds()


func _drain_counted_health_to(target_total: float) -> void:
	var excess := get_current_health() - target_total
	for part in parts:
		if excess <= 0.0:
			break
		if not part.counts_toward_boss_health or part.is_destroyed:
			continue
		var amount := minf(excess, part.current_health)
		part.apply_approved_damage(amount)
		excess -= amount
	health_changed.emit(get_current_health(), get_max_health())


func _check_health_thresholds() -> void:
	if lifecycle == Lifecycle.DEFEATED or lifecycle == Lifecycle.DORMANT:
		return
	if get_max_health() > 0.0 and get_current_health() <= 0.0:
		_defeat()
		return
	if lifecycle != Lifecycle.ACTIVE:
		return
	var next := data.get_phase(_phase_index + 1) if data else null
	if next and get_health_ratio() <= next.start_health_ratio:
		_exit_current_state()
		_begin_phase_transition(_phase_index + 1)


func _begin_phase_transition(index: int) -> void:
	_phase_index = index
	_set_lifecycle(Lifecycle.TRANSITIONING)
	for part in parts:
		part._on_boss_phase_changed(index)
	phase_transition_started.emit(index)


func _begin_phase() -> void:
	phase_changed.emit(_phase_index)
	_on_phase_entered(_phase_index)
	var phase := get_phase()
	if phase and not phase.entry_state.is_empty():
		transition_to(phase.entry_state)


func _defeat() -> void:
	_exit_current_state()
	_set_lifecycle(Lifecycle.DEFEATED)
	for part in parts:
		part.set_attacks_enabled(false)
	_on_defeated()
	defeated.emit()


func _exit_current_state() -> void:
	if _current_state == null:
		return
	var from := get_current_state_id()
	_current_state.exit(&"")
	_current_state = null
	for part in parts:
		part._on_boss_state_changed(from, &"")


func _set_lifecycle(value: Lifecycle) -> void:
	if lifecycle == value:
		return
	lifecycle = value
	for part in parts:
		part._on_boss_lifecycle_changed(value)


func _collect_parts(node: Node) -> void:
	for child in node.get_children():
		if child is BossPart:
			parts.append(child as BossPart)
		_collect_parts(child)
