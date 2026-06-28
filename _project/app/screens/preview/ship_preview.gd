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

@onready var _magnet: Node2D = $Magnet
@onready var _storage_marker: ColorRect = $StorageMarker
@onready var _hazard_pattern: TextureRect = $StorageMarker/HazardPattern


func apply_run_loadout(loadout: RunLoadout) -> void:
	if loadout == null:
		return
	# The magnet's own apply_run_loadout re-stretches its sprite to magnet_width.
	if _magnet != null and _magnet.has_method("apply_run_loadout"):
		_magnet.apply_run_loadout(loadout)
	_update_storage_marker(loadout)


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
