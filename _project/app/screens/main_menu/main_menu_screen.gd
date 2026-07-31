extends Control
class_name MainMenuScreen

signal continue_requested
signal new_game_requested

const CONFIRM_DIM_COLOR := Color(0.0, 0.0, 0.0, 0.65)
const CONFIRM_TITLE_FONT_SIZE: int = 40
const CONFIRM_BODY_FONT_SIZE: int = 22
const CONFIRM_BUTTON_MIN_SIZE := Vector2(200.0, 48.0)

@onready var _continue_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/ContinueButton
@onready var _new_game_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/NewGameButton
@onready var _options_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/OptionsButton
@onready var _exit_button: Button = $CenterContainer/VBoxContainer/VBoxContainer/ExitButton

var _continue_available: bool = false
var _confirm_overlay: Control = null


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)


func set_continue_available(is_available: bool) -> void:
	_continue_available = is_available
	if _continue_button:
		_continue_button.visible = is_available


func _on_continue_pressed() -> void:
	continue_requested.emit()


# A new game overwrites the save, so only ask for confirmation when there is a
# save to lose. With no continue data, start immediately.
func _on_new_game_pressed() -> void:
	if _continue_available:
		_show_overwrite_confirm()
	else:
		new_game_requested.emit()


func _on_options_pressed() -> void:
	var app_root := Magnetide.app_root
	if app_root and app_root.has_method("open_options_menu"):
		app_root.call("open_options_menu")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _show_overwrite_confirm() -> void:
	if _confirm_overlay == null:
		_confirm_overlay = _build_overwrite_confirm()
		add_child(_confirm_overlay)
	_confirm_overlay.visible = true


func _hide_overwrite_confirm() -> void:
	if _confirm_overlay:
		_confirm_overlay.visible = false


func _on_overwrite_confirmed() -> void:
	_hide_overwrite_confirm()
	new_game_requested.emit()


func _build_overwrite_confirm() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = CONFIRM_DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)

	var title := Label.new()
	title.text = "Start New Game?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", CONFIRM_TITLE_FONT_SIZE)
	column.add_child(title)

	var body := Label.new()
	body.text = "This will overwrite your current save. Continue?"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(420.0, 0.0)
	body.add_theme_font_size_override("font_size", CONFIRM_BODY_FONT_SIZE)
	column.add_child(body)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	button_row.add_child(_make_confirm_button("Continue", _on_overwrite_confirmed))
	button_row.add_child(_make_confirm_button("Cancel", _hide_overwrite_confirm))
	column.add_child(button_row)

	center.add_child(column)
	overlay.add_child(center)
	return overlay


func _make_confirm_button(text: String, pressed_handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = CONFIRM_BUTTON_MIN_SIZE
	button.pressed.connect(pressed_handler)
	return button
