extends Node
class_name ViewportAnchor

signal viewport_changed(size: Vector2)

var size: Vector2:
	get:
		return _size

var _size: Vector2 = Vector2.ZERO

func _ready() -> void:
	_update_size()
	get_tree().root.size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	_update_size()
	viewport_changed.emit(_size)


func _update_size() -> void:
	_size = get_viewport().get_visible_rect().size


func get_position(anchor_x: float, anchor_y: float) -> Vector2:
	return Vector2(_size.x * anchor_x, _size.y * anchor_y)


func get_x(anchor: float) -> float:
	return _size.x * anchor


func get_y(anchor: float) -> float:
	return _size.y * anchor


func get_left() -> float:
	return 0.0


func get_right() -> float:
	return _size.x


func get_top() -> float:
	return 0.0


func get_bottom() -> float:
	return _size.y


func get_center() -> Vector2:
	return _size * 0.5


func get_center_x() -> float:
	return _size.x * 0.5


func get_center_y() -> float:
	return _size.y * 0.5
