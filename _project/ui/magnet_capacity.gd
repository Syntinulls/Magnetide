extends Node2D
class_name MagnetCapacity

## In-world magnet capacity readout that floats above the magnet. Because it lives
## in the world (not the UI canvas layer), enemies and salvage render on top of it
## and it participates in normal scene positioning / scaling / z-layering.

const MAGNET_ICON: Texture2D = preload("res://_project/ui/sprites/ui_ship_icon_magnet.png")
const ICON_HEIGHT: float = 34.0
const LABEL_FONT_SIZE: int = 30
const LABEL_BOX := Vector2(200.0, 40.0)

## World-space gap between the magnet's origin and this readout.
@export var above_magnet_offset: float = 20.0
## Z-index of the readout in the world. Kept low so gameplay entities draw on top.
@export var world_z_index: int = 0

var _magnet_count: int = 0
var _magnet_capacity: int = 10
var _label: Label = null
var _icon: Sprite2D = null


func _ready() -> void:
	z_index = world_z_index
	_build()
	_update_display()
	_update_position()


func _build() -> void:
	# Icon sits above the label; both are centered on this node's origin, which is
	# pinned just above the magnet.
	_icon = Sprite2D.new()
	_icon.texture = MAGNET_ICON
	_icon.centered = true
	if MAGNET_ICON != null and MAGNET_ICON.get_height() > 0:
		var icon_scale := ICON_HEIGHT / float(MAGNET_ICON.get_height())
		_icon.scale = Vector2(icon_scale, icon_scale)
	_icon.position = Vector2(0.0, -LABEL_BOX.y - ICON_HEIGHT * 0.5)
	add_child(_icon)

	_label = Label.new()
	Magnetide.apply_label_font(_label)
	_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Fixed box centered on x, sitting just above the magnet (bottom at origin).
	_label.size = LABEL_BOX
	_label.position = Vector2(-LABEL_BOX.x * 0.5, -LABEL_BOX.y)
	add_child(_label)


func _process(_delta: float) -> void:
	_update_position()


## Pin the readout just above the magnet in world space.
func _update_position() -> void:
	var magnet := Magnetide.magnet as Node2D
	if magnet == null or not is_instance_valid(magnet) or not magnet.is_inside_tree():
		return
	global_position = magnet.global_position + Vector2(0.0, -above_magnet_offset)


func _update_display() -> void:
	if _label:
		_label.text = "%d / %d" % [_magnet_count, _magnet_capacity]


func set_magnet_capacity(current: int, max_capacity: int) -> void:
	_magnet_count = maxi(current, 0)
	_magnet_capacity = maxi(max_capacity, 0)
	_update_display()
