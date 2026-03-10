extends Node2D
class_name Ship

signal item_stored(item: SalvageItem)

## Size of the full storage area (clickable zone extending upward from floor).
@export var storage_area_size: Vector2 = Vector2(400, 250)
## Position of the storage area bottom-center relative to ship (floor level).
@export var storage_area_position: Vector2 = Vector2(0, -95)
## Height of the hazard pattern floor marker strip.
@export var storage_marker_height: float = 24.0
## Maximum weight capacity for ship storage.
@export var storage_max_weight: float = 100.0

const STORAGE_COLLISION_LAYER: int = 8
const STORAGE_BORDER_THICKNESS: float = 8.0

var _stored_items: Array[SalvageItem] = []
var _storage_color_rect: ColorRect = null
var _storage_borders: StaticBody2D = null

var stored_items: Array[SalvageItem]:
	get:
		return _stored_items


func _ready() -> void:
	_create_storage_zone()


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

	# Floor
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(storage_area_size.x, STORAGE_BORDER_THICKNESS)
	floor_shape.shape = floor_rect
	floor_shape.position = Vector2(storage_area_position.x, floor_y + STORAGE_BORDER_THICKNESS * 0.5)
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


func add_to_storage(item: SalvageItem) -> void:
	if item not in _stored_items:
		_stored_items.append(item)
		item_stored.emit(item)
		_update_storage_weight_ui()


func _update_storage_weight_ui() -> void:
	var game_ui := Magnetide.game_ui
	if not game_ui:
		return
	var ship_status := game_ui.get_node_or_null("ShipStatusUI")
	if ship_status and ship_status.has_method("set_storage_weight"):
		var total_weight := get_storage_weight()
		ship_status.set_storage_weight(total_weight, storage_max_weight)


func get_storage_weight() -> float:
	var total := 0.0
	for item in _stored_items:
		if is_instance_valid(item) and item.item_data:
			total += item.item_data.weight
	return total


func remove_from_storage(item: SalvageItem) -> void:
	_stored_items.erase(item)
	_update_storage_weight_ui()
