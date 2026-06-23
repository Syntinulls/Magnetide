extends Resource
class_name SalvagePileData

enum PullCategory { NORMAL_ITEM, TRASH, ARTIFACT }

const DEFAULT_TRASH_SPRITES: Array[Texture2D] = [
	preload("res://_project/items/salvage/sprites/trash_small.png"),
]

## Highest salvage item rarity this pile is allowed to roll.
@export var rarity: SalvagePile.Rarity = SalvagePile.Rarity.COMMON

## Loot table for salvageable items (broken down into parts/scrap).
@export var salvageable_loot_table: LootTable = null
## Loot table for non-salvageable items (redeemed directly to inventory).
@export var non_salvageable_loot_table: LootTable = null

@export_group("Pull Categories")
## Relative weight for rolling regular salvage/non-salvage loot before the pity sub-roll.
@export_range(0.0, 100.0, 0.1) var normal_item_percent: float = 79.0
## Relative weight for rolling trash.
@export_range(0.0, 100.0, 0.1) var trash_percent: float = 20.0
## Legacy relative weight for rolling research artifacts inside normal piles. New artifact acquisition uses artifact piles.
@export_range(0.0, 100.0, 0.1) var artifact_percent: float = 1.0

@export_group("Artifact Pile")
@export var is_artifact_pile: bool = false
@export_range(0, 50, 1) var pre_artifact_trash_pulls: int = 4
## Optional looting duration for this pile. Values <= 0 use the minigame default.
@export_range(0.0, 180.0, 0.5, "suffix:s") var departure_duration_override: float = 0.0

@export_group("Pity System")
## Base probability (0-100) for pulling a salvageable item.
@export var salvageable_base_percent: float = 30.0
## Probability increase per non-salvageable pull (pseudo-pity).
@export var salvageable_increment_percent: float = 5.0
## Maximum probability cap for salvageable items.
@export var salvageable_max_percent: float = 80.0

@export_group("Trash")
@export var trash_sprites: Array[Texture2D] = DEFAULT_TRASH_SPRITES
@export var trash_area: Vector2 = Vector2(64, 64)
@export var trash_hitbox_size: Vector2 = Vector2(36, 36)
@export var trash_weight: float = 0.75

@export_group("Artifacts")
@export var artifact_loot_table: LootTable = null
@export var allow_legacy_artifact_rolls: bool = false


## Calculate the current salvageable probability based on pull count.
func get_salvageable_chance(pull_count: int) -> float:
	return minf(salvageable_base_percent + (pull_count * salvageable_increment_percent), salvageable_max_percent)


## Roll whether the next pull should be salvageable or non-salvageable.
## Returns true for salvageable, false for non-salvageable.
func roll_is_salvageable(pull_count: int) -> bool:
	var chance := get_salvageable_chance(pull_count)
	return randf() * 100.0 < chance


func get_category_percent_total() -> float:
	return normal_item_percent + trash_percent + artifact_percent


func has_valid_category_distribution() -> bool:
	return get_category_percent_total() > 0.0


func can_roll_trash() -> bool:
	return trash_percent > 0.0 and not trash_sprites.is_empty()


func can_roll_artifact() -> bool:
	return allow_legacy_artifact_rolls and artifact_percent > 0.0 and artifact_loot_table != null and not is_artifact_pile


## Roll an item from this pile's loot tables.
## Returns the item data and whether it was salvageable.
func roll_item(pull_count: int, threat_level: int = 0) -> Dictionary:
	if is_artifact_pile:
		return roll_artifact_pile_item(pull_count, threat_level)

	match _roll_pull_category():
		PullCategory.ARTIFACT:
			var artifact_item := artifact_loot_table.roll_item(threat_level, SalvageItemData.ItemRarity.LEGENDARY) if artifact_loot_table else null
			return {
				"item": artifact_item,
				"is_artifact": true,
				"is_trash": false,
				"is_salvageable": false,
			}
		PullCategory.TRASH:
			return {
				"item": null,
				"is_artifact": false,
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
		return { "item": item, "is_artifact": false, "is_trash": false, "is_salvageable": is_salvageable }
	return { "item": null, "is_artifact": false, "is_trash": false, "is_salvageable": false }


func roll_artifact_pile_item(_sequence_pull_count: int, _threat_level: int = 0) -> Dictionary:
	return get_trash_roll_result()


func roll_artifact_pile_final_item(threat_level: int = 0) -> Dictionary:
	var artifact_item := roll_artifact_item(threat_level)
	return {
		"item": artifact_item,
		"is_artifact": true,
		"is_artifact_pile_final": true,
		"is_trash": false,
		"is_salvageable": false,
	}


func get_departure_duration(default_duration: float) -> float:
	if departure_duration_override > 0.0:
		return departure_duration_override
	return default_duration


func roll_artifact_item(threat_level: int = 0) -> SalvageItemData:
	if artifact_loot_table == null:
		return null
	return artifact_loot_table.roll_item(threat_level, SalvageItemData.ItemRarity.LEGENDARY)


func get_trash_roll_result() -> Dictionary:
	return {
		"item": null,
		"is_artifact": false,
		"is_trash": true,
		"is_salvageable": false,
		"trash_texture": _roll_trash_sprite(),
		"trash_area": trash_area,
		"trash_hitbox_size": trash_hitbox_size,
		"trash_weight": trash_weight,
	}


func _roll_pull_category() -> int:
	if not has_valid_category_distribution():
		push_warning("SalvagePileData category weights should include at least one positive outcome.")

	var entries: Array = [
		PullCategory.NORMAL_ITEM,
		PullCategory.TRASH,
		PullCategory.ARTIFACT,
	]
	var selected: Variant = WeightedRandom.roll_weighted(entries, Callable(self, "_get_category_roll_weight"))
	return int(selected) if selected != null else PullCategory.NORMAL_ITEM


func _get_category_roll_weight(category: int) -> float:
	match category:
		PullCategory.NORMAL_ITEM:
			return maxf(normal_item_percent, 0.0)
		PullCategory.TRASH:
			return maxf(trash_percent, 0.0) if can_roll_trash() else 0.0
		PullCategory.ARTIFACT:
			return maxf(artifact_percent, 0.0) if can_roll_artifact() else 0.0
	return 0.0


func _roll_trash_sprite() -> Texture2D:
	if trash_sprites.is_empty():
		return null
	return trash_sprites[randi() % trash_sprites.size()]
