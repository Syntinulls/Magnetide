extends Control
class_name AlignmentAMinigame

signal progress_changed(progress: float)
signal attempt_failed(reason: StringName)
signal completed()
signal state_changed(state: Dictionary)

@export var alignment_tolerance: float = 0.12
@export var base_progress_rate: float = 0.11
@export var base_drift_speed: float = 0.2
@export var threat_drift_speed_scale: float = 0.025
@export var max_random_drift_speed_bonus: float = 0.035
@export var base_drift_direction_change_interval: float = 4.5
@export var input_speed: float = 0.62
@export var max_laser_offset: float = 1.0
@export var heat_build_rate: float = 0.28
@export var threat_heat_build_rate_scale: float = 0.025
@export var heat_cool_rate: float = 0.2
@export var base_heat_cool_delay: float = 0.6
@export var threat_heat_cool_delay_scale: float = 0.25
@export var red_heat_threshold: float = 0.8
@export var red_heat_failure_duration: float = 2.5
@export var resume_delay: float = 0.8

const LEFT_LASER := &"left"
const RIGHT_LASER := &"right"
const ARTIFACT_HIT_RADIUS: float = 34.0

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
var left_heat_cool_delay_remaining: float = 0.0
var right_heat_cool_delay_remaining: float = 0.0

var _threat_level: int = 0
var _active: bool = false
var _paused: bool = true
var _resume_countdown: float = 0.0
var _left_direction_change_remaining: float = 0.0
var _right_direction_change_remaining: float = 0.0
var _left_drift_speed_bonus: float = 0.0
var _right_drift_speed_bonus: float = 0.0
var _drift_speed_bonuses_initialized: bool = false
var _rng := RandomNumberGenerator.new()
var _hint_label: Label = null
var _prompt_label: Label = null
var _status_label: Label = null
var _failure_result_laser: StringName = &""
var _success_result_active: bool = false
var _left_emitter_shake_offset: float = 0.0
var _right_emitter_shake_offset: float = 0.0
var _is_resuming_altered_state: bool = false
var _has_started_state: bool = false


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
	if not _drift_speed_bonuses_initialized:
		_reset_drift_speed_bonuses()

	_active = true
	_paused = false
	_resume_countdown = resume_delay
	_has_started_state = true
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
		"left_heat_cool_delay_remaining": left_heat_cool_delay_remaining,
		"right_heat_cool_delay_remaining": right_heat_cool_delay_remaining,
		"left_direction_change_remaining": _left_direction_change_remaining,
		"right_direction_change_remaining": _right_direction_change_remaining,
		"left_drift_speed_bonus": _left_drift_speed_bonus,
		"right_drift_speed_bonus": _right_drift_speed_bonus,
		"has_started": _has_started_state,
		"rng_state": _rng.state,
	}


func load_state(state: Dictionary) -> void:
	if state.is_empty():
		_is_resuming_altered_state = false
		_has_started_state = false
		_drift_speed_bonuses_initialized = false
		return
	_has_started_state = bool(state.get("has_started", _is_saved_state_altered(state)))
	_is_resuming_altered_state = _has_started_state
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
	left_heat_cool_delay_remaining = maxf(float(state.get("left_heat_cool_delay_remaining", left_heat_cool_delay_remaining)), 0.0)
	right_heat_cool_delay_remaining = maxf(float(state.get("right_heat_cool_delay_remaining", right_heat_cool_delay_remaining)), 0.0)
	_left_direction_change_remaining = maxf(float(state.get("left_direction_change_remaining", _left_direction_change_remaining)), 0.2)
	_right_direction_change_remaining = maxf(float(state.get("right_direction_change_remaining", _right_direction_change_remaining)), 0.2)
	if state.has("left_drift_speed_bonus") and state.has("right_drift_speed_bonus"):
		_left_drift_speed_bonus = _clamp_drift_speed_bonus(float(state["left_drift_speed_bonus"]))
		_right_drift_speed_bonus = _clamp_drift_speed_bonus(float(state["right_drift_speed_bonus"]))
		_drift_speed_bonuses_initialized = true
	else:
		_drift_speed_bonuses_initialized = false
	if state.has("rng_state"):
		_rng.state = int(state["rng_state"])
	_update_labels()
	queue_redraw()


func reset_attempt() -> void:
	progress = 0.0
	left_laser_offset = 0.0
	right_laser_offset = 0.0
	selected_laser = LEFT_LASER
	clear_result_display()
	left_drift_direction = 1.0
	right_drift_direction = -1.0
	left_heat = 0.0
	right_heat = 0.0
	left_red_heat_time = 0.0
	right_red_heat_time = 0.0
	left_heat_cool_delay_remaining = 0.0
	right_heat_cool_delay_remaining = 0.0
	_is_resuming_altered_state = false
	_has_started_state = false
	_reset_drift_timers()
	_reset_drift_speed_bonuses()
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
	var left_origin := Vector2(size.x * 0.12 + _left_emitter_shake_offset, center.y)
	var right_origin := Vector2(size.x * 0.88 + _right_emitter_shake_offset, center.y)
	var artifact_hitbox := _get_artifact_hitbox(center)
	var left_target := center + Vector2(0.0, _offset_to_pixels(left_laser_offset))
	var right_target := center + Vector2(0.0, _offset_to_pixels(right_laser_offset))
	var left_impact := _get_laser_impact_point(left_origin, left_target, artifact_hitbox, rect)
	var right_impact := _get_laser_impact_point(right_origin, right_target, artifact_hitbox, rect)

	_draw_signal_line(center)
	_draw_laser(left_origin, left_impact, _is_left_aligned(), selected_laser == LEFT_LASER, LEFT_LASER)
	_draw_laser(right_origin, right_impact, _is_right_aligned(), selected_laser == RIGHT_LASER, RIGHT_LASER)
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


func _draw_laser(origin: Vector2, impact: Vector2, aligned: bool, selected: bool, laser_id: StringName) -> void:
	var is_destroyed := _failure_result_laser == laser_id
	var color := Color("5bff8e") if _success_result_active else Color("75ffe8")
	if not aligned:
		color = Color("ff6f68")
	if is_destroyed:
		color = Color("ff2424")
	if selected:
		draw_circle(origin, 24.0, Color("f7f1a3"))
	draw_circle(origin, 16.0, Color("6b1515") if is_destroyed else Color("303030"))
	if is_destroyed:
		draw_line(origin, origin.lerp(impact, 0.22), color, 5.0)
		draw_circle(origin + Vector2(0.0, -25.0), 9.0, Color("ff7b42"))
	else:
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


func _get_artifact_hitbox(center: Vector2) -> Dictionary:
	return {
		"center": center,
		"radius": ARTIFACT_HIT_RADIUS,
	}


func _get_laser_impact_point(origin: Vector2, target: Vector2, artifact_hitbox: Dictionary, window_rect: Rect2) -> Vector2:
	var direction := (target - origin).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var artifact_hit := _raycast_circle(origin, direction, artifact_hitbox.get("center", Vector2.ZERO), float(artifact_hitbox.get("radius", ARTIFACT_HIT_RADIUS)))
	if artifact_hit.get("hit", false):
		return artifact_hit["point"] as Vector2

	var window_hit := _raycast_rect(origin, direction, window_rect)
	if window_hit.get("hit", false):
		return window_hit["point"] as Vector2
	return target


func _raycast_circle(origin: Vector2, direction: Vector2, center: Vector2, radius: float) -> Dictionary:
	var to_center := center - origin
	var projection := to_center.dot(direction)
	if projection < 0.0:
		return { "hit": false }

	var closest_point := origin + direction * projection
	var distance_sq := closest_point.distance_squared_to(center)
	var radius_sq := radius * radius
	if distance_sq > radius_sq:
		return { "hit": false }

	var half_chord := sqrt(radius_sq - distance_sq)
	var hit_distance := projection - half_chord
	if hit_distance < 0.0:
		hit_distance = projection + half_chord
	if hit_distance < 0.0:
		return { "hit": false }
	return {
		"hit": true,
		"point": origin + direction * hit_distance,
	}


func _raycast_rect(origin: Vector2, direction: Vector2, rect: Rect2) -> Dictionary:
	var t_min := -INF
	var t_max := INF

	if is_zero_approx(direction.x):
		if origin.x < rect.position.x or origin.x > rect.end.x:
			return { "hit": false }
	else:
		var tx1 := (rect.position.x - origin.x) / direction.x
		var tx2 := (rect.end.x - origin.x) / direction.x
		t_min = maxf(t_min, minf(tx1, tx2))
		t_max = minf(t_max, maxf(tx1, tx2))

	if is_zero_approx(direction.y):
		if origin.y < rect.position.y or origin.y > rect.end.y:
			return { "hit": false }
	else:
		var ty1 := (rect.position.y - origin.y) / direction.y
		var ty2 := (rect.end.y - origin.y) / direction.y
		t_min = maxf(t_min, minf(ty1, ty2))
		t_max = minf(t_max, maxf(ty1, ty2))

	if t_max < maxf(t_min, 0.0):
		return { "hit": false }

	var distance := t_min if t_min >= 0.0 else t_max
	if distance < 0.0:
		return { "hit": false }
	return {
		"hit": true,
		"point": origin + direction * distance,
	}


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

	var left_motion := left_drift_direction * _get_laser_drift_speed(true) * delta
	var right_motion := right_drift_direction * _get_laser_drift_speed(false) * delta

	if selected_laser == LEFT_LASER and not is_zero_approx(selected_motion):
		left_motion = selected_motion
	elif selected_laser == RIGHT_LASER and not is_zero_approx(selected_motion):
		right_motion = selected_motion

	left_laser_offset = clampf(left_laser_offset + left_motion, -max_laser_offset, max_laser_offset)
	right_laser_offset = clampf(right_laser_offset + right_motion, -max_laser_offset, max_laser_offset)


func _process_progress_and_heat(delta: float) -> void:
	var left_aligned := _is_left_aligned()
	var right_aligned := _is_right_aligned()
	if left_aligned and right_aligned:
		progress = clampf(progress + base_progress_rate * delta, 0.0, 1.0)
		progress_changed.emit(progress)

	left_heat = _update_heat(left_heat, left_aligned, delta, true)
	right_heat = _update_heat(right_heat, right_aligned, delta, false)
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


func _update_heat(value: float, aligned: bool, delta: float, is_left_laser: bool) -> float:
	var delay_remaining := left_heat_cool_delay_remaining if is_left_laser else right_heat_cool_delay_remaining
	if aligned:
		delay_remaining = maxf(delay_remaining - delta, 0.0)
		_set_heat_cool_delay(is_left_laser, delay_remaining)
		if delay_remaining > 0.0:
			return value
		return clampf(value - heat_cool_rate * delta, 0.0, 1.0)
	_set_heat_cool_delay(is_left_laser, _get_heat_cool_delay())
	return clampf(value + _get_heat_build_rate() * delta, 0.0, 1.0)


func _set_heat_cool_delay(is_left_laser: bool, value: float) -> void:
	if is_left_laser:
		left_heat_cool_delay_remaining = value
	else:
		right_heat_cool_delay_remaining = value


func _get_heat_cool_delay() -> float:
	return maxf(base_heat_cool_delay + float(maxi(_threat_level, 0)) * threat_heat_cool_delay_scale, 0.0)


func _get_heat_build_rate() -> float:
	return maxf(heat_build_rate + float(maxi(_threat_level, 0)) * threat_heat_build_rate_scale, 0.0)


func _update_red_time(value: float, heat: float, delta: float) -> float:
	if heat >= red_heat_threshold:
		return value + delta
	return 0.0


func _update_drift_direction(delta: float) -> void:
	if _is_left_aligned():
		_left_direction_change_remaining -= delta
		if _left_direction_change_remaining <= 0.0:
			left_drift_direction = _roll_direction(left_laser_offset)
			_left_direction_change_remaining = _roll_direction_change_interval()
	if _is_right_aligned():
		_right_direction_change_remaining -= delta
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
	return maxf(base_drift_direction_change_interval * _rng.randf_range(0.75, 1.25), 0.45)


func _reset_drift_speed_bonuses() -> void:
	_left_drift_speed_bonus = _roll_drift_speed_bonus()
	_right_drift_speed_bonus = _roll_drift_speed_bonus()
	_drift_speed_bonuses_initialized = true


func _roll_drift_speed_bonus() -> float:
	return _rng.randf_range(0.0, maxf(max_random_drift_speed_bonus, 0.0))


func _get_laser_drift_speed(is_left_laser: bool) -> float:
	var bonus := _left_drift_speed_bonus if is_left_laser else _right_drift_speed_bonus
	return _get_base_drift_speed() + bonus


func _get_base_drift_speed() -> float:
	return base_drift_speed + float(maxi(_threat_level, 0)) * threat_drift_speed_scale


func _clamp_drift_speed_bonus(value: float) -> float:
	return clampf(value, 0.0, maxf(max_random_drift_speed_bonus, 0.0))


func _offset_to_pixels(offset: float) -> float:
	return offset * size.y * 0.22


func _is_left_aligned() -> bool:
	return _does_laser_hit_artifact(left_laser_offset, true)


func _is_right_aligned() -> bool:
	return _does_laser_hit_artifact(right_laser_offset, false)


func _does_laser_hit_artifact(laser_offset: float, is_left_laser: bool) -> bool:
	if size.x <= 0.0 or size.y <= 0.0:
		return absf(laser_offset) <= alignment_tolerance

	var window_rect := Rect2(Vector2.ZERO, size)
	var center := window_rect.get_center() + Vector2(0.0, -8.0)
	var origin_x := size.x * 0.12 if is_left_laser else size.x * 0.88
	var origin := Vector2(origin_x, center.y)
	var target := center + Vector2(0.0, _offset_to_pixels(laser_offset))
	var direction := (target - origin).normalized()
	if direction == Vector2.ZERO:
		return false

	var hitbox := _get_artifact_hitbox(center)
	return bool(_raycast_circle(origin, direction, hitbox.get("center", center), float(hitbox.get("radius", ARTIFACT_HIT_RADIUS))).get("hit", false))


func _normalize_direction(value: float) -> float:
	return -1.0 if value < 0.0 else 1.0


func show_failure_result(reason: StringName) -> void:
	_success_result_active = false
	_failure_result_laser = LEFT_LASER if str(reason).contains("left") else RIGHT_LASER
	_play_failure_emitter_shake()
	_update_labels()
	queue_redraw()


func show_success_result() -> void:
	_failure_result_laser = &""
	_success_result_active = true
	_left_emitter_shake_offset = 0.0
	_right_emitter_shake_offset = 0.0
	_update_labels()
	queue_redraw()


func clear_result_display() -> void:
	_failure_result_laser = &""
	_success_result_active = false
	_left_emitter_shake_offset = 0.0
	_right_emitter_shake_offset = 0.0
	_update_labels()
	queue_redraw()


func _is_saved_state_altered(state: Dictionary) -> bool:
	if absf(float(state.get("progress", 0.0))) > 0.001:
		return true
	if absf(float(state.get("left_laser_offset", 0.0))) > 0.001:
		return true
	if absf(float(state.get("right_laser_offset", 0.0))) > 0.001:
		return true
	if absf(float(state.get("left_heat", 0.0))) > 0.001:
		return true
	if absf(float(state.get("right_heat", 0.0))) > 0.001:
		return true
	if absf(float(state.get("left_red_heat_time", 0.0))) > 0.001:
		return true
	if absf(float(state.get("right_red_heat_time", 0.0))) > 0.001:
		return true
	if absf(float(state.get("left_heat_cool_delay_remaining", 0.0))) > 0.001:
		return true
	if absf(float(state.get("right_heat_cool_delay_remaining", 0.0))) > 0.001:
		return true
	return StringName(str(state.get("selected_laser", LEFT_LASER))) != LEFT_LASER


func _play_failure_emitter_shake() -> void:
	var tween := create_tween()
	tween.tween_method(Callable(self, "_set_failed_emitter_shake_offset"), 0.0, -14.0, 0.045)
	tween.tween_method(Callable(self, "_set_failed_emitter_shake_offset"), -14.0, 12.0, 0.06)
	tween.tween_method(Callable(self, "_set_failed_emitter_shake_offset"), 12.0, -7.0, 0.05)
	tween.tween_method(Callable(self, "_set_failed_emitter_shake_offset"), -7.0, 0.0, 0.07)


func _set_failed_emitter_shake_offset(value: float) -> void:
	if _failure_result_laser == LEFT_LASER:
		_left_emitter_shake_offset = value
	elif _failure_result_laser == RIGHT_LASER:
		_right_emitter_shake_offset = value
	queue_redraw()


func _update_labels() -> void:
	if _hint_label:
		if _failure_result_laser != &"":
			_hint_label.text = "LASER OVERHEATED"
		elif _success_result_active:
			_hint_label.text = "ARTIFACT STABLE"
		else:
			_hint_label.text = "ALIGN BOTH LASERS"
	if _prompt_label:
		_prompt_label.text = "A/D SELECT   W/S TUNE"
	if _status_label:
		if _paused:
			_status_label.text = "PAUSED"
		elif _resume_countdown > 0.0:
			var countdown_action := "RESUME" if _is_resuming_altered_state else "START"
			_status_label.text = "%s IN %.1f" % [countdown_action, _resume_countdown]
		else:
			var selected := "LEFT" if selected_laser == LEFT_LASER else "RIGHT"
			_status_label.text = "%s LASER" % selected
