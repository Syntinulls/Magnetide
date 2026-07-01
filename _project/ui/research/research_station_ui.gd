extends Control
class_name ResearchStationUI

## Emitted the instant the final stage is cleared — the station awards points and
## consumes the artifact immediately, regardless of the result screens that follow.
signal research_completed(item_data: SalvageItemData)
signal research_failed(item_data: SalvageItemData, reason: StringName)
signal ui_closed()
## Emitted when an already-finalized session's result screens are dismissed
## (auto-proceed / skip / X / ESC). The station just tears down the UI.
signal research_dismissed()

const DEFAULT_MINIGAME_SCENE: PackedScene = preload("res://_project/ui/research/minigames/alignment_a_minigame.tscn")
const OVERALL_BG: Texture2D = preload("res://_project/ui/research/minigames/sprites/minigame_overall_bg.png")
const OVERALL_PROGRESS: Texture2D = preload("res://_project/ui/research/minigames/sprites/minigame_overall_progress.png")
const OVERALL_BAR: Texture2D = preload("res://_project/ui/research/minigames/sprites/minigame_overall_bar.png")

## Pool of minigame scenes the station can present. A random one is selected per
## research stage. Empty falls back to DEFAULT_MINIGAME_SCENE.
@export var minigame_scenes: Array[PackedScene] = []

@export var max_fail_count: int = 3
@export var required_stage_count: int = 1
@export var resume_delay: float = 0.8
@export var failure_reset_duration: float = 2.5
@export var failure_result_hesitation_duration: float = 1.0
@export var stage_success_duration: float = 2.5
## Seconds the final "RESEARCH COMPLETE" screen is shown before it auto-closes
## and finalizes the research (no click required).
@export var final_results_auto_proceed_duration: float = 2.5

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
## True once the final stage has been cleared and rewards granted. From then on
## the result screens are purely cosmetic and closing just dismisses the UI.
var _research_finalized: bool = false
var _is_paused: bool = true
var _display_state: int = DisplayState.ACTIVE
var _result_countdown: float = 0.0
var _result_hesitation_remaining: float = 0.0
var _pending_failure_reason: StringName = &""
var _pending_failure_is_terminal: bool = false
var _panel: PanelContainer = null
var _progress_bar: TextureProgressBar = null
var _stage_host: MinigameDocker = null
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
		_research_finalized = false
	_is_started = true
	_show_and_resume()


func reopen() -> void:
	if not _is_started:
		return
	_show_and_resume()


func close_and_pause() -> void:
	if not _is_started:
		return
	# Rewards were already granted when the final stage cleared, so any close
	# from here on (auto-proceed, skip, X, ESC) just tears the UI down.
	if _research_finalized:
		_dismiss_after_finalized()
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


func _dismiss_after_finalized() -> void:
	_is_started = false
	_is_paused = true
	visible = false
	set_process(false)
	Magnetide.research_ui_input_captured = false
	research_dismissed.emit()


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
		_result_countdown = maxf(final_results_auto_proceed_duration, 0.0)
		_show_result_overlay("RESEARCH COMPLETE", _build_final_result_text(), "")
	else:
		_ensure_minigame()
	_refresh_shell()
	grab_focus()
	set_process(true)
	if _active_minigame and _display_state == DisplayState.ACTIVE:
		if _active_minigame.has_method("load_state") and not current_stage_state.is_empty():
			_active_minigame.call("load_state", current_stage_state)
		if "resume_delay" in _active_minigame:
			_active_minigame.set("resume_delay", resume_delay)
		if _active_minigame.has_method("start_minigame"):
			_active_minigame.call("start_minigame", _build_context())


func _process(delta: float) -> void:
	if not visible or _is_paused or not _is_started:
		return
	elapsed_seconds += delta
	if _display_state == DisplayState.FINAL_RESULTS:
		# Auto-finalize the research after showing the complete screen briefly,
		# so the player doesn't have to click to move on.
		_result_countdown = maxf(_result_countdown - delta, 0.0)
		if _result_countdown <= 0.0:
			close_and_pause()
		return
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

	_active_minigame = _stage_host.mount(_select_minigame_scene())
	if _active_minigame == null:
		return
	if _active_minigame.has_signal("progress_changed"):
		_active_minigame.connect("progress_changed", Callable(self, "_on_minigame_progress_changed"))
	if _active_minigame.has_signal("attempt_failed"):
		_active_minigame.connect("attempt_failed", Callable(self, "_on_minigame_attempt_failed"))
	if _active_minigame.has_signal("completed"):
		_active_minigame.connect("completed", Callable(self, "_on_minigame_completed"))
	if _active_minigame.has_signal("state_changed"):
		_active_minigame.connect("state_changed", Callable(self, "_on_minigame_state_changed"))


func _select_minigame_scene() -> PackedScene:
	var pool := minigame_scenes.filter(func(scene): return scene != null)
	if pool.is_empty():
		return DEFAULT_MINIGAME_SCENE
	return pool[randi() % pool.size()]


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
		# Scales 1.0 (level 1) -> 2.0 (max level) across the full threat range.
		"difficulty": 1.0 + float(threat_level) / float(maxi(ThreatManager.LEVEL_COUNT - 1, 1)),
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

	_progress_bar = TextureProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(860.0, 46.0)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.step = 0.0
	_progress_bar.value = 0.0
	_progress_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_progress_bar.nine_patch_stretch = true
	_progress_bar.stretch_margin_left = 22
	_progress_bar.stretch_margin_right = 22
	_progress_bar.texture_under = OVERALL_BG
	_progress_bar.texture_progress = OVERALL_PROGRESS
	_progress_bar.texture_over = OVERALL_BAR
	top_row.add_child(_progress_bar)

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

	_stage_host = MinigameDocker.new()
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
	_result_countdown = maxf(final_results_auto_proceed_duration, 0.0)
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
	if _stage_host:
		_stage_host.clear()
	_active_minigame = null


func _refresh_shell() -> void:
	var stage_progress := 0.0
	if _display_state == DisplayState.ACTIVE and _active_minigame and _active_minigame.has_method("get_progress"):
		stage_progress = float(_active_minigame.call("get_progress"))
	var total_progress := (float(completed_stage_count) + clampf(stage_progress, 0.0, 1.0)) / float(maxi(required_stage_count, 1))
	if _progress_bar:
		_progress_bar.value = clampf(total_progress, 0.0, 1.0)
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
	# The moment the final stage is cleared, finalize the research: the station
	# awards points and consumes the artifact right away. The success/complete
	# screens that follow are cosmetic and can be skipped or closed freely.
	if completed_stage_count >= required_stage_count and not _research_finalized:
		_research_finalized = true
		research_completed.emit(artifact_data)
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
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_E:
			if _try_skip_result_screen() or _try_begin_active_minigame():
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and _panel and not _panel.get_global_rect().has_point(mouse_event.position):
			close_and_pause()
			get_viewport().set_input_as_handled()
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _try_skip_result_screen() or _try_begin_active_minigame():
				get_viewport().set_input_as_handled()
				return


## Skip the wait on a stage-complete / research-complete screen via E or LMB.
## Returns true if a result screen was skipped.
func _try_skip_result_screen() -> bool:
	if _display_state == DisplayState.STAGE_SUCCESS:
		_finish_stage_success_countdown()
		return true
	if _display_state == DisplayState.FINAL_RESULTS:
		close_and_pause()
		return true
	return false


## Player-triggered start (E / LMB) for a minigame that is mounted but waiting
## for activation. Returns true if a waiting minigame was started.
func _try_begin_active_minigame() -> bool:
	if _display_state != DisplayState.ACTIVE:
		return false
	if _active_minigame == null or not is_instance_valid(_active_minigame):
		return false
	if not _active_minigame.has_method("is_awaiting_start") or not _active_minigame.call("is_awaiting_start"):
		return false
	if _active_minigame.has_method("begin_play"):
		_active_minigame.call("begin_play")
	return true


func _exit_tree() -> void:
	if visible:
		Magnetide.research_ui_input_captured = false
