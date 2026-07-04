extends CanvasLayer
class_name LevelParallaxForeground

@export_group("Positioning")
## Y position ratio for the ground (0.0 = top, 1.0 = bottom).
@export var ground_y_ratio: float = 0.77

var _ground_textures: Array[Texture2D] = []
var _sprites: Array[Sprite2D] = []
var _container: Node2D
var _level: Node = null
var _viewport_anchor: ViewportAnchor = null


func _ready() -> void:
	# Above the world but below the storm vignette (5) and the game UI (10), so
	# the foreground ground is still covered by the acid-storm overlay.
	layer = 4
	_ground_textures = [
		preload("res://_project/level/decoration/sprites/ground_1.png"),
		preload("res://_project/level/decoration/sprites/ground_2.png"),
		preload("res://_project/level/decoration/sprites/ground_3.png"),
	]

	_level = get_parent()
	if _level and "viewport_anchor" in _level:
		_viewport_anchor = _level.viewport_anchor
		_viewport_anchor.viewport_changed.connect(_on_viewport_changed)

	# Defer generation to ensure viewport size is correct
	call_deferred("_generate_foreground")


func _on_viewport_changed(_size: Vector2) -> void:
	_regenerate_foreground()


func _regenerate_foreground() -> void:
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()
	if _container:
		_container.queue_free()
		_container = null
	_generate_foreground()


func _get_level_speed() -> float:
	if _level and "level_speed" in _level:
		return _level.level_speed
	return 0.0


func _get_screen_width() -> float:
	if _viewport_anchor:
		return _viewport_anchor.size.x
	return get_viewport().get_visible_rect().size.x


func _get_screen_height() -> float:
	if _viewport_anchor:
		return _viewport_anchor.size.y
	return get_viewport().get_visible_rect().size.y


func _get_ground_y() -> float:
	return _get_screen_height() * ground_y_ratio


func _generate_foreground() -> void:
	var screen_width := _get_screen_width()
	var ground_y := _get_ground_y()
	
	_container = Node2D.new()
	add_child(_container)
	
	# Generate enough sprites to cover screen plus buffer
	var x_pos := 0.0
	while x_pos < screen_width + 500.0:
		var sprite := _create_ground_sprite(x_pos, ground_y)
		x_pos += sprite.texture.get_size().x * sprite.scale.x
		_sprites.append(sprite)
		_container.add_child(sprite)


func _create_ground_sprite(x_pos: float, ground_y: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _ground_textures[randi() % _ground_textures.size()]
	
	# Scale to fit screen height from ground_y to bottom
	var screen_height := _get_screen_height()
	var desired_height := screen_height - ground_y + 50.0  # Extra to extend below screen
	var tex_size := sprite.texture.get_size()
	var scale_y := desired_height / tex_size.y
	var scale_x := scale_y  # Maintain aspect ratio
	sprite.scale = Vector2(scale_x, scale_y)
	
	# Position: anchor at top-left of texture
	var scaled_width := tex_size.x * scale_x
	var scaled_height := tex_size.y * scale_y
	sprite.position = Vector2(x_pos + scaled_width / 2.0, ground_y + scaled_height / 2.0)
	
	sprite.z_index = 100
	
	return sprite


func _process(delta: float) -> void:
	var level_speed := _get_level_speed()
	if level_speed <= 0.0:
		return
	
	var ground_y := _get_ground_y()
	var screen_width := _get_screen_width()
	
	# Move all sprites at full level speed (foreground = 1.0x speed)
	for sprite in _sprites:
		sprite.position.x -= level_speed * delta
	
	# Check for sprites that need recycling (fully off left side)
	for sprite in _sprites:
		var sprite_right := sprite.position.x + (sprite.texture.get_size().x * sprite.scale.x) / 2.0
		if sprite_right < 0.0:
			_recycle_sprite(sprite, ground_y)
	
	# Ensure we have enough sprites to cover the viewport
	_ensure_coverage(ground_y, screen_width)


func _recycle_sprite(sprite: Sprite2D, ground_y: float) -> void:
	# Find rightmost sprite
	var rightmost_x := 0.0
	for s in _sprites:
		var right_edge := s.position.x + (s.texture.get_size().x * s.scale.x) / 2.0
		if right_edge > rightmost_x:
			rightmost_x = right_edge
	
	# Change texture
	sprite.texture = _ground_textures[randi() % _ground_textures.size()]
	
	# Recalculate scale for new texture
	var screen_height := _get_screen_height()
	var desired_height := screen_height - ground_y + 50.0
	var tex_size := sprite.texture.get_size()
	var scale_y := desired_height / tex_size.y
	var scale_x := scale_y
	sprite.scale = Vector2(scale_x, scale_y)
	
	# Position after rightmost sprite
	var scaled_width := tex_size.x * scale_x
	var scaled_height := tex_size.y * scale_y
	sprite.position.x = rightmost_x + scaled_width / 2.0
	sprite.position.y = ground_y + scaled_height / 2.0


func _ensure_coverage(ground_y: float, screen_width: float) -> void:
	# Find rightmost sprite edge
	var rightmost_x := 0.0
	for s in _sprites:
		var right_edge := s.position.x + (s.texture.get_size().x * s.scale.x) / 2.0
		if right_edge > rightmost_x:
			rightmost_x = right_edge
	
	# Generate more sprites if rightmost edge doesn't cover viewport
	while rightmost_x < screen_width + 100.0:
		var sprite := _create_ground_sprite(rightmost_x, ground_y)
		rightmost_x += sprite.texture.get_size().x * sprite.scale.x
		_sprites.append(sprite)
		_container.add_child(sprite)
