extends Resource
class_name AppSaveData

const SAVE_PATH := "user://magnetide_save.tres"

@export var current_run_loadout: RunLoadout = null
@export var storage_entries: Array[Dictionary] = []


static func load_or_create(default_run_loadout: RunLoadout) -> AppSaveData:
	var save_data: AppSaveData = null
	if ResourceLoader.exists(SAVE_PATH):
		save_data = ResourceLoader.load(SAVE_PATH) as AppSaveData
	if save_data == null:
		save_data = AppSaveData.new()
	save_data.setup(default_run_loadout)
	return save_data


func setup(default_run_loadout: RunLoadout, reset: bool = false) -> void:
	if reset:
		storage_entries.clear()
		current_run_loadout = null
	if current_run_loadout == null and default_run_loadout != null:
		current_run_loadout = default_run_loadout.duplicate(true) as RunLoadout
	if current_run_loadout != null:
		current_run_loadout.prepare_for_run()


func reset_to_default(default_run_loadout: RunLoadout) -> void:
	setup(default_run_loadout, true)
	save_to_disk()


func save_to_disk() -> void:
	var error := ResourceSaver.save(self, SAVE_PATH)
	if error != OK:
		push_error("AppSaveData: Failed to save single-slot data to %s. Error: %s" % [SAVE_PATH, error])


func has_continue_data(default_run_loadout: RunLoadout) -> bool:
	return not is_default(default_run_loadout)


func is_default(default_run_loadout: RunLoadout) -> bool:
	if not storage_entries.is_empty():
		return false
	if current_run_loadout == null:
		return true
	if default_run_loadout == null:
		return false

	var default_copy := default_run_loadout.duplicate(true) as RunLoadout
	if default_copy:
		default_copy.prepare_for_run()
	return _loadout_state_key(current_run_loadout) == _loadout_state_key(default_copy)


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
	save_to_disk()


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
	save_to_disk()


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
	save_to_disk()
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


func _loadout_state_key(loadout: RunLoadout) -> String:
	if loadout == null:
		return ""
	loadout.prepare_for_run()
	var parts := PackedStringArray()
	parts.append(_resource_key(loadout.equipped_weapon))
	parts.append(_resource_key(loadout.equipped_magnet_tool))
	for upgrade in _get_loadout_upgrades(loadout):
		if upgrade == null:
			continue
		parts.append("%s:%d" % [
			String(upgrade.get("upgrade_id")),
			int(upgrade.get("current_level")),
		])
	return "|".join(parts)


func _get_loadout_upgrades(loadout: RunLoadout) -> Array[Resource]:
	var upgrades: Array[Resource] = []
	upgrades.append_array(loadout.equipment_upgrades)
	upgrades.append_array(loadout.player_upgrades)
	upgrades.append_array(loadout.ship_upgrades)
	upgrades.append_array(loadout.magnet_upgrades)
	upgrades.sort_custom(func(a: Resource, b: Resource) -> bool:
		return String(a.get("upgrade_id")) < String(b.get("upgrade_id"))
	)
	return upgrades


func _resource_key(resource: Resource) -> String:
	if resource == null:
		return ""
	if not resource.resource_path.is_empty():
		return resource.resource_path
	return resource.resource_name
