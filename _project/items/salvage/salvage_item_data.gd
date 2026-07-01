extends Resource
class_name SalvageItemData

## Standard hitbox size for terminal parts.
const PART_HITBOX_SIZE: Vector2 = Vector2(40, 40)
## Standard sprite size for terminal parts.
const PART_SPRITE_SIZE: Vector2 = Vector2(80, 80)

enum ItemRarity { COMMON, RARE, EPIC, LEGENDARY }
enum ItemKind { SALVAGE, ARTIFACT }
## Physical heft class. Replaces the old free-float weight: each class maps to a
## predetermined internal weight and physics profile (see WEIGHT_CLASS_PROFILES).
enum WeightClass { LIGHT, MEDIUM, HEAVY, VERY_HEAVY }

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

## Predetermined per-weight-class physics profile. Each class drives:
## - weight: internal mass float (pull velocity/acceleration + dwell scaling;
##   higher = slower to accelerate, longer to break free from a pile)
## - gravity_scale: multiplier on drop/in-storage gravity (higher = falls harder)
## - damp_scale: multiplier on in-storage linear/angular damping (deceleration;
##   higher = settles/stops faster once resting)
const WEIGHT_CLASS_PROFILES := {
	WeightClass.LIGHT: { "weight": 0.5, "gravity_scale": 0.8, "damp_scale": 0.85 },
	WeightClass.MEDIUM: { "weight": 1.0, "gravity_scale": 1.0, "damp_scale": 1.0 },
	WeightClass.HEAVY: { "weight": 2.0, "gravity_scale": 1.35, "damp_scale": 1.25 },
	WeightClass.VERY_HEAVY: { "weight": 4.0, "gravity_scale": 1.75, "damp_scale": 1.5 },
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
## Physical heft class. Drives pull velocity/acceleration/deceleration and
## in-storage gravity via a predetermined profile (WEIGHT_CLASS_PROFILES). The
## internal `weight` float is derived from this, not authored directly.
@export var weight_class: WeightClass = WeightClass.MEDIUM
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

## A terminal "part": a salvage item that doesn't break down further and isn't an
## artifact. Only parts are stackable; salvageables (which have parts) are not.
var is_part: bool:
	get:
		return parts.is_empty() and not is_artifact

## Internal weight float (hidden), derived from the predetermined weight class.
## Kept as a read-only property so existing physics code that reads `weight`
## continues to work unchanged.
var weight: float:
	get:
		return get_class_weight()


func get_class_weight() -> float:
	return float(_weight_profile().get("weight", 1.0))


## Multiplier applied to an item's drop/in-storage gravity_scale.
func get_gravity_scale() -> float:
	return float(_weight_profile().get("gravity_scale", 1.0))


## Multiplier applied to an item's in-storage linear/angular damping.
func get_damp_scale() -> float:
	return float(_weight_profile().get("damp_scale", 1.0))


func _weight_profile() -> Dictionary:
	return WEIGHT_CLASS_PROFILES.get(weight_class, WEIGHT_CLASS_PROFILES[WeightClass.MEDIUM])


func get_drop_weight() -> float:
	return get_weight_for_rarity(int(rarity))


func get_rarity_color() -> Color:
	return get_color_for_rarity(int(rarity))


static func get_weight_for_rarity(item_rarity: int) -> float:
	return ITEM_RARITY_WEIGHTS.get(item_rarity, ITEM_RARITY_WEIGHTS[ItemRarity.COMMON])


static func get_color_for_rarity(item_rarity: int) -> Color:
	return ITEM_RARITY_COLORS.get(item_rarity, Color.WHITE)
