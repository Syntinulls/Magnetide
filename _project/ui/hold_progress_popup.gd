extends Control
class_name HoldProgressPopup

var _target_node: Node2D = null
var _world_offset: Vector2 = Vector2.ZERO

@onready var _progress_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/ProgressBar


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func attach_to_target(target: Node2D, world_offset: Vector2 = Vector2.ZERO) -> void:
	_target_node = target
	_world_offset = world_offset


func set_progress(progress: float) -> void:
	visible = true
	if _progress_bar:
		_progress_bar.value = clampf(progress, 0.0, 1.0) * 100.0


func hide_progress() -> void:
	visible = false
	if _progress_bar:
		_progress_bar.value = 0.0


func _process(_delta: float) -> void:
	if not visible:
		return
	if _target_node == null or not is_instance_valid(_target_node):
		hide_progress()
		return

	var screen_position := _target_node.get_global_transform_with_canvas().origin + _world_offset
	position = screen_position - Vector2(size.x * 0.5, size.y)
