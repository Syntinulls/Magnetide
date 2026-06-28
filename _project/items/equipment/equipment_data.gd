extends Resource
class_name EquipmentData

## Stable identifier used for per-item upgrade levels / unlock state.
## Falls back to the resource path when left empty.
@export var item_id: StringName = &""
## Display name shown in UI
@export var display_name: String = ""
## Icon texture for hotbar slot
@export var hotbar_icon: Texture2D


## Per-item upgrade identifier, falling back to the resource path so distinct
## equipment never collide when item_id is unset.
func get_upgrade_item_id() -> StringName:
	if item_id != &"":
		return item_id
	if not resource_path.is_empty():
		return StringName(resource_path)
	return &""

@export_group("Muzzle Effect")
@export_enum("None", "Magnet Gun", "Rifle Flash") var muzzle_effect_type: int = MuzzleEffect.EffectType.NONE
@export var muzzle_effect_offset: Vector2 = Vector2.ZERO


func get_muzzle_effect_type() -> MuzzleEffect.EffectType:
	return muzzle_effect_type as MuzzleEffect.EffectType


func get_muzzle_effect_offset(is_facing_right: bool) -> Vector2:
	var facing_mult := 1.0 if is_facing_right else -1.0
	return Vector2(muzzle_effect_offset.x * facing_mult, muzzle_effect_offset.y)
