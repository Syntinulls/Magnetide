extends Resource
class_name EquipmentCatalogEntry

@export var equipment_data: EquipmentData = null
@export var locked: bool = false
@export var unlock_cost: Array[Resource] = []
@export var research_unlock_id: StringName = &""
@export var research_unlock_group: StringName = &"weapons"
@export var research_unlock_order: int = 0
@export var research_point_cost: int = 0


func get_display_name() -> String:
	if equipment_data != null and not equipment_data.display_name.is_empty():
		return equipment_data.display_name
	return "Unknown Equipment"


func get_icon() -> Texture2D:
	if equipment_data == null:
		return null
	return equipment_data.hotbar_icon


func get_unlock_cost_text() -> String:
	if research_point_cost > 0:
		return "%d RP" % research_point_cost
	if unlock_cost.is_empty():
		return "No unlock cost"

	var cost_parts := PackedStringArray()
	for cost in unlock_cost:
		if cost != null:
			cost_parts.append(cost.get_display_text())
	return ", ".join(cost_parts)


func get_research_unlock_id() -> StringName:
	if research_unlock_id != &"":
		return research_unlock_id
	if equipment_data != null and not equipment_data.resource_path.is_empty():
		return StringName(equipment_data.resource_path)
	return StringName(get_display_name().to_snake_case())
