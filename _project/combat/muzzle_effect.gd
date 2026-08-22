extends AnimatedSprite2D
class_name MuzzleEffect

## Muzzle flash at the weapon barrel. Its glow pulses once per shot rather than
## following the animation: at a high fire rate the animation stays up between
## rounds, so a glow tied to it would read as one continuous flare. A held-down tool
## (the magnet gun) passes no interval and simply holds the glow while it runs.

enum EffectType {
	NONE,
	MAGNET_GUN,
	RIFLE_FLASH,
}

## Longest a per-shot flash may last, so a slow weapon does not hold the flare up for
## most of a second.
@export var glow_flash_max_time: float = 0.09
## Fraction of the interval between shots a flash may fill. Under 1 so consecutive
## rounds read as separate pulses instead of running together.
@export_range(0.05, 1.0, 0.01) var glow_flash_ratio: float = 0.55

var _current_effect: EffectType = EffectType.NONE
var _glow_tween: Tween = null

@onready var _glow: ShaderMaterial = material as ShaderMaterial


func _ready() -> void:
	visible = false
	stop()
	_set_glow(0.0)


## fire_interval is the seconds between shots of the weapon that triggered this, and
## sizes the flash. Leave it at 0 for an effect that should simply glow while it runs.
func play_effect(effect_type: EffectType, fire_interval: float = 0.0) -> void:
	# Ahead of the dedupe below on purpose: the shot happened, so the flash fires
	# again even when the animation from the previous round is still on screen.
	if effect_type == EffectType.RIFLE_FLASH:
		_flash_glow(fire_interval)
	if effect_type == _current_effect and visible:
		return
	
	_current_effect = effect_type
	
	match effect_type:
		EffectType.NONE:
			stop_effect()
		EffectType.MAGNET_GUN:
			_play_magnet_gun()
		EffectType.RIFLE_FLASH:
			_play_rifle_flash()


func stop_effect() -> void:
	_current_effect = EffectType.NONE
	visible = false
	stop()
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_set_glow(0.0)


func _play_magnet_gun() -> void:
	visible = true
	_set_glow(1.0)
	if sprite_frames and sprite_frames.has_animation("magnet_gun"):
		play("magnet_gun")


func _play_rifle_flash() -> void:
	visible = true
	if sprite_frames and sprite_frames.has_animation("rifle_flash"):
		play("rifle_flash")
		frame = 0
		if not animation_looped.is_connected(_on_rifle_flash_looped):
			animation_looped.connect(_on_rifle_flash_looped)


func _on_rifle_flash_looped() -> void:
	if _current_effect == EffectType.RIFLE_FLASH:
		stop_effect()
		if animation_looped.is_connected(_on_rifle_flash_looped):
			animation_looped.disconnect(_on_rifle_flash_looped)


## Punch the emission to full and let it fall away inside one shot's interval.
func _flash_glow(fire_interval: float) -> void:
	if _glow == null:
		return
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	var flash_time := glow_flash_max_time
	if fire_interval > 0.0:
		flash_time = minf(flash_time, fire_interval * glow_flash_ratio)
	_set_glow(1.0)
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_glow, 1.0, 0.0, maxf(flash_time, 0.01)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_glow(value: float) -> void:
	if _glow != null:
		_glow.set_shader_parameter(&"glow_intensity", value)
