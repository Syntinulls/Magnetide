extends Resource
class_name LootTable

## Raw item resources rolled directly by the loot table.
@export var entries: Array[SalvageItemData] = []


## Roll a random item from the table using weighted selection.
## Filters by threat level first, then picks based on item rarity weights.
func roll_item(threat_level: int = 0, max_item_rarity: int = SalvageItemData.ItemRarity.LEGENDARY) -> SalvageItemData:
	# 1. Filter entries by threat level and the pile's allowed max item rarity.
	var available_entries := _get_available_entries(threat_level, max_item_rarity)

	# 2. Sum total weight of filtered entries
	var total := 0.0
	for entry in available_entries:
		total += entry.get_drop_weight()
	if total <= 0.0:
		return null
	
	# 3. Roll random [0, total_weight)
	var roll := randf() * total
	
	# 4. Iterate entries, subtract chance until roll <= 0
	for entry in available_entries:
		roll -= entry.get_drop_weight()
		if roll <= 0:
			return entry
	
	# 5. Return selected item_data (or null if empty)
	return null

## Get all entries available at the given threat level and rarity cap.
func _get_available_entries(threat_level: int, max_item_rarity: int) -> Array[SalvageItemData]:
	var available: Array[SalvageItemData] = []
	for entry in entries:
		var item := entry as SalvageItemData
		if item and item.min_threat_level <= threat_level and int(item.rarity) <= max_item_rarity:
			available.append(item)
	return available
