extends SubViewportContainer
class_name PreviewStage

## Hosts a render-only preview scene (player or ship) inside a SubViewport and
## displays it as a UI element. A Camera2D frames the content; `set_loadout()`
## forwards the loadout to the preview instance so it updates in realtime.

@export var preview_scene: PackedScene = null
@export var camera_offset: Vector2 = Vector2.ZERO
@export var camera_zoom: float = 1.0

var _viewport: SubViewport = null
var _camera: Camera2D = null
var _preview_instance: Node = null
var _pending_loadout: RunLoadout = null


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_camera = Camera2D.new()
	_camera.position = camera_offset
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
	_viewport.add_child(_camera)
	_camera.make_current()

	if preview_scene != null:
		_preview_instance = preview_scene.instantiate()
		_viewport.add_child(_preview_instance)

	if _pending_loadout != null:
		set_loadout(_pending_loadout)
		_pending_loadout = null


func set_loadout(loadout: RunLoadout) -> void:
	if loadout == null:
		return
	if _preview_instance == null:
		_pending_loadout = loadout
		return
	if _preview_instance.has_method("apply_run_loadout"):
		_preview_instance.apply_run_loadout(loadout)


func set_camera(offset: Vector2, zoom: float) -> void:
	camera_offset = offset
	camera_zoom = zoom
	if _camera != null:
		_camera.position = offset
		_camera.zoom = Vector2(zoom, zoom)
