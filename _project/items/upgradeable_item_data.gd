extends Resource
class_name UpgradeableItemData

@export var item_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var max_level: int = 0:
	set(value):
		max_level = maxi(value, 0)
@export var level_costs: Array[Resource] = []
@export var tags: Array[StringName] = []


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if item_id != &"":
		return String(item_id).capitalize()
	return "Item"


func get_icon() -> Texture2D:
	return icon


func get_current_effect_summary(state: Resource) -> String:
	return get_level_text(state)


func get_next_level_gain_summary(_state: Resource) -> String:
	return ""


func get_next_level_detail_lines(state: Resource) -> PackedStringArray:
	var summary := get_next_level_gain_summary(state)
	if summary.is_empty():
		return PackedStringArray()
	return PackedStringArray([summary])


func get_level_text(state: Resource) -> String:
	var level := _get_state_level(state)
	if max_level <= 0:
		return "Active" if _is_state_unlocked(state) else "Locked"
	if not _is_state_unlocked(state):
		return "Locked"
	return "Lv %d/%d" % [level, max_level]


func get_next_level_cost(state: Resource) -> Resource:
	if not _is_state_unlocked(state):
		return null
	var level := _get_state_level(state)
	if level >= max_level:
		return null
	var cost_index := level
	if cost_index < 0 or cost_index >= level_costs.size():
		return null
	return level_costs[cost_index]


func _get_state_level(state: Resource) -> int:
	if state == null:
		return 0
	if not _has_property(state, "current_level"):
		return 0
	return clampi(int(state.get("current_level")), 0, max_level)


func _is_state_unlocked(state: Resource) -> bool:
	if state == null:
		return false
	if not _has_property(state, "unlocked"):
		return true
	return bool(state.get("unlocked"))


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
