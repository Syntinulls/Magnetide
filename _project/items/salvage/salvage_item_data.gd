extends Resource
class_name SalvageItemData

## Standard hitbox size for terminal parts.
const PART_HITBOX_SIZE: Vector2 = Vector2(40, 40)
## Standard sprite size for terminal parts.
const PART_SPRITE_SIZE: Vector2 = Vector2(80, 80)

enum ItemRarity { COMMON, RARE, EPIC, LEGENDARY }
enum ItemKind { SALVAGE, ARTIFACT }

const ITEM_RARITY_WEIGHTS := {
	ItemRarity.COMMON: 20.0,
	ItemRarity.RARE: 10.0,
	ItemRarity.EPIC: 5.0,
	ItemRarity.LEGENDARY: 2.0,
}

const ITEM_RARITY_COLORS := {
	ItemRarity.COMMON: Color("5af03c"),
	ItemRarity.RARE: Color("7ebaff"),
	ItemRarity.EPIC: Color("e17dff"),
	ItemRarity.LEGENDARY: Color("f0d23c"),
}

# =============================================================================
# BASIC INFO
# =============================================================================
@export_group("Basic Info")
## The display name of this salvage item.
@export var item_name: String = ""
## Base monetary value of this item.
@export var value: int = 0
## Intrinsic rarity of this salvage item. Determines its weighted drop chance.
@export var rarity: ItemRarity = ItemRarity.COMMON
## Minimum threat level required for this item to appear in loot tables.
## 0 means always available.
@export var min_threat_level: int = 0

# =============================================================================
# RESEARCH
# =============================================================================
@export_group("Research")
## Broad gameplay category for special handling such as research artifacts.
@export var item_kind: ItemKind = ItemKind.SALVAGE
## Research points awarded when this artifact is successfully researched.
@export var research_point_reward: int = 0

# =============================================================================
# VISUALS
# =============================================================================
@export_group("Visuals")
## Visual sprite for the item.
@export var sprite: Texture2D = null
## In-world size of the item in pixels. Sprite will be scaled to fit this area.
## Terminal parts use PART_SPRITE_SIZE automatically.
@export var area: Vector2 = PART_SPRITE_SIZE

# =============================================================================
# PHYSICS
# =============================================================================
@export_group("Physics")
## Weight of the item in kg. Heavier items accelerate slower.
@export var weight: float = 1.0
## If true, use hitbox_size_override instead of auto-calculated hitbox (half of area).
@export var use_hitbox_override: bool = false
## Custom hitbox size. Only used if use_hitbox_override is true.
@export var hitbox_size_override: Vector2 = Vector2(40, 40)

# =============================================================================
# PARTS (BREAKDOWN)
# =============================================================================
@export_group("Parts")
## Parts recovered when this item is salvaged. Empty means this item is already a terminal part.
@export var parts: Array[SalvagePartEntry] = []

# =============================================================================
# COMPUTED PROPERTIES
# =============================================================================

## Actual hitbox size used for collision.
## Terminal parts: PART_HITBOX_SIZE (40x40)
## Salvageables: hitbox_size_override if use_hitbox_override, else half of area
var actual_hitbox_size: Vector2:
	get:
		if parts.is_empty() and not is_artifact:
			return PART_HITBOX_SIZE
		if use_hitbox_override:
			return hitbox_size_override
		return area * 0.5

## Actual area used for rendering. Terminal parts use constant size.
var actual_area: Vector2:
	get:
		return PART_SPRITE_SIZE if parts.is_empty() and not is_artifact else area

var is_artifact: bool:
	get:
		return item_kind == ItemKind.ARTIFACT


func get_drop_weight() -> float:
	return get_weight_for_rarity(int(rarity))


func get_rarity_color() -> Color:
	return get_color_for_rarity(int(rarity))


static func get_weight_for_rarity(item_rarity: int) -> float:
	return ITEM_RARITY_WEIGHTS.get(item_rarity, ITEM_RARITY_WEIGHTS[ItemRarity.COMMON])


static func get_color_for_rarity(item_rarity: int) -> Color:
	return ITEM_RARITY_COLORS.get(item_rarity, Color.WHITE)
