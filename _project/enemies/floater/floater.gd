extends Enemy
class_name Floater

## Slow ship bomber. It drifts to the ship target point nearest its spawn, coils, then
## bursts -- hurting the ship and anyone standing close -- scatters pines, and retreats
## off screen. The approach and the coil/explode sequence live in its move and attack
## behaviors; this body owns the coil squash, played on the Visual container so every
## sprite layer squashes together and the base hit shake (which moves Visual) is kept.

const ANIM_COIL: StringName = &"coil"

## Vertical scale the body squashes to while coiling.
@export_range(0.1, 1.0) var coil_squash_scale: float = 0.7
## Seconds the squash takes to settle; the elastic ease bounces inside this window.
@export var coil_squash_duration: float = 0.45
## Seconds the body takes to spring back to full height as it bursts.
@export var release_duration: float = 0.15

var _rest_scale_y: float = 1.0
var _squash_tween: Tween = null


func _ready() -> void:
	super._ready()
	_rest_scale_y = visual.scale.y


func play_coil_squash() -> void:
	_restart_squash_tween().tween_property(
		visual, "scale:y", _rest_scale_y * coil_squash_scale, coil_squash_duration
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func release_squash() -> void:
	_restart_squash_tween().tween_property(
		visual, "scale:y", _rest_scale_y, release_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _restart_squash_tween() -> Tween:
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	return _squash_tween
