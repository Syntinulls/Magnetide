extends Resource
class_name EquipmentData

## Display name shown in UI
@export var display_name: String = ""
## Icon texture for hotbar slot
@export var hotbar_icon: Texture2D

@export_group("Muzzle Effect")
@export_enum("None", "Magnet Gun", "Rifle Flash") var muzzle_effect_type: int = MuzzleEffect.EffectType.NONE
@export var muzzle_effect_offset: Vector2 = Vector2.ZERO


func get_muzzle_effect_type() -> MuzzleEffect.EffectType:
	return muzzle_effect_type


func get_muzzle_effect_offset(is_facing_right: bool) -> Vector2:
	var facing_mult := 1.0 if is_facing_right else -1.0
	return Vector2(muzzle_effect_offset.x * facing_mult, muzzle_effect_offset.y)
