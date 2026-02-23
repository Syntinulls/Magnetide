extends Node2D
class_name LevelParallaxBackground

@export_group("Bands")
## List of background bands to render (ordered back to front).
@export var bands: Array[BackgroundBand] = []

@export_group("Positioning")
## Extra horizontal padding beyond viewport as ratio of screen width.
@export var padding_ratio: float = 0.1
## X position ratio where objects are recycled (left of screen, can be negative).
@export var despawn_x_ratio: float = -0.08
## Y ratio for the horizon (top of background area).
@export var horizon_y_ratio: float = 0.5

@export_group("Perspective Background")
## Texture for the perspective background covering all bands.
@export var background_texture: Texture2D
## Width ratio at the bottom of the trapezoid (relative to screen width).
@export var bottom_width_ratio: float = 2.0
## Scroll speed ratio for the background (relative to level speed).
@export var background_speed_ratio: float = 0.3

const REFERENCE_HEIGHT: float = 1440.0  # Scale values are tuned for 1440p

var _trash_textures: Array[Texture2D] = []
var _level: Node = null
var _viewport_anchor: ViewportAnchor = null
var _band_sprites: Array[Array] = []
var _perspective_background: TextureRect = null
var _bg_scroll_offset: float = 0.0
var _perspective_shader: Shader = null


func _ready() -> void:
	y_sort_enabled = true
	_trash_textures = [
		preload("res://_project/objects/sprites/trash_small_half.png"),
		preload("res://_project/objects/sprites/trash_medium_half.png"),
	]
	_perspective_shader = preload("res://_project/level/decoration/perspective_scroll.gdshader")

	_level = _find_level_node()
	if _level and "viewport_anchor" in _level:
		_viewport_anchor = _level.viewport_anchor
		_viewport_anchor.viewport_changed.connect(_on_viewport_changed)
	
	# Always defer initial generation - _regenerate_bands clears first so it's safe
	call_deferred("_regenerate_bands")


func _find_level_node() -> Node:
	# Traverse up the tree to find the Level node (may be past SubViewport)
	var node := get_parent()
	while node:
		if "level_speed" in node and "viewport_anchor" in node:
			return node
		node = node.get_parent()
	return null


func _on_viewport_changed(_size: Vector2) -> void:
	# Always regenerate on viewport change - _regenerate_bands clears existing nodes first
	_regenerate_bands()


func _regenerate_bands() -> void:
	for sprites_array in _band_sprites:
		for sprite in sprites_array:
			sprite.queue_free()
	if _perspective_background:
		_perspective_background.queue_free()
		_perspective_background = null
	_band_sprites.clear()
	_bg_scroll_offset = 0.0
	_generate_bands()


func _get_level_speed() -> float:
	if _level and "level_speed" in _level:
		return _level.level_speed
	return 0.0


func _get_haze_color() -> Color:
	if _level and "haze_color" in _level:
		return _level.haze_color
	return Color(0.85, 0.65, 0.4, 1.0)


func _get_haze_intensity() -> float:
	if _level and "haze_intensity" in _level:
		return _level.haze_intensity
	return 0.7


func _get_screen_size() -> Vector2:
	if _viewport_anchor:
		return _viewport_anchor.size
	return get_viewport().get_visible_rect().size


func _get_screen_width() -> float:
	return _get_screen_size().x


func _get_padding() -> float:
	return _get_screen_width() * padding_ratio


func _get_despawn_x() -> float:
	return _get_screen_width() * despawn_x_ratio


func _get_band_y_min(band: BackgroundBand) -> float:
	return band.y_min * _get_screen_size().y


func _get_band_y_max(band: BackgroundBand) -> float:
	return band.y_max * _get_screen_size().y


func _generate_bands() -> void:
	var screen_size := _get_screen_size()
	var screen_width := screen_size.x
	var screen_height := screen_size.y
	
	# Create single perspective background covering horizon to bottom
	if background_texture:
		var horizon_y := horizon_y_ratio * screen_height
		var bg_height := screen_height - horizon_y
		
		var bg := TextureRect.new()
		bg.texture = background_texture
		bg.z_index = -100  # Behind all trash objects
		
		# Size to cover full width and from horizon to bottom
		bg.size = Vector2(screen_width, bg_height)
		bg.position = Vector2(0, horizon_y)
		
		# Use TILE stretch mode - texture tiles based on size ratio
		bg.stretch_mode = TextureRect.STRETCH_TILE
		
		# Apply perspective shader
		var shader_material := ShaderMaterial.new()
		shader_material.shader = _perspective_shader
		shader_material.set_shader_parameter("scroll_offset", 0.0)
		shader_material.set_shader_parameter("bottom_width_ratio", bottom_width_ratio)
		# Calculate how many times texture tiles in each direction
		var tex_size := background_texture.get_size()
		var scale_factor := screen_height / REFERENCE_HEIGHT
		var effective_tex_width := tex_size.x * scale_factor
		var effective_tex_height := tex_size.y * scale_factor
		var x_tiles := screen_width / effective_tex_width
		var y_tiles := bg_height / effective_tex_height
		shader_material.set_shader_parameter("x_tiles", x_tiles)
		shader_material.set_shader_parameter("y_tiles", y_tiles)
		bg.material = shader_material
		
		_perspective_background = bg
		add_child(bg)
	
	# Create trash sprites for each band
	for band_index in range(bands.size()):
		var band := bands[band_index]
		
		# Create trash sprites
		var sprites: Array[Sprite2D] = []

		for _i in range(band.sprite_count):
			var sprite := _create_band_sprite(band)
			sprites.append(sprite)
			add_child(sprite)

		_band_sprites.append(sprites)


func _create_band_sprite(band: BackgroundBand) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _trash_textures[randi() % _trash_textures.size()]

	var screen_width := _get_screen_width()
	var padding := _get_padding()
	var y_min := _get_band_y_min(band)
	var y_max := _get_band_y_max(band)

	var x := randf_range(-padding, screen_width + padding)
	var y := randf_range(y_min, y_max)
	sprite.position = Vector2(x, y)

	_apply_y_based_properties(band, sprite, y)

	sprite.rotation = deg_to_rad(randf_range(-10.0, 10.0))

	return sprite


func _process(delta: float) -> void:
	var level_speed := _get_level_speed()
	if level_speed <= 0.0:
		return

	var despawn_x := _get_despawn_x()

	# Scroll perspective background
	_scroll_perspective_background(level_speed, delta)
	
	# Base scroll speed for the perspective background
	var base_scroll_speed := level_speed * background_speed_ratio
	var screen_size := _get_screen_size()
	var screen_height := screen_size.y
	var horizon_y := horizon_y_ratio * screen_height
	var bg_height := screen_height - horizon_y
	
	var band_count := mini(_band_sprites.size(), bands.size())
	for band_index in range(band_count):
		var sprites: Array = _band_sprites[band_index]
		var band := bands[band_index]

		for i in range(sprites.size()):
			var sprite: Sprite2D = sprites[i]
			
			# Calculate width ratio at sprite's Y position to match perspective texture speed
			# Shader uses: mix(bottom_width_ratio, top_width_ratio, uv.y)
			# uv.y=0 is horizon (top of rect), uv.y=1 is bottom of screen
			# So at horizon: width = bottom_width_ratio, at bottom: width = 1.0
			# Larger width = texture zoomed out = slower apparent pixel movement
			var sprite_y_ratio := (sprite.position.y - horizon_y) / bg_height
			sprite_y_ratio = clampf(sprite_y_ratio, 0.0, 1.0)
			var width_at_y := lerpf(bottom_width_ratio, 1.0, sprite_y_ratio)
			
			# Move sprite at speed inversely proportional to width (wider = slower)
			sprite.position.x -= (base_scroll_speed / width_at_y) * delta

			if sprite.position.x < despawn_x:
				_recycle_band_sprite(band, sprite, band_index, i)


func _scroll_perspective_background(level_speed: float, delta: float) -> void:
	if not _perspective_background:
		return
	
	var scroll_speed := level_speed * background_speed_ratio
	var screen_width := _get_screen_width()
	
	# Update offset (normalized 0-1 range for UV)
	_bg_scroll_offset += (scroll_speed * delta) / screen_width
	
	# Wrap offset to 0-1 range
	_bg_scroll_offset = fmod(_bg_scroll_offset, 1.0)
	
	# Update shader parameter
	var shader_mat := _perspective_background.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("scroll_offset", _bg_scroll_offset)


func _recycle_band_sprite(band: BackgroundBand, sprite: Sprite2D, band_index: int, _sprite_index: int) -> void:
	var y_min := _get_band_y_min(band)
	var y_max := _get_band_y_max(band)
	var y := randf_range(y_min, y_max)
	sprite.position.y = y

	var y_tolerance := (y_max - y_min) * 0.1
	var rightmost := _get_rightmost_x_near_y(band_index, y, y_tolerance)
	# Scale spacing relative to viewport width for resolution independence
	var spacing_scale := _get_screen_width() / (REFERENCE_HEIGHT * 16.0 / 9.0)
	var scaled_spacing := band.max_spacing * spacing_scale
	sprite.position.x = rightmost + randf_range(scaled_spacing * 0.5, scaled_spacing)

	_apply_y_based_properties(band, sprite, y)

	sprite.rotation = deg_to_rad(randf_range(-10.0, 10.0))


func _get_rightmost_x_near_y(band_index: int, target_y: float, tolerance: float) -> float:
	var rightmost: float = _get_screen_width() + _get_padding()
	var sprites: Array = _band_sprites[band_index]
	for sprite in sprites:
		if absf(sprite.position.y - target_y) <= tolerance:
			if sprite.position.x > rightmost:
				rightmost = sprite.position.x
	return rightmost


func _apply_y_based_properties(band: BackgroundBand, sprite: Sprite2D, y: float) -> void:
	var y_min := _get_band_y_min(band)
	var y_max := _get_band_y_max(band)
	var y_ratio := (y - y_min) / (y_max - y_min)
	y_ratio = clampf(y_ratio, 0.0, 1.0)

	var jitter := randf_range(-0.1, 0.1)
	var adjusted_ratio := clampf(y_ratio + jitter, 0.0, 1.0)

	# Scale relative to viewport height for resolution independence
	var scale_factor := _get_screen_size().y / REFERENCE_HEIGHT
	var s := lerpf(band.scale_min, band.scale_max, adjusted_ratio) * scale_factor
	sprite.scale = Vector2(s, s)

	var a := band.alpha * lerpf(0.7, 1.0, adjusted_ratio)
	sprite.modulate = Color(1.0, 1.0, 1.0, a)
