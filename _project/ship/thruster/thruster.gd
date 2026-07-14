extends Node2D
class_name Thruster

enum ThrustLevel { OFF, LOW, HIGH }

const DEFAULT_THRUST_ANIMATION := &"loop_1"

@export var rotation_tween_duration: float = 0.6
@export var straight_down_degrees: float = 0.0
@export var bottom_left_degrees: float = 45.0
@export var bottom_right_degrees: float = -45.0
@export var min_animation_fps: float = 10.0
@export var max_animation_fps: float = 24.0

var _current_thrust_level: ThrustLevel = ThrustLevel.LOW
var _thrust_animation: StringName = DEFAULT_THRUST_ANIMATION
var _rotation_tween: Tween = null

@onready var _plume_animation: AnimatedSprite2D = $PlumeAnimation


func _ready() -> void:
	set_thrust_level(_current_thrust_level, true)


func aim_straight_down() -> void:
	_tween_to_rotation_degrees(straight_down_degrees)


func aim_bottom_left() -> void:
	_tween_to_rotation_degrees(bottom_left_degrees)


func aim_bottom_right() -> void:
	_tween_to_rotation_degrees(bottom_right_degrees)


func set_aim_degrees(target_degrees: float) -> void:
	if _rotation_tween and _rotation_tween.is_valid():
		_rotation_tween.kill()
	rotation = deg_to_rad(target_degrees)


func set_thrust_level(level: ThrustLevel, _instant: bool = false) -> void:
	if level == _current_thrust_level and not _instant:
		return

	_current_thrust_level = level

	if level == ThrustLevel.OFF:
		_plume_animation.stop()
		_plume_animation.visible = false
		return

	_plume_animation.visible = true
	_play_animation(_thrust_animation)


func set_thrust_animation(animation_name: StringName) -> void:
	_thrust_animation = animation_name
	if _current_thrust_level != ThrustLevel.OFF:
		_play_animation(_thrust_animation)


func set_ship_speed_ratio(speed_ratio: float) -> void:
	var animation_speed := _get_animation_speed(_thrust_animation)
	if animation_speed <= 0.0:
		_plume_animation.speed_scale = 1.0
		return

	var target_fps := lerpf(min_animation_fps, max_animation_fps, clampf(speed_ratio, 0.0, 1.0))
	_plume_animation.speed_scale = target_fps / animation_speed


func _tween_to_rotation_degrees(target_degrees: float) -> void:
	var target_rotation := deg_to_rad(target_degrees)
	if is_equal_approx(rotation, target_rotation):
		return

	if _rotation_tween and _rotation_tween.is_valid():
		_rotation_tween.kill()

	_rotation_tween = create_tween()
	_rotation_tween.tween_property(self, "rotation", target_rotation, rotation_tween_duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)


func _play_animation(animation_name: StringName) -> void:
	if _has_animation(animation_name):
		_plume_animation.play(animation_name)


func _has_animation(animation_name: StringName) -> bool:
	return _plume_animation.sprite_frames != null and _plume_animation.sprite_frames.has_animation(animation_name)


func _get_animation_speed(animation_name: StringName) -> float:
	if not _has_animation(animation_name):
		return 0.0
	return _plume_animation.sprite_frames.get_animation_speed(animation_name)
