extends Resource
class_name RunLoadout

const DefaultWeaponData := preload("res://_project/items/equipment/rifle/rifle.tres")
const DefaultMagnetToolData := preload("res://_project/items/equipment/magnet_gun.tres")
const RunUpgradeScript := preload("res://_project/run/run_upgrade.gd")
const RunUpgradeLevelCostScript := preload("res://_project/run/run_upgrade_level_cost.gd")
const UpgradeableItemStateScript := preload("res://_project/run/upgradeable_item_state.gd")
const UpgradeSlotStateScript := preload("res://_project/run/upgrade_slot_state.gd")
const SalvageItemCostScript := preload("res://_project/items/salvage/salvage_item_cost.gd")
const CostGearData := preload("res://_project/items/salvage/resources/gear.tres")
const CostMagnetData := preload("res://_project/items/salvage/resources/magnet.tres")
const CostBatteryData := preload("res://_project/items/salvage/resources/battery.tres")
const CostSpringData := preload("res://_project/items/salvage/resources/spring.tres")
const CostProcessorData := preload("res://_project/items/salvage/resources/processor.tres")
const CostCircuitryData := preload("res://_project/items/salvage/resources/circuitry.tres")
const CostPowerCoreData := preload("res://_project/items/salvage/resources/power_core.tres")
const DEFAULT_PLAYER_MAX_SHIELD_HITS := 0.0
const UNLOCKED_PLAYER_BASE_SHIELD_HITS := 2.0
const DEFAULT_PLAYER_SHIELD_SECONDS_PER_HIT := 1.0
const PLAYER_SHIELD_SLOT_ID := &"player_shield"

@export_group("Ship")
@export var ship_storage_area_size: Vector2 = Vector2(400, 250)
@export var ship_storage_area_position: Vector2 = Vector2(0, -95)
@export var ship_storage_marker_height: float = 24.0
@export var ship_storage_max_weight: float = 100.0
@export var ship_max_health: float = 250.0

@export_group("Magnet")
@export var magnet_pull_frequency: float = 2.5
@export var magnet_pull_batch_size: int = 1
@export var magnet_hold_capacity: int = 10
@export var magnet_pull_base_speed: float = 200.0
@export var magnet_pull_max_speed: float = 1500.0
@export var magnet_pull_ramp_time: float = 0.6
@export var magnet_surface_slow_speed: float = 15.0
@export var magnet_surface_dwell_time: float = 1.2
@export var magnet_breakaway_ramp_time: float = 0.3
@export var magnet_breakaway_max_speed: float = 2000.0
@export var magnet_threat_penalty: float = 10.0
@export var magnet_width: float = 264.0
@export var magnet_max_health: float = 150.0

@export_group("Player")
@export var player_speed: float = 400.0
@export var player_jump_velocity: float = -600.0
@export var player_gravity: float = 1600.0
@export var player_max_health: float = 100.0
@export var player_max_shield: float = 0.0
@export var player_shield_recharge_delay: float = 6.0
@export var player_shield_recharge_duration: float = 1.0
@export var player_shield_break_recharge_delay: float = 10.0

@export_group("Equipment")
@export var equipped_weapon: WeaponData = null
@export var equipped_magnet_tool: MagnetToolData = null
@export var player_equipment: Array[EquipmentData] = []
@export var player_selected_equipment_index: int = 0
@export var player_augments: Array[AugmentData] = []
@export var ship_augments: Array[AugmentData] = []
@export var magnet_augments: Array[AugmentData] = []

@export_group("Upgrade State")
@export var equipment_upgrades: Array[Resource] = []
@export var player_upgrades: Array[Resource] = []
@export var ship_upgrades: Array[Resource] = []
@export var magnet_upgrades: Array[Resource] = []
@export var upgrade_base_values: Dictionary = {}
@export var item_states: Array[Resource] = []
@export var slot_states: Array[Resource] = []


func equip_weapon(weapon_data: WeaponData) -> void:
	if weapon_data == null:
		return
	equipped_weapon = weapon_data
	player_selected_equipment_index = 0
	prepare_for_run()


func increase_upgrade(upgrade_id: StringName, amount: int = 1) -> bool:
	ensure_upgrade_state()
	var upgrade := get_upgrade(upgrade_id)
	if upgrade == null:
		return false

	var changed := bool(upgrade.call("increase_level", amount))
	if changed:
		prepare_for_run()
	return changed


func get_upgrade(upgrade_id: StringName) -> Resource:
	for upgrade in _get_all_upgrades():
		if upgrade != null and upgrade.get("upgrade_id") == upgrade_id:
			return upgrade
	return null


func prepare_for_run() -> void:
	ensure_upgrade_state()
	_apply_loadout_upgrades()
	_apply_augment_loadout_modifiers()
	player_equipment = _build_runtime_equipment()
	if player_equipment.is_empty():
		player_selected_equipment_index = 0
	else:
		player_selected_equipment_index = clampi(player_selected_equipment_index, 0, player_equipment.size() - 1)


func ensure_upgrade_state() -> void:
	_ensure_equipped_defaults()
	_migrate_player_shield_defaults()
	_ensure_upgrade(equipment_upgrades, _create_upgrade(
		&"weapon_damage",
		"Weapon Damage",
		RunUpgradeScript.TargetScope.EQUIPPED_WEAPON,
		&"damage",
		0.05,
		RunUpgradeScript.IncreaseMode.PERCENT_OF_BASE,
		_create_default_level_costs(CostGearData, CostCircuitryData)
	))
	_ensure_upgrade(equipment_upgrades, _create_upgrade(
		&"magnet_tool_pull",
		"Magnet Tool Pull",
		RunUpgradeScript.TargetScope.EQUIPPED_MAGNET_TOOL,
		&"pull_max_speed",
		0.05,
		RunUpgradeScript.IncreaseMode.PERCENT_OF_BASE,
		_create_default_level_costs(CostMagnetData, CostBatteryData)
	))
	_ensure_upgrade(player_upgrades, _create_upgrade(
		&"player_health",
		"Player Health",
		RunUpgradeScript.TargetScope.LOADOUT,
		&"player_max_health",
		0.05,
		RunUpgradeScript.IncreaseMode.PERCENT_OF_BASE,
		_create_default_level_costs(CostSpringData, CostProcessorData)
	))
	_ensure_upgrade(player_upgrades, _create_upgrade(
		&"player_shield",
		"Player Shield",
		RunUpgradeScript.TargetScope.LOADOUT,
		&"player_max_shield",
		1.0,
		RunUpgradeScript.IncreaseMode.FLAT,
		_create_default_level_costs(CostBatteryData, CostPowerCoreData),
		[1.0, 1.0, 1.0, 1.0, 1.0]
	))
	_ensure_upgrade(ship_upgrades, _create_upgrade(
		&"ship_hull",
		"Ship Hull",
		RunUpgradeScript.TargetScope.LOADOUT,
		&"ship_max_health",
		0.05,
		RunUpgradeScript.IncreaseMode.PERCENT_OF_BASE,
		_create_default_level_costs(CostGearData, CostSpringData)
	))
	_ensure_upgrade(ship_upgrades, _create_upgrade(
		&"ship_storage",
		"Ship Storage",
		RunUpgradeScript.TargetScope.LOADOUT,
		&"ship_storage_max_weight",
		0.05,
		RunUpgradeScript.IncreaseMode.PERCENT_OF_BASE,
		_create_default_level_costs(CostGearData, CostMagnetData)
	))
	_ensure_upgrade(magnet_upgrades, _create_upgrade(
		&"ship_magnet_capacity",
		"Ship Magnet Capacity",
		RunUpgradeScript.TargetScope.LOADOUT,
		&"magnet_hold_capacity",
		1.0,
		RunUpgradeScript.IncreaseMode.FLAT,
		_create_default_level_costs(CostMagnetData, CostProcessorData)
	))
	_ensure_upgrade(magnet_upgrades, _create_upgrade(
		&"ship_magnet_health",
		"Ship Magnet Health",
		RunUpgradeScript.TargetScope.LOADOUT,
		&"magnet_max_health",
		0.05,
		RunUpgradeScript.IncreaseMode.PERCENT_OF_BASE,
		_create_default_level_costs(CostBatteryData, CostCircuitryData)
	))
	_migrate_player_shield_defaults()


func get_upgraded_weapon_preview(weapon_data: WeaponData = null) -> WeaponData:
	var source := weapon_data if weapon_data != null else equipped_weapon
	return get_upgraded_equipment_preview(source, RunUpgradeScript.TargetScope.EQUIPPED_WEAPON) as WeaponData


func get_upgraded_magnet_tool_preview(tool_data: MagnetToolData = null) -> MagnetToolData:
	var source := tool_data if tool_data != null else equipped_magnet_tool
	return get_upgraded_equipment_preview(source, RunUpgradeScript.TargetScope.EQUIPPED_MAGNET_TOOL) as MagnetToolData


func get_upgraded_equipment_preview(equipment_data: EquipmentData, target_scope: int) -> EquipmentData:
	if equipment_data == null:
		return null

	var preview := equipment_data.duplicate(true) as EquipmentData
	if preview == null:
		return equipment_data

	for upgrade in equipment_upgrades:
		_apply_upgrade_to_resource(preview, equipment_data, upgrade, target_scope)
	return preview


func apply_to_level(level: Node) -> void:
	if level == null:
		return

	prepare_for_run()

	var ship := level.get_node_or_null("Ship") as Ship
	if ship:
		ship.apply_run_loadout(self)

	var magnet := ship.get_node_or_null("Magnet") as Magnet if ship else null
	if magnet:
		magnet.apply_run_loadout(self)

	var player := ship.get_node_or_null("Player") as Player if ship else null
	if player:
		player.apply_run_loadout(self)


func get_equipped_augments() -> Array[AugmentData]:
	var augments: Array[AugmentData] = []
	for augment in player_augments:
		if augment != null:
			augments.append(augment)
	for augment in ship_augments:
		if augment != null:
			augments.append(augment)
	for augment in magnet_augments:
		if augment != null:
			augments.append(augment)
	return augments


func get_item_state(item_id: StringName) -> Resource:
	for state in item_states:
		if state != null and state.get("item_id") == item_id:
			return state
	return null


func get_or_create_item_state(item_id: StringName) -> Resource:
	if item_id == &"":
		return null
	var state := get_item_state(item_id)
	if state != null:
		return state
	state = UpgradeableItemStateScript.new()
	state.set("item_id", item_id)
	state.set("current_level", 0)
	state.set("unlocked", false)
	item_states.append(state)
	return state


func get_item_level(item_data: Resource) -> int:
	if item_data == null or not _has_property(item_data, "item_id"):
		return 0
	var item_id := item_data.get("item_id") as StringName
	var state := get_item_state(item_id)
	if state != null and _has_property(state, "current_level"):
		return int(state.get("current_level"))
	return 0


func is_item_unlocked(item_data: Resource, default_unlocked: bool = false) -> bool:
	if item_data == null or not _has_property(item_data, "item_id"):
		return default_unlocked
	var item_id := item_data.get("item_id") as StringName
	var state := get_item_state(item_id)
	if state == null or not _has_property(state, "unlocked"):
		return default_unlocked
	return bool(state.get("unlocked"))


func set_item_unlocked(item_data: Resource, unlocked: bool = true) -> void:
	if item_data == null or not _has_property(item_data, "item_id"):
		return
	var item_id := item_data.get("item_id") as StringName
	var state := get_or_create_item_state(item_id)
	if state != null and _has_property(state, "unlocked"):
		state.set("unlocked", unlocked)


func get_slot_state(slot_id: StringName) -> Resource:
	for state in slot_states:
		if state != null and state.get("slot_id") == slot_id:
			return state
	return null


func get_or_create_slot_state(slot_id: StringName) -> Resource:
	if slot_id == &"":
		return null
	var state := get_slot_state(slot_id)
	if state != null:
		return state
	state = UpgradeSlotStateScript.new()
	state.set("slot_id", slot_id)
	state.set("equipped_item_id", &"")
	state.set("unlocked", false)
	slot_states.append(state)
	return state


func is_slot_unlocked(slot_id: StringName, default_unlocked: bool = false) -> bool:
	var state := get_slot_state(slot_id)
	if state == null or not _has_property(state, "unlocked"):
		return default_unlocked
	return bool(state.get("unlocked"))


func set_slot_unlocked(slot_id: StringName, unlocked: bool = true) -> void:
	var state := get_or_create_slot_state(slot_id)
	if state != null and _has_property(state, "unlocked"):
		state.set("unlocked", unlocked)


func equip_player_augment(slot_index: int, augment_data: AugmentData) -> void:
	if slot_index < 0:
		return
	while player_augments.size() <= slot_index:
		player_augments.append(null)

	if augment_data != null:
		for index in player_augments.size():
			if index != slot_index and _same_upgradeable_item(player_augments[index], augment_data):
				player_augments[index] = null

	player_augments[slot_index] = augment_data


func _same_upgradeable_item(left: Resource, right: Resource) -> bool:
	if left == null or right == null:
		return false
	if left == right:
		return true
	if _has_property(left, "item_id") and _has_property(right, "item_id"):
		return left.get("item_id") == right.get("item_id")
	return false


func _ensure_equipped_defaults() -> void:
	if equipped_weapon == null:
		for equipment_data in player_equipment:
			if equipment_data is WeaponData:
				equipped_weapon = equipment_data as WeaponData
				break
	if equipped_weapon == null:
		equipped_weapon = DefaultWeaponData

	if equipped_magnet_tool == null:
		for equipment_data in player_equipment:
			if equipment_data is MagnetToolData:
				equipped_magnet_tool = equipment_data as MagnetToolData
				break
	if equipped_magnet_tool == null:
		equipped_magnet_tool = DefaultMagnetToolData


func _migrate_player_shield_defaults() -> void:
	if player_max_shield < 0.0 or player_max_shield > 10.0:
		player_max_shield = DEFAULT_PLAYER_MAX_SHIELD_HITS
	if upgrade_base_values.has("player_max_shield"):
		var shield_base := float(upgrade_base_values["player_max_shield"])
		if shield_base < 0.0 or shield_base > 10.0:
			upgrade_base_values["player_max_shield"] = DEFAULT_PLAYER_MAX_SHIELD_HITS
	var shield_unlocked := is_slot_unlocked(PLAYER_SHIELD_SLOT_ID, false)
	var shield_base := UNLOCKED_PLAYER_BASE_SHIELD_HITS if shield_unlocked else DEFAULT_PLAYER_MAX_SHIELD_HITS
	player_max_shield = shield_base
	upgrade_base_values["player_max_shield"] = shield_base
	if is_equal_approx(player_shield_recharge_duration, 4.0):
		player_shield_recharge_duration = DEFAULT_PLAYER_SHIELD_SECONDS_PER_HIT


func _build_runtime_equipment() -> Array[EquipmentData]:
	var runtime_equipment: Array[EquipmentData] = []
	var weapon := get_upgraded_weapon_preview()
	var magnet_tool := get_upgraded_magnet_tool_preview()
	if weapon:
		runtime_equipment.append(weapon)
	if magnet_tool:
		runtime_equipment.append(magnet_tool)
	return runtime_equipment


func _apply_augment_loadout_modifiers() -> void:
	for augment in get_equipped_augments():
		if augment == null or augment.behavior == null:
			continue
		augment.behavior.apply_to_loadout(self, get_item_level(augment))


func _apply_loadout_upgrades() -> void:
	var target_properties := {}
	for upgrade in _get_all_upgrades():
		if upgrade == null:
			continue
		if upgrade.get("target_scope") != RunUpgradeScript.TargetScope.LOADOUT:
			continue
		if String(upgrade.get("target_property")).is_empty():
			continue
		var property_name := String(upgrade.get("target_property"))
		if not _has_property(self, property_name):
			continue
		if not upgrade_base_values.has(property_name):
			upgrade_base_values[property_name] = get(property_name)
		target_properties[property_name] = true

	for property_name in target_properties.keys():
		set(property_name, upgrade_base_values[property_name])

	for upgrade in _get_all_upgrades():
		if upgrade == null or upgrade.get("target_scope") != RunUpgradeScript.TargetScope.LOADOUT:
			continue
		var property_name := String(upgrade.get("target_property"))
		if not target_properties.has(property_name):
			continue
		var base_value: Variant = upgrade_base_values[property_name]
		var delta := float(upgrade.call("get_delta_from_base", base_value))
		_add_numeric_delta(property_name, base_value, delta)


func _apply_upgrade_to_resource(
	target_resource: Resource,
	base_resource: Resource,
	upgrade: Resource,
	target_scope: int
) -> void:
	if target_resource == null or base_resource == null or upgrade == null:
		return
	if upgrade.get("target_scope") != target_scope:
		return
	if String(upgrade.get("target_property")).is_empty():
		return

	var property_name := String(upgrade.get("target_property"))
	if not _has_property(base_resource, property_name) or not _has_property(target_resource, property_name):
		return

	var base_value: Variant = base_resource.get(property_name)
	var delta := float(upgrade.call("get_delta_from_base", base_value))
	var current_value: Variant = target_resource.get(property_name)
	if typeof(current_value) != TYPE_INT and typeof(current_value) != TYPE_FLOAT:
		return

	var upgraded_value := float(current_value) + delta
	if typeof(base_value) == TYPE_INT:
		target_resource.set(property_name, int(round(upgraded_value)))
	else:
		target_resource.set(property_name, upgraded_value)


func _add_numeric_delta(property_name: String, base_value: Variant, delta: float) -> void:
	var current_value: Variant = get(property_name)
	if typeof(current_value) != TYPE_INT and typeof(current_value) != TYPE_FLOAT:
		return

	var upgraded_value := float(current_value) + delta
	if typeof(base_value) == TYPE_INT:
		set(property_name, int(round(upgraded_value)))
	else:
		set(property_name, upgraded_value)


func _get_all_upgrades() -> Array[Resource]:
	var all_upgrades: Array[Resource] = []
	all_upgrades.append_array(equipment_upgrades)
	all_upgrades.append_array(player_upgrades)
	all_upgrades.append_array(ship_upgrades)
	all_upgrades.append_array(magnet_upgrades)
	return all_upgrades


func _ensure_upgrade(upgrade_array: Array[Resource], default_upgrade: Resource) -> void:
	if default_upgrade == null:
		return
	for upgrade in upgrade_array:
		if upgrade != null and upgrade.get("upgrade_id") == default_upgrade.get("upgrade_id"):
			_sync_upgrade_definition(upgrade, default_upgrade)
			return
	upgrade_array.append(default_upgrade)


func _create_upgrade(
	upgrade_id: StringName,
	display_name: String,
	target_scope: int,
	target_property: StringName,
	amount_per_level: float,
	increase_mode: int,
	upgrade_costs: Array[Resource],
	level_amounts: Array[float] = []
) -> Resource:
	var upgrade := RunUpgradeScript.new()
	upgrade.upgrade_id = upgrade_id
	upgrade.display_name = display_name
	upgrade.target_scope = target_scope
	upgrade.target_property = target_property
	upgrade.amount_per_level = amount_per_level
	upgrade.level_amounts = level_amounts.duplicate()
	upgrade.increase_mode = increase_mode
	upgrade.max_level = 5
	upgrade.upgrade_costs = upgrade_costs.duplicate()
	return upgrade


func _sync_upgrade_definition(upgrade: Resource, default_upgrade: Resource) -> void:
	var current_level := int(upgrade.get("current_level"))
	upgrade.set("display_name", default_upgrade.get("display_name"))
	upgrade.set("target_scope", default_upgrade.get("target_scope"))
	upgrade.set("target_property", default_upgrade.get("target_property"))
	upgrade.set("amount_per_level", default_upgrade.get("amount_per_level"))
	upgrade.set("level_amounts", default_upgrade.get("level_amounts"))
	upgrade.set("increase_mode", default_upgrade.get("increase_mode"))
	upgrade.set("max_level", default_upgrade.get("max_level"))
	upgrade.set("upgrade_costs", default_upgrade.get("upgrade_costs"))
	upgrade.set("current_level", current_level)


func _create_default_level_costs(primary_item: SalvageItemData, secondary_item: SalvageItemData = null) -> Array[Resource]:
	var level_costs: Array[Resource] = []
	for level_index in range(5):
		var level_cost := RunUpgradeLevelCostScript.new()
		level_cost.costs.append(_create_item_cost(primary_item, level_index + 1))
		if secondary_item != null and level_index >= 1:
			level_cost.costs.append(_create_item_cost(secondary_item, level_index))
		level_costs.append(level_cost)
	return level_costs


func _create_item_cost(item_data: SalvageItemData, quantity: int) -> Resource:
	var item_cost := SalvageItemCostScript.new()
	item_cost.item_data = item_data
	item_cost.quantity = quantity
	return item_cost


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
