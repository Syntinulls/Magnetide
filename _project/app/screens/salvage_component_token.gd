extends TextureRect
class_name SalvageComponentToken

signal arrived(token: SalvageComponentToken, item_data: SalvageItemData, count: int)

@export var acceleration: float = 2200.0
@export var max_speed: float = 2600.0
@export var turn_speed_radians: float = 8.5
@export var arrival_radius: float = 48.0

var item_data: SalvageItemData = null
var item_count: int = 1

var _velocity: Vector2 = Vector2.ZERO
var _target_center: Vector2 = Vector2.ZERO
var _is_flying: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func setup(data: SalvageItemData, display_size: Vector2 = Vector2(80.0, 80.0), count: int = 1) -> void:
	item_data = data
	item_count = maxi(count, 1)
	custom_minimum_size = display_size
	size = display_size
	pivot_offset = display_size * 0.5
	texture = data.sprite if data != null else null
	if texture == null:
		texture = _create_placeholder_texture(data, display_size)


func set_center_position(center_position: Vector2) -> void:
	position = center_position - (size * 0.5)


func get_center_position() -> Vector2:
	return position + (size * 0.5)


func begin_flight(target_center: Vector2, initial_velocity: Vector2 = Vector2.ZERO) -> void:
	_target_center = target_center
	_velocity = initial_velocity

	if _velocity.length_squared() <= 0.001:
		var to_target := _target_center - get_center_position()
		if to_target.length_squared() > 0.001:
			_velocity = to_target.normalized() * minf(max_speed * 0.2, 180.0)

	_is_flying = true
	set_process(true)


func _process(delta: float) -> void:
	if not _is_flying:
		return

	var current_center := get_center_position()
	var to_target := _target_center - current_center
	if to_target.length() <= arrival_radius:
		_is_flying = false
		set_process(false)
		arrived.emit(self, item_data, item_count)
		return

	var desired_direction := to_target.normalized()
	var current_direction := desired_direction
	if _velocity.length_squared() > 0.001:
		current_direction = _velocity.normalized()

	var angle_delta := wrapf(desired_direction.angle() - current_direction.angle(), -PI, PI)
	var rotation_step := clampf(angle_delta, -turn_speed_radians * delta, turn_speed_radians * delta)
	current_direction = current_direction.rotated(rotation_step).normalized()

	var speed := minf(_velocity.length() + acceleration * delta, max_speed)
	_velocity = current_direction * speed
	rotation = lerp_angle(rotation, current_direction.angle(), minf(delta * 10.0, 1.0))
	set_center_position(current_center + (_velocity * delta))


func _create_placeholder_texture(data: SalvageItemData, display_size: Vector2) -> Texture2D:
	var image_size := Vector2i(maxi(int(display_size.x), 2), maxi(int(display_size.y), 2))
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	var fill_color := Color.WHITE
	if data != null:
		fill_color = data.get_rarity_color()
	image.fill(fill_color)
	return ImageTexture.create_from_image(image)
