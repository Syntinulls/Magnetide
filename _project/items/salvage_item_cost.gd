extends Resource
class_name SalvageItemCost

@export var item_data: SalvageItemData = null
@export var quantity: int = 1:
	set(value):
		quantity = maxi(value, 1)


func get_display_text() -> String:
	var item_name := "Unknown"
	if item_data != null and not item_data.item_name.is_empty():
		item_name = item_data.item_name
	return "x%d %s" % [quantity, item_name]
