extends Resource
class_name LootTable

## All possible items in this loot table.
@export var items: Array[SalvageItemData] = []

## Rarity distribution weights per pile rarity.
## Each array is [COMMON%, RARE%, EPIC%, LEGENDARY%] weights for item rarities.
@export var rarity_weights: Dictionary = {
	SalvagePile.Rarity.COMMON: [80.0, 18.0, 1.9, 0.1],
	SalvagePile.Rarity.RARE: [60.0, 30.0, 9.0, 1.0],
	SalvagePile.Rarity.EPIC: [40.0, 35.0, 20.0, 5.0],
	SalvagePile.Rarity.LEGENDARY: [20.0, 30.0, 35.0, 15.0],
}

## Roll a random item from the table based on pile rarity.
## First rolls for item rarity tier, then picks an item of that rarity.
## Falls back to any available item if no items of rolled rarity exist.
func roll_item(pile_rarity: SalvagePile.Rarity = SalvagePile.Rarity.COMMON, current_threat_level: int = 0) -> SalvageItemData:
	var available := _get_available_items(current_threat_level)
	if available.is_empty():
		return null
	
	# Get rarity weights for this pile type
	var weights: Array = rarity_weights.get(pile_rarity, [80.0, 15.0, 4.0, 1.0])
	
	# Roll for item rarity tier
	var item_rarity := _roll_rarity_tier(weights)
	
	# Get items of that rarity
	var rarity_items := _filter_by_rarity(available, item_rarity)
	
	# If no items of that rarity, try lower rarities
	while rarity_items.is_empty() and item_rarity > SalvagePile.Rarity.COMMON:
		item_rarity = (item_rarity - 1) as SalvagePile.Rarity
		rarity_items = _filter_by_rarity(available, item_rarity)
	
	# If still empty, use all available items
	if rarity_items.is_empty():
		rarity_items = available
	
	# Weighted random selection within the rarity tier
	var total_weight := 0.0
	for item in rarity_items:
		total_weight += item.chance
	
	if total_weight <= 0.0:
		return rarity_items[randi() % rarity_items.size()]
	
	var roll := randf() * total_weight
	for item in rarity_items:
		roll -= item.chance
		if roll <= 0.0:
			return item
	
	return rarity_items.back()


## Roll which rarity tier an item should be based on weights.
func _roll_rarity_tier(weights: Array) -> SalvagePile.Rarity:
	var total := 0.0
	for w in weights:
		total += w
	
	var roll := randf() * total
	for i in range(weights.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return i as SalvagePile.Rarity
	
	return SalvagePile.Rarity.COMMON


## Get all items available at the given threat level.
func _get_available_items(current_threat_level: int) -> Array[SalvageItemData]:
	var available: Array[SalvageItemData] = []
	for item in items:
		if item.min_threat_level <= current_threat_level:
			available.append(item)
	return available


## Filter items by rarity.
func _filter_by_rarity(item_list: Array[SalvageItemData], rarity: SalvagePile.Rarity) -> Array[SalvageItemData]:
	var filtered: Array[SalvageItemData] = []
	for item in item_list:
		if item.rarity == rarity:
			filtered.append(item)
	return filtered
