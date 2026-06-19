extends UpgradeableItemData
class_name EquipmentUpgradeableItemData

@export var equipment_data: EquipmentData = null
@export var stat_behaviors: Array[Resource] = []


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if equipment_data != null and not equipment_data.display_name.is_empty():
		return equipment_data.display_name
	return super()


func get_icon() -> Texture2D:
	if icon != null:
		return icon
	if equipment_data != null:
		if equipment_data.hotbar_icon != null:
			return equipment_data.hotbar_icon
		if equipment_data is WeaponData:
			return (equipment_data as WeaponData).weapon_sprite
		if equipment_data is MagnetToolData:
			return (equipment_data as MagnetToolData).weapon_sprite
	return null
