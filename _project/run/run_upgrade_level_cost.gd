extends Resource
class_name RunUpgradeLevelCost

@export var costs: Array[Resource] = []
## Scrap metal required for this level, on top of the salvage-part costs.
@export var scrap_cost: int = 0


func is_empty() -> bool:
	if scrap_cost > 0:
		return false
	for cost in costs:
		if cost != null:
			return false
	return true


func get_display_text() -> String:
	var parts := PackedStringArray()
	for cost in costs:
		if cost == null:
			continue
		if cost.has_method("get_display_text"):
			parts.append(String(cost.call("get_display_text")))
	if parts.is_empty():
		return "No cost"
	return "\n".join(parts)
