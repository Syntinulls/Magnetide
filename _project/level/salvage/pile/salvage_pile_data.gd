extends Resource
class_name SalvagePileData

const DEFAULT_TRASH_SPRITES: Array[Texture2D] = [
	preload("res://_project/items/sprites/trash_small.png"),
]

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

@export_group("Trash")
## Independent roll made before salvageable/non-salvageable selection.
@export_range(0.0, 100.0, 1.0) var trash_percent: float = 20.0
@export var trash_sprites: Array[Texture2D] = DEFAULT_TRASH_SPRITES
@export var trash_area: Vector2 = Vector2(64, 64)
@export var trash_hitbox_size: Vector2 = Vector2(36, 36)
@export var trash_weight: float = 0.75


## Calculate the current salvageable probability based on pull count.
func get_salvageable_chance(pull_count: int) -> float:
	return minf(salvageable_base_percent + (pull_count * salvageable_increment_percent), salvageable_max_percent)


## Roll whether the next pull should be salvageable or non-salvageable.
## Returns true for salvageable, false for non-salvageable.
func roll_is_salvageable(pull_count: int) -> bool:
	var chance := get_salvageable_chance(pull_count)
	return randf() * 100.0 < chance


func can_roll_trash() -> bool:
	return trash_percent > 0.0 and not trash_sprites.is_empty()


func roll_is_trash() -> bool:
	if not can_roll_trash():
		return false
	return randf() * 100.0 < trash_percent


## Get the total activation threat cost for this pile using the magnet's base cost.
func get_activation_threat_cost(base_cost: float) -> float:
	return base_cost + threat_cost_bonus


## Roll an item from this pile's loot tables.
## Returns the item data and whether it was salvageable.
func roll_item(pull_count: int, threat_level: int = 0) -> Dictionary:
	if roll_is_trash():
		return {
			"item": null,
			"is_trash": true,
			"is_salvageable": false,
			"trash_texture": _roll_trash_sprite(),
			"trash_area": trash_area,
			"trash_hitbox_size": trash_hitbox_size,
			"trash_weight": trash_weight,
		}

	var is_salvageable := roll_is_salvageable(pull_count)
	var loot_table := salvageable_loot_table if is_salvageable else non_salvageable_loot_table
	if loot_table:
		var item := loot_table.roll_item(threat_level, int(rarity))
		return { "item": item, "is_trash": false, "is_salvageable": is_salvageable }
	return { "item": null, "is_trash": false, "is_salvageable": false }


func _roll_trash_sprite() -> Texture2D:
	if trash_sprites.is_empty():
		return null
	return trash_sprites[randi() % trash_sprites.size()]
