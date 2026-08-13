extends ItemData
class_name HeldItemData

## Base for items the player holds in the hotbar (weapons, the magnet tool): the shared
## visual/mounting data on top of the generic ItemData identity + leveling.

## Icon texture for the hotbar slot.
@export var hotbar_icon: Texture2D
## Sprite shown on the player's arm when equipped.
@export var weapon_sprite: Texture2D

@export_group("Positioning")
@export var weapon_offset: Vector2 = Vector2(-15.125, 0.0)
@export var weapon_rotation: float = -0.14660765
@export var muzzle_position: Vector2 = Vector2(-55.915, -4.695)
@export_group("Muzzle Effect")
@export_enum("None", "Magnet Gun", "Rifle Flash") var muzzle_effect_type: int = MuzzleEffect.EffectType.NONE
@export var muzzle_effect_offset: Vector2 = Vector2.ZERO
@export_group("")


## Behavior handling this item's input and runtime state while equipped. Each
## subclass returns a fresh instance; PlayerEquipment creates one per hotbar
## slot so slots never share state.
func create_use_behavior() -> HeldItemBehavior:
	return null


func get_icon() -> Texture2D:
	return hotbar_icon


## Per-item upgrade identifier, falling back to the resource path so distinct equipment
## never collide when item_id is unset.
func get_upgrade_item_id() -> StringName:
	if item_id != &"":
		return item_id
	if not resource_path.is_empty():
		return StringName(resource_path)
	return &""


func get_muzzle_effect_type() -> MuzzleEffect.EffectType:
	return muzzle_effect_type as MuzzleEffect.EffectType


func get_muzzle_effect_offset(is_facing_right: bool) -> Vector2:
	var facing_mult := 1.0 if is_facing_right else -1.0
	return Vector2(muzzle_effect_offset.x * facing_mult, muzzle_effect_offset.y)
