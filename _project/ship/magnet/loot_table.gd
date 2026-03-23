extends Resource
class_name LootTable

## Loot entries with item data and chance weights.
@export var entries: Array[LootEntry] = []


## Roll a random item from the table using weighted selection.
## Filters by threat level first, then picks based on chance weights.
func roll_item(threat_level: int = 0) -> SalvageItemData:
	# 1. Filter entries by threat_level (item.min_threat_level <= threat_level)
	var available_entries := _get_available_entries(threat_level)

	# 2. Sum total weight of filtered entries
	var total := 0.0
	for entry in available_entries:
		total += entry.chance
	
	# 3. Roll random [0, total_weight)
	var roll := randf() * total
	
	# 4. Iterate entries, subtract chance until roll <= 0
	for entry in available_entries:
		roll -= entry.chance
		if roll <= 0:
			return entry.item_data
	
	# 5. Return selected item_data (or null if empty)
	return null

## Get all entries available at the given threat level.
func _get_available_entries(threat_level: int) -> Array[LootEntry]:
	var available: Array[LootEntry] = []
	for entry in entries:
		if entry.item_data and entry.item_data.min_threat_level <= threat_level:
			available.append(entry)
	return available
