extends Resource
class_name RunLoadout

const DefaultWeaponData := preload("res://_project/items/weapons/pistol/pistol.tres")
const DefaultMagnetToolData := preload("res://_project/items/magnet_tool/magnet_gun.tres")
const UpgradeableItemStateScript := preload("res://_project/run/upgradeable_item_state.gd")
const UpgradeSlotStateScript := preload("res://_project/run/upgrade_slot_state.gd")
## Static loadout-stat items (data-driven; see specs/project_organization.md §9): each is a
## StatItemData whose upgrade_data effects target loadout properties. Together with the equipped
## weapon / magnet tool / augments, these are the upgradeable items in a loadout — progress for all
## of them is tracked in item_states, keyed by item_id.
const STAT_ITEMS := [
	preload("res://_project/items/stats/player_health.tres"),
	preload("res://_project/items/stats/player_shield.tres"),
	preload("res://_project/items/stats/ship_hull.tres"),
	preload("res://_project/items/stats/ship_storage_size.tres"),
	preload("res://_project/items/stats/magnet_capacity.tres"),
	preload("res://_project/items/stats/magnet_health.tres"),
]
const DEFAULT_PLAYER_MAX_SHIELD_HITS := 0.0
const UNLOCKED_PLAYER_BASE_SHIELD_HITS := 2.0
const DEFAULT_PLAYER_SHIELD_SECONDS_PER_HIT := 1.0
const PLAYER_SHIELD_SLOT_ID := &"player_shield"

@export_group("Ship")
@export var ship_storage_area_size: Vector2 = Vector2(180, 100)
@export var ship_storage_area_position: Vector2 = Vector2(0, -95)
@export var ship_storage_marker_height: float = 24.0
@export var ship_max_health: float = 250.0

@export_group("Magnet")
@export var magnet_pull_frequency: float = 2.5
@export var magnet_hold_capacity: int = 10
@export var magnet_pull_base_speed: float = 200.0
@export var magnet_pull_max_speed: float = 1500.0
@export var magnet_pull_ramp_time: float = 0.6
@export var magnet_surface_slow_speed: float = 15.0
@export var magnet_surface_dwell_time: float = 1.2
@export var magnet_breakaway_ramp_time: float = 0.3
@export var magnet_breakaway_max_speed: float = 2000.0
@export var magnet_width: float = 264.0
@export var magnet_max_health: float = 150.0

@export_group("Player")
@export var player_speed: float = 400.0
## Apex height of a full-hold (maximum) jump, in pixels. Gravity and the launch
## velocity are derived from this and player_jump_time_to_apex so both the height
## and the airtime are exact.
@export var player_jump_max_height: float = 150.0
## Apex height of a tapped (minimum) jump, in pixels. Releasing jump while still
## rising cuts the ascent so it peaks here.
@export var player_jump_min_height: float = 25.0
## Seconds from leaving the floor to the top of a full-hold jump.
@export var player_jump_time_to_apex: float = 0.375
@export var player_max_health: float = 100.0
@export var player_max_shield: float = 0.0
@export var player_shield_recharge_delay: float = 6.0
@export var player_shield_recharge_duration: float = 1.0
@export var player_shield_break_recharge_delay: float = 10.0

@export_group("State")
## The saved per-run state: what's equipped in every slot + each item's upgrade progress. The
## fields below delegate into it so consumers read/write loadout.equipped_weapon etc. transparently.
@export var run_upgrade: RunUpgrade = null

var equipped_weapon: WeaponData:
	get: return _state().equipped_weapon
	set(v): _state().equipped_weapon = v
var equipped_magnet_tool: MagnetToolData:
	get: return _state().equipped_magnet_tool
	set(v): _state().equipped_magnet_tool = v
var player_equipment: Array[HeldItemData]:
	get: return _state().player_equipment
	set(v): _state().player_equipment = v
var player_selected_equipment_index: int:
	get: return _state().player_selected_equipment_index
	set(v): _state().player_selected_equipment_index = v
var player_augments: Array[AugmentData]:
	get: return _state().player_augments
	set(v): _state().player_augments = v
var ship_augments: Array[AugmentData]:
	get: return _state().ship_augments
	set(v): _state().ship_augments = v
var magnet_augments: Array[AugmentData]:
	get: return _state().magnet_augments
	set(v): _state().magnet_augments = v
var item_states: Array[Resource]:
	get: return _state().item_states
	set(v): _state().item_states = v
var slot_states: Array[Resource]:
	get: return _state().slot_states
	set(v): _state().slot_states = v
var upgrade_base_values: Dictionary:
	get: return _state().upgrade_base_values
	set(v): _state().upgrade_base_values = v


## The run-state container, created on first use so a fresh loadout is never null.
func _state() -> RunUpgrade:
	if run_upgrade == null:
		run_upgrade = RunUpgrade.new()
	return run_upgrade


## Upward launch velocity (negative Y) of a full-hold jump: reaches
## player_jump_max_height in player_jump_time_to_apex seconds under the derived
## gravity.
func get_player_jump_velocity() -> float:
	if player_jump_time_to_apex <= 0.0:
		return 0.0
	return -2.0 * player_jump_max_height / player_jump_time_to_apex


## Upward velocity (negative Y) the ascent is clamped to when jump is released
## early, so a tapped jump peaks at player_jump_min_height. Derived so the min/max
## heights are exact under the shared gravity.
func get_player_jump_cut_velocity() -> float:
	if player_jump_time_to_apex <= 0.0:
		return 0.0
	return -2.0 * sqrt(player_jump_max_height * player_jump_min_height) / player_jump_time_to_apex


## Gravity that brings a full-hold jump to its apex in player_jump_time_to_apex
## seconds, so both the height and the airtime match the authored values exactly.
func get_player_gravity() -> float:
	if player_jump_time_to_apex <= 0.0:
		return 0.0
	return 2.0 * player_jump_max_height / (player_jump_time_to_apex * player_jump_time_to_apex)


func equip_weapon(weapon_data: WeaponData) -> void:
	if weapon_data == null:
		return
	equipped_weapon = weapon_data
	player_selected_equipment_index = 0
	prepare_for_run()


# ---------------------------------------------------------------------------
# Upgrade accessors: every upgrade is an item (weapon / magnet gun / augment /
# static stat item) with an upgrade_data definition; progress is tracked per
# item_id in item_states. The station drives all of these by item_id.
# ---------------------------------------------------------------------------

## Every upgradeable item in the loadout: static stat items + equipped weapon / magnet tool /
## augments. Each carries its own upgrade_data.
func _get_upgradeable_items() -> Array:
	var items: Array = []
	items.append_array(STAT_ITEMS)
	if equipped_weapon != null:
		items.append(equipped_weapon)
	if equipped_magnet_tool != null:
		items.append(equipped_magnet_tool)
	items.append_array(get_equipped_augments())
	return items


func _find_upgradeable_item(item_id: StringName) -> ItemData:
	if item_id == &"":
		return null
	for item in _get_upgradeable_items():
		if item != null and item.item_id == item_id:
			return item
	return null


## Raise an item's upgrade level by one (clamped to its upgrade_data.max_level). Returns true if
## the level changed.
func increase_upgrade(item_id: StringName, amount: int = 1) -> bool:
	ensure_upgrade_state()
	var item := _find_upgradeable_item(item_id)
	if item == null or item.upgrade_data == null:
		return false
	var state := get_or_create_item_state(item_id)
	if state == null:
		return false
	var level_changed := bool(state.call("increase_level", item.upgrade_data.max_level, amount))
	if level_changed:
		prepare_for_run()
	return level_changed


## Per-item upgrade level for a specific equipment (keyed by its item id).
func get_equipment_item_level(equipment: HeldItemData) -> int:
	return get_item_level(equipment)


func get_upgrade_level(item_id: StringName) -> int:
	var state := get_item_state(item_id)
	if state != null and Utils.has_property(state, "current_level"):
		return int(state.get("current_level"))
	return 0


func get_upgrade_max_level(item_id: StringName) -> int:
	var item := _find_upgradeable_item(item_id)
	return item.get_max_level() if item != null else 0


func is_upgrade_maxed(item_id: StringName) -> bool:
	var item := _find_upgradeable_item(item_id)
	if item == null:
		return true
	return get_upgrade_level(item_id) >= item.get_max_level()


func get_upgrade_next_level_cost(item_id: StringName) -> Resource:
	var item := _find_upgradeable_item(item_id)
	if item == null or item.upgrade_data == null:
		return null
	return item.upgrade_data.get_cost_for_level(get_upgrade_level(item_id))


func get_upgrade_next_gain_text(item_id: StringName, stat_name: String) -> String:
	var item := _find_upgradeable_item(item_id)
	if item == null or item.upgrade_data == null:
		return ""
	return item.upgrade_data.get_gain_text_for_level(stat_name, get_upgrade_level(item_id))


## The UpgradeData definition for an item id (null if not upgradeable).
func get_upgrade(item_id: StringName) -> Resource:
	var item := _find_upgradeable_item(item_id)
	return item.upgrade_data if item != null else null


func prepare_for_run() -> void:
	ensure_upgrade_state()
	_apply_loadout_upgrades()
	_sync_storage_area_size()
	_apply_augment_loadout_modifiers()
	player_equipment = _build_runtime_equipment()
	if player_equipment.is_empty():
		player_selected_equipment_index = 0
	else:
		player_selected_equipment_index = clampi(player_selected_equipment_index, 0, player_equipment.size() - 1)


func ensure_upgrade_state() -> void:
	_ensure_equipped_defaults()
	_migrate_player_shield_defaults()


func get_upgraded_weapon_preview(weapon_data: WeaponData = null) -> WeaponData:
	var source := weapon_data if weapon_data != null else equipped_weapon
	return _upgraded_item_preview(source, UpgradeEffect.Target.WEAPON) as WeaponData


func get_upgraded_magnet_tool_preview(tool_data: MagnetToolData = null) -> MagnetToolData:
	var source := tool_data if tool_data != null else equipped_magnet_tool
	return _upgraded_item_preview(source, UpgradeEffect.Target.MAGNET_GUN) as MagnetToolData


## Duplicates `item` and applies its upgrade_data's `effect_target` effects at the item's current
## per-item level, so the returned resource carries its upgraded stats.
func _upgraded_item_preview(item: HeldItemData, effect_target: int) -> HeldItemData:
	if item == null:
		return null
	var preview := item.duplicate(true) as HeldItemData
	if preview == null:
		return item
	if item.upgrade_data != null:
		item.upgrade_data.apply_for_level(preview, item, get_item_level(item), effect_target)
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
	if item_data == null or not Utils.has_property(item_data, "item_id"):
		return 0
	var item_id := item_data.get("item_id") as StringName
	var state := get_item_state(item_id)
	if state != null and Utils.has_property(state, "current_level"):
		return int(state.get("current_level"))
	return 0


## Cost (UpgradeLevelCost) to raise this augment/item to its next level, via its upgrade_data.
func get_augment_next_level_cost(augment_data: Resource) -> Resource:
	var item := augment_data as ItemData
	if item == null or item.upgrade_data == null:
		return null
	return item.upgrade_data.get_cost_for_level(get_item_level(augment_data))


## Raise an augment's per-item level by one (clamped to its upgrade_data.max_level). Returns true
## if the level changed.
func increase_augment_level(augment_data: Resource) -> bool:
	var item := augment_data as ItemData
	if item == null:
		return false
	return increase_upgrade(item.item_id)


func is_item_unlocked(item_data: Resource, default_unlocked: bool = false) -> bool:
	if item_data == null or not Utils.has_property(item_data, "item_id"):
		return default_unlocked
	var item_id := item_data.get("item_id") as StringName
	var state := get_item_state(item_id)
	if state == null or not Utils.has_property(state, "unlocked"):
		return default_unlocked
	return bool(state.get("unlocked"))


func set_item_unlocked(item_data: Resource, unlocked: bool = true) -> void:
	if item_data == null or not Utils.has_property(item_data, "item_id"):
		return
	var item_id := item_data.get("item_id") as StringName
	var state := get_or_create_item_state(item_id)
	if state != null and Utils.has_property(state, "unlocked"):
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
	state.set("unlocked", false)
	slot_states.append(state)
	return state


func is_slot_unlocked(slot_id: StringName, default_unlocked: bool = false) -> bool:
	var state := get_slot_state(slot_id)
	if state == null or not Utils.has_property(state, "unlocked"):
		return default_unlocked
	return bool(state.get("unlocked"))


func set_slot_unlocked(slot_id: StringName, unlocked: bool = true) -> void:
	var state := get_or_create_slot_state(slot_id)
	if state != null and Utils.has_property(state, "unlocked"):
		state.set("unlocked", unlocked)


func equip_player_augment(slot_index: int, augment_data: AugmentData) -> void:
	if slot_index < 0:
		return
	while player_augments.size() <= slot_index:
		player_augments.append(null)

	if augment_data != null:
		# If this augment already occupies another slot, swap: move whatever is in
		# the target slot into that other slot (rather than just clearing it).
		for index in player_augments.size():
			if index != slot_index and ItemData.is_same_item(player_augments[index], augment_data):
				player_augments[index] = player_augments[slot_index]
				break

	player_augments[slot_index] = augment_data


func equip_ship_augment(slot_index: int, augment_data: AugmentData) -> void:
	_equip_augment_into(ship_augments, slot_index, augment_data)


func equip_magnet_augment(slot_index: int, augment_data: AugmentData) -> void:
	_equip_augment_into(magnet_augments, slot_index, augment_data)


func _equip_augment_into(augments: Array[AugmentData], slot_index: int, augment_data: AugmentData) -> void:
	if slot_index < 0:
		return
	while augments.size() <= slot_index:
		augments.append(null)

	if augment_data != null:
		# Swap with the target slot if this augment already occupies another slot.
		for index in augments.size():
			if index != slot_index and ItemData.is_same_item(augments[index], augment_data):
				augments[index] = augments[slot_index]
				break

	augments[slot_index] = augment_data


func _ensure_equipped_defaults() -> void:
	if equipped_weapon == null:
		for equipment_data in player_equipment:
			if equipment_data is WeaponData:
				equipped_weapon = equipment_data as WeaponData
				break
	if equipped_weapon == null:
		equipped_weapon = DefaultWeaponData
	# An equipped weapon is unlocked by definition; keep its unlock state honest so
	# the station catalog never shows the active weapon as locked (e.g. a save made
	# before a weapon became gated behind an unlock chain).
	set_item_unlocked(equipped_weapon, true)

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
		var existing_shield_base := float(upgrade_base_values["player_max_shield"])
		if existing_shield_base < 0.0 or existing_shield_base > 10.0:
			upgrade_base_values["player_max_shield"] = DEFAULT_PLAYER_MAX_SHIELD_HITS
	var shield_unlocked := is_slot_unlocked(PLAYER_SHIELD_SLOT_ID, false)
	var shield_base := UNLOCKED_PLAYER_BASE_SHIELD_HITS if shield_unlocked else DEFAULT_PLAYER_MAX_SHIELD_HITS
	player_max_shield = shield_base
	upgrade_base_values["player_max_shield"] = shield_base
	if is_equal_approx(player_shield_recharge_duration, 4.0):
		player_shield_recharge_duration = DEFAULT_PLAYER_SHIELD_SECONDS_PER_HIT


func _build_runtime_equipment() -> Array[HeldItemData]:
	var runtime_equipment: Array[HeldItemData] = []
	var weapon := get_upgraded_weapon_preview()
	var magnet_tool := get_upgraded_magnet_tool_preview()
	if weapon:
		runtime_equipment.append(weapon)
	if magnet_tool:
		runtime_equipment.append(magnet_tool)
	return runtime_equipment


## Storage rectangle dimensions per ship_storage_size upgrade level (0..5).
## Level 0 starts small; each level grows both width and height.
const STORAGE_SIZE_BY_LEVEL: Array[Vector2] = [
	Vector2(180, 100),
	Vector2(240, 140),
	Vector2(300, 180),
	Vector2(360, 220),
	Vector2(420, 260),
	Vector2(480, 300),
]


## Drive the storage area rectangle (both width and height) from the
## ship_storage_size upgrade level, since a single upgrade grows both dims.
func _sync_storage_area_size() -> void:
	var level := clampi(get_upgrade_level(&"ship_storage_size"), 0, STORAGE_SIZE_BY_LEVEL.size() - 1)
	ship_storage_area_size = STORAGE_SIZE_BY_LEVEL[level]


## Storage rectangle size for a given upgrade level (used by station UI previews).
func get_storage_size_for_level(level: int) -> Vector2:
	return STORAGE_SIZE_BY_LEVEL[clampi(level, 0, STORAGE_SIZE_BY_LEVEL.size() - 1)]


func _apply_augment_loadout_modifiers() -> void:
	for augment in get_equipped_augments():
		if augment == null or augment.behavior == null:
			continue
		augment.behavior.apply_to_loadout(self, get_item_level(augment))


## True for effects whose target is a stat on this loadout (player / ship / magnet),
## as opposed to on an equipped item (weapon / magnet gun).
func _effect_targets_loadout(effect: Resource) -> bool:
	var t := int(effect.get("target"))
	return t == UpgradeEffect.Target.PLAYER \
		or t == UpgradeEffect.Target.SHIP \
		or t == UpgradeEffect.Target.MAGNET


func _apply_loadout_upgrades() -> void:
	var target_properties := {}
	for item in STAT_ITEMS:
		if item == null or item.upgrade_data == null:
			continue
		for effect in item.upgrade_data.effects:
			if not _effect_targets_loadout(effect):
				continue
			var property_name := String(effect.target_property)
			if property_name.is_empty() or not Utils.has_property(self, property_name):
				continue
			if not upgrade_base_values.has(property_name):
				upgrade_base_values[property_name] = get(property_name)
			target_properties[property_name] = true

	for property_name in target_properties.keys():
		set(property_name, upgrade_base_values[property_name])

	for item in STAT_ITEMS:
		if item == null or item.upgrade_data == null:
			continue
		var level := get_item_level(item)
		var max_level: int = item.upgrade_data.max_level
		for effect in item.upgrade_data.effects:
			if not _effect_targets_loadout(effect):
				continue
			var property_name := String(effect.target_property)
			if not target_properties.has(property_name):
				continue
			var base_value: Variant = upgrade_base_values[property_name]
			var delta: float = effect.get_delta_for_level(base_value, level, max_level)
			_add_numeric_delta(property_name, base_value, delta)


func _add_numeric_delta(property_name: String, base_value: Variant, delta: float) -> void:
	var current_value: Variant = get(property_name)
	if typeof(current_value) != TYPE_INT and typeof(current_value) != TYPE_FLOAT:
		return

	var upgraded_value := float(current_value) + delta
	if typeof(base_value) == TYPE_INT:
		set(property_name, int(round(upgraded_value)))
	else:
		set(property_name, upgraded_value)
