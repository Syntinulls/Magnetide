extends Resource
class_name SalvageItemData

## Standard hitbox size for all items.
const STANDARD_HITBOX_SIZE: Vector2 = Vector2(40, 40)
## Standard component sprite size.
const COMPONENT_SPRITE_SIZE: Vector2 = Vector2(80, 80)
## Component hitbox is half of sprite size.
const COMPONENT_HITBOX_SIZE: Vector2 = Vector2(40, 40)
## Density multiplier for weight calculation (kg per pixel² of volume).
const DENSITY: float = 0.001

## The display name of this salvage item.
@export var item_name: String = ""
## Base monetary value of this item.
@export var value: int = 0
## Chance weight for pulling this item from a pile (higher = more likely).
@export var chance: float = 1.0
## Visual sprite for the item.
@export var sprite: Texture2D = null
## In-world size of the item in pixels. Sprite will be scaled to fit this area.
## Ignored if is_component is true (uses COMPONENT_SPRITE_SIZE).
@export var area: Vector2 = COMPONENT_SPRITE_SIZE
## Minimum threat level required for this item to appear in loot tables.
## 0 means always available.
@export var min_threat_level: int = 0

@export_group("Component")
## If true, this item is a component that can be broken down further.
@export var is_component: bool = false
## Items this recycles into when broken down. Only used if is_component is true.
@export var components: Array[SalvageItemData] = []
## Override hitbox size for components. Only used if is_component is true.
@export var hitbox_size_override: Vector2 = COMPONENT_HITBOX_SIZE

## Hitbox size for collision. Components use override, others use standard.
var hitbox_size: Vector2:
	get:
		return hitbox_size_override if is_component else STANDARD_HITBOX_SIZE

## Actual area used for rendering. Components use constant size.
var actual_area: Vector2:
	get:
		return COMPONENT_SPRITE_SIZE if is_component else area

## Weight of the item, calculated from actual area volume * density.
var weight: float:
	get:
		return actual_area.x * actual_area.y * DENSITY
