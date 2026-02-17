extends Node2D
class_name TrashOceanBackground

@export_group("Bands")
## List of background bands to render (ordered back to front).
@export var bands: Array[BackgroundBand] = []

@export_group("Positioning")
## Extra horizontal padding beyond viewport as ratio of screen width.
@export var padding_ratio: float = 0.1
## X position ratio where objects are recycled (left of screen, can be negative).
@export var despawn_x_ratio: float = -0.08

var _icon_texture: Texture2D
var _level: Node = null
var _viewport_anchor: ViewportAnchor = null
var _band_sprites: Array[Array] = []
var _band_speed_ratios: Array[Array] = []


func _ready() -> void:
	y_sort_enabled = true
	_icon_texture = preload("res://icon.svg")

	_level = get_parent()
	if _level and "viewport_anchor" in _level:
		_viewport_anchor = _level.viewport_anchor
		_viewport_anchor.viewport_changed.connect(_on_viewport_changed)

	_generate_bands()


func _on_viewport_changed(_size: Vector2) -> void:
	_regenerate_bands()


func _regenerate_bands() -> void:
	for sprites_array in _band_sprites:
		for sprite in sprites_array:
			sprite.queue_free()
	_band_sprites.clear()
	_band_speed_ratios.clear()
	_generate_bands()


func _get_level_speed() -> float:
	if _level and "level_speed" in _level:
		return _level.level_speed
	return 0.0


func _get_screen_width() -> float:
	if _viewport_anchor:
		return _viewport_anchor.size.x
	return get_viewport().get_visible_rect().size.x


func _get_padding() -> float:
	return _get_screen_width() * padding_ratio


func _get_despawn_x() -> float:
	return _get_screen_width() * despawn_x_ratio


func _get_band_y_min(band: BackgroundBand) -> float:
	return band.y_min * get_viewport().get_visible_rect().size.y


func _get_band_y_max(band: BackgroundBand) -> float:
	return band.y_max * get_viewport().get_visible_rect().size.y


func _generate_bands() -> void:
	for band_index in range(bands.size()):
		var band := bands[band_index]
		var sprites: Array[Sprite2D] = []
		var speeds: Array[float] = []

		for _i in range(band.sprite_count):
			var sprite := _create_band_sprite(band)
			var speed_ratio := _calculate_speed_ratio(band, sprite.position.y)
			sprites.append(sprite)
			speeds.append(speed_ratio)
			add_child(sprite)

		_band_sprites.append(sprites)
		_band_speed_ratios.append(speeds)


func _create_band_sprite(band: BackgroundBand) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _icon_texture

	var screen_width := _get_screen_width()
	var padding := _get_padding()
	var y_min := _get_band_y_min(band)
	var y_max := _get_band_y_max(band)

	var x := randf_range(-padding, screen_width + padding)
	var y := randf_range(y_min, y_max)
	sprite.position = Vector2(x, y)

	_apply_y_based_properties(band, sprite, y)

	sprite.rotation = randf_range(0.0, TAU)

	return sprite


func _process(delta: float) -> void:
	var level_speed := _get_level_speed()
	if level_speed <= 0.0:
		return

	var despawn_x := _get_despawn_x()

	for band_index in range(_band_sprites.size()):
		var sprites: Array = _band_sprites[band_index]
		var speed_ratios: Array = _band_speed_ratios[band_index]
		var band := bands[band_index]

		for i in range(sprites.size()):
			var sprite: Sprite2D = sprites[i]
			var speed_ratio: float = speed_ratios[i]
			sprite.position.x -= level_speed * speed_ratio * delta

			if sprite.position.x < despawn_x:
				_recycle_band_sprite(band, sprite, band_index, i)


func _recycle_band_sprite(band: BackgroundBand, sprite: Sprite2D, band_index: int, sprite_index: int) -> void:
	var y_min := _get_band_y_min(band)
	var y_max := _get_band_y_max(band)
	var y := randf_range(y_min, y_max)
	sprite.position.y = y

	var y_tolerance := (y_max - y_min) * 0.1
	var rightmost := _get_rightmost_x_near_y(band_index, y, y_tolerance)
	sprite.position.x = rightmost + randf_range(band.max_spacing * 0.5, band.max_spacing)

	_apply_y_based_properties(band, sprite, y)
	_band_speed_ratios[band_index][sprite_index] = _calculate_speed_ratio(band, y)

	sprite.rotation = randf_range(0.0, TAU)


func _get_rightmost_x_near_y(band_index: int, target_y: float, tolerance: float) -> float:
	var rightmost: float = _get_screen_width() + _get_padding()
	var sprites: Array = _band_sprites[band_index]
	for sprite in sprites:
		if absf(sprite.position.y - target_y) <= tolerance:
			if sprite.position.x > rightmost:
				rightmost = sprite.position.x
	return rightmost


func _calculate_speed_ratio(band: BackgroundBand, y: float) -> float:
	var y_min := _get_band_y_min(band)
	var y_max := _get_band_y_max(band)
	var y_ratio := (y - y_min) / (y_max - y_min)
	y_ratio = clampf(y_ratio, 0.0, 1.0)
	return lerpf(band.speed_ratio_min, band.speed_ratio_max, y_ratio)


func _apply_y_based_properties(band: BackgroundBand, sprite: Sprite2D, y: float) -> void:
	var y_min := _get_band_y_min(band)
	var y_max := _get_band_y_max(band)
	var y_ratio := (y - y_min) / (y_max - y_min)
	y_ratio = clampf(y_ratio, 0.0, 1.0)

	var jitter := randf_range(-0.1, 0.1)
	var adjusted_ratio := clampf(y_ratio + jitter, 0.0, 1.0)

	var s := lerpf(band.scale_min, band.scale_max, adjusted_ratio)
	sprite.scale = Vector2(s, s)

	var h := randf_range(band.brown_hue_min, band.brown_hue_max)
	var sat := lerpf(band.brown_sat_min, band.brown_sat_max, adjusted_ratio)
	var val := lerpf(band.brown_val_max, band.brown_val_min, adjusted_ratio)
	var a := band.alpha * lerpf(0.7, 1.0, adjusted_ratio)
	sprite.modulate = Color.from_hsv(h, sat, val, a)
