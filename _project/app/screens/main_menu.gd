extends Control
class_name MainMenuScreen

signal new_game_requested

@onready var _new_game_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/NewGameButton
@onready var _exit_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/ExitButton


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)


func _on_new_game_pressed() -> void:
	new_game_requested.emit()


func _on_exit_pressed() -> void:
	get_tree().quit()
