extends Resource
class_name SalvageItemData

## Standard hitbox size for components.
const COMPONENT_HITBOX_SIZE: Vector2 = Vector2(40, 40)
## Standard sprite size for components.
const COMPONENT_SPRITE_SIZE: Vector2 = Vector2(80, 80)

# =============================================================================
# BASIC INFO
# =============================================================================
@export_group("Basic Info")
## The display name of this salvage item.
@export var item_name: String = ""
## Base monetary value of this item.
@export var value: int = 0
## Chance weight for pulling this item from a pile (higher = more likely).
@export var chance: float = 1.0
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
