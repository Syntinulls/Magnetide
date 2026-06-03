extends Node2D
class_name SalvagePile

enum Rarity { COMMON, RARE, EPIC, LEGENDARY, ARTIFACT }

const RARITY_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.0, 0.8, 0.0),      # Green
	Rarity.RARE: Color(0.2, 0.4, 1.0),        # Blue
	Rarity.EPIC: Color(0.6, 0.2, 0.8),        # Purple
	Rarity.LEGENDARY: Color(1.0, 0.85, 0.0),  # Yellow/Gold
	Rarity.ARTIFACT: Color("4fffe8"),
}

var _pile_textures: Array[Texture2D] = []
var direction: Vector2 = Vector2.LEFT
var rarity: Rarity = Rarity.COMMON
var is_active: bool = false
var pile_data: SalvagePileData = null
var _level: Node = null
var _surface_line: Line2D = null  # Bezier curve along top edge of pile sprite


func _ready() -> void:
	_pile_textures = [
		preload("res://_project/level/salvage/pile/sprites/trash_pile_1.png"),
		preload("res://_project/level/salvage/pile/sprites/trash_pile_2.png"),
		preload("res://_project/level/salvage/pile/sprites/trash_pile_3.png"),
	]
	deactivate()


func activate(new_rarity: Rarity, spawn_position: Vector2, level: Node, target_height: float, _new_rotation: float) -> void:
	rarity = new_rarity
	position = spawn_position
	_level = level
	rotation = deg_to_rad(randf_range(-3.0, 3.0))  # Subtle random rotation

	var sprite := $Sprite2D as Sprite2D
	if sprite and _pile_textures.size() > 0:
		var tex_idx := randi() % _pile_textures.size()
		sprite.texture = _pile_textures[tex_idx]
		
		# Apply rarity color via shader tint_color parameter
		var tint: Color = RARITY_COLORS.get(rarity, Color.WHITE)
		if sprite.material:
			var shader_mat := sprite.material as ShaderMaterial
			if shader_mat:
				shader_mat.set_shader_parameter("tint_color", tint)
		
		# Calculate uniform scale to achieve target height
		var tex_size := sprite.texture.get_size()
		if tex_size.y > 0:
			var uniform_scale := target_height / tex_size.y
			scale = Vector2(uniform_scale, uniform_scale)
		
		# Offset sprite so it's anchored at bottom center (extends upward from parent position)
		sprite.offset = Vector2(0.0, -tex_size.y / 2.0)

	is_active = true
	visible = true
	z_index = 5
	set_process(true)
	
	# Generate surface line for magnet pull Phase 2 detection
	_generate_surface_line()


func deactivate() -> void:
	is_active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not is_active:
		return

	var level_speed := _get_level_speed()
	if level_speed <= 0.0:
		return

	position += direction * level_speed * delta


func _get_level_speed() -> float:
	if _level and "level_speed" in _level:
		return _level.level_speed
	return 0.0


# ============================================================================
# SURFACE LINE SYSTEM (for Phase 2 detection)
# ============================================================================

## Get the surface line for magnet pull Phase 2 detection
func get_surface_line() -> Line2D:
	return _surface_line


## Initialize the surface line reference from the scene's Line2D node.
## The Line2D is manually positioned in the scene to match the pile sprite contour.
func _generate_surface_line() -> void:
	_surface_line = $Sprite2D/Line2D as Line2D
	if _surface_line:
		_surface_line.visible = false  # Hidden in production
	else:
		push_warning("SalvagePile: Line2D not found at Sprite2D/Line2D")


## Get the Y position of the surface line at a given local X coordinate
func get_surface_y_at_x(local_x: float) -> float:
	if not _surface_line or _surface_line.points.size() < 2:
		return -INF  # No surface line
	
	var points := _surface_line.points
	
	# Find the two points that bracket the given X
	for i in range(points.size() - 1):
		var p1 := points[i]
		var p2 := points[i + 1]
		
		if (p1.x <= local_x and local_x <= p2.x) or (p2.x <= local_x and local_x <= p1.x):
			# Interpolate Y between these two points
			var t := (local_x - p1.x) / (p2.x - p1.x) if abs(p2.x - p1.x) > 0.001 else 0.0
			return lerpf(p1.y, p2.y, t)
	
	# X is outside the line bounds - return nearest endpoint
	if local_x < points[0].x:
		return points[0].y
	return points[points.size() - 1].y
