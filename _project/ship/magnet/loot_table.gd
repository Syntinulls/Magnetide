extends Resource
class_name LootTable

## Raw item resources rolled directly by the loot table.
@export var entries: Array[SalvageItemData] = []


## Roll a random item from the table using weighted selection.
## Filters by threat level first, then picks based on item rarity weights.
func roll_item(threat_level: int = 0, max_item_rarity: int = SalvageItemData.ItemRarity.LEGENDARY) -> SalvageItemData:
	# 1. Filter entries by threat level and the pile's allowed max item rarity.
	var available_entries := _get_available_entries(threat_level, max_item_rarity)
	return WeightedRandom.roll_weighted(available_entries, Callable(self, "_get_entry_weight")) as SalvageItemData


func _get_entry_weight(entry: SalvageItemData) -> float:
	if entry == null:
		return 0.0
	return entry.get_drop_weight()

## Get all entries available at the given threat level and rarity cap.
func _get_available_entries(threat_level: int, max_item_rarity: int) -> Array[SalvageItemData]:
	var available: Array[SalvageItemData] = []
	for entry in entries:
		var item := entry as SalvageItemData
		if item and item.min_threat_level <= threat_level and int(item.rarity) <= max_item_rarity:
			available.append(item)
	return available
