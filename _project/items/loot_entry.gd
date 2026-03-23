extends Resource
class_name LootEntry

## Reference to the item data.
@export var item_data: SalvageItemData = null
## Weight for selection (higher = more likely relative to other entries).
@export var chance: float = 1.0
