extends Control
class_name MainMenuScreen

signal continue_requested
signal new_game_requested

@onready var _continue_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/ContinueButton
@onready var _new_game_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/NewGameButton
@onready var _exit_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/ExitButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)


func set_continue_available(is_available: bool) -> void:
	if _continue_button:
		_continue_button.visible = is_available


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_new_game_pressed() -> void:
	new_game_requested.emit()


func _on_exit_pressed() -> void:
	get_tree().quit()
