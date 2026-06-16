extends Resource
class_name AttackBehavior

signal state_changed(previous_state: StringName, next_state: StringName)

var _current_state: StringName = &""
var _registered_states: Array[StringName] = []


func setup(enemy: Enemy) -> void:
	_registered_states.clear()
	register_states(enemy)
	var initial_state := get_initial_state(enemy)
	if initial_state != &"":
		request_state(enemy, initial_state)


func teardown(enemy: Enemy) -> void:
	if _current_state != &"":
		on_exit_state(enemy, _current_state)
	_current_state = &""
	_registered_states.clear()


func get_initial_state(_enemy: Enemy) -> StringName:
	return &"windup"


func register_states(_enemy: Enemy) -> void:
	add_state(&"windup")


func add_state(state_name: StringName) -> void:
	if state_name != &"" and not _registered_states.has(state_name):
		_registered_states.append(state_name)


func has_state(state_name: StringName) -> bool:
	return _registered_states.has(state_name)


func get_current_state() -> StringName:
	return _current_state


func can_attack(_enemy: Enemy) -> bool:
	return false


func can_transition(_enemy: Enemy, _from_state: StringName, to_state: StringName) -> bool:
	return has_state(to_state)


func request_state(enemy: Enemy, next_state: StringName) -> bool:
	if next_state == _current_state:
		return true
	if not can_transition(enemy, _current_state, next_state):
		return false

	var previous_state := _current_state
	if previous_state != &"":
		on_exit_state(enemy, previous_state)
	_current_state = next_state
	on_enter_state(enemy, _current_state)
	state_changed.emit(previous_state, _current_state)
	return true


func on_enter_attack(_enemy: Enemy) -> void:
	pass


func on_exit_attack(_enemy: Enemy) -> void:
	pass


func physics_tick(enemy: Enemy, delta: float) -> void:
	if _current_state == &"":
		request_state(enemy, get_initial_state(enemy))
	update_state(enemy, delta, _current_state)


func on_enter_state(_enemy: Enemy, _state_name: StringName) -> void:
	pass


func on_exit_state(_enemy: Enemy, _state_name: StringName) -> void:
	pass


func update_state(_enemy: Enemy, _delta: float, _state_name: StringName) -> void:
	pass
