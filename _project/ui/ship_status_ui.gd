extends Control
class_name ShipStatusUI

## Magnet capacity readout that floats a bit above the magnet sprite (inside the
## ship hull), horizontally centered on screen. No background.

## Vertical gap (px, screen space) between the magnet's origin and this readout.
@export var above_magnet_offset: float = 20.0

var _magnet_count: int = 0
var _magnet_capacity: int = 10

@onready var _magnet_label: Label = $MagnetColumn/MagnetLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_display()
	_update_position()


func _process(_delta: float) -> void:
	_update_position()


## Center horizontally on screen, sitting just above the magnet sprite.
func _update_position() -> void:
	var magnet := Magnetide.magnet as Node2D
	if magnet == null or not is_instance_valid(magnet) or not magnet.is_inside_tree():
		return
	var magnet_screen := magnet.get_global_transform_with_canvas().origin
	var viewport_width := get_viewport_rect().size.x
	position = Vector2(
		viewport_width * 0.5 - size.x * 0.5,
		magnet_screen.y - above_magnet_offset - size.y
	)


func _update_display() -> void:
	if _magnet_label:
		_magnet_label.text = "%d / %d" % [_magnet_count, _magnet_capacity]


func set_magnet_capacity(current: int, max_capacity: int) -> void:
	_magnet_count = maxi(current, 0)
	_magnet_capacity = maxi(max_capacity, 0)
	_update_display()
