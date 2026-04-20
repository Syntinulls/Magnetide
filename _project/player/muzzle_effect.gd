extends AnimatedSprite2D
class_name MuzzleEffect

enum EffectType {
	NONE,
	MAGNET_GUN,
	RIFLE_FLASH,
}

var _current_effect: EffectType = EffectType.NONE


func _ready() -> void:
	visible = false
	stop()


func play_effect(effect_type: EffectType) -> void:
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


func _play_magnet_gun() -> void:
	visible = true
	if sprite_frames and sprite_frames.has_animation("magnet_gun"):
		play("magnet_gun")


func _play_rifle_flash() -> void:
	visible = true
	if sprite_frames and sprite_frames.has_animation("rifle_flash"):
		play("rifle_flash")
		# Rifle flash is a one-shot effect
		if not animation_finished.is_connected(_on_rifle_flash_finished):
			animation_finished.connect(_on_rifle_flash_finished, CONNECT_ONE_SHOT)


func _on_rifle_flash_finished() -> void:
	if _current_effect == EffectType.RIFLE_FLASH:
		stop_effect()
