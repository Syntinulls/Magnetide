extends Resource
class_name SlottableCatalogEntry

@export var item_data: Resource = null
@export var locked: bool = false
@export var research_unlock_id: StringName = &""
@export var research_unlock_group: StringName = &""
@export var research_unlock_order: int = 0
@export var research_point_cost: int = 0
@export var unlock_cost: Array[Resource] = []


func get_display_name() -> String:
	if item_data != null and item_data.has_method("get_display_name"):
		return String(item_data.call("get_display_name"))
	if item_data != null and _has_property(item_data, "display_name"):
		var name := String(item_data.get("display_name"))
		if not name.is_empty():
			return name
	return "Unknown Item"


func get_icon() -> Texture2D:
	if item_data != null and item_data.has_method("get_icon"):
		return item_data.call("get_icon") as Texture2D
	if item_data != null and _has_property(item_data, "icon"):
		return item_data.get("icon") as Texture2D
	return null


func get_unlock_cost_text() -> String:
	if research_point_cost > 0:
		return "%d RP" % research_point_cost
	if unlock_cost.is_empty():
		return "No unlock cost"

	var cost_parts := PackedStringArray()
	for cost in unlock_cost:
		if cost != null and cost.has_method("get_display_text"):
			cost_parts.append(String(cost.call("get_display_text")))
	return ", ".join(cost_parts)


func get_research_unlock_id() -> StringName:
	if research_unlock_id != &"":
		return research_unlock_id
	if item_data != null and _has_property(item_data, "item_id"):
		return item_data.get("item_id") as StringName
	return StringName(get_display_name().to_snake_case())


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
