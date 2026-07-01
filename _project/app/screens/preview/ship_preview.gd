extends Node2D
class_name ShipPreview

## Render-only skeleton of the Ship used for the station screen preview. Renders
## the hull, generators, magnet, thrusters and storage-floor marker. It excludes
## gameplay-only nodes (research station, recycler, levers, pylons, boundaries,
## hitboxes, enemy target points). The magnet/thruster sub-scenes are reused as-is
## because they are self-contained and safe when not activated, so the preview
## stays visually faithful and updates in realtime as the loadout changes.

## Border thickness around the hazard floor marker (matches Ship._create_storage_floor_marker).
const STORAGE_BORDER_WIDTH: float = 6.0
## Dashed storage-area outline (same shader the in-game Ship uses), shown so the
## Storage Size upgrade's width AND height growth is visible in the preview.
const STORAGE_AREA_OUTLINE_SHADER: Shader = preload("res://_project/shaders/border_outline.gdshader")
const STORAGE_OUTLINE_WIDTH: float = 4.0
const STORAGE_OUTLINE_OPACITY: float = 0.9

@onready var _magnet: Node2D = $Magnet
@onready var _storage_marker: ColorRect = $StorageMarker
@onready var _hazard_pattern: TextureRect = $StorageMarker/HazardPattern

var _storage_outline_line: Line2D = null
var _storage_outline_material: ShaderMaterial = null


func apply_run_loadout(loadout: RunLoadout) -> void:
	if loadout == null:
		return
	# The magnet's own apply_run_loadout re-stretches its sprite to magnet_width.
	if _magnet != null and _magnet.has_method("apply_run_loadout"):
		_magnet.apply_run_loadout(loadout)
	_update_storage_marker(loadout)
	_update_storage_outline(loadout)


## Resize the hazard floor marker to match the storage area width/height, so the
## Storage Size upgrade is reflected in the preview in realtime.
func _update_storage_marker(loadout: RunLoadout) -> void:
	if _storage_marker == null:
		return
	var area_size := loadout.ship_storage_area_size
	var area_position := loadout.ship_storage_area_position
	var marker_height := loadout.ship_storage_marker_height
	_storage_marker.size = Vector2(
		area_size.x + STORAGE_BORDER_WIDTH * 2.0,
		marker_height + STORAGE_BORDER_WIDTH * 2.0
	)
	_storage_marker.position = Vector2(
		area_position.x - area_size.x * 0.5 - STORAGE_BORDER_WIDTH,
		area_position.y - marker_height - STORAGE_BORDER_WIDTH
	)
	if _hazard_pattern != null:
		_hazard_pattern.size = Vector2(area_size.x, marker_height)
		_hazard_pattern.position = Vector2(STORAGE_BORDER_WIDTH, STORAGE_BORDER_WIDTH)


## Trace the dashed storage-area rectangle so both the width and height of the
## Storage Size upgrade are shown. Geometry matches Ship._update_storage_area_outline_geometry.
func _update_storage_outline(loadout: RunLoadout) -> void:
	_ensure_storage_outline()
	var area_size := loadout.ship_storage_area_size
	var area_position := loadout.ship_storage_area_position
	var top_left := Vector2(
		area_position.x - area_size.x * 0.5,
		area_position.y - area_size.y
	)
	_storage_outline_line.points = PackedVector2Array([
		top_left,
		top_left + Vector2(area_size.x, 0.0),
		top_left + area_size,
		top_left + Vector2(0.0, area_size.y),
	])
	if _storage_outline_material != null:
		_storage_outline_material.set_shader_parameter("rect_top_left", top_left)
		_storage_outline_material.set_shader_parameter("rect_size", area_size)


func _ensure_storage_outline() -> void:
	if _storage_outline_line != null and is_instance_valid(_storage_outline_line):
		return
	_storage_outline_line = Line2D.new()
	_storage_outline_line.name = "StorageAreaOutline"
	_storage_outline_line.width = STORAGE_OUTLINE_WIDTH
	_storage_outline_line.default_color = Color.WHITE
	_storage_outline_line.closed = true
	_storage_outline_line.antialiased = true
	# Above the ship hull so the full rectangle stays visible in the preview.
	_storage_outline_line.z_index = 1
	_storage_outline_material = ShaderMaterial.new()
	_storage_outline_material.shader = STORAGE_AREA_OUTLINE_SHADER
	_storage_outline_material.set_shader_parameter("opacity", STORAGE_OUTLINE_OPACITY)
	_storage_outline_line.material = _storage_outline_material
	add_child(_storage_outline_line)
