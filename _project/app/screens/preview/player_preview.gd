extends Node2D
class_name PlayerPreview

## Render-only skeleton of the Player used for the station screen preview.
## Mirrors the body/legs/arm/weapon visuals and reflects the equipped weapon from
## a RunLoadout. It deliberately has no input, physics, collisions, hotbar, or
## autoload dependencies — it exists purely to be drawn inside a SubViewport.

const ARM_OFFSET_X: float = -13.585
const ARM_POSITION_X: float = 12.56

@onready var _body_sprite: Sprite2D = $BodySprite
@onready var _legs_sprite: Sprite2D = $Legs
@onready var _arm_sprite: Sprite2D = $ArmSprite
@onready var _weapon_sprite: Sprite2D = $ArmSprite/Weapon

var _facing_right: bool = false
var _pending_loadout: RunLoadout = null


func _ready() -> void:
	_apply_facing(_facing_right)
	if _pending_loadout != null:
		apply_run_loadout(_pending_loadout)
		_pending_loadout = null


## Update the preview to reflect the currently equipped weapon in the loadout.
func apply_run_loadout(loadout: RunLoadout) -> void:
	if loadout == null:
		return
	if not is_node_ready():
		_pending_loadout = loadout
		return
	_apply_equipment(_get_preview_equipment(loadout))


func _get_preview_equipment(loadout: RunLoadout) -> EquipmentData:
	# Mirror the player's default in-run selection (the equipped weapon).
	if loadout.equipped_weapon != null:
		return loadout.equipped_weapon
	if not loadout.player_equipment.is_empty():
		return loadout.player_equipment[0]
	return null


func _apply_equipment(equip: EquipmentData) -> void:
	if _weapon_sprite == null:
		return
	if equip == null:
		_weapon_sprite.texture = null
		return
	_weapon_sprite.texture = _equipment_sprite(equip)
	_apply_equipment_positioning(equip, _facing_mult())


func _equipment_sprite(equip: EquipmentData) -> Texture2D:
	if equip is WeaponData:
		return (equip as WeaponData).weapon_sprite
	if equip is MagnetToolData:
		return (equip as MagnetToolData).weapon_sprite
	return null


func _facing_mult() -> float:
	return -1.0 if _facing_right else 1.0


func _apply_facing(facing_right: bool) -> void:
	_facing_right = facing_right
	if _body_sprite == null:
		return
	_body_sprite.flip_h = facing_right
	_legs_sprite.flip_h = facing_right
	_arm_sprite.flip_h = facing_right
	_weapon_sprite.flip_h = facing_right
	var offset_mult := -1.0 if facing_right else 1.0
	_arm_sprite.offset.x = ARM_OFFSET_X * offset_mult
	_arm_sprite.position.x = ARM_POSITION_X * offset_mult


func _apply_equipment_positioning(equip: EquipmentData, offset_mult: float) -> void:
	if _weapon_sprite == null or equip == null:
		return
	var w_offset := Vector2.ZERO
	var w_rotation := 0.0
	if equip is WeaponData:
		w_offset = (equip as WeaponData).weapon_offset
		w_rotation = (equip as WeaponData).weapon_rotation
	elif equip is MagnetToolData:
		w_offset = (equip as MagnetToolData).weapon_offset
		w_rotation = (equip as MagnetToolData).weapon_rotation
	_weapon_sprite.offset = Vector2(w_offset.x * offset_mult, w_offset.y)
	_weapon_sprite.rotation = w_rotation * offset_mult
