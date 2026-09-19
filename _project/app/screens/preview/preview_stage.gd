extends SubViewportContainer
class_name PreviewStage

## Hosts a render-only preview scene (player or ship) inside a SubViewport and
## displays it as a UI element. A Camera2D frames the content; `set_loadout()`
## forwards the loadout to the preview instance so it updates in realtime.

@export var preview_scene: PackedScene = null
@export var camera_offset: Vector2 = Vector2.ZERO
@export var camera_zoom: float = 1.0
## When true the camera also pulls back far enough to fit whatever bounds the preview
## scene reports through `get_preview_content_bounds()`, on top of its authored frame.
## The ship's storage outline grows with its upgrade and at max level reached above the
## authored frame, so its top edge was cut off. A preview that reports no bounds, or
## leaves this off, keeps exactly the authored offset and zoom.
@export var fit_to_preview_bounds: bool = false

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
	_apply_camera_frame()


func _notification(what: int) -> void:
	# The viewport tracks this container's size, so the fitted zoom is recomputed whenever
	# the stage is resized.
	if what == NOTIFICATION_RESIZED and _camera != null:
		_apply_camera_frame()


func set_loadout(loadout: RunLoadout) -> void:
	if loadout == null:
		return
	if _preview_instance == null:
		_pending_loadout = loadout
		return
	if _preview_instance.has_method("apply_run_loadout"):
		_preview_instance.apply_run_loadout(loadout)
	_apply_camera_frame()


func set_camera(offset: Vector2, zoom: float) -> void:
	camera_offset = offset
	camera_zoom = zoom
	_apply_camera_frame()


## Point the camera at the authored frame, widened to also contain the preview's reported
## bounds. Zoom is chosen so the merged rectangle fits the viewport on both axes, so the
## framing only ever pulls back — never crops what the authored offset already showed.
func _apply_camera_frame() -> void:
	if _camera == null:
		return
	_camera.position = camera_offset
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
	if not fit_to_preview_bounds or _preview_instance == null:
		return
	if not _preview_instance.has_method("get_preview_content_bounds"):
		return
	var bounds: Rect2 = _preview_instance.call("get_preview_content_bounds")
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var viewport_size := Vector2(_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or camera_zoom <= 0.0:
		return
	var authored_size := viewport_size / camera_zoom
	var frame := Rect2(camera_offset - authored_size * 0.5, authored_size).merge(bounds)
	var fitted_zoom := minf(viewport_size.x / frame.size.x, viewport_size.y / frame.size.y)
	_camera.position = frame.get_center()
	_camera.zoom = Vector2(fitted_zoom, fitted_zoom)
