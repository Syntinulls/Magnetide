extends Resource
class_name SalvageItemData

## Standard hitbox size for components.
const COMPONENT_HITBOX_SIZE: Vector2 = Vector2(40, 40)
## Standard sprite size for components.
const COMPONENT_SPRITE_SIZE: Vector2 = Vector2(80, 80)

enum ItemRarity { COMMON, RARE, EPIC, LEGENDARY }

const ITEM_RARITY_WEIGHTS := {
	ItemRarity.COMMON: 20.0,
	ItemRarity.RARE: 10.0,
	ItemRarity.EPIC: 5.0,
	ItemRarity.LEGENDARY: 2.0,
}

const ITEM_RARITY_COLORS := {
	ItemRarity.COMMON: Color(0.0, 0.8, 0.0),
	ItemRarity.RARE: Color(0.2, 0.4, 1.0),
	ItemRarity.EPIC: Color(0.6, 0.2, 0.8),
	ItemRarity.LEGENDARY: Color(1.0, 0.85, 0.0),
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
# VISUALS
# =============================================================================
@export_group("Visuals")
## Visual sprite for the item.
@export var sprite: Texture2D = null
## In-world size of the item in pixels. Sprite will be scaled to fit this area.
## Ignored if is_component is true (uses COMPONENT_SPRITE_SIZE).
@export var area: Vector2 = COMPONENT_SPRITE_SIZE

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
# COMPONENT (BREAKDOWN)
# =============================================================================
@export_group("Component")
## If true, this item is a component that can be broken down further.
@export var is_component: bool = false
## Items this recycles into when broken down. Only used if is_component is true.
@export var components: Array[SalvageItemData] = []

# =============================================================================
# COMPUTED PROPERTIES
# =============================================================================

## Actual hitbox size used for collision.
## Components: COMPONENT_HITBOX_SIZE (40x40)
## Salvageables: hitbox_size_override if use_hitbox_override, else half of area
var actual_hitbox_size: Vector2:
	get:
		if is_component:
			return COMPONENT_HITBOX_SIZE
		if use_hitbox_override:
			return hitbox_size_override
		return area * 0.5

## Actual area used for rendering. Components use constant size.
var actual_area: Vector2:
	get:
		return COMPONENT_SPRITE_SIZE if is_component else area


func get_drop_weight() -> float:
	return get_weight_for_rarity(int(rarity))


func get_rarity_color() -> Color:
	return get_color_for_rarity(int(rarity))


static func get_weight_for_rarity(item_rarity: int) -> float:
	return ITEM_RARITY_WEIGHTS.get(item_rarity, ITEM_RARITY_WEIGHTS[ItemRarity.COMMON])


static func get_color_for_rarity(item_rarity: int) -> Color:
	return ITEM_RARITY_COLORS.get(item_rarity, Color.WHITE)
