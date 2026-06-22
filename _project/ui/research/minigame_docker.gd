extends Control
class_name MinigameDocker

## Hosts a single minigame scene and scales it to fit this container.
##
## Minigames are authored at a fixed reference size (their custom_minimum_size)
## with absolute node positions. The docker instantiates the chosen scene and
## uniformly scales/centers it to fill the available space, so what is laid out
## in the editor is exactly what is rendered, regardless of window size.

const FALLBACK_REFERENCE_SIZE := Vector2(980.0, 590.0)

var _active: Control = null


func _ready() -> void:
	clip_contents = true
	resized.connect(_fit)


## Instantiate the given minigame scene, replacing any currently mounted one.
## Returns the instantiated minigame (a Control), or null if it could not mount.
func mount(scene: PackedScene) -> Control:
	clear()
	if scene == null:
		return null
	var instance := scene.instantiate()
	_active = instance as Control
	add_child(instance)
	if _active != null:
		_active.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_active.size = _reference_size()
		_active.pivot_offset = Vector2.ZERO
		_fit()
	return _active


func clear() -> void:
	if _active != null and is_instance_valid(_active):
		_active.queue_free()
	_active = null


func get_active() -> Control:
	return _active


func _reference_size() -> Vector2:
	if _active == null:
		return FALLBACK_REFERENCE_SIZE
	var ref := _active.custom_minimum_size
	if ref.x <= 0.0 or ref.y <= 0.0:
		return FALLBACK_REFERENCE_SIZE
	return ref


func _fit() -> void:
	if _active == null or not is_instance_valid(_active):
		return
	var ref := _reference_size()
	if ref.x <= 0.0 or ref.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor := minf(size.x / ref.x, size.y / ref.y)
	_active.size = ref
	_active.scale = Vector2(scale_factor, scale_factor)
	_active.position = (size - ref * scale_factor) * 0.5
