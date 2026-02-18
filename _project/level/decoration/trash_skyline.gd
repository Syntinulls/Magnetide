extends Node2D
class_name LevelSkyline

@export_group("Positioning")
## Y position ratio for the skyline (0.0 = top, 1.0 = bottom).
@export var horizon_y_ratio: float = 0.5
## Speed ratio relative to level_speed (should be slow for distant horizon).
@export var speed_ratio: float = 0.1

@export_group("Sprites")
## Maximum height of skyline sprites in pixels (for the front layer).
@export var max_height: float = 150.0

@export_group("Layers")
## Number of skyline layers to render.
@export var layer_count: int = 2
## Scale multiplier for each subsequent layer (e.g., 0.7 = 70% of previous layer).
@export var layer_scale_falloff: float = 0.7
## Darkness multiplier for each subsequent layer (0.0 = black, 1.0 = no change).
@export var layer_tint_falloff: float = 0.6
## Maximum random horizontal offset for layer starting positions.
@export var layer_offset_range: float = 300.0

var _skyline_textures: Array[Texture2D] = []
var _layer_sprites: Array[Array] = []  # Array of sprite arrays, one per layer
var _layer_offsets: Array[float] = []  # Random x offset for each layer
var _level: Node = null
var _viewport_anchor: ViewportAnchor = null


func _ready() -> void:
	_skyline_textures = [
		preload("res://_project/level/decoration/sprites/trash_mountain_1_crop1.png"),
		preload("res://_project/level/decoration/sprites/trash_mountain_2_crop1.png"),
		preload("res://_project/level/decoration/sprites/trash_mountain_3_crop1.png"),
	]
	
	_level = _find_level_node()
	if _level and "viewport_anchor" in _level:
		_viewport_anchor = _level.viewport_anchor
		_viewport_anchor.viewport_changed.connect(_on_viewport_changed)
	
	# Defer generation to ensure viewport size is correct
	call_deferred("_generate_skyline")


func _find_level_node() -> Node:
	# Traverse up the tree to find the Level node (may be past SubViewport)
	var node := get_parent()
	while node:
		if "level_speed" in node and "viewport_anchor" in node:
			return node
		node = node.get_parent()
	return null


func _on_viewport_changed(_size: Vector2) -> void:
	_regenerate_skyline()


func _regenerate_skyline() -> void:
	for layer_sprites in _layer_sprites:
		for sprite in layer_sprites:
			sprite.queue_free()
	_layer_sprites.clear()
	_layer_offsets.clear()
	_generate_skyline()


func _get_level_speed() -> float:
	if _level and "level_speed" in _level:
		return _level.level_speed
	return 0.0


func _get_screen_size() -> Vector2:
	if _viewport_anchor:
		return _viewport_anchor.size
	return get_viewport().get_visible_rect().size


func _get_screen_width() -> float:
	return _get_screen_size().x


func _get_horizon_y() -> float:
	return horizon_y_ratio * _get_screen_size().y


func _generate_skyline() -> void:
	var screen_width := _get_screen_width()
	var horizon_y := _get_horizon_y()
	
	# Generate layers from back to front (last layer first, so first layer renders on top)
	for layer_index in range(layer_count - 1, -1, -1):
		var layer_sprites: Array[Sprite2D] = []
		var layer_scale := _get_layer_scale(layer_index)
		var layer_tint := _get_layer_tint(layer_index)
		var layer_z := -50 - layer_index  # First layer (index 0) has highest z_index, renders on top
		
		# Random offset for this layer
		var layer_offset := randf_range(-layer_offset_range, layer_offset_range)
		_layer_offsets.insert(0, layer_offset)  # Insert at front to match layer order
		
		# Generate enough sprites to cover screen plus buffer
		var x_pos := layer_offset
		while x_pos < screen_width + 500.0:
			var sprite := _create_skyline_sprite(x_pos, horizon_y, layer_scale, layer_tint, layer_z)
			x_pos += sprite.texture.get_size().x * sprite.scale.x
			layer_sprites.append(sprite)
			add_child(sprite)
		
		_layer_sprites.insert(0, layer_sprites)  # Insert at front to match layer order


func _get_layer_scale(layer_index: int) -> float:
	# First layer (index 0) is full scale, subsequent layers are progressively smaller
	return max_height * pow(layer_scale_falloff, layer_index)


func _get_layer_tint(layer_index: int) -> Color:
	# Apply layer-based darkening for depth between layers
	var layer_darken := pow(layer_tint_falloff, layer_index)
	return Color(layer_darken, layer_darken, layer_darken, 1.0)


func _create_skyline_sprite(x_pos: float, horizon_y: float, layer_height: float, tint: Color, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _skyline_textures[randi() % _skyline_textures.size()]
	
	# Scale based on layer height
	var tex_size := sprite.texture.get_size()
	var scale_factor := layer_height / tex_size.y
	sprite.scale = Vector2(scale_factor, scale_factor)
	
	# Position at horizon with left edge at x_pos, bottom edge at horizon_y
	var scaled_width := tex_size.x * scale_factor
	var scaled_height := tex_size.y * scale_factor
	sprite.position = Vector2(x_pos + scaled_width / 2.0, horizon_y - scaled_height / 2.0)
	
	sprite.z_index = z
	sprite.modulate = tint
	
	return sprite


func _process(delta: float) -> void:
	var level_speed := _get_level_speed()
	if level_speed <= 0.0:
		return
	
	var scroll_speed := level_speed * speed_ratio
	var horizon_y := _get_horizon_y()
	var screen_width := _get_screen_width()
	
	# Process each layer
	for layer_index in range(_layer_sprites.size()):
		var layer_sprites: Array = _layer_sprites[layer_index]
		var layer_scale := _get_layer_scale(layer_index)
		var layer_tint := _get_layer_tint(layer_index)
		var layer_z := -50 - layer_index
		
		# Move all sprites in this layer
		for sprite in layer_sprites:
			sprite.position.x -= scroll_speed * delta
		
		# Check for sprites that need recycling (fully off left side)
		for sprite: Sprite2D in layer_sprites:
			var sprite_right: float = sprite.position.x + (sprite.texture.get_size().x * sprite.scale.x) / 2.0
			if sprite_right < 0.0:
				_recycle_sprite(sprite, horizon_y, layer_sprites, layer_scale, layer_tint, layer_z)
		
		# Ensure we have enough sprites to cover the viewport
		_ensure_coverage(horizon_y, screen_width, layer_sprites, layer_scale, layer_tint, layer_z)


func _recycle_sprite(sprite: Sprite2D, horizon_y: float, layer_sprites: Array, layer_height: float, tint: Color, z: int) -> void:
	# Find rightmost sprite edge in this layer
	var rightmost_x := 0.0
	for s: Sprite2D in layer_sprites:
		var right_edge: float = s.position.x + (s.texture.get_size().x * s.scale.x) / 2.0
		if right_edge > rightmost_x:
			rightmost_x = right_edge
	
	# Change texture
	sprite.texture = _skyline_textures[randi() % _skyline_textures.size()]
	
	# Scale based on layer height
	var tex_size := sprite.texture.get_size()
	var scale_factor := layer_height / tex_size.y
	sprite.scale = Vector2(scale_factor, scale_factor)
	
	# Position flush with rightmost sprite (left edge at rightmost_x)
	var scaled_width := tex_size.x * scale_factor
	var scaled_height := tex_size.y * scale_factor
	sprite.position.x = rightmost_x + scaled_width / 2.0
	sprite.position.y = horizon_y - scaled_height / 2.0
	sprite.z_index = z
	sprite.modulate = tint


func _ensure_coverage(horizon_y: float, screen_width: float, layer_sprites: Array, layer_height: float, tint: Color, z: int) -> void:
	# Find rightmost sprite edge in this layer
	var rightmost_x := 0.0
	for s: Sprite2D in layer_sprites:
		var right_edge: float = s.position.x + (s.texture.get_size().x * s.scale.x) / 2.0
		if right_edge > rightmost_x:
			rightmost_x = right_edge
	
	# Generate more sprites if rightmost edge doesn't cover viewport
	while rightmost_x < screen_width + 100.0:
		var sprite := _create_skyline_sprite(rightmost_x, horizon_y, layer_height, tint, z)
		rightmost_x += sprite.texture.get_size().x * sprite.scale.x
		layer_sprites.append(sprite)
		add_child(sprite)
