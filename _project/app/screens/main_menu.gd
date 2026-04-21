extends Control
class_name MainMenuScreen

signal start_requested

@onready var _start_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	start_requested.emit()
