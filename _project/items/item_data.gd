extends Resource
class_name ItemData

@export var item_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var tags: Array[StringName] = []
## How this item upgrades (level cap, per-level costs, per-level effects). Null = not upgradeable.
@export var upgrade_data: UpgradeData = null


func get_max_level() -> int:
	return upgrade_data.max_level if upgrade_data != null else 0


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


func get_level_text(state: Resource) -> String:
	var max_level := get_max_level()
	var level := _get_state_level(state)
	if max_level <= 0:
		return "Active" if _is_state_unlocked(state) else "Locked"
	if not _is_state_unlocked(state):
		return "Locked"
	return "Lv %d/%d" % [level, max_level]


## True when both refer to the same item (same instance or matching item_id).
static func is_same_item(a: ItemData, b: ItemData) -> bool:
	if a == null or b == null:
		return false
	if a == b:
		return true
	return a.item_id == b.item_id


func get_next_level_cost(state: Resource) -> Resource:
	if upgrade_data == null or not _is_state_unlocked(state):
		return null
	return upgrade_data.get_cost_for_level(_get_state_level(state))


func _get_state_level(state: Resource) -> int:
	if state == null:
		return 0
	if not Utils.has_property(state, "current_level"):
		return 0
	return clampi(int(state.get("current_level")), 0, get_max_level())


func _is_state_unlocked(state: Resource) -> bool:
	if state == null:
		return false
	if not Utils.has_property(state, "unlocked"):
		return true
	return bool(state.get("unlocked"))
