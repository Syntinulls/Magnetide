extends Resource
class_name EquipmentCatalogEntry

@export var equipment_data: EquipmentData = null
@export var locked: bool = false
@export var unlock_cost: Array[Resource] = []


func get_display_name() -> String:
	if equipment_data != null and not equipment_data.display_name.is_empty():
		return equipment_data.display_name
	return "Unknown Equipment"


func get_icon() -> Texture2D:
	if equipment_data == null:
		return null
	return equipment_data.hotbar_icon


func get_unlock_cost_text() -> String:
	if unlock_cost.is_empty():
		return "No unlock cost"

	var cost_parts := PackedStringArray()
	for cost in unlock_cost:
		if cost != null:
			cost_parts.append(cost.get_display_text())
	return ", ".join(cost_parts)
