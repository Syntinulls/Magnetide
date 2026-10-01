extends Camera2D
class_name LevelCamera

## The run's camera. The level re-derives its rest position (screen center) on every
## viewport resize; cinematic moves pose the camera away from rest and reset() eases it
## back. While posed, a resize updates the rest position without snapping the camera.
##
## Shake owns `offset` for its duration (restored when it ends), so it must not overlap
## another system that tweens offset directly (the lever minigame's zoom framing).

## Zoom the camera returns to on reset().
@export var rest_zoom: Vector2 = Vector2.ONE

## Screen-centered resting position, written by the level on layout changes.
var rest_position: Vector2 = Vector2.ZERO:
	set(value):
		rest_position = value
		if not _is_posed:
			position = value

var _is_posed: bool = false
var _position_tween: Tween = null
var _zoom_tween: Tween = null
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_remaining: float = 0.0
var _shake_base_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_shake_remaining -= delta
	if _shake_remaining <= 0.0:
		offset = _shake_base_offset
		set_process(false)
		return
	var falloff := _shake_remaining / maxf(_shake_duration, 0.001)
	var strength := _shake_strength * falloff
	offset = _shake_base_offset + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))


## True while a cinematic move holds the camera away from its rest position.
func is_posed() -> bool:
	return _is_posed


## Place the camera immediately (e.g. from a cutscene's own tween_method), posing it.
func move_to(global_target: Vector2) -> void:
	_is_posed = true
	_kill(_position_tween)
	global_position = global_target


func tween_position(
	global_target: Vector2,
	duration: float,
	trans: Tween.TransitionType = Tween.TRANS_SINE,
	ease_type: Tween.EaseType = Tween.EASE_IN_OUT
) -> Tween:
	_is_posed = true
	_kill(_position_tween)
	_position_tween = create_tween()
	_position_tween.tween_property(self, "global_position", global_target, maxf(duration, 0.001)) \
		.set_trans(trans).set_ease(ease_type)
	return _position_tween


func tween_zoom(
	target: Vector2,
	duration: float,
	trans: Tween.TransitionType = Tween.TRANS_SINE,
	ease_type: Tween.EaseType = Tween.EASE_IN_OUT
) -> Tween:
	_kill(_zoom_tween)
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", target, maxf(duration, 0.001)) \
		.set_trans(trans).set_ease(ease_type)
	return _zoom_tween


## Random jitter that decays linearly to nothing over `duration`. A new shake replaces
## one already running.
func shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	if _shake_remaining <= 0.0:
		_shake_base_offset = offset
	_shake_strength = strength
	_shake_duration = duration
	_shake_remaining = duration
	set_process(true)


## Ease position and zoom back to rest; the camera stops being posed once it arrives.
func reset(duration: float = 0.0) -> Tween:
	var tween := create_tween().set_parallel(true)
	_kill(_position_tween)
	_kill(_zoom_tween)
	_position_tween = tween
	_zoom_tween = tween
	var seconds := maxf(duration, 0.001)
	tween.tween_property(self, "position", rest_position, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "zoom", rest_zoom, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(func() -> void: _is_posed = false)
	return tween


func _kill(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
