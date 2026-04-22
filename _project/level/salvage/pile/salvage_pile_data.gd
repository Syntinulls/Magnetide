extends Resource
class_name SalvagePileData

## Highest salvage item rarity this pile is allowed to roll.
@export var rarity: SalvagePile.Rarity = SalvagePile.Rarity.COMMON

## Loot table for salvageable items (broken down into parts/scrap).
@export var salvageable_loot_table: LootTable = null
## Loot table for non-salvageable items (redeemed directly to inventory).
@export var non_salvageable_loot_table: LootTable = null

@export_group("Threat")
## Additional threat cost applied on top of the magnet's base activation cost.
@export var threat_cost_bonus: float = 0.0

@export_group("Pity System")
## Base probability (0-100) for pulling a salvageable item.
@export var salvageable_base_percent: float = 30.0
## Probability increase per non-salvageable pull (pseudo-pity).
@export var salvageable_increment_percent: float = 5.0
## Maximum probability cap for salvageable items.
@export var salvageable_max_percent: float = 80.0


## Calculate the current salvageable probability based on pull count.
func get_salvageable_chance(pull_count: int) -> float:
	return minf(salvageable_base_percent + (pull_count * salvageable_increment_percent), salvageable_max_percent)


## Roll whether the next pull should be salvageable or non-salvageable.
## Returns true for salvageable, false for non-salvageable.
func roll_is_salvageable(pull_count: int) -> bool:
	var chance := get_salvageable_chance(pull_count)
	return randf() * 100.0 < chance


## Get the total activation threat cost for this pile using the magnet's base cost.
func get_activation_threat_cost(base_cost: float) -> float:
	return base_cost + threat_cost_bonus


## Roll an item from this pile's loot tables.
## Returns the item data and whether it was salvageable.
func roll_item(pull_count: int, threat_level: int = 0) -> Dictionary:
	# 1. Roll salvageable vs non-salvageable
	var is_salvageable := roll_is_salvageable(pull_count)
	# 2. Pick appropriate loot table and roll item
	var loot_table := salvageable_loot_table if is_salvageable else non_salvageable_loot_table
	if loot_table:
		var item := loot_table.roll_item(threat_level, int(rarity))
		return { "item": item, "is_salvageable": is_salvageable }
	return { "item": null, "is_salvageable": false }
