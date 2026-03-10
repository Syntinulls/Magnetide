extends TextureRect
class_name ShipStatusUI

var _storage_weight: float = 0.0
var _storage_max_weight: float = 100.0
var _magnet_weight: float = 0.0
var _magnet_max_weight: float = 60.0

@onready var _storage_label: Label = $MarginContainer/VBoxContainer/StorageRow/StorageLabel
@onready var _magnet_label: Label = $MarginContainer/VBoxContainer/MagnetRow/MagnetLabel


func _ready() -> void:
	_update_display()


func _update_display() -> void:
	if _storage_label:
		_storage_label.text = "%.1f / %.1fkg" % [_storage_weight, _storage_max_weight]
	if _magnet_label:
		_magnet_label.text = "%.1f / %.1fkg" % [_magnet_weight, _magnet_max_weight]


func set_storage_weight(current: float, max_weight: float) -> void:
	_storage_weight = current
	_storage_max_weight = max_weight
	_update_display()


func set_magnet_weight(current: float, max_weight: float) -> void:
	_magnet_weight = current
	_magnet_max_weight = max_weight
	_update_display()
