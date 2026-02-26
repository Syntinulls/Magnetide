extends Area2D
class_name MagnetLever

signal lever_flipped()
signal lever_flipped_back()

## Start rotation in radians (45 degrees clockwise).
@export var start_rotation: float = 0.785398
## End rotation in radians (45 degrees counter-clockwise).
@export var end_rotation: float = -0.785398
## Duration of rotation tween in seconds.
@export var rotation_tween_duration: float = 0.15

var _is_available: bool = false
var _is_flipped: bool = false
var _player_in_range: bool = false
var _current_rotation_progress: float = 0.0  # 0.0 = start, 1.0 = end
var _target_rotation_progress: float = 0.0
var _is_tweening: bool = false
var _tween_elapsed: float = 0.0
var _tween_start_progress: float = 0.0

@onready var _handle_pivot: Node2D = $HandlePivot


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_available(false)
	reset_rotation()
	# Lever is always visible
	set_handle_visible(true)


func _process(delta: float) -> void:
	# Handle tweening with timescale compensation
	if _is_tweening:
		_process_rotation_tween(delta)
	
	if not _is_available or not _player_in_range:
		return

	if Input.is_action_just_pressed("interact"):
		if not _is_flipped:
			_is_flipped = true
			lever_flipped.emit()
			set_available(false)
		else:
			# Player flips lever back (manual abort during looting)
			_is_flipped = false
			flip_back_with_tween()
			lever_flipped_back.emit()
			set_available(false)


func _process_rotation_tween(delta: float) -> void:
	# Compensate for timescale to run at real-time speed
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_tween_elapsed += real_delta
	
	var t := clampf(_tween_elapsed / rotation_tween_duration, 0.0, 1.0)
	# Ease out quad for smooth deceleration
	t = 1.0 - (1.0 - t) * (1.0 - t)
	
	_current_rotation_progress = lerpf(_tween_start_progress, _target_rotation_progress, t)
	_apply_rotation()
	
	if _tween_elapsed >= rotation_tween_duration:
		_is_tweening = false
		_current_rotation_progress = _target_rotation_progress


func set_available(available: bool) -> void:
	_is_available = available
	# Don't change visibility here - let set_handle_visible control it separately


## Set handle visibility (used during minigame to keep lever visible).
func set_handle_visible(handle_visible: bool) -> void:
	if _handle_pivot:
		_handle_pivot.visible = handle_visible


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = false


## Reset lever to start rotation position (immediate, no tween).
func reset_rotation() -> void:
	_current_rotation_progress = 0.0
	_target_rotation_progress = 0.0
	_is_flipped = false
	_is_tweening = false
	_apply_rotation()


## Animate lever back to start position (0.0 progress) with tween.
func flip_back_with_tween() -> void:
	_tween_start_progress = _current_rotation_progress
	_target_rotation_progress = 0.0
	_tween_elapsed = 0.0
	_is_tweening = true
	_is_flipped = false


## Progress lever rotation by a given amount (0.0 to 1.0 range) with tweening.
## Returns the new target progress value.
func progress_rotation(amount: float) -> float:
	_tween_start_progress = _current_rotation_progress
	_target_rotation_progress = clampf(_target_rotation_progress + amount, 0.0, 1.0)
	_tween_elapsed = 0.0
	_is_tweening = true
	return _target_rotation_progress


## Set lever rotation progress directly (0.0 = start, 1.0 = end).
func set_rotation_progress(progress: float) -> void:
	_current_rotation_progress = clampf(progress, 0.0, 1.0)
	_apply_rotation()


## Set lever to fully flipped state (for entering looting mode).
func set_flipped(flipped: bool) -> void:
	_is_flipped = flipped
	if flipped:
		_current_rotation_progress = 1.0
		_target_rotation_progress = 1.0
	else:
		_current_rotation_progress = 0.0
		_target_rotation_progress = 0.0
	_is_tweening = false
	_apply_rotation()


func _apply_rotation() -> void:
	if _handle_pivot:
		_handle_pivot.rotation = lerpf(start_rotation, end_rotation, _current_rotation_progress)
