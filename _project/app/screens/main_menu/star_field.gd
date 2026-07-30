extends Node2D

## Camera-style drift for the menu star field. Stars never move relative to one
## another; the whole field slowly drifts toward a small random offset from its
## resting position, then picks a new offset (and a new interval) after a random
## few seconds, so the sky wanders gently around center without ever straying.

@export var drift_radius: float = 60.0
## Drift speed in px/s. Kept well below anything that reads as scrolling.
@export var drift_speed: float = 6.0
@export var retarget_interval_min: float = 4.0
@export var retarget_interval_max: float = 10.0

var _base_position: Vector2
var _target: Vector2
var _retarget_timer: float = 0.0


func _ready() -> void:
	_base_position = position
	_pick_target()


func _process(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_pick_target()
	position = position.move_toward(_target, drift_speed * delta)


func _pick_target() -> void:
	var direction := Vector2.from_angle(randf() * TAU)
	# A minimum leg length keeps the sky from stalling when a target lands next
	# to the resting position.
	_target = _base_position + direction * randf_range(drift_radius * 0.25, drift_radius)
	_retarget_timer = randf_range(retarget_interval_min, retarget_interval_max)
