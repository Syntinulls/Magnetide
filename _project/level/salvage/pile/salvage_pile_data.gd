extends Resource
class_name SalvagePileData

## Generic salvage pile loot configuration (salvage loot & artifact rework —
## see specs/salvage_loot_pool_system_spec.md).
##
## A pull resolves as: trash -> artifact -> salvage rarity -> salvageable/non pity -> uniform item.
## Loot comes from the shared SalvageLootPools + SalvageRarityWeights + ArtifactPools resources.

const DEFAULT_TRASH_SPRITES: Array[Texture2D] = [
	preload("res://_project/items/salvage/sprites/trash_small.png"),
]

@export_group("Loot Pools")
## Shared salvage item sub-pools (4 rarities x salvageable/non-salvageable).
@export var loot_pools: SalvageLootPools = null
## Threat-scaled rarity weight curve.
@export var rarity_weights: SalvageRarityWeights = null

@export_group("Artifacts")
## Shared per-rarity artifact sprite pools + minter.
@export var artifact_pools: ArtifactPools = null
## Fixed artifact chance [0,1]. Constant — does NOT scale with threat.
@export_range(0.0, 1.0, 0.01) var artifact_chance: float = 0.05
## Minimum stage index (0-9) per artifact rarity. No upper bound, so lower rarities stay
## obtainable at higher threats. Defaults: COMMON 0, RARE 3, EPIC 6 (player levels 1, 4, 7).
@export var artifact_min_stage: Dictionary = {
	SalvageItemData.ItemRarity.COMMON: 0,
	SalvageItemData.ItemRarity.RARE: 3,
	SalvageItemData.ItemRarity.EPIC: 6,
}

@export_group("Pity System")
## Constant base probability (0-100) for pulling a salvageable item at pity 0.
@export var salvageable_base_percent: float = 10.0
## Probability increase per consecutive non-salvageable pull (pseudo-pity delta).
@export var salvageable_increment_percent: float = 2.0
## Maximum probability cap for salvageable items.
@export var salvageable_max_percent: float = 20.0

@export_group("Trash")
## Trash probability [0,1] at min threat (level 1) — high early, scales down with threat.
@export_range(0.0, 1.0, 0.01) var trash_chance_start: float = 0.60
## Trash probability [0,1] at max threat (level 10) — low late.
@export_range(0.0, 1.0, 0.01) var trash_chance_end: float = 0.15
@export var trash_sprites: Array[Texture2D] = DEFAULT_TRASH_SPRITES
@export var trash_area: Vector2 = Vector2(64, 64)
@export var trash_hitbox_size: Vector2 = Vector2(36, 36)
@export var trash_weight: float = 0.75

@export_group("Departure")
## Optional looting duration for this pile. Values <= 0 use the minigame default.
@export_range(0.0, 180.0, 0.5, "suffix:s") var departure_duration_override: float = 0.0


## Constant base + accumulated pity delta, clamped to the maximum.
func get_salvageable_chance(pull_count: int) -> float:
	return minf(salvageable_base_percent + (pull_count * salvageable_increment_percent), salvageable_max_percent)


## Roll salvageable (true) vs non-salvageable (false) using the pity chance.
func roll_is_salvageable(pull_count: int) -> bool:
	return randf() * 100.0 < get_salvageable_chance(pull_count)


## Per-pull resolution: trash -> artifact -> salvage rarity -> pity -> uniform item.
## `pull_count` is the magnet's pity counter; the result reports `is_salvageable` so the magnet can
## reset (salvageable) or increment (non-salvageable) it. `tracker` gates the per-run artifact caps.
func roll_pull(threat_level: int, tracker: RunArtifactTracker, pull_count: int) -> Dictionary:
	# 1. Trash (chance scales down as threat rises).
	if not trash_sprites.is_empty() and randf() < _trash_chance_for_threat(threat_level):
		return get_trash_roll_result()

	# 2. Artifact (fixed chance; min-threshold + per-run cap; uniform among available rarities).
	var available_artifacts := available_artifact_rarities(threat_level, tracker)
	if not available_artifacts.is_empty() and randf() < artifact_chance:
		var art_rarity: int = available_artifacts[randi() % available_artifacts.size()]
		var artifact := artifact_pools.make_artifact(art_rarity) if artifact_pools else null
		if artifact != null:
			return {
				"item": artifact,
				"rarity": art_rarity,
				"is_artifact": true,
				"is_salvageable": false,
				"is_trash": false,
			}

	# 3. Salvage item: rarity (curve) -> pity sub-pool -> uniform item.
	if loot_pools == null or rarity_weights == null:
		return get_trash_roll_result()
	var available := _available_salvage_rarities(threat_level)
	var rarity := rarity_weights.roll_rarity(threat_level, available)
	if rarity < 0:
		return get_trash_roll_result()
	var is_salvageable := roll_is_salvageable(pull_count)
	var item := loot_pools.pick_uniform(rarity, is_salvageable, threat_level)
	if item == null:
		return get_trash_roll_result()
	return {
		"item": item,
		"rarity": rarity,
		"is_artifact": false,
		"is_salvageable": is_salvageable,
		"is_trash": false,
	}


## Artifact rarities currently rollable: min-threat met, not yet capped this run, pool has sprites.
## Returns empty when there is no tracker (caps can't be enforced) or no artifact pools.
func available_artifact_rarities(threat_level: int, tracker: RunArtifactTracker) -> Array[int]:
	var out: Array[int] = []
	if tracker == null or artifact_pools == null:
		return out
	for rarity in artifact_min_stage:
		var rarity_int := int(rarity)
		if threat_level >= int(artifact_min_stage[rarity]) \
			and tracker.can_pull(rarity_int) \
			and artifact_pools.has_sprites(rarity_int):
			out.append(rarity_int)
	return out


## Salvage rarities with at least one unlocked item in either sub-pool.
func _available_salvage_rarities(threat_level: int) -> Array[int]:
	var out: Array[int] = []
	if loot_pools == null:
		return out
	for i in range(SalvageRarityWeights.TIER_COUNT):
		if loot_pools.has_available_items(i, threat_level):
			out.append(i)
	return out


## Trash chance for a threat stage index — linear from trash_chance_start (level 1) down to
## trash_chance_end (level 10).
func _trash_chance_for_threat(threat_level: int) -> float:
	var span := maxi(ThreatManager.LEVEL_COUNT - 1, 1)
	var t := clampf(float(threat_level) / float(span), 0.0, 1.0)
	return lerpf(trash_chance_start, trash_chance_end, t)


func get_departure_duration(default_duration: float) -> float:
	if departure_duration_override > 0.0:
		return departure_duration_override
	return default_duration


func get_trash_roll_result() -> Dictionary:
	return {
		"item": null,
		"rarity": -1,
		"is_artifact": false,
		"is_salvageable": false,
		"is_trash": true,
		"trash_texture": _roll_trash_sprite(),
		"trash_area": trash_area,
		"trash_hitbox_size": trash_hitbox_size,
		"trash_weight": trash_weight,
	}


func _roll_trash_sprite() -> Texture2D:
	if trash_sprites.is_empty():
		return null
	return trash_sprites[randi() % trash_sprites.size()]
