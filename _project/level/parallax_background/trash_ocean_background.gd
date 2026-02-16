extends ParallaxBackground
class_name TrashOceanBackground

@export_group("Layer Settings")
## Number of parallax layers (farther layers appear smaller and slower).
@export var layer_count: int = 4
## Base number of sprites per layer (multiplied for farther layers).
@export var sprites_per_layer: int = 150

@export_group("Positioning")
## The Y position of the horizon line (top of the trash ocean).
@export var horizon_y: float = 200.0
## The Y position of the bottom of the visible trash ocean (extends below screen).
@export var ocean_bottom_y: float = 700.0
## Extra horizontal padding beyond viewport for parallax movement.
@export var ocean_padding: float = 200.0

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
var _buoyancy_shader: Shader


func _ready() -> void:
	_icon_texture = preload("res://icon.svg")
	_buoyancy_shader = preload("res://_project/level/parallax_background/buoyancy.gdshader")
	_generate_layers()


func _generate_layers() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_width := viewport_size.x

	for i in range(layer_count):
		var depth_ratio := float(i) / float(layer_count)
		var parallax_layer := ParallaxLayer.new()
		parallax_layer.motion_scale = Vector2(1.0 - depth_ratio * 0.8, 0.0)
		add_child(parallax_layer)

		var container := Node2D.new()
		parallax_layer.add_child(container)

		var sprite_count := int(sprites_per_layer * (1.0 + depth_ratio * 1.5))

		for _j in range(sprite_count):
			var sprite := Sprite2D.new()
			sprite.texture = _icon_texture

			var x := randf_range(-ocean_padding, screen_width + ocean_padding)
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

			sprite.z_index = -layer_count + i

			var mat := ShaderMaterial.new()
			mat.shader = _buoyancy_shader
			mat.set_shader_parameter("amplitude", randf_range(1.0, 3.0) * (1.0 - depth_ratio * 0.5))
			mat.set_shader_parameter("frequency", randf_range(1.0, 2.0))
			mat.set_shader_parameter("phase_offset", randf() * TAU)
			sprite.material = mat

			container.add_child(sprite)


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
