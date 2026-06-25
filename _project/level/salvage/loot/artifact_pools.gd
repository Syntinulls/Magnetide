extends Resource
class_name ArtifactPools

## Shared artifact sprite pools (Step 3 of the salvage loot & artifact rework —
## see specs/salvage_loot_pool_system_spec.md).
##
## Artifacts are NOT authored as individual items. Like trash, they are a GENERIC item with sprite
## variations: each artifact rarity (common/rare/epic) owns a shared pool of sprites. When the
## artifact roll picks a rarity, a generic "Unknown Artifact" of that rarity is minted with a random
## sprite from that rarity's pool. Assign the SAME instance to every pile so piles share artifacts.

const ARTIFACT_NAME: String = "Unknown Artifact"

@export_group("Common")
@export var common_sprites: Array[Texture2D] = []
@export var common_research_reward: int = 1
@export_group("Rare")
@export var rare_sprites: Array[Texture2D] = []
@export var rare_research_reward: int = 1
@export_group("Epic")
@export var epic_sprites: Array[Texture2D] = []
@export var epic_research_reward: int = 1

@export_group("Shared Physics / Visuals")
## In-world size of the minted artifact (sprite scaled to fit).
@export var area: Vector2 = Vector2(80, 80)
@export var use_hitbox_override: bool = false
@export var hitbox_size_override: Vector2 = Vector2(40, 40)
@export var weight: float = 1.0


func get_sprites(rarity: int) -> Array[Texture2D]:
	match rarity:
		SalvageItemData.ItemRarity.COMMON:
			return common_sprites
		SalvageItemData.ItemRarity.RARE:
			return rare_sprites
		SalvageItemData.ItemRarity.EPIC:
			return epic_sprites
	return common_sprites


func get_research_reward(rarity: int) -> int:
	match rarity:
		SalvageItemData.ItemRarity.COMMON:
			return common_research_reward
		SalvageItemData.ItemRarity.RARE:
			return rare_research_reward
		SalvageItemData.ItemRarity.EPIC:
			return epic_research_reward
	return common_research_reward


## True if this artifact rarity has at least one sprite to mint from.
func has_sprites(rarity: int) -> bool:
	return not get_sprites(rarity).is_empty()


## Mint a generic artifact item of the given rarity with a random sprite from that rarity's pool.
## Returns a freshly built SalvageItemData (ItemKind.ARTIFACT), or null if the pool has no sprites.
func make_artifact(rarity: int) -> SalvageItemData:
	var sprites := get_sprites(rarity)
	if sprites.is_empty():
		return null
	var data := SalvageItemData.new()
	data.item_kind = SalvageItemData.ItemKind.ARTIFACT
	data.rarity = rarity
	data.item_name = ARTIFACT_NAME
	data.sprite = sprites[randi() % sprites.size()]
	data.area = area
	data.weight = weight
	data.use_hitbox_override = use_hitbox_override
	data.hitbox_size_override = hitbox_size_override
	data.research_point_reward = get_research_reward(rarity)
	return data
