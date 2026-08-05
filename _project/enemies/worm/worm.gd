extends Enemy
class_name Worm

## Worm that bursts toward a random magnet/ship target, latches onto the first
## target point it touches, and rides that point's every movement while dealing
## contact damage. A latched worm only lets go when a nearby worm's death
## retargets it onto the attacker (ALLY_DEATH switching); free worms never
## switch targets.

var _latched: bool = false
var _latch_anchor: Node2D = null
var _latch_local_offset: Vector2 = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _latched and state == State.DEATH:
		_unlatch()
	if data and state != State.DEATH and not _run_ended:
		_update_latch()
	super._physics_process(delta)
	if _latched:
		_follow_latch_anchor()


## True while anchored to the current target point. Read by the worm's move and
## attack behaviors: it gates can_attack, so a latched worm sits in ATTACK.
func is_latched() -> bool:
	return _latched


func _allows_ally_death_switch() -> bool:
	return _latched


func _on_target_switched() -> void:
	_unlatch()


func _update_latch() -> void:
	if _latched:
		if _latch_anchor == null or not is_instance_valid(_latch_anchor) or not has_valid_target():
			_unlatch()
		return
	if has_valid_target() and get_distance_to_target() <= get_attack_range():
		_latch()


func _latch() -> void:
	_latched = true
	_latch_anchor = current_target_point
	_latch_local_offset = _latch_anchor.global_transform.affine_inverse() * global_position
	velocity = Vector2.ZERO


# Deliberately leaves velocity alone: on death the pop impulse must survive,
# and on retarget the move behavior's windup entry zeroes it anyway.
func _unlatch() -> void:
	_latched = false
	_latch_anchor = null


func _follow_latch_anchor() -> void:
	if _latch_anchor and is_instance_valid(_latch_anchor):
		global_position = _latch_anchor.global_transform * _latch_local_offset
