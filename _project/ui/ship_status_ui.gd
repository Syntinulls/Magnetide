extends TextureRect
class_name ShipStatusUI

const DEFAULT_STORAGE_LABEL_COLOR := Color.WHITE
const OVER_CAPACITY_STORAGE_LABEL_COLOR := Color("ff7c7c")

var _storage_weight: float = 0.0
var _storage_max_weight: float = 100.0
var _magnet_count: int = 0
var _magnet_capacity: int = 10

@onready var _storage_label: Label = $MarginContainer/VBoxContainer/StorageRow/StorageLabel
@onready var _magnet_label: Label = $MarginContainer/VBoxContainer/MagnetRow/MagnetLabel


func _ready() -> void:
	_update_display()


func _update_display() -> void:
	if _storage_label:
		_storage_label.text = "%.1f / %.1fkg" % [_storage_weight, _storage_max_weight]
		_storage_label.add_theme_color_override(
			"font_color",
			OVER_CAPACITY_STORAGE_LABEL_COLOR if _is_storage_at_or_over_capacity() else DEFAULT_STORAGE_LABEL_COLOR
		)
	if _magnet_label:
		_magnet_label.text = "%d / %d" % [_magnet_count, _magnet_capacity]


func set_storage_weight(current: float, max_weight: float) -> void:
	_storage_weight = current
	_storage_max_weight = max_weight
	_update_display()


func set_magnet_capacity(current: int, max_capacity: int) -> void:
	_magnet_count = maxi(current, 0)
	_magnet_capacity = maxi(max_capacity, 0)
	_update_display()


func _is_storage_at_or_over_capacity() -> bool:
	return _storage_weight >= _storage_max_weight
