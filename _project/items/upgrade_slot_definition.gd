extends Resource
class_name UpgradeSlotDefinition

enum SlotKind { STATIC, DYNAMIC }
enum SlotOwner { PLAYER, SHIP, MAGNET }
enum SlotCategory { EQUIPMENT, STAT, AUGMENT }

@export var slot_id: StringName = &""
@export var display_name: String = ""
@export var owner: SlotOwner = SlotOwner.PLAYER
@export var category: SlotCategory = SlotCategory.EQUIPMENT
@export var kind: SlotKind = SlotKind.STATIC
@export var static_item: Resource = null
@export var allowed_tags: Array[StringName] = []
@export var unlock_group: StringName = &""


func accepts_item(item_data: Resource) -> bool:
	if kind == SlotKind.STATIC:
		return item_data == static_item
	if item_data == null:
		return false
	if allowed_tags.is_empty():
		return true
	if not _has_property(item_data, "tags"):
		return false
	var item_tags := item_data.get("tags") as Array
	for tag in allowed_tags:
		if tag in item_tags:
			return true
	return false


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
