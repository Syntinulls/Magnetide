@tool
extends Resource
class_name EnemyData

enum TargetSelectionMode {
	ORDER,
	RANDOM,
	CLOSEST,
}

enum TargetSwitchingMode {
	DEFAULT,
	RECEIVED_DAMAGE,
	PROXIMITY,
}

const TARGET_SELECTION_HINT := "ORDER,RANDOM,CLOSEST"
const TARGET_SWITCHING_HINT := "DEFAULT,RECEIVED_DAMAGE,PROXIMITY"
const GROUP_PLAYER := "player"
const GROUP_MAGNET := "magnet"
const GROUP_SHIP := "ship"

@export var enemy_name: String = ""

@export_group("Visuals")
@export var sprite_frames: SpriteFrames

@export_group("Stats")
## Maximum health points.
@export var max_health: float = 50.0
## Damage dealt per attack hit.
@export var damage: float = 5.0
## Movement speed in pixels per second.
@export var movement_speed: float = 100.0
## Distance at which the enemy stops moving and begins attacking.
@export var attack_range: float = 50.0
## Seconds between each attack hit while in range.
@export var attack_interval: float = 1.0

@export_group("Hitbox")
## Rectangle size used for the enemy damage hitbox.
@export var hitbox_size: Vector2 = Vector2(40.0, 40.0)

var valid_targets: Array[String] = [GROUP_PLAYER]
var target_range: float = 500.0
var target_acquire_interval: float = 1.0
var target_priority_mode: TargetSelectionMode = TargetSelectionMode.ORDER:
	set(value):
		target_priority_mode = value
		_notify_target_property_list_changed()
var target_priority_order: Array[String] = [GROUP_PLAYER]
var target_priority_random_excludes: Array[String] = []
var target_switching_mode: TargetSwitchingMode = TargetSwitchingMode.DEFAULT:
	set(value):
		target_switching_mode = value
		_notify_target_property_list_changed()
var proximity_switch_interval: float = 1.0
var target_point_selection_mode: TargetSelectionMode = TargetSelectionMode.RANDOM:
	set(value):
		target_point_selection_mode = value
		_notify_target_property_list_changed()

@export_group("Behaviors")
@export var move_behavior: Resource
@export var attack_behavior: Resource

@export_group("Rewards")
@export var loot_table: LootTable

@export_group("Death Sequence")
@export var death_shake_duration: float = 0.5
@export var death_shake_distance: float = 8.0
@export var death_shake_steps: int = 28
@export var death_pause_duration: float = 0.5
@export var death_pop_velocity_x_range: Vector2 = Vector2(-80.0, 80.0)
@export var death_pop_up_velocity_range: Vector2 = Vector2(520.0, 760.0)
@export var death_pop_gravity: float = 1400.0
@export var death_pop_rotation_velocity_range: Vector2 = Vector2(-10.0, 10.0)
@export var death_pop_despawn_margin: float = 128.0
@export var death_pop_max_time: float = 4.0


func _get_property_list() -> Array:
	var properties: Array = []

	_add_group(properties, "Target Acquisition")
	_add_target_array_property(properties, "valid_targets", PROPERTY_USAGE_DEFAULT)
	_add_float_property(properties, "target_range", PROPERTY_USAGE_DEFAULT, 0.0, 10000.0, 1.0, "or_greater")
	_add_float_property(properties, "target_acquire_interval", PROPERTY_USAGE_DEFAULT, 0.05, 60.0, 0.05, "or_greater")

	_add_group(properties, "Priority Settings")
	_add_enum_property(properties, "target_priority_mode", TARGET_SELECTION_HINT, PROPERTY_USAGE_DEFAULT)
	_add_target_array_property(
		properties,
		"target_priority_order",
		PROPERTY_USAGE_DEFAULT if target_priority_mode == TargetSelectionMode.ORDER else PROPERTY_USAGE_STORAGE
	)
	_add_target_array_property(
		properties,
		"target_priority_random_excludes",
		PROPERTY_USAGE_DEFAULT if target_priority_mode == TargetSelectionMode.RANDOM else PROPERTY_USAGE_STORAGE
	)

	_add_group(properties, "Switching Settings")
	_add_enum_property(properties, "target_switching_mode", TARGET_SWITCHING_HINT, PROPERTY_USAGE_DEFAULT)
	_add_float_property(
		properties,
		"proximity_switch_interval",
		PROPERTY_USAGE_DEFAULT if target_switching_mode == TargetSwitchingMode.PROXIMITY else PROPERTY_USAGE_STORAGE,
		0.05,
		60.0,
		0.05,
		"or_greater"
	)

	_add_group(properties, "Target Point Settings")
	_add_enum_property(properties, "target_point_selection_mode", TARGET_SELECTION_HINT, PROPERTY_USAGE_DEFAULT)

	return properties


func _get(property: StringName) -> Variant:
	match property:
		&"valid_targets":
			return valid_targets
		&"target_range":
			return target_range
		&"target_acquire_interval":
			return target_acquire_interval
		&"target_priority_mode":
			return target_priority_mode
		&"target_priority_order":
			return target_priority_order
		&"target_priority_random_excludes":
			return target_priority_random_excludes
		&"target_switching_mode":
			return target_switching_mode
		&"proximity_switch_interval":
			return proximity_switch_interval
		&"target_point_selection_mode":
			return target_point_selection_mode
	return null


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"valid_targets":
			valid_targets = _normalize_target_group_array(value)
			return true
		&"target_range":
			target_range = maxf(float(value), 0.0)
			return true
		&"target_acquire_interval":
			target_acquire_interval = maxf(float(value), 0.05)
			return true
		&"target_priority_mode":
			target_priority_mode = value as TargetSelectionMode
			return true
		&"target_priority_order":
			target_priority_order = _normalize_target_group_array(value)
			return true
		&"target_priority_random_excludes":
			target_priority_random_excludes = _normalize_target_group_array(value)
			return true
		&"target_switching_mode":
			target_switching_mode = value as TargetSwitchingMode
			return true
		&"proximity_switch_interval":
			proximity_switch_interval = maxf(float(value), 0.05)
			return true
		&"target_point_selection_mode":
			target_point_selection_mode = value as TargetSelectionMode
			return true
	return false


func get_target_priority_groups() -> Array[String]:
	return _get_target_priority_groups(true)


func get_target_priority_groups_including_random_excludes() -> Array[String]:
	return _get_target_priority_groups(false)


func _get_target_priority_groups(apply_random_excludes: bool) -> Array[String]:
	var groups: Array[String] = []
	if target_priority_mode == TargetSelectionMode.ORDER and not target_priority_order.is_empty():
		groups = target_priority_order.duplicate()
	else:
		groups = valid_targets.duplicate()

	if valid_targets.is_empty():
		return groups

	var filtered_groups: Array[String] = []
	for group_name in groups:
		if apply_random_excludes and target_priority_mode == TargetSelectionMode.RANDOM and target_priority_random_excludes.has(group_name):
			continue
		if valid_targets.has(group_name) and not filtered_groups.has(group_name):
			filtered_groups.append(group_name)
	return filtered_groups


func _notify_target_property_list_changed() -> void:
	if Engine.is_editor_hint():
		notify_property_list_changed()


func _add_group(properties: Array, group_name: String) -> void:
	properties.append({
		"name": group_name,
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
	})


func _add_enum_property(properties: Array, property_name: String, hint_string: String, usage: int) -> void:
	properties.append({
		"name": property_name,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_string,
		"usage": usage,
	})


func _add_target_array_property(properties: Array, property_name: String, usage: int) -> void:
	properties.append({
		"name": property_name,
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "%s:" % TYPE_STRING,
		"usage": usage,
	})


func _add_float_property(properties: Array, property_name: String, usage: int, minimum: float, maximum: float, step: float, extra_hint: String = "") -> void:
	var hint_parts: Array[String] = [str(minimum), str(maximum), str(step)]
	if not extra_hint.is_empty():
		hint_parts.append(extra_hint)
	properties.append({
		"name": property_name,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": ",".join(hint_parts),
		"usage": usage,
	})


func _normalize_target_group_array(value: Variant) -> Array[String]:
	var groups: Array[String] = []
	if not value is Array:
		return groups

	for item in value:
		var group_name := str(item).strip_edges()
		if group_name.is_empty():
			continue
		groups.append(group_name)
	return groups
