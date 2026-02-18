extends Node2D

## The speed at which the level scrolls (used by trash stream and foreground).
@export var level_speed: float = 300.0
## The Y position of the ocean surface as ratio of viewport height.
@export var surface_y_ratio: float = 0.46

@export_group("Atmospheric Haze")
## Fog/haze color for atmospheric depth effect.
@export var haze_color: Color = Color(0.85, 0.65, 0.4, 1.0)
## Maximum haze intensity at the horizon (0 = no haze, 1 = full haze color).
@export var haze_intensity: float = 0.7
## Falloff exponent for haze density (higher = more concentrated at horizon, lower = more spread out).
## 1.0 = linear, 2.0 = quadratic, 0.5 = square root (spreads further down).
@export var haze_falloff: float = 2.0

@export_group("Ship Positioning")
## Ship X position as ratio of viewport width.
@export var ship_x_ratio: float = 0.5
## Ship Y position as ratio of viewport height.
@export var ship_y_ratio: float = 0.44

var viewport_anchor: ViewportAnchor
var _fog_overlay: TextureRect = null
var _fog_shader: Shader = null

@onready var _parallax_viewport: SubViewport = $ParallaxViewportContainer/ParallaxViewport
@onready var _parallax_container: SubViewportContainer = $ParallaxViewportContainer

var surface_y: float:
	get:
		if viewport_anchor:
			return viewport_anchor.get_y(surface_y_ratio)
		return 500.0

@onready var ship: Node2D = $Ship


func _enter_tree() -> void:
	viewport_anchor = ViewportAnchor.new()
	add_child(viewport_anchor)


func _ready() -> void:
	viewport_anchor.viewport_changed.connect(_on_viewport_changed)
	# Defer to ensure @onready variables are resolved and viewport size is available
	call_deferred("_update_parallax_viewport_size")
	call_deferred("_create_fog_overlay")
	call_deferred("_update_positions")


func _on_viewport_changed(_size: Vector2) -> void:
	_update_parallax_viewport_size()
	_update_positions()
	_update_fog_overlay()


func _update_parallax_viewport_size() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0:
		return
	
	# Manually set container size since it's a child of Node2D, not a Control
	if _parallax_container:
		_parallax_container.size = screen_size
	
	# SubViewport should auto-resize with stretch=true, but set it explicitly too
	if _parallax_viewport:
		_parallax_viewport.size = Vector2i(int(screen_size.x), int(screen_size.y))


func _create_fog_overlay() -> void:
	_fog_shader = preload("res://_project/level/decoration/fog_overlay.gdshader")
	
	# Create a 1x1 white placeholder texture - shader handles all the fog coloring
	var placeholder := PlaceholderTexture2D.new()
	placeholder.size = Vector2(1, 1)
	
	_fog_overlay = TextureRect.new()
	_fog_overlay.texture = placeholder
	_fog_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fog_overlay.z_index = -49  # Above parallax content
	
	# Apply shader that handles fog with exponential falloff
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _fog_shader
	shader_material.set_shader_parameter("haze_color", haze_color)
	shader_material.set_shader_parameter("haze_intensity", haze_intensity)
	shader_material.set_shader_parameter("haze_falloff", haze_falloff)
	_fog_overlay.material = shader_material
	
	add_child(_fog_overlay)
	_update_fog_overlay()


func _update_fog_overlay() -> void:
	if not viewport_anchor or not _fog_overlay:
		return
	
	var screen_size := viewport_anchor.size
	
	# Cover full screen - shader will mask to parallax content only
	_fog_overlay.position = Vector2(0, 0)
	_fog_overlay.size = screen_size
	
	# Update shader with parallax viewport texture
	if _parallax_viewport and _fog_overlay.material:
		var shader_mat := _fog_overlay.material as ShaderMaterial
		if shader_mat:
			shader_mat.set_shader_parameter("parallax_texture", _parallax_viewport.get_texture())


func _update_positions() -> void:
	if not viewport_anchor:
		return
	
	if ship:
		ship.position = viewport_anchor.get_position(ship_x_ratio, ship_y_ratio)
