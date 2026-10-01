extends Resource
class_name BossRewardData

## What a defeated boss hands the player, collected automatically: a scrap payout and
## salvage items (guaranteed ones plus rolls against the shared salvage loot pools).

@export var scrap_metal: int = 0
@export var guaranteed_items: Array[SalvageItemData] = []

@export_group("Rolled Loot")
## Number of extra items rolled from the loot pools.
@export var loot_rolls: int = 0
@export var loot_pools: SalvageLootPools
@export var rarity_weights: SalvageRarityWeights
## Chance (0-1) each roll draws from the salvageable sub-pool rather than the whole-item one.
@export_range(0.0, 1.0, 0.01) var salvageable_chance: float = 0.5


## Guaranteed items followed by `loot_rolls` pool rolls at `threat_level` (stage index
## 0-9). A roll that finds nothing available is dropped.
func roll_items(threat_level: int) -> Array[SalvageItemData]:
	var items: Array[SalvageItemData] = []
	for item in guaranteed_items:
		if item:
			items.append(item)
	if loot_pools == null or rarity_weights == null:
		return items
	var available := loot_pools.get_available_rarities(threat_level)
	for i in loot_rolls:
		var rarity := rarity_weights.roll_rarity(threat_level, available)
		if rarity < 0:
			continue
		var item := loot_pools.pick_uniform(rarity, randf() < salvageable_chance, threat_level)
		if item:
			items.append(item)
	return items
