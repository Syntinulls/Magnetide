extends Control
class_name PauseMenu

## Full-screen pause overlay for the in-run game. ESC (the "pause" action)
## toggles it: the tree pauses, the screen darkens behind a PAUSED title with
## CONTINUE, OPTIONS and ABANDON RUN buttons. Abandoning asks for confirmation,
## then discards all run progress and returns to the station.

const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.65)
const TITLE_FONT_SIZE: int = 96
const BUTTON_FONT_SIZE: int = 40
const CONFIRM_FONT_SIZE: int = 48
const BUTTON_MIN_SIZE := Vector2(420.0, 72.0)
const CONFIRM_BUTTON_MIN_SIZE := Vector2(180.0, 64.0)

var _main_panel: Control = null
var _confirm_panel: Control = null


func _ready() -> void:
	# ALWAYS, not WHEN_PAUSED: the menu must receive input in both states — while
	# running (to pause) and while paused (to resume and for its buttons).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	Magnetide.apply_label_fonts(self)


# _input rather than _unhandled_input: ESC must work even when a Control holds
# keyboard focus (the GUI layer would otherwise consume it to release focus).
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if visible:
		if _confirm_panel.visible:
			_show_main_panel()
		else:
			_resume()
	elif _can_pause():
		_pause()


func _can_pause() -> bool:
	if get_tree().paused:
		return false
	var run := Magnetide.run
	if run == null or not is_instance_valid(run):
		return false
	# No pausing once the run is ending (departure cutscene / death teardown).
	if run.has_method("is_run_ending") and run.call("is_run_ending"):
		return false
	return true


func _pause() -> void:
	get_tree().paused = true
	move_to_front()
	_show_main_panel()
	visible = true


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _show_main_panel() -> void:
	_main_panel.visible = true
	_confirm_panel.visible = false


func _on_options_pressed() -> void:
	var app_root := Magnetide.app_root
	if app_root and app_root.has_method("open_options_menu"):
		app_root.call("open_options_menu")


func _on_abandon_pressed() -> void:
	_main_panel.visible = false
	_confirm_panel.visible = true


func _on_abandon_confirmed() -> void:
	visible = false
	get_tree().paused = false
	var app_root := Magnetide.app_root
	if app_root and app_root.has_method("abandon_run_to_station"):
		app_root.call("abandon_run_to_station")


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_main_panel = _build_center_column([
		_make_title("PAUSED"),
		_make_button("CONTINUE", _resume, BUTTON_MIN_SIZE, BUTTON_FONT_SIZE),
		_make_button("OPTIONS", _on_options_pressed, BUTTON_MIN_SIZE, BUTTON_FONT_SIZE),
		_make_button("ABANDON RUN", _on_abandon_pressed, BUTTON_MIN_SIZE, BUTTON_FONT_SIZE),
	])
	add_child(_main_panel)

	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_row.add_theme_constant_override("separation", 40)
	confirm_row.add_child(_make_button("YES", _on_abandon_confirmed, CONFIRM_BUTTON_MIN_SIZE, BUTTON_FONT_SIZE))
	confirm_row.add_child(_make_button("NO", _show_main_panel, CONFIRM_BUTTON_MIN_SIZE, BUTTON_FONT_SIZE))

	var confirm_title := _make_title("ABANDON RUN?")
	confirm_title.add_theme_font_size_override("font_size", CONFIRM_FONT_SIZE)
	_confirm_panel = _build_center_column([confirm_title, confirm_row])
	_confirm_panel.visible = false
	add_child(_confirm_panel)


func _build_center_column(children: Array) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	for child in children:
		column.add_child(child)
	center.add_child(column)
	return center


func _make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	return label


func _make_button(text: String, pressed_handler: Callable, min_size: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(pressed_handler)
	return button
