extends Node2D
class_name TrashOceanBackground

@export_group("Layer Settings")
## Total number of background sprites.
@export var sprite_count: int = 400

@export_group("Positioning")
## The Y position of the horizon line (top of the trash ocean).
@export var horizon_y: float = 200.0
## The Y position of the bottom of the visible trash ocean (extends below screen).
@export var ocean_bottom_y: float = 700.0
## Extra horizontal padding beyond viewport.
@export var ocean_padding: float = 200.0
## X position where objects are recycled (left of screen).
@export var despawn_x: float = -150.0
## Minimum speed ratio for objects at the horizon (0.0-1.0).
@export var min_speed_ratio: float = 0.1

@export_group("Appearance")
## Minimum brown tint hue shift.
@export var brown_hue_min: float = 0.05
## Maximum brown tint hue shift.
@export var brown_hue_max: float = 0.12
## Minimum saturation for brown tints.
@export var brown_sat_min: float = 0.3
## Maximum saturation for brown tints.
@export var brown_sat_max: float = 0.6
## Minimum value/brightness for brown tints.
@export var brown_val_min: float = 0.2
## Maximum value/brightness for brown tints.
@export var brown_val_max: float = 0.5

var _icon_texture: Texture2D
var _screen_width: float = 0.0
var _level_speed: float = 150.0
var _sprites: Array[Sprite2D] = []
var _sprite_speeds: Array[float] = []


func _ready() -> void:
	_icon_texture = preload("res://icon.svg")

	var level := get_parent()
	if level and "level_speed" in level:
		_level_speed = level.level_speed

	_generate_sprites()


func _generate_sprites() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_screen_width = viewport_size.x

	for _i in range(sprite_count):
		var sprite := Sprite2D.new()
		sprite.texture = _icon_texture

		var x := randf_range(-ocean_padding, _screen_width + ocean_padding)
		var t := randf()
		var y_ratio := t * t
		var y := lerpf(horizon_y, ocean_bottom_y, y_ratio)
		sprite.position = Vector2(x, y)

		var base_scale := lerpf(0.15, 0.8, y_ratio)
		var s := base_scale * randf_range(0.8, 1.2)
		sprite.scale = Vector2(s, s)

		sprite.rotation = randf_range(0.0, TAU)

		var color_depth := 1.0 - y_ratio
		sprite.modulate = _random_brown_color(color_depth)

		sprite.z_index = -10 + int(y_ratio * 10)

		var speed_ratio := lerpf(min_speed_ratio, 1.0, y_ratio * y_ratio)
		var speed := _level_speed * speed_ratio
		_sprite_speeds.append(speed)

		_sprites.append(sprite)
		add_child(sprite)


func _process(delta: float) -> void:
	for i in range(_sprites.size()):
		var sprite := _sprites[i]
		var speed := _sprite_speeds[i]
		sprite.position.x -= speed * delta

		if sprite.position.x < despawn_x:
			_recycle_sprite(i)


func _recycle_sprite(index: int) -> void:
	var sprite := _sprites[index]

	sprite.position.x = _screen_width + ocean_padding + randf_range(0.0, 100.0)

	var t := randf()
	var y_ratio := t * t
	var y := lerpf(horizon_y, ocean_bottom_y, y_ratio)
	sprite.position.y = y

	var base_scale := lerpf(0.15, 0.8, y_ratio)
	var s := base_scale * randf_range(0.8, 1.2)
	sprite.scale = Vector2(s, s)

	sprite.rotation = randf_range(0.0, TAU)

	var color_depth := 1.0 - y_ratio
	sprite.modulate = _random_brown_color(color_depth)

	sprite.z_index = -10 + int(y_ratio * 10)

	var speed_ratio := lerpf(min_speed_ratio, 1.0, y_ratio * y_ratio)
	_sprite_speeds[index] = _level_speed * speed_ratio


func _random_brown_color(depth_ratio: float) -> Color:
	var h := randf_range(brown_hue_min, brown_hue_max)
	var s := randf_range(brown_sat_min, brown_sat_max)
	var v := randf_range(brown_val_min, brown_val_max)
	s = lerpf(s, s * 0.3, depth_ratio)
	v = lerpf(v, minf(v * 1.8, 1.0), depth_ratio)
	var a := 1.0
	if depth_ratio > 0.8:
		var fade_ratio := (depth_ratio - 0.8) / 0.2
		a = lerpf(1.0, 0.3, fade_ratio)
	return Color.from_hsv(h, s, v, a)
