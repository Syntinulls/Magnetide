extends Node2D
class_name Ship

signal item_stored(item: SalvageItem)
signal destroyed

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
@export var ship_status_ui_path: NodePath

const STORAGE_COLLISION_LAYER: int = 8
const STORAGE_BORDER_THICKNESS: float = 8.0

var _stored_items: Array[SalvageItem] = []
var _storage_color_rect: ColorRect = null
var _storage_borders: StaticBody2D = null
var current_health: float = 0.0

@onready var _ship_status_ui: ShipStatusUI = get_node_or_null(ship_status_ui_path) as ShipStatusUI

var stored_items: Array[SalvageItem]:
	get:
		return _stored_items


func _ready() -> void:
	current_health = max_health
	_create_storage_zone()
	call_deferred("_update_storage_weight_ui")


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


func _create_storage_zone() -> void:
	_create_storage_floor_marker()
	_create_storage_borders()


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


func is_storage_at_or_over_capacity() -> bool:
	return get_storage_weight() >= storage_max_weight


func add_to_storage(item: SalvageItem) -> void:
	if not can_accept_new_storage_item():
		return
	if item not in _stored_items:
		_stored_items.append(item)
		item_stored.emit(item)
		_update_storage_weight_ui()


func _update_storage_weight_ui() -> void:
	if not _ship_status_ui:
		return
	var total_weight := get_storage_weight()
	_ship_status_ui.set_storage_weight(total_weight, storage_max_weight)


func get_storage_weight() -> float:
	var total := 0.0
	for item in _stored_items:
		if is_instance_valid(item) and item.item_data:
			total += item.item_data.weight
	return total


func remove_from_storage(item: SalvageItem) -> void:
	_stored_items.erase(item)
	_update_storage_weight_ui()


func take_damage(amount: float) -> void:
	if current_health <= 0.0:
		return
	var previous_health := current_health
	current_health = maxf(current_health - amount, 0.0)
	if previous_health > 0.0 and current_health <= 0.0:
		destroyed.emit()


func get_hitbox() -> Hitbox:
	var hitboxes := find_children("*", "Hitbox", true, false)
	if hitboxes.is_empty():
		return null
	return hitboxes[0] as Hitbox


func get_enemy_target_points() -> Array[EnemyTargetPoint]:
	var points: Array[EnemyTargetPoint] = []
	for child in find_children("*", "EnemyTargetPoint", true, false):
		var point := child as EnemyTargetPoint
		if point and point.category == EnemyData.TargetCategory.SHIP and point.is_target_enabled():
			points.append(point)
	return points


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
