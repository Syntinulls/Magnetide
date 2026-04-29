extends Resource
class_name AppSaveData

@export var current_run_loadout: RunLoadout = null
@export var storage_entries: Array[Dictionary] = []


func setup(default_run_loadout: RunLoadout) -> void:
	if current_run_loadout == null and default_run_loadout != null:
		current_run_loadout = default_run_loadout.duplicate(true) as RunLoadout
	if current_run_loadout != null:
		current_run_loadout.prepare_for_run()


func get_storage_entries() -> Array[Dictionary]:
	var entries := storage_entries.duplicate(true)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var item_a := a.get("item_data", null) as SalvageItemData
		var item_b := b.get("item_data", null) as SalvageItemData
		var name_a := item_a.item_name if item_a != null else ""
		var name_b := item_b.item_name if item_b != null else ""
		return name_a.to_lower() < name_b.to_lower()
	)
	return entries


func add_storage_entries(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var item_data := entry.get("item_data", null) as SalvageItemData
		var quantity := int(entry.get("quantity", entry.get("count", 0)))
		add_storage_item(item_data, quantity)


func add_storage_item(item_data: SalvageItemData, quantity: int = 1) -> void:
	if item_data == null or quantity <= 0:
		return

	var key := _get_item_key(item_data)
	for index in range(storage_entries.size()):
		var entry := storage_entries[index]
		if str(entry.get("key", "")) != key:
			continue
		entry["quantity"] = int(entry.get("quantity", 0)) + quantity
		storage_entries[index] = entry
		return

	storage_entries.append({
		"key": key,
		"item_data": item_data,
		"quantity": quantity,
	})


func can_pay_costs(costs: Array[Resource]) -> bool:
	for cost in costs:
		if cost == null:
			continue
		var item_data := cost.get("item_data") as SalvageItemData
		var quantity := int(cost.get("quantity"))
		if item_data == null:
			continue
		if get_storage_quantity(item_data) < quantity:
			return false
	return true


func spend_costs(costs: Array[Resource]) -> bool:
	if not can_pay_costs(costs):
		return false

	for cost in costs:
		if cost == null:
			continue
		var item_data := cost.get("item_data") as SalvageItemData
		var quantity := int(cost.get("quantity"))
		if item_data != null and quantity > 0:
			_remove_storage_item(item_data, quantity)
	return true


func spend_upgrade_cost(upgrade: Resource) -> bool:
	if upgrade == null:
		return false
	if bool(upgrade.call("is_maxed")):
		return false

	var level_cost := upgrade.call("get_next_level_cost") as Resource
	if level_cost == null:
		return true

	var costs := level_cost.get("costs") as Array
	return spend_costs(_to_resource_array(costs))


func get_storage_quantity(item_data: SalvageItemData) -> int:
	if item_data == null:
		return 0

	var key := _get_item_key(item_data)
	for entry in storage_entries:
		if str(entry.get("key", "")) == key:
			return int(entry.get("quantity", 0))
	return 0


func _remove_storage_item(item_data: SalvageItemData, quantity: int) -> void:
	var key := _get_item_key(item_data)
	for index in range(storage_entries.size()):
		var entry := storage_entries[index]
		if str(entry.get("key", "")) != key:
			continue
		var remaining := int(entry.get("quantity", 0)) - quantity
		if remaining <= 0:
			storage_entries.remove_at(index)
		else:
			entry["quantity"] = remaining
			storage_entries[index] = entry
		return


func _to_resource_array(values: Array) -> Array[Resource]:
	var resources: Array[Resource] = []
	for value in values:
		if value is Resource:
			resources.append(value as Resource)
	return resources


func _get_item_key(item_data: SalvageItemData) -> String:
	if item_data == null:
		return ""
	var key := item_data.resource_path
	if key.is_empty():
		key = item_data.item_name
	return key
