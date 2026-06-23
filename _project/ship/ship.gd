extends Node2D
class_name Ship

signal item_stored(item: SalvageItem)
signal destroyed

enum ThrusterState { STOPPED, MOVING, DECELERATING, NEAR_STOPPED }

## Size of the full storage area (clickable zone extending upward from floor).
@export var storage_area_size: Vector2 = Vector2(400, 250)
## Position of the storage area bottom-center relative to ship (floor level).
@export var storage_area_position: Vector2 = Vector2(0, -95)
## Height of the hazard pattern floor marker strip.
@export var storage_marker_height: float = 24.0
## Maximum weight capacity for ship storage.
@export var storage_max_weight: float = 100.0
@export_group("Combat")
@export var max_health: float = 250.0
@export var hitbox_path: NodePath = NodePath("Hitbox")
@export var enemy_target_point_paths: Array[NodePath] = []
@export var ship_status_ui_path: NodePath
@export_group("Thrusters")
@export var auto_update_thrusters: bool = true
@export var thruster_moving_speed_ratio_threshold: float = 0.15
@export var thruster_near_stop_speed_ratio_threshold: float = 0.25
@export var thruster_near_stop_left_lead: float = 0.35
@export var thruster_speed_change_epsilon: float = 1.0
@export_group("Debug")
@export var spawn_debug_research_artifact_in_storage: bool = true
@export var debug_research_artifact_storage_offset: Vector2 = Vector2(-140.0, -90.0)

const STORAGE_COLLISION_LAYER: int = 8
const STORAGE_BORDER_THICKNESS: float = 8.0
const STORAGE_ITEMS_ROOT_NAME := "StoredSalvageItems"
const STORAGE_ITEMS_Z_INDEX: int = -5
const DEBUG_RESEARCH_ARTIFACT_DATA: SalvageItemData = preload("res://_project/items/salvage/resources/artifacts/unknown_artifact.tres")
const STORAGE_AREA_OUTLINE_SHADER: Shader = preload("res://_project/shaders/border_outline.gdshader")
const STORAGE_OUTLINE_IDLE_ALPHA: float = 0.35
const STORAGE_OUTLINE_HOVER_ALPHA: float = 1.0
## Outline highlight for the shared pylon/generator sprite, driven by either
## departure pylon being in range.
const PYLON_OUTLINE_SHADER: Shader = preload("res://_project/shaders/outline.gdshader")

var _pylon_outline_material: ShaderMaterial = null
var _active_departure_pylons: Dictionary = {}

var _stored_items: Array[SalvageItem] = []
var _storage_color_rect: ColorRect = null
var _storage_borders: StaticBody2D = null
var _storage_outline_line: Line2D = null
var _storage_outline_material: ShaderMaterial = null
var _stored_salvage_items_root: Node2D = null
var current_health: float = 0.0
var _thruster_state: ThrusterState = ThrusterState.STOPPED
var _thruster_reference_speed: float = 0.0
var _last_level_speed: float = -1.0

@onready var _ship_status_ui: ShipStatusUI = get_node_or_null(ship_status_ui_path) as ShipStatusUI
@onready var _ship_gens: AnimatedSprite2D = $ShipGens as AnimatedSprite2D
@onready var _thruster_left: Thruster = $ThrusterLeft as Thruster
@onready var _thruster_right: Thruster = $ThrusterRight as Thruster
@onready var _research_station: ResearchStation = get_node_or_null("ResearchStation") as ResearchStation
@onready var _recycler: Node = get_node_or_null("Recycler")

var stored_items: Array[SalvageItem]:
	get:
		return _stored_items


func _ready() -> void:
	add_to_group("ship")
	current_health = max_health
	_ensure_storage_items_root()
	_create_storage_zone()
	_spawn_debug_research_artifact_in_storage()
	call_deferred("_update_storage_weight_ui")
	call_deferred("_initialize_thrusters")
	_setup_pylon_highlight()


func _process(_delta: float) -> void:
	if auto_update_thrusters:
		_update_thrusters_from_level_speed()


func apply_run_loadout(loadout: RunLoadout) -> void:
	if loadout == null:
		return

	storage_area_size = loadout.ship_storage_area_size
	storage_area_position = loadout.ship_storage_area_position
	storage_marker_height = loadout.ship_storage_marker_height
	storage_max_weight = loadout.ship_storage_max_weight
	max_health = loadout.ship_max_health
	current_health = max_health if not is_inside_tree() else minf(current_health, max_health)
	if _ship_status_ui:
		_update_storage_weight_ui()


func set_thrusters_auto_update(enabled: bool) -> void:
	auto_update_thrusters = enabled
	if enabled:
		_last_level_speed = -1.0
		_update_thrusters_from_level_speed()


func set_thruster_state(state: ThrusterState) -> void:
	auto_update_thrusters = false
	_apply_thruster_state(state)


func refresh_thrusters_from_level_speed() -> void:
	_last_level_speed = -1.0
	_update_thrusters_from_level_speed()


func set_departure_lift_thrusters(boosting: bool) -> void:
	auto_update_thrusters = false
	if _thruster_left == null or _thruster_right == null:
		return

	var thrust_level := Thruster.ThrustLevel.HIGH if boosting else Thruster.ThrustLevel.LOW
	var speed_ratio := 1.0 if boosting else 0.45
	var animation_name := &"loop_2" if boosting else &"loop_1"
	_thruster_left.aim_straight_down()
	_thruster_right.aim_straight_down()
	_thruster_left.set_thrust_animation(animation_name)
	_thruster_right.set_thrust_animation(animation_name)
	_thruster_left.set_thrust_level(thrust_level)
	_thruster_right.set_thrust_level(thrust_level)
	_thruster_left.set_ship_speed_ratio(speed_ratio)
	_thruster_right.set_ship_speed_ratio(speed_ratio)


## Turbo boost plume used during the threat-advance cutscene. When disabled,
## thrusters return to following the level speed automatically.
func set_turbo_thrusters(enabled: bool) -> void:
	auto_update_thrusters = not enabled
	if _thruster_left == null or _thruster_right == null:
		return
	if enabled:
		_thruster_left.set_thrust_animation(&"loop_2")
		_thruster_right.set_thrust_animation(&"loop_2")
		_thruster_left.set_thrust_level(Thruster.ThrustLevel.HIGH)
		_thruster_right.set_thrust_level(Thruster.ThrustLevel.HIGH)
		_thruster_left.set_ship_speed_ratio(1.0)
		_thruster_right.set_ship_speed_ratio(1.0)
	else:
		_thruster_left.set_thrust_animation(Thruster.DEFAULT_THRUST_ANIMATION)
		_thruster_right.set_thrust_animation(Thruster.DEFAULT_THRUST_ANIMATION)
		refresh_thrusters_from_level_speed()


func lock_stored_items_for_departure() -> void:
	var storage_root := _ensure_storage_items_root()
	for item in _stored_items:
		if is_instance_valid(item):
			item.lock_for_departure_cutscene(storage_root)


func show_departure_shield() -> void:
	var shield := _find_departure_shield()
	if shield:
		shield.visible = true
		if shield is AnimatedSprite2D:
			(shield as AnimatedSprite2D).play()


func _find_departure_shield() -> CanvasItem:
	var shield := find_child("ShipShield", true, false) as CanvasItem
	if shield:
		return shield
	shield = find_child("DepartureShield", true, false) as CanvasItem
	if shield:
		return shield
	return find_child("Shield", true, false) as CanvasItem


func _create_storage_zone() -> void:
	_create_storage_floor_marker()
	_create_storage_borders()
	_create_storage_area_outline()


func _ensure_storage_items_root() -> Node2D:
	if _stored_salvage_items_root and is_instance_valid(_stored_salvage_items_root):
		return _stored_salvage_items_root

	_stored_salvage_items_root = get_node_or_null(STORAGE_ITEMS_ROOT_NAME) as Node2D
	if _stored_salvage_items_root == null:
		_stored_salvage_items_root = Node2D.new()
		_stored_salvage_items_root.name = STORAGE_ITEMS_ROOT_NAME
		add_child(_stored_salvage_items_root)

	var ship_back := get_node_or_null("ShipBack")
	if ship_back:
		move_child(_stored_salvage_items_root, ship_back.get_index())

	_stored_salvage_items_root.y_sort_enabled = true
	_stored_salvage_items_root.z_index = STORAGE_ITEMS_Z_INDEX
	return _stored_salvage_items_root


func _create_storage_floor_marker() -> void:
	var pattern := preload("res://_project/ship/sprites/pattern_hazard.png")
	const BORDER_WIDTH: float = 6.0

	_storage_color_rect = ColorRect.new()
	_storage_color_rect.size = Vector2(storage_area_size.x + BORDER_WIDTH * 2, storage_marker_height + BORDER_WIDTH * 2)
	_storage_color_rect.position = Vector2(
		storage_area_position.x - storage_area_size.x * 0.5 - BORDER_WIDTH,
		storage_area_position.y - storage_marker_height - BORDER_WIDTH
	)
	_storage_color_rect.color = Color.BLACK  # Black border
	_storage_color_rect.z_index = -2  # Render behind ship sprites

	# Create TextureRect for tiled pattern inside the border
	var tex_rect := TextureRect.new()
	tex_rect.texture = pattern
	tex_rect.stretch_mode = TextureRect.STRETCH_TILE
	tex_rect.size = Vector2(storage_area_size.x, storage_marker_height)
	tex_rect.position = Vector2(BORDER_WIDTH, BORDER_WIDTH)
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	_storage_color_rect.add_child(tex_rect)

	add_child(_storage_color_rect)


func _create_storage_borders() -> void:
	_storage_borders = StaticBody2D.new()
	_storage_borders.collision_layer = STORAGE_COLLISION_LAYER
	_storage_borders.collision_mask = 0
	add_child(_storage_borders)

	var half_w := storage_area_size.x * 0.5
	var floor_y := storage_area_position.y

	# Floor (positioned at top edge of marker sprite)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(storage_area_size.x, STORAGE_BORDER_THICKNESS)
	floor_shape.shape = floor_rect
	floor_shape.position = Vector2(storage_area_position.x, floor_y - storage_marker_height + STORAGE_BORDER_THICKNESS * 0.5)
	_storage_borders.add_child(floor_shape)

	# Left wall
	var left_shape := CollisionShape2D.new()
	var left_rect := RectangleShape2D.new()
	left_rect.size = Vector2(STORAGE_BORDER_THICKNESS, storage_area_size.y)
	left_shape.shape = left_rect
	left_shape.position = Vector2(
		storage_area_position.x - half_w - STORAGE_BORDER_THICKNESS * 0.5,
		floor_y - storage_area_size.y * 0.5
	)
	_storage_borders.add_child(left_shape)

	# Right wall
	var right_shape := CollisionShape2D.new()
	var right_rect := RectangleShape2D.new()
	right_rect.size = Vector2(STORAGE_BORDER_THICKNESS, storage_area_size.y)
	right_shape.shape = right_rect
	right_shape.position = Vector2(
		storage_area_position.x + half_w + STORAGE_BORDER_THICKNESS * 0.5,
		floor_y - storage_area_size.y * 0.5
	)
	_storage_borders.add_child(right_shape)


func _create_storage_area_outline() -> void:
	_storage_outline_line = Line2D.new()
	_storage_outline_line.name = "StorageAreaOutline"
	_storage_outline_line.width = 5.0
	_storage_outline_line.default_color = Color.WHITE
	_storage_outline_line.closed = true
	_storage_outline_line.antialiased = true
	_storage_outline_line.z_index = -1
	_storage_outline_line.visible = false

	_storage_outline_material = ShaderMaterial.new()
	_storage_outline_material.shader = STORAGE_AREA_OUTLINE_SHADER
	_storage_outline_line.material = _storage_outline_material
	_update_storage_area_outline_geometry()
	add_child(_storage_outline_line)


func _update_storage_area_outline_geometry() -> void:
	if _storage_outline_line == null or not is_instance_valid(_storage_outline_line):
		return

	var top_left := Vector2(
		storage_area_position.x - storage_area_size.x * 0.5,
		storage_area_position.y - storage_area_size.y
	)
	_storage_outline_line.points = PackedVector2Array([
		top_left,
		top_left + Vector2(storage_area_size.x, 0.0),
		top_left + storage_area_size,
		top_left + Vector2(0.0, storage_area_size.y)
	])

	if _storage_outline_material:
		_storage_outline_material.set_shader_parameter("rect_top_left", top_left)
		_storage_outline_material.set_shader_parameter("rect_size", storage_area_size)


func set_storage_area_outline_state(enabled: bool, hovered: bool = false) -> void:
	if _storage_outline_line == null or not is_instance_valid(_storage_outline_line):
		_create_storage_area_outline()

	_update_storage_area_outline_geometry()
	_storage_outline_line.visible = enabled
	if _storage_outline_material:
		var alpha := STORAGE_OUTLINE_HOVER_ALPHA if hovered else STORAGE_OUTLINE_IDLE_ALPHA
		_storage_outline_material.set_shader_parameter("opacity", alpha)


func get_storage_area_global_rect() -> Rect2:
	var top_left := global_position + Vector2(
		storage_area_position.x - storage_area_size.x * 0.5,
		storage_area_position.y - storage_area_size.y
	)
	return Rect2(top_left, storage_area_size)


func is_point_in_storage_area(global_point: Vector2) -> bool:
	return get_storage_area_global_rect().has_point(global_point)


func can_accept_new_storage_item() -> bool:
	return get_storage_weight() < storage_max_weight


func can_accept_storage_item(item: SalvageItem) -> bool:
	if item == null or not is_instance_valid(item):
		return false

	var current_weight := get_storage_weight()
	if item in _stored_items:
		current_weight -= _get_item_weight(item)

	return current_weight + _get_item_weight(item) <= storage_max_weight


func is_storage_at_or_over_capacity() -> bool:
	return get_storage_weight() >= storage_max_weight


func add_to_storage(item: SalvageItem) -> void:
	if not can_accept_new_storage_item():
		return
	if item not in _stored_items:
		_stored_items.append(item)
		item_stored.emit(item)
		_update_storage_weight_ui()


func store_item(item: SalvageItem, target_pos: Vector2) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	if not can_accept_storage_item(item):
		return false

	item.place_in_storage(target_pos, _ensure_storage_items_root())
	add_to_storage(item)
	return true


func _spawn_debug_research_artifact_in_storage() -> void:
	if not spawn_debug_research_artifact_in_storage:
		return
	if DEBUG_RESEARCH_ARTIFACT_DATA == null:
		return

	var storage_root := _ensure_storage_items_root()
	var artifact := SalvageItem.new()
	artifact.name = "DebugResearchArtifact"
	storage_root.add_child(artifact)
	artifact.setup(DEBUG_RESEARCH_ARTIFACT_DATA)

	var target_pos := global_position + storage_area_position + debug_research_artifact_storage_offset
	if not store_item(artifact, target_pos):
		artifact.queue_free()


func get_research_station_at_point(global_point: Vector2) -> ResearchStation:
	if _research_station == null or not is_instance_valid(_research_station):
		return null
	if _research_station.is_point_in_placement_area(global_point):
		return _research_station
	return null


func get_research_station_in_interaction_range(_global_point: Vector2) -> ResearchStation:
	if _research_station == null or not is_instance_valid(_research_station):
		return null
	if _research_station.is_player_in_range:
		return _research_station
	return null


func can_accept_research_item(item: SalvageItem) -> bool:
	return _research_station != null and is_instance_valid(_research_station) and _research_station.can_accept_item(item)


func place_research_item(item: SalvageItem) -> bool:
	if _research_station == null or not is_instance_valid(_research_station):
		return false
	return _research_station.place_artifact(item)


func clear_research_station_highlight() -> void:
	if _research_station and is_instance_valid(_research_station):
		_research_station.set_highlighted(false)


func get_recycler_at_point(global_point: Vector2) -> Node:
	if _recycler == null or not is_instance_valid(_recycler):
		return null
	if _recycler.has_method("is_point_in_placement_area") and _recycler.call("is_point_in_placement_area", global_point):
		return _recycler
	return null


func clear_recycler_highlight() -> void:
	if _recycler and is_instance_valid(_recycler):
		if _recycler.has_method("set_highlighted"):
			_recycler.call("set_highlighted", false)


func stop_for_run_end() -> void:
	if _research_station and is_instance_valid(_research_station):
		_research_station.stop_for_run_end()


func _update_storage_weight_ui() -> void:
	if not _ship_status_ui:
		return
	var total_weight := get_storage_weight()
	_ship_status_ui.set_storage_weight(total_weight, storage_max_weight)


func get_storage_weight() -> float:
	var total := 0.0
	for item in _stored_items:
		if is_instance_valid(item):
			total += _get_item_weight(item)
	return total


func remove_from_storage(item: SalvageItem) -> void:
	_stored_items.erase(item)
	_update_storage_weight_ui()


func get_storage_items_root() -> Node2D:
	return _ensure_storage_items_root()


func _get_item_weight(item: SalvageItem) -> float:
	if item and item.has_method("get_weight"):
		return item.get_weight()
	return 0.0


func _initialize_thrusters() -> void:
	_thruster_reference_speed = maxf(_get_level_speed(), 0.0)
	_update_thrusters_from_level_speed()


func _update_thrusters_from_level_speed() -> void:
	if _thruster_left == null or _thruster_right == null:
		return

	var speed := maxf(_get_level_speed(), 0.0)
	if speed > _thruster_reference_speed:
		_thruster_reference_speed = speed

	var reference_speed := maxf(_thruster_reference_speed, 1.0)
	var speed_ratio := speed / reference_speed
	var next_state := ThrusterState.STOPPED
	_thruster_left.set_ship_speed_ratio(speed_ratio)
	_thruster_right.set_ship_speed_ratio(speed_ratio)

	if speed <= thruster_speed_change_epsilon:
		next_state = ThrusterState.STOPPED
	elif _last_level_speed >= 0.0 and speed > _last_level_speed + thruster_speed_change_epsilon:
		next_state = ThrusterState.MOVING
	elif speed_ratio <= thruster_near_stop_speed_ratio_threshold:
		next_state = ThrusterState.NEAR_STOPPED
	elif _last_level_speed >= 0.0 and speed < _last_level_speed - thruster_speed_change_epsilon:
		next_state = ThrusterState.DECELERATING
	elif speed_ratio >= thruster_moving_speed_ratio_threshold:
		next_state = ThrusterState.MOVING

	_last_level_speed = speed
	_apply_thruster_state(next_state)
	if next_state == ThrusterState.NEAR_STOPPED:
		_update_near_stop_thruster_rotation(speed_ratio)


func _apply_thruster_state(state: ThrusterState) -> void:
	if state == _thruster_state:
		return
	_thruster_state = state

	match state:
		ThrusterState.MOVING:
			_thruster_left.aim_bottom_left()
			_thruster_right.aim_bottom_left()
			_thruster_left.set_thrust_level(Thruster.ThrustLevel.HIGH)
			_thruster_right.set_thrust_level(Thruster.ThrustLevel.HIGH)
		ThrusterState.DECELERATING:
			_thruster_left.aim_bottom_right()
			_thruster_right.aim_bottom_right()
			_thruster_left.set_thrust_level(Thruster.ThrustLevel.HIGH)
			_thruster_right.set_thrust_level(Thruster.ThrustLevel.HIGH)
		ThrusterState.NEAR_STOPPED:
			_thruster_left.set_thrust_level(Thruster.ThrustLevel.LOW)
			_thruster_right.set_thrust_level(Thruster.ThrustLevel.HIGH)
		_:
			_thruster_left.aim_straight_down()
			_thruster_right.aim_straight_down()
			_thruster_left.set_thrust_level(Thruster.ThrustLevel.LOW)
			_thruster_right.set_thrust_level(Thruster.ThrustLevel.LOW)


func _update_near_stop_thruster_rotation(speed_ratio: float) -> void:
	var stop_progress := 1.0 - clampf(speed_ratio / maxf(thruster_near_stop_speed_ratio_threshold, 0.001), 0.0, 1.0)
	var left_completion_point := maxf(1.0 - thruster_near_stop_left_lead, 0.001)
	var left_progress := clampf(stop_progress / left_completion_point, 0.0, 1.0)
	var left_degrees := lerpf(_thruster_left.bottom_right_degrees, _thruster_left.straight_down_degrees, left_progress)
	var right_degrees := lerpf(_thruster_right.bottom_right_degrees, _thruster_right.straight_down_degrees, stop_progress)
	_thruster_left.set_aim_degrees(left_degrees)
	_thruster_right.set_aim_degrees(right_degrees)


func _get_level_speed() -> float:
	var level := get_parent()
	if level and "level_speed" in level:
		return level.level_speed
	return 0.0


func take_damage(amount: float, _source: Node = null) -> void:
	if current_health <= 0.0:
		return
	var previous_health := current_health
	current_health = maxf(current_health - amount, 0.0)
	if previous_health > 0.0 and current_health <= 0.0:
		destroyed.emit()


## Environmental acid-storm drain (continuous DoT on hull integrity).
func apply_storm_damage(amount: float) -> void:
	take_damage(amount)


func get_hitbox() -> Hitbox:
	return get_node_or_null(hitbox_path) as Hitbox


func get_damage_receiver_for_target_point(point: EnemyTargetPoint) -> Hitbox:
	if point == null or not _has_configured_target_point(point):
		return null
	return get_hitbox()


func get_enemy_target_points() -> Array[EnemyTargetPoint]:
	var points: Array[EnemyTargetPoint] = []
	for target_point_path in enemy_target_point_paths:
		var point := get_node_or_null(target_point_path) as EnemyTargetPoint
		if point and point.target_group == EnemyData.GROUP_SHIP and point.is_target_enabled():
			points.append(point)
	return points


func _has_configured_target_point(point: EnemyTargetPoint) -> bool:
	for target_point_path in enemy_target_point_paths:
		if get_node_or_null(target_point_path) == point:
			return true
	return false


func get_stored_item_count() -> int:
	var total := 0
	for item in _stored_items:
		if is_instance_valid(item):
			total += 1
	return total


func get_stored_loot_payload() -> Array[SalvageItemData]:
	var loot: Array[SalvageItemData] = []
	for item in _stored_items:
		if is_instance_valid(item) and item.item_data != null:
			loot.append(item.item_data)
	return loot


func get_departure_pylons() -> Array[DeparturePylon]:
	var pylons: Array[DeparturePylon] = []
	for child in find_children("*", "DeparturePylon", true, false):
		var pylon := child as DeparturePylon
		if pylon:
			pylons.append(pylon)
	return pylons


func _setup_pylon_highlight() -> void:
	if _ship_gens == null:
		return
	_pylon_outline_material = ShaderMaterial.new()
	_pylon_outline_material.shader = PYLON_OUTLINE_SHADER
	_pylon_outline_material.set_shader_parameter("outline_enabled", false)
	_pylon_outline_material.set_shader_parameter("outline_width", 3.0)
	_ship_gens.material = _pylon_outline_material


## Called by each departure pylon as it enters/leaves interaction range. The
## shared generator-sprite highlight and the depart control prompt are driven by
## whether *any* pylon is currently active, so either pylon triggers them.
func set_departure_pylon_active(pylon: Node, active: bool) -> void:
	if active:
		_active_departure_pylons[pylon] = true
	else:
		_active_departure_pylons.erase(pylon)

	var any_active := not _active_departure_pylons.is_empty()
	if _pylon_outline_material:
		_pylon_outline_material.set_shader_parameter("outline_enabled", any_active)

	var prompts := Magnetide.control_prompts
	if prompts:
		if any_active:
			prompts.set_prompt(&"depart", "E", "DEPART", true, 10)
		else:
			prompts.clear_prompt(&"depart")
