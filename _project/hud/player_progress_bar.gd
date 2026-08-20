extends Control
class_name PlayerProgressBar

## Generic world-anchored progress bar rendered above the player's head.
##
## Reused by every "fill a bar over time" interaction — hold-to-depart, magnet-gun
## repel, and weapon reloading. It carries no mechanic-specific logic: an owner
## drives it via set_progress()/set_fill_color()/set_text() and it positions itself
## in screen space above the attached world target each frame.
##
## Visuals: a ui_border_4px nine-patch frame (5px margins) drawn on top of a ColorRect
## fill that is clipped to the frame's interior. Unfilled interior stays transparent;
## filled interior shows the solid fill color. An optional label floats above.

@onready var _label: Label = $Label
@onready var _fill_clip: Control = $FillClip
@onready var _fill: ColorRect = $FillClip/Fill
@onready var _border: NinePatchRect = $Border

var _target: Node2D = null
var _world_offset: Vector2 = Vector2.ZERO
var _progress: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _label:
		Magnetide.apply_label_font(_label)
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_label.add_theme_constant_override("outline_size", 4)
		_label.visible = false
	visible = false
	set_process(true)
	_apply_progress()


## Anchor the bar above `target`, offset by `world_offset` in world units.
func attach_to_target(target: Node2D, world_offset: Vector2 = Vector2.ZERO) -> void:
	_target = target
	_world_offset = world_offset


func set_fill_color(color: Color) -> void:
	if _fill:
		_fill.color = color


## Sets the caption above the bar. Empty text hides the label entirely.
func set_text(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_label.visible = not text.is_empty()


func set_progress(progress: float) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	_apply_progress()


func show_bar() -> void:
	visible = true


func hide_bar() -> void:
	visible = false


func _apply_progress() -> void:
	if _fill == null or _fill_clip == null:
		return
	var interior := _fill_clip.size
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(interior.x * _progress, interior.y)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _target == null or not is_instance_valid(_target):
		hide_bar()
		return
	# Project the anchor point into screen space and center the bar horizontally
	# above it (bar's bottom edge sits at the anchor).
	var screen_pos := get_viewport().get_canvas_transform() * (_target.global_position + _world_offset)
	position = screen_pos - Vector2(size.x * 0.5, size.y)
	_apply_progress()
