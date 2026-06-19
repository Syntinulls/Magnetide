extends Control
class_name ResearchStationUI

signal research_completed(item_data: SalvageItemData)
signal research_failed(item_data: SalvageItemData, reason: StringName)
signal ui_closed()

const AlignmentAScene: PackedScene = preload("res://_project/ui/research/minigames/alignment_a_minigame.tscn")

@export var max_fail_count: int = 3
@export var required_stage_count: int = 1
@export var resume_delay: float = 0.8
@export var failure_reset_duration: float = 2.5
@export var failure_result_hesitation_duration: float = 1.0
@export var stage_success_duration: float = 2.5

enum DisplayState {
	ACTIVE,
	STAGE_FAILURE,
	STAGE_SUCCESS,
	FINAL_RESULTS,
}

var artifact_data: SalvageItemData = null
var current_stage_index: int = 0
var completed_stage_count: int = 0
var total_fail_count: int = 0
var current_stage_state: Dictionary = {}
var elapsed_seconds: float = 0.0

var _active_minigame: Control = null
var _is_started: bool = false
var _is_paused: bool = true
var _display_state: int = DisplayState.ACTIVE
var _result_countdown: float = 0.0
var _result_hesitation_remaining: float = 0.0
var _pending_failure_reason: StringName = &""
var _pending_failure_is_terminal: bool = false
var _panel: PanelContainer = null
var _progress_fill: ColorRect = null
var _stage_host: Control = null
var _fail_labels: Array[Label] = []
var _status_label: Label = null
var _close_button: Button = null
var _result_overlay: PanelContainer = null
var _result_title_label: Label = null
var _result_body_label: Label = null
var _result_countdown_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_shell()
	set_process(false)


func start_session(new_artifact_data: SalvageItemData, saved_state: Dictionary = {}) -> void:
	artifact_data = new_artifact_data
	current_stage_state = saved_state.duplicate(true)
	if not _is_started:
		current_stage_index = 0
		completed_stage_count = 0
		total_fail_count = 0
		elapsed_seconds = 0.0
		_display_state = DisplayState.ACTIVE
	_is_started = true
	_show_and_resume()


func reopen() -> void:
	if not _is_started:
		return
	_show_and_resume()


func close_and_pause() -> void:
	if not _is_started:
		return
	if _display_state == DisplayState.FINAL_RESULTS:
		_is_started = false
		_is_paused = true
		visible = false
		set_process(false)
		Magnetide.research_ui_input_captured = false
		research_completed.emit(artifact_data)
		return
	if _active_minigame and _active_minigame.has_method("save_state"):
		current_stage_state = _active_minigame.call("save_state")
	if _active_minigame and _active_minigame.has_method("pause_minigame"):
		_active_minigame.call("pause_minigame", true)
	_is_paused = true
	visible = false
	set_process(false)
	Magnetide.research_ui_input_captured = false
	ui_closed.emit()


func fail_session(reason: StringName = &"research_failed") -> void:
	if _active_minigame and _active_minigame.has_method("stop_minigame"):
		_active_minigame.call("stop_minigame")
	_is_started = false
	_is_paused = true
	visible = false
	set_process(false)
	Magnetide.research_ui_input_captured = false
	research_failed.emit(artifact_data, reason)


func get_saved_state() -> Dictionary:
	return current_stage_state.duplicate(true)


func _show_and_resume() -> void:
	visible = true
	_is_paused = false
	Magnetide.research_ui_input_captured = true
	if _display_state == DisplayState.FINAL_RESULTS:
		_show_result_overlay("RESEARCH COMPLETE", _build_final_result_text(), "")
	else:
		_ensure_minigame()
	_refresh_shell()
	grab_focus()
	set_process(true)
	if _active_minigame and _display_state == DisplayState.ACTIVE:
		if _active_minigame.has_method("load_state") and not current_stage_state.is_empty():
			_active_minigame.call("load_state", current_stage_state)
		if _active_minigame is AlignmentAMinigame:
			(_active_minigame as AlignmentAMinigame).resume_delay = resume_delay
		if _active_minigame.has_method("start_minigame"):
			_active_minigame.call("start_minigame", _build_context())


func _process(delta: float) -> void:
	if not visible or _is_paused or not _is_started:
		return
	elapsed_seconds += delta
	if _display_state == DisplayState.STAGE_FAILURE or _display_state == DisplayState.STAGE_SUCCESS:
		if _display_state == DisplayState.STAGE_FAILURE and _result_hesitation_remaining > 0.0:
			_result_hesitation_remaining = maxf(_result_hesitation_remaining - delta, 0.0)
			_update_result_countdown_label()
			return
		_result_countdown = maxf(_result_countdown - delta, 0.0)
		_update_result_countdown_label()
		if _result_countdown <= 0.0:
			if _display_state == DisplayState.STAGE_FAILURE:
				_finish_failure_countdown()
			else:
				_finish_stage_success_countdown()


func _ensure_minigame() -> void:
	if _active_minigame and is_instance_valid(_active_minigame):
		return
	if _stage_host == null:
		return

	_active_minigame = AlignmentAScene.instantiate() as Control
	_active_minigame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage_host.add_child(_active_minigame)
	if _active_minigame.has_signal("progress_changed"):
		_active_minigame.connect("progress_changed", Callable(self, "_on_minigame_progress_changed"))
	if _active_minigame.has_signal("attempt_failed"):
		_active_minigame.connect("attempt_failed", Callable(self, "_on_minigame_attempt_failed"))
	if _active_minigame.has_signal("completed"):
		_active_minigame.connect("completed", Callable(self, "_on_minigame_completed"))
	if _active_minigame.has_signal("state_changed"):
		_active_minigame.connect("state_changed", Callable(self, "_on_minigame_state_changed"))


func _build_context() -> Dictionary:
	var threat_level := 0
	if Magnetide.level and "threat" in Magnetide.level and Magnetide.level.threat:
		threat_level = Magnetide.level.threat.threat_level
	return {
		"artifact_data": artifact_data,
		"stage_index": current_stage_index,
		"stage_count": required_stage_count,
		"total_fail_count": total_fail_count,
		"max_fail_count": max_fail_count,
		"difficulty": 1.0 + float(threat_level) * 0.25,
		"threat_level": threat_level,
		"rng_seed": randi(),
	}


func _build_shell() -> void:
	var shade := ColorRect.new()
	shade.name = "InputShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.04)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.name = "ResearchCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "ResearchPanel"
	_panel.custom_minimum_size = Vector2(1040.0, 760.0)
	center.add_child(_panel)
	_apply_panel_style(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.custom_minimum_size = Vector2(0.0, 54.0)
	top_row.add_theme_constant_override("separation", 14)
	vbox.add_child(top_row)

	var progress_back := ColorRect.new()
	progress_back.custom_minimum_size = Vector2(860.0, 42.0)
	progress_back.color = Color("494949")
	progress_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(progress_back)

	_progress_fill = ColorRect.new()
	_progress_fill.color = Color("73f7cf")
	_progress_fill.anchor_left = 0.0
	_progress_fill.anchor_top = 0.0
	_progress_fill.anchor_bottom = 1.0
	progress_back.add_child(_progress_fill)

	_status_label = Label.new()
	_status_label.custom_minimum_size = Vector2(150.0, 42.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Magnetide.apply_digital_font(_status_label)
	_status_label.add_theme_font_size_override("font_size", 26)
	_status_label.add_theme_color_override("font_color", Color("eeeeee"))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 4)
	top_row.add_child(_status_label)

	_close_button = Button.new()
	_close_button.custom_minimum_size = Vector2(46.0, 42.0)
	_close_button.text = "X"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.pressed.connect(close_and_pause)
	top_row.add_child(_close_button)

	_stage_host = Control.new()
	_stage_host.name = "MinigameHost"
	_stage_host.custom_minimum_size = Vector2(980.0, 590.0)
	_stage_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_stage_host)
	_build_result_overlay()

	var fail_row := HBoxContainer.new()
	fail_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fail_row.custom_minimum_size = Vector2(0.0, 58.0)
	fail_row.add_theme_constant_override("separation", 34)
	vbox.add_child(fail_row)
	for index in range(max_fail_count):
		var fail_label := Label.new()
		fail_label.text = "X"
		fail_label.custom_minimum_size = Vector2(54.0, 54.0)
		fail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Magnetide.apply_digital_font(fail_label)
		fail_label.add_theme_font_size_override("font_size", 54)
		fail_label.add_theme_color_override("font_outline_color", Color.BLACK)
		fail_label.add_theme_constant_override("outline_size", 4)
		fail_row.add_child(fail_label)
		_fail_labels.append(fail_label)

	_refresh_shell()


func _apply_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("767878")
	style.border_color = Color("111111")
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)


func _build_result_overlay() -> void:
	if _stage_host == null:
		return
	_result_overlay = PanelContainer.new()
	_result_overlay.name = "ResultOverlay"
	_result_overlay.visible = false
	_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_host.add_child(_result_overlay)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.74)
	style.border_color = Color("171717")
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	_result_overlay.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(520.0, 220.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	_result_title_label = _create_result_label(42, Color("73f7cf"))
	vbox.add_child(_result_title_label)
	_result_body_label = _create_result_label(28, Color("f0f0f0"))
	vbox.add_child(_result_body_label)
	_result_countdown_label = _create_result_label(54, Color("f7f1a3"))
	vbox.add_child(_result_countdown_label)


func _create_result_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Magnetide.apply_digital_font(label)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _show_result_overlay(title: String, body: String, countdown_text: String = "") -> void:
	if _result_overlay == null:
		return
	_result_overlay.visible = true
	_result_overlay.move_to_front()
	if _result_title_label:
		_result_title_label.text = title
	if _result_body_label:
		_result_body_label.text = body
	if _result_countdown_label:
		_result_countdown_label.text = countdown_text


func _hide_result_overlay() -> void:
	if _result_overlay:
		_result_overlay.visible = false


func _update_result_countdown_label() -> void:
	if _result_countdown_label == null:
		return
	if _display_state == DisplayState.STAGE_SUCCESS:
		_result_countdown_label.text = ""
		return
	if _display_state == DisplayState.STAGE_FAILURE:
		if _result_hesitation_remaining > 0.0:
			_result_countdown_label.text = ""
		else:
			_result_countdown_label.text = "RESET IN %.1f" % _result_countdown
	elif _display_state == DisplayState.STAGE_SUCCESS:
		_result_countdown_label.text = "NEXT IN %.1f" % _result_countdown


func _begin_failure_countdown(reason: StringName, terminal: bool) -> void:
	_display_state = DisplayState.STAGE_FAILURE
	_pending_failure_reason = reason
	_pending_failure_is_terminal = terminal
	_result_hesitation_remaining = failure_result_hesitation_duration
	_result_countdown = failure_reset_duration
	if _active_minigame and _active_minigame.has_method("show_failure_result"):
		_active_minigame.call("show_failure_result", reason)
	if _active_minigame and _active_minigame.has_method("pause_minigame"):
		_active_minigame.call("pause_minigame", true)
	var laser_name := "LEFT" if str(reason).contains("left") else "RIGHT"
	var body := "%s LASER DESTROYED" % laser_name
	if terminal:
		body += "\nRESEARCH FAILURE"
	_show_result_overlay("CALIBRATION FAILURE", body)
	_update_result_countdown_label()
	_refresh_shell()


func _finish_failure_countdown() -> void:
	if _pending_failure_is_terminal:
		fail_session(_pending_failure_reason)
		return
	_display_state = DisplayState.ACTIVE
	_pending_failure_reason = &""
	_pending_failure_is_terminal = false
	current_stage_state.clear()
	if _active_minigame and _active_minigame.has_method("reset_attempt"):
		_active_minigame.call("reset_attempt")
	if _active_minigame and _active_minigame.has_method("clear_result_display"):
		_active_minigame.call("clear_result_display")
	if _active_minigame and _active_minigame.has_method("pause_minigame"):
		_active_minigame.call("pause_minigame", false)
	_hide_result_overlay()
	_refresh_shell()


func _begin_stage_success_countdown() -> void:
	_display_state = DisplayState.STAGE_SUCCESS
	_result_countdown = stage_success_duration
	if _active_minigame and _active_minigame.has_method("show_success_result"):
		_active_minigame.call("show_success_result")
	if _active_minigame and _active_minigame.has_method("pause_minigame"):
		_active_minigame.call("pause_minigame", true)
	_show_result_overlay("ARTIFACT STABLE", "RESEARCH STAGE COMPLETE")
	_update_result_countdown_label()
	_refresh_shell()


func _finish_stage_success_countdown() -> void:
	if completed_stage_count >= required_stage_count:
		_display_final_results()
		return
	current_stage_index += 1
	_display_state = DisplayState.ACTIVE
	_hide_result_overlay()
	_clear_active_minigame()
	_ensure_minigame()
	if _active_minigame and _active_minigame.has_method("start_minigame"):
		_active_minigame.call("start_minigame", _build_context())
	_refresh_shell()


func _display_final_results() -> void:
	_display_state = DisplayState.FINAL_RESULTS
	_clear_active_minigame()
	_show_result_overlay("RESEARCH COMPLETE", _build_final_result_text())
	_refresh_shell()


func _build_final_result_text() -> String:
	var reward := 0
	if artifact_data:
		reward = maxi(artifact_data.research_point_reward, 0)
	return "RESEARCH POINTS: %d\nFAILURES: %d / %d\nTIME: %s" % [
		reward,
		total_fail_count,
		max_fail_count,
		_format_elapsed_time(elapsed_seconds),
	]


func _format_elapsed_time(seconds: float) -> String:
	var total_seconds := maxi(roundi(seconds), 0)
	@warning_ignore("integer_division")
	var minutes := total_seconds / 60
	var remaining_seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]


func _clear_active_minigame() -> void:
	if _active_minigame and is_instance_valid(_active_minigame):
		_active_minigame.queue_free()
	_active_minigame = null


func _refresh_shell() -> void:
	var stage_progress := 0.0
	if _display_state == DisplayState.ACTIVE and _active_minigame and _active_minigame.has_method("get_progress"):
		stage_progress = float(_active_minigame.call("get_progress"))
	var total_progress := (float(completed_stage_count) + clampf(stage_progress, 0.0, 1.0)) / float(maxi(required_stage_count, 1))
	if _progress_fill:
		_progress_fill.anchor_right = clampf(total_progress, 0.0, 1.0)
		_progress_fill.offset_right = 0.0
	if _status_label:
		var display_stage := mini(completed_stage_count + 1, required_stage_count)
		_status_label.text = "%d/%d" % [display_stage, required_stage_count]
	for index in range(_fail_labels.size()):
		var label := _fail_labels[index]
		var used := index < total_fail_count
		label.add_theme_color_override("font_color", Color("ff5c5c") if used else Color("151515"))


func _on_minigame_progress_changed(_progress: float) -> void:
	_refresh_shell()


func _on_minigame_state_changed(state: Dictionary) -> void:
	current_stage_state = state.duplicate(true)


func _on_minigame_attempt_failed(reason: StringName) -> void:
	total_fail_count += 1
	_refresh_shell()
	if total_fail_count >= max_fail_count:
		_begin_failure_countdown(reason, true)
		return
	_begin_failure_countdown(reason, false)


func _on_minigame_completed() -> void:
	completed_stage_count += 1
	current_stage_state.clear()
	_refresh_shell()
	_begin_stage_success_countdown()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.physical_keycode == KEY_ESCAPE:
			close_and_pause()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and _panel and not _panel.get_global_rect().has_point(mouse_event.position):
			close_and_pause()
			get_viewport().set_input_as_handled()
			return


func _exit_tree() -> void:
	if visible:
		Magnetide.research_ui_input_captured = false
