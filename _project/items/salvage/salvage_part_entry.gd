extends Resource
class_name SalvagePartEntry

## The terminal part item produced by salvaging.
@export var item_data: SalvageItemData = null
## Minimum quantity that can be produced for this part entry.
@export var min_quantity: int = 1
## Maximum quantity that can be produced for this part entry.
@export var max_quantity: int = 1


func roll_quantity() -> int:
	var min_count := maxi(min_quantity, 1)
	var max_count := maxi(max_quantity, 1)
	if max_count < min_count:
		var temp := min_count
		min_count = max_count
		max_count = temp
	return randi_range(min_count, max_count)
