extends Control
class_name ResonanceAlignmentMinigame

signal progress_changed(progress: float)
signal attempt_failed(reason: StringName)
signal completed()
signal state_changed(state: Dictionary)

@export var alignment_tolerance: float = 0.12
@export var base_progress_rate: float = 0.11
@export var base_drift_speed: float = 0.11
@export var threat_drift_speed_scale: float = 0.025
@export var base_drift_direction_change_interval: float = 3.0
@export var threat_direction_change_scale: float = 0.18
@export var input_speed: float = 0.62
@export var max_laser_offset: float = 1.0
@export var heat_build_rate: float = 0.28
@export var heat_cool_rate: float = 0.2
@export var red_heat_threshold: float = 0.8
@export var red_heat_failure_duration: float = 2.5
@export var resume_delay: float = 0.8

const LEFT_LASER := &"left"
const RIGHT_LASER := &"right"

var progress: float = 0.0
var left_laser_offset: float = 0.0
var right_laser_offset: float = 0.0
var selected_laser: StringName = LEFT_LASER
var left_drift_direction: float = 1.0
var right_drift_direction: float = -1.0
var left_heat: float = 0.0
var right_heat: float = 0.0
var left_red_heat_time: float = 0.0
var right_red_heat_time: float = 0.0

var _threat_level: int = 0
var _active: bool = false
var _paused: bool = true
var _resume_countdown: float = 0.0
var _left_direction_change_remaining: float = 0.0
var _right_direction_change_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()
var _hint_label: Label = null
var _prompt_label: Label = null
var _status_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	_rng.randomize()
	_build_labels()
	_reset_drift_timers()
	set_process(false)


func start_minigame(context) -> void:
	_threat_level = 0
	if context is Dictionary:
		_threat_level = int(context.get("threat_level", 0))
		var seed := int(context.get("rng_seed", 0))
		if seed != 0:
			_rng.seed = seed

	_active = true
	_paused = false
	_resume_countdown = resume_delay
	grab_focus()
	set_process(true)
	_update_labels()
	queue_redraw()


func stop_minigame() -> void:
	_active = false
	_paused = true
	set_process(false)


func pause_minigame(paused: bool) -> void:
	_paused = paused
	if _active and not _paused:
		_resume_countdown = resume_delay
	set_process(_active)
	_update_labels()
	queue_redraw()


func get_progress() -> float:
	return progress


func save_state() -> Dictionary:
	return {
		"progress": progress,
		"selected_laser": selected_laser,
		"left_laser_offset": left_laser_offset,
		"right_laser_offset": right_laser_offset,
		"left_drift_direction": left_drift_direction,
		"right_drift_direction": right_drift_direction,
		"left_heat": left_heat,
		"right_heat": right_heat,
		"left_red_heat_time": left_red_heat_time,
		"right_red_heat_time": right_red_heat_time,
		"left_direction_change_remaining": _left_direction_change_remaining,
		"right_direction_change_remaining": _right_direction_change_remaining,
		"rng_state": _rng.state,
	}


func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	progress = clampf(float(state.get("progress", progress)), 0.0, 1.0)
	selected_laser = StringName(str(state.get("selected_laser", selected_laser)))
	left_laser_offset = clampf(float(state.get("left_laser_offset", left_laser_offset)), -max_laser_offset, max_laser_offset)
	right_laser_offset = clampf(float(state.get("right_laser_offset", right_laser_offset)), -max_laser_offset, max_laser_offset)
	left_drift_direction = _normalize_direction(float(state.get("left_drift_direction", left_drift_direction)))
	right_drift_direction = _normalize_direction(float(state.get("right_drift_direction", right_drift_direction)))
	left_heat = clampf(float(state.get("left_heat", left_heat)), 0.0, 1.0)
	right_heat = clampf(float(state.get("right_heat", right_heat)), 0.0, 1.0)
	left_red_heat_time = maxf(float(state.get("left_red_heat_time", left_red_heat_time)), 0.0)
	right_red_heat_time = maxf(float(state.get("right_red_heat_time", right_red_heat_time)), 0.0)
	_left_direction_change_remaining = maxf(float(state.get("left_direction_change_remaining", _left_direction_change_remaining)), 0.2)
	_right_direction_change_remaining = maxf(float(state.get("right_direction_change_remaining", _right_direction_change_remaining)), 0.2)
	if state.has("rng_state"):
		_rng.state = int(state["rng_state"])
	_update_labels()
	queue_redraw()


func reset_attempt() -> void:
	progress = 0.0
	left_laser_offset = 0.0
	right_laser_offset = 0.0
	selected_laser = LEFT_LASER
	left_drift_direction = 1.0
	right_drift_direction = -1.0
	left_heat = 0.0
	right_heat = 0.0
	left_red_heat_time = 0.0
	right_red_heat_time = 0.0
	_reset_drift_timers()
	_resume_countdown = resume_delay
	progress_changed.emit(progress)
	state_changed.emit(save_state())
	_update_labels()
	queue_redraw()


func _process(delta: float) -> void:
	if not _active or _paused:
		return
	if _resume_countdown > 0.0:
		_resume_countdown = maxf(_resume_countdown - delta, 0.0)
		_update_labels()
		queue_redraw()
		return

	_process_selection_input()
	_process_laser_motion(delta)
	_process_progress_and_heat(delta)
	_update_labels()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _paused:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed:
			match key_event.physical_keycode:
				KEY_A, KEY_D, KEY_W, KEY_S:
					get_viewport().set_input_as_handled()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("aeb0b0"), true)
	draw_rect(rect, Color("252525"), false, 5.0)

	var center := rect.get_center() + Vector2(0.0, -8.0)
	var left_origin := Vector2(size.x * 0.12, center.y)
	var right_origin := Vector2(size.x * 0.88, center.y)
	var left_impact := center + Vector2(-42.0, _offset_to_pixels(left_laser_offset))
	var right_impact := center + Vector2(42.0, _offset_to_pixels(right_laser_offset))

	_draw_signal_line(center)
	_draw_laser(left_origin, left_impact, _is_left_aligned(), selected_laser == LEFT_LASER)
	_draw_laser(right_origin, right_impact, _is_right_aligned(), selected_laser == RIGHT_LASER)
	_draw_artifact(center)
	_draw_heat_meter(Vector2(size.x * 0.08, size.y * 0.12), left_heat, _is_left_aligned(), selected_laser == LEFT_LASER)
	_draw_heat_meter(Vector2(size.x * 0.88, size.y * 0.12), right_heat, _is_right_aligned(), selected_laser == RIGHT_LASER)

	if _resume_countdown > 0.0 and not _paused and _active:
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.28), true)


func _draw_signal_line(center: Vector2) -> void:
	var points := PackedVector2Array()
	var start_x := size.x * 0.18
	var end_x := size.x * 0.82
	var steps := 64
	for index in range(steps + 1):
		var ratio := float(index) / float(steps)
		var x := lerpf(start_x, end_x, ratio)
		var y := center.y + sin(ratio * TAU * 7.0) * 5.0
		points.append(Vector2(x, y))
	draw_polyline(points, Color("626262"), 4.0)


func _draw_laser(origin: Vector2, impact: Vector2, aligned: bool, selected: bool) -> void:
	var color := Color("75ffe8") if aligned else Color("ff6f68")
	if selected:
		draw_circle(origin, 24.0, Color("f7f1a3"))
	draw_circle(origin, 16.0, Color("303030"))
	draw_line(origin, impact, color, 5.0)
	draw_circle(impact, 7.0, color)
	if aligned:
		_draw_check(impact + Vector2(18.0, -28.0), Color("5bff8e"))
	else:
		_draw_warning(impact + Vector2(18.0, -28.0), Color("ffe066"))


func _draw_artifact(center: Vector2) -> void:
	var artifact_color := SalvageItemData.ARTIFACT_COLOR
	var points := PackedVector2Array([
		center + Vector2(-34, -28),
		center + Vector2(-8, -22),
		center + Vector2(5, -42),
		center + Vector2(18, -20),
		center + Vector2(40, -28),
		center + Vector2(28, -4),
		center + Vector2(42, 16),
		center + Vector2(12, 18),
		center + Vector2(2, 38),
		center + Vector2(-12, 18),
		center + Vector2(-38, 24),
		center + Vector2(-28, -4),
	])
	draw_colored_polygon(points, artifact_color.darkened(0.35))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color("222222"), 4.0)


func _draw_heat_meter(origin: Vector2, heat: float, aligned: bool, selected: bool) -> void:
	var meter_size := Vector2(38.0, 150.0)
	var rect := Rect2(origin, meter_size)
	draw_rect(rect, Color("d4d4d4"), true)
	draw_rect(rect, Color("565656"), false, 4.0)
	var fill_height := meter_size.y * clampf(heat, 0.0, 1.0)
	var fill_rect := Rect2(origin + Vector2(5.0, meter_size.y - fill_height + 5.0), Vector2(meter_size.x - 10.0, maxf(fill_height - 10.0, 0.0)))
	var fill_color := Color("6bdcff")
	if heat >= red_heat_threshold:
		fill_color = Color("ff4f4f")
	elif heat >= 0.55:
		fill_color = Color("ffd166")
	draw_rect(fill_rect, fill_color, true)
	if selected:
		draw_rect(rect.grow(7.0), Color("f7f1a3"), false, 4.0)
	if aligned:
		_draw_check(origin + Vector2(54.0, meter_size.y - 18.0), Color("5bff8e"))
	elif heat >= 0.55:
		_draw_warning(origin + Vector2(54.0, 28.0), Color("ffe066"))


func _draw_check(position: Vector2, color: Color) -> void:
	draw_line(position + Vector2(-10.0, 0.0), position + Vector2(-2.0, 8.0), color, 5.0)
	draw_line(position + Vector2(-2.0, 8.0), position + Vector2(12.0, -12.0), color, 5.0)


func _draw_warning(position: Vector2, color: Color) -> void:
	draw_line(position, position + Vector2(0.0, 20.0), color, 5.0)
	draw_circle(position + Vector2(0.0, 30.0), 4.0, color)


func _build_labels() -> void:
	_hint_label = _create_label("KEEP LASERS ON THE ARTIFACT", 28, HORIZONTAL_ALIGNMENT_LEFT)
	_hint_label.anchor_left = 0.12
	_hint_label.anchor_top = 0.77
	_hint_label.anchor_right = 0.52
	_hint_label.anchor_bottom = 0.88

	_prompt_label = _create_label("A/D SELECT   W/S TUNE", 30, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_label.anchor_left = 0.34
	_prompt_label.anchor_top = 0.84
	_prompt_label.anchor_right = 0.66
	_prompt_label.anchor_bottom = 0.96

	_status_label = _create_label("", 28, HORIZONTAL_ALIGNMENT_CENTER)
	_status_label.anchor_left = 0.34
	_status_label.anchor_top = 0.05
	_status_label.anchor_right = 0.66
	_status_label.anchor_bottom = 0.14


func _create_label(text_value: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Magnetide.digital_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("2a2a2a"))
	label.add_theme_color_override("font_outline_color", Color("d6d6d6"))
	label.add_theme_constant_override("outline_size", 2)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _process_selection_input() -> void:
	if Input.is_key_pressed(KEY_A):
		selected_laser = LEFT_LASER
	elif Input.is_key_pressed(KEY_D):
		selected_laser = RIGHT_LASER


func _process_laser_motion(delta: float) -> void:
	_update_drift_direction(delta)
	var selected_motion := 0.0
	if Input.is_key_pressed(KEY_W):
		selected_motion -= input_speed * delta
	elif Input.is_key_pressed(KEY_S):
		selected_motion += input_speed * delta

	var drift_speed := _get_drift_speed()
	var left_motion := left_drift_direction * drift_speed * delta
	var right_motion := right_drift_direction * drift_speed * delta

	if selected_laser == LEFT_LASER and not is_zero_approx(selected_motion):
		left_motion = selected_motion
	elif selected_laser == RIGHT_LASER and not is_zero_approx(selected_motion):
		right_motion = selected_motion

	left_laser_offset = clampf(left_laser_offset + left_motion, -max_laser_offset, max_laser_offset)
	right_laser_offset = clampf(right_laser_offset + right_motion, -max_laser_offset, max_laser_offset)


func _process_progress_and_heat(delta: float) -> void:
	var left_aligned := _is_left_aligned()
	var right_aligned := _is_right_aligned()
	var aligned_count := (1 if left_aligned else 0) + (1 if right_aligned else 0)
	if aligned_count > 0:
		progress = clampf(progress + base_progress_rate * float(aligned_count) * delta, 0.0, 1.0)
		progress_changed.emit(progress)

	left_heat = _update_heat(left_heat, left_aligned, delta)
	right_heat = _update_heat(right_heat, right_aligned, delta)
	left_red_heat_time = _update_red_time(left_red_heat_time, left_heat, delta)
	right_red_heat_time = _update_red_time(right_red_heat_time, right_heat, delta)
	state_changed.emit(save_state())

	if progress >= 1.0:
		completed.emit()
		stop_minigame()
		return

	if left_red_heat_time >= red_heat_failure_duration:
		attempt_failed.emit(&"left_laser_destroyed")
	elif right_red_heat_time >= red_heat_failure_duration:
		attempt_failed.emit(&"right_laser_destroyed")


func _update_heat(value: float, aligned: bool, delta: float) -> float:
	if aligned:
		return clampf(value - heat_cool_rate * delta, 0.0, 1.0)
	return clampf(value + heat_build_rate * delta, 0.0, 1.0)


func _update_red_time(value: float, heat: float, delta: float) -> float:
	if heat >= red_heat_threshold:
		return value + delta
	return 0.0


func _update_drift_direction(delta: float) -> void:
	_left_direction_change_remaining -= delta
	_right_direction_change_remaining -= delta
	if _left_direction_change_remaining <= 0.0:
		left_drift_direction = _roll_direction(left_laser_offset)
		_left_direction_change_remaining = _roll_direction_change_interval()
	if _right_direction_change_remaining <= 0.0:
		right_drift_direction = _roll_direction(right_laser_offset)
		_right_direction_change_remaining = _roll_direction_change_interval()


func _roll_direction(offset: float) -> float:
	if offset >= max_laser_offset * 0.9:
		return -1.0
	if offset <= -max_laser_offset * 0.9:
		return 1.0
	return -1.0 if _rng.randf() < 0.5 else 1.0


func _reset_drift_timers() -> void:
	_left_direction_change_remaining = _roll_direction_change_interval()
	_right_direction_change_remaining = _roll_direction_change_interval()


func _roll_direction_change_interval() -> float:
	var scale := 1.0 + float(maxi(_threat_level, 0)) * threat_direction_change_scale
	var base_interval := base_drift_direction_change_interval / scale
	return maxf(base_interval * _rng.randf_range(0.75, 1.25), 0.45)


func _get_drift_speed() -> float:
	return base_drift_speed + float(maxi(_threat_level, 0)) * threat_drift_speed_scale


func _offset_to_pixels(offset: float) -> float:
	return offset * size.y * 0.22


func _is_left_aligned() -> bool:
	return absf(left_laser_offset) <= alignment_tolerance


func _is_right_aligned() -> bool:
	return absf(right_laser_offset) <= alignment_tolerance


func _normalize_direction(value: float) -> float:
	return -1.0 if value < 0.0 else 1.0


func _update_labels() -> void:
	if _hint_label:
		_hint_label.text = "ALIGN BOTH LASERS"
	if _prompt_label:
		_prompt_label.text = "A/D SELECT   W/S TUNE"
	if _status_label:
		if _paused:
			_status_label.text = "PAUSED"
		elif _resume_countdown > 0.0:
			_status_label.text = "RESUME %.1f" % _resume_countdown
		else:
			var selected := "LEFT" if selected_laser == LEFT_LASER else "RIGHT"
			_status_label.text = "%s LASER" % selected
