extends Control
class_name MainMenuScreen

signal start_requested

@onready var _start_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/StartButton
@onready var _exit_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/ExitButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)


func _on_start_pressed() -> void:
	start_requested.emit()


func _on_exit_pressed() -> void:
	get_tree().quit()
