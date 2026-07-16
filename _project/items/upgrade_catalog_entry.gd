extends Resource
class_name UpgradeCatalogEntry

## One selectable entry in a dynamic upgrade slot's catalog: the item it equips plus its
## per-item unlock gating. Works for any item type (weapon, augment, ...) — the item's own
## data supplies name/icon; the entry only adds catalog concerns (lock, group, cost).

## The item this entry equips (WeaponData, AugmentData, ...).
@export var item_data: Resource = null
## Optional upgrade track shown for this entry (a duplicate of item_data.upgrade_data). May be
## left null; the equipped item's own upgrade_data is the source of truth at runtime.
@export var upgrade: UpgradeData = null
@export var locked: bool = false
@export var research_unlock_id: StringName = &""
@export var research_unlock_group: StringName = &""
@export var research_unlock_order: int = 0
@export_group("Research Cost")
@export var research_cost_common: int = 0
@export var research_cost_rare: int = 0
@export var research_cost_epic: int = 0
@export_group("")
@export var unlock_cost: Array[Resource] = []


## Non-zero per-rarity costs as a rarity -> amount map (empty when free).
func get_research_cost() -> Dictionary:
	return UpgradeCatalogEntry.build_research_cost(
		research_cost_common, research_cost_rare, research_cost_epic
	)


func get_display_name() -> String:
	if item_data != null and item_data.has_method("get_display_name"):
		return String(item_data.call("get_display_name"))
	if item_data != null and Utils.has_property(item_data, "display_name"):
		var display_name := String(item_data.get("display_name"))
		if not display_name.is_empty():
			return display_name
	return "Unknown Item"


func get_icon() -> Texture2D:
	if item_data != null and item_data.has_method("get_icon"):
		return item_data.call("get_icon") as Texture2D
	if item_data != null and Utils.has_property(item_data, "icon"):
		return item_data.get("icon") as Texture2D
	return null


func get_unlock_cost_text() -> String:
	var research_cost := get_research_cost()
	if not research_cost.is_empty():
		return UpgradeCatalogEntry.format_research_cost(research_cost)
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
	if item_data != null and Utils.has_property(item_data, "item_id"):
		return item_data.get("item_id") as StringName
	return StringName(get_display_name().to_snake_case())


## Non-zero per-rarity costs as a rarity -> amount map (empty when free).
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
