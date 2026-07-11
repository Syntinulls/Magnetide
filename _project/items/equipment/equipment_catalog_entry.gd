extends Resource
class_name EquipmentCatalogEntry

@export var equipment_data: EquipmentData = null
@export var locked: bool = false
@export var unlock_cost: Array[Resource] = []
@export var research_unlock_id: StringName = &""
@export var research_unlock_group: StringName = &"weapons"
@export var research_unlock_order: int = 0
@export_group("Research Cost")
@export var research_cost_common: int = 0
@export var research_cost_rare: int = 0
@export var research_cost_epic: int = 0
@export_group("")


## Non-zero per-rarity costs as a rarity -> amount map (empty when free).
func get_research_cost() -> Dictionary:
	return EquipmentCatalogEntry.build_research_cost(
		research_cost_common, research_cost_rare, research_cost_epic
	)


## Shared builder so the two catalog-entry classes format costs identically.
static func build_research_cost(common: int, rare: int, epic: int) -> Dictionary:
	var cost := {}
	if common > 0:
		cost[SalvageItemData.ItemRarity.COMMON] = common
	if rare > 0:
		cost[SalvageItemData.ItemRarity.RARE] = rare
	if epic > 0:
		cost[SalvageItemData.ItemRarity.EPIC] = epic
	return cost


## Compact single-line cost text, e.g. "1x Common, 1x Rare".
static func format_research_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts := PackedStringArray()
	for rarity in cost:
		parts.append("%dx %s" % [int(cost[rarity]), SalvageItemData.get_name_for_rarity(int(rarity))])
	return ", ".join(parts)


func get_display_name() -> String:
	if equipment_data != null and not equipment_data.display_name.is_empty():
		return equipment_data.display_name
	return "Unknown Equipment"


func get_icon() -> Texture2D:
	if equipment_data == null:
		return null
	return equipment_data.hotbar_icon


func get_unlock_cost_text() -> String:
	var research_cost := get_research_cost()
	if not research_cost.is_empty():
		return EquipmentCatalogEntry.format_research_cost(research_cost)
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
