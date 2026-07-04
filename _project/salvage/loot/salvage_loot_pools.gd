extends Resource
class_name SalvageLootPools

## Shared loot pools for all generic salvage piles (Step 1 of the salvage loot & artifact rework —
## see specs/salvage_loot_pool_system_spec.md).
##
## Each of the four salvage rarities keeps the salvageable / non-salvageable split, so every rarity
## owns two arrays (8 total). Salvageable items are broken into parts/scrap; non-salvageable items
## are redeemed whole. An item may appear in both sub-pools — the sub-pool it is pulled from decides
## how it is processed.
##
## Selection within a sub-pool is uniform. Rarity (Step 2 weight curve) and the salvageable pity
## roll (Step 4) decide which sub-pool to draw from; this resource only stores the items and answers
## availability/pick queries. Assign the SAME instance to every pile so piles share their loot.

@export_group("Common")
@export var common_salvageable: Array[SalvageItemData] = []
@export var common_non_salvageable: Array[SalvageItemData] = []
@export_group("Rare")
@export var rare_salvageable: Array[SalvageItemData] = []
@export var rare_non_salvageable: Array[SalvageItemData] = []
@export_group("Epic")
@export var epic_salvageable: Array[SalvageItemData] = []
@export var epic_non_salvageable: Array[SalvageItemData] = []
@export_group("Legendary")
@export var legendary_salvageable: Array[SalvageItemData] = []
@export var legendary_non_salvageable: Array[SalvageItemData] = []


## The raw sub-pool array for a rarity + salvageable flag.
func get_pool(rarity: int, is_salvageable: bool) -> Array[SalvageItemData]:
	match rarity:
		SalvageItemData.ItemRarity.COMMON:
			return common_salvageable if is_salvageable else common_non_salvageable
		SalvageItemData.ItemRarity.RARE:
			return rare_salvageable if is_salvageable else rare_non_salvageable
		SalvageItemData.ItemRarity.EPIC:
			return epic_salvageable if is_salvageable else epic_non_salvageable
		SalvageItemData.ItemRarity.LEGENDARY:
			return legendary_salvageable if is_salvageable else legendary_non_salvageable
	return common_salvageable if is_salvageable else common_non_salvageable


## Items in one sub-pool unlocked at the given threat level (min_threat_level filter).
func get_available_items(rarity: int, is_salvageable: bool, threat_level: int) -> Array[SalvageItemData]:
	var out: Array[SalvageItemData] = []
	for item in get_pool(rarity, is_salvageable):
		if item and item.min_threat_level <= threat_level:
			out.append(item)
	return out


## True if either sub-pool of this rarity has an unlocked item (i.e. the rarity is rollable).
func has_available_items(rarity: int, threat_level: int) -> bool:
	return not get_available_items(rarity, true, threat_level).is_empty() \
		or not get_available_items(rarity, false, threat_level).is_empty()


## Uniform pick within the chosen sub-pool. Falls back to the other sub-pool if the chosen one is
## empty; returns null only if both are empty.
func pick_uniform(rarity: int, is_salvageable: bool, threat_level: int) -> SalvageItemData:
	var items := get_available_items(rarity, is_salvageable, threat_level)
	if items.is_empty():
		items = get_available_items(rarity, not is_salvageable, threat_level)
	if items.is_empty():
		return null
	return items[randi() % items.size()]
