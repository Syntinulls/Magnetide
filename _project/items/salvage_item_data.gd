extends Resource
class_name SalvageItemData

## The display name of this salvage item.
@export var item_name: String = ""
## Base monetary value of this item.
@export var value: int = 0
## Items this recycles into when broken down.
@export var components: Array[SalvageItemData] = []
## Chance weight for pulling this item from a pile (higher = more likely).
@export var chance: float = 1.0
## Rarity tier of this item.
@export var rarity: SalvagePile.Rarity = SalvagePile.Rarity.COMMON
## Visual sprite for the item.
@export var sprite: Texture2D = null
## In-world size of the item in pixels. Sprite will be scaled to fit this area.
@export var area: Vector2 = Vector2(50, 50)
## Hitbox size for collision, smaller than area to account for sprite padding.
@export var hitbox_size: Vector2 = Vector2(40, 40)

## Density multiplier for weight calculation (kg per pixel² of volume).
const DENSITY: float = 0.001

## Weight of the item, calculated from area volume * density.
var weight: float:
	get:
		return area.x * area.y * DENSITY
## Minimum threat level required for this item to appear in loot tables.
## 0 means always available.
@export var min_threat_level: int = 0
