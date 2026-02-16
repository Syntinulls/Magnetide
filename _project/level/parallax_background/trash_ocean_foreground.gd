extends CanvasLayer
class_name TrashOceanForeground

@export_group("Layer Settings")
## Number of sprites in the foreground layer.
@export var sprite_count: int = 60

@export_group("Positioning")
## The Y position of the ocean surface (foreground starts below this).
@export var surface_y: float = 540.0
## Offset below surface_y where foreground sprites begin.
@export var surface_offset: float = 20.0
## The Y position where the foreground band ends (bottom, extends off screen).
@export var foreground_y_max: float = 720.0
## Extra horizontal padding beyond viewport.
@export var padding: float = 100.0
## Maximum horizontal spacing between foreground sprites.
@export var max_spacing: float = 50.0

@export_group("Scrolling")
## Speed at which foreground objects scroll left (pixels per second).
@export var scroll_speed: float = 20.0
## X position where objects are recycled (left of screen).
@export var despawn_x: float = -150.0

@export_group("Appearance")
## Minimum scale for foreground trash.
@export var scale_min: float = 1.0
## Maximum scale for foreground trash.
@export var scale_max: float = 1.2
## Minimum brown tint hue.
@export var brown_hue_min: float = 0.05
## Maximum brown tint hue.
@export var brown_hue_max: float = 0.12
## Minimum saturation.
@export var brown_sat_min: float = 0.4
## Maximum saturation.
@export var brown_sat_max: float = 0.7
## Minimum brightness.
@export var brown_val_min: float = 0.15
## Maximum brightness.
@export var brown_val_max: float = 0.35

var _icon_texture: Texture2D
var _buoyancy_shader: Shader
var _container: Node2D
var _screen_width: float = 0.0


func _ready() -> void:
	layer = 10
	_icon_texture = preload("res://icon.svg")
	_buoyancy_shader = preload("res://_project/level/parallax_background/buoyancy.gdshader")
	_generate_foreground()


func _generate_foreground() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_screen_width = viewport_size.x

	_container = Node2D.new()
	add_child(_container)

	var total_width := _screen_width + padding * 2.0
	var spacing := total_width / float(sprite_count)

	for i in range(sprite_count):
		var x_pos := -padding + (i * spacing) + randf_range(-10.0, 10.0)
		var sprite := _create_sprite(x_pos)
		_container.add_child(sprite)


func _create_sprite(x_pos: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _icon_texture

	var foreground_y_min := surface_y + surface_offset
	var y := randf_range(foreground_y_min, foreground_y_max)
	sprite.position = Vector2(x_pos, y)

	var s := randf_range(scale_min, scale_max)
	sprite.scale = Vector2(s, s)

	sprite.rotation = randf_range(-0.3, 0.3)

	sprite.modulate = _random_brown_color()

	sprite.z_index = 100

	var mat := ShaderMaterial.new()
	mat.shader = _buoyancy_shader
	mat.set_shader_parameter("amplitude", randf_range(2.0, 4.0))
	mat.set_shader_parameter("frequency", randf_range(1.0, 1.8))
	mat.set_shader_parameter("phase_offset", randf() * TAU)
	sprite.material = mat

	return sprite


func _process(delta: float) -> void:
	for sprite in _container.get_children():
		sprite.position.x -= scroll_speed * delta

		if sprite.position.x < despawn_x:
			_recycle_sprite(sprite)


func _get_rightmost_x() -> float:
	var rightmost := -INF
	for child in _container.get_children():
		if child.position.x > rightmost:
			rightmost = child.position.x
	return rightmost


func _recycle_sprite(sprite: Sprite2D) -> void:
	var rightmost := _get_rightmost_x()
	sprite.position.x = rightmost + randf_range(max_spacing * 0.5, max_spacing)

	var foreground_y_min := surface_y + surface_offset
	sprite.position.y = randf_range(foreground_y_min, foreground_y_max)

	var s := randf_range(scale_min, scale_max)
	sprite.scale = Vector2(s, s)

	sprite.rotation = randf_range(-0.3, 0.3)

	sprite.modulate = _random_brown_color()

	var mat := sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("phase_offset", randf() * TAU)


func _random_brown_color() -> Color:
	var h := randf_range(brown_hue_min, brown_hue_max)
	var s := randf_range(brown_sat_min, brown_sat_max)
	var v := randf_range(brown_val_min, brown_val_max)
	return Color.from_hsv(h, s, v)
