@tool
extends Control
class_name AlignmentAMinigame

signal progress_changed(progress: float)
signal attempt_failed(reason: StringName)
signal completed()
signal state_changed(state: Dictionary)

## Fixed reference size the scene is authored at. The docker scales the whole
## node to fit the host window, so internally everything works in this space.
const REFERENCE_SIZE := Vector2(980.0, 590.0)

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
## How far (radians) the emitter rotates to aim at offset = ±1. The beam fires
## along the emitter's facing direction, so this rotation aims the laser.
@export var max_aim_angle: float = 0.3
## Standalone per-frame textures for the animated beam. They must be individual
## textures, not AtlasTexture regions — Line2D ignores atlas regions and would
## draw the whole sheet. Cycled at beam_anim_fps and tiled along the beam.
@export var beam_frames: Array[Texture2D] = [
	preload("res://_project/ui/research/minigames/sprites/minigame_laser_1_frame_0.png"),
	preload("res://_project/ui/research/minigames/sprites/minigame_laser_1_frame_1.png"),
	preload("res://_project/ui/research/minigames/sprites/minigame_laser_1_frame_2.png"),
	preload("res://_project/ui/research/minigames/sprites/minigame_laser_1_frame_3.png"),
]
@export var beam_anim_fps: float = 8.0
## Base gear spin speed as a multiple of the emitter's aim speed (~2x = the gear
## spins about twice as fast as the laser rotates), in whatever direction the
## emitter base is currently turning. It flips direction the instant the emitter
## reverses, keeping the same speed.
@export var gear_speed_multiplier: float = 10.0
## Extra speed multiple added on top while the player is actively rotating that
## laser with W/S, so the gear visibly spins up in the aimed direction.
@export var gear_input_boost: float = 10.0
## Inset (reference px) from the window edge that bounds the beam, matching the
## frame border so the laser stops at the inner edge rather than under it. The
## root node also clips its contents, so nothing renders past the window.
@export var window_border_inset: float = 5.0

const LEFT_LASER := &"left"
const RIGHT_LASER := &"right"
const ARTIFACT_HIT_RADIUS: float = 34.0
const SELECTED_LASER_COLOR := Color("f7f1a3")

const BEAM_COLOR_NORMAL := Color("75ffe8")
const BEAM_COLOR_SUCCESS := Color("5bff8e")
const BEAM_COLOR_MISALIGNED := Color("ff6f68")
const BEAM_COLOR_DESTROYED := Color("ff2424")
const HEAT_COLOR_COOL := Color("6bdcff")
const HEAT_COLOR_WARM := Color("ffd166")
const HEAT_COLOR_HOT := Color("ff4f4f")
const HEAT_WARM_THRESHOLD: float = 0.55

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
var _left_emitter_base_x: float = 0.0
var _right_emitter_base_x: float = 0.0
var _left_emitter_base_rotation: float = 0.0
var _right_emitter_base_rotation: float = 0.0
var _left_prev_emitter_rotation: float = 0.0
var _right_prev_emitter_rotation: float = 0.0
var _left_gear_dir: float = 1.0
var _right_gear_dir: float = 1.0
var _beam_anim_time: float = 0.0

@onready var _background: Panel = %Background
@onready var _signal_line: Line2D = %SignalLine
@onready var _artifact: Sprite2D = %Artifact
@onready var _left_emitter: Node2D = %LeftEmitter
@onready var _right_emitter: Node2D = %RightEmitter
@onready var _left_muzzle: Marker2D = %LeftMuzzle
@onready var _right_muzzle: Marker2D = %RightMuzzle
@onready var _left_gear: Sprite2D = %LeftGear
@onready var _right_gear: Sprite2D = %RightGear
@onready var _left_beam: Line2D = %LeftBeam
@onready var _right_beam: Line2D = %RightBeam
@onready var _left_beam_glow: Line2D = %LeftBeamGlow
@onready var _right_beam_glow: Line2D = %RightBeamGlow
@onready var _left_heat_bar: TextureProgressBar = %LeftHeat
@onready var _right_heat_bar: TextureProgressBar = %RightHeat
@onready var _left_ticker: Node2D = %LeftTicker
@onready var _right_ticker: Node2D = %RightTicker
@onready var _dim_overlay: ColorRect = %DimOverlay


func _ready() -> void:
	_left_emitter_base_x = _left_emitter.position.x
	_right_emitter_base_x = _right_emitter.position.x
	_left_emitter_base_rotation = _left_emitter.rotation
	_right_emitter_base_rotation = _right_emitter.rotation
	_left_prev_emitter_rotation = _left_emitter.rotation
	_right_prev_emitter_rotation = _right_emitter.rotation
	_build_signal_line()
	if Engine.is_editor_hint():
		# Run a passive refresh loop so the visuals track node edits live.
		set_process(true)
		_update_visuals()
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = REFERENCE_SIZE
	size = REFERENCE_SIZE
	_rng.randomize()
	_build_labels()
	_reset_drift_timers()
	set_process(false)
	_update_visuals()


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
	_update_visuals()


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
	_update_visuals()


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
	_update_visuals()


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
	_update_visuals()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_visuals(delta)
		return
	if not _active or _paused:
		return
	if _resume_countdown > 0.0:
		_resume_countdown = maxf(_resume_countdown - delta, 0.0)
		_update_labels()
		_update_visuals(delta)
		return

	_process_selection_input()
	_process_laser_motion(delta)
	_process_progress_and_heat(delta)
	_update_labels()
	_update_visuals(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _paused:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed:
			match key_event.physical_keycode:
				KEY_A, KEY_D, KEY_W, KEY_S:
					get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Visual updates (drive placed scene nodes; no imperative drawing).
# ---------------------------------------------------------------------------

func _update_visuals(delta: float = 0.0) -> void:
	if _left_beam == null:
		return

	_advance_beam_animation(delta)

	# At runtime the emitters carry the failure-shake offset and aim rotation;
	# in the editor we leave their transforms alone so manual placement and
	# rotation aren't fought — the beam follows whatever rotation is authored.
	if not Engine.is_editor_hint():
		_left_emitter.position.x = _left_emitter_base_x + _left_emitter_shake_offset
		_right_emitter.position.x = _right_emitter_base_x + _right_emitter_shake_offset
		_left_emitter.rotation = _left_aim_angle()
		_right_emitter.rotation = _right_aim_angle()

	var left_origin := _left_origin()
	var right_origin := _right_origin()
	var left_impact := _beam_impact(left_origin, _left_forward())
	var right_impact := _beam_impact(right_origin, _right_forward())

	var left_aligned := _is_left_aligned()
	var right_aligned := _is_right_aligned()
	_update_beam(_left_beam, _left_beam_glow, left_origin, left_impact, left_aligned, selected_laser == LEFT_LASER, LEFT_LASER)
	_update_beam(_right_beam, _right_beam_glow, right_origin, right_impact, right_aligned, selected_laser == RIGHT_LASER, RIGHT_LASER)
	_update_emitter(_left_emitter, selected_laser == LEFT_LASER, _failure_result_laser == LEFT_LASER)
	_update_emitter(_right_emitter, selected_laser == RIGHT_LASER, _failure_result_laser == RIGHT_LASER)
	# Defensive: hot-reloading the script onto an already-open editor instance
	# can leave newly-added member vars uninitialized (null); heal them here.
	if not (_left_gear_dir is float):
		_left_gear_dir = 1.0
	if not (_right_gear_dir is float):
		_right_gear_dir = 1.0
	var aiming := not Engine.is_editor_hint() and _active and not _paused and _resume_countdown <= 0.0 and (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S))
	_left_gear_dir = _spin_gear(_left_gear, _left_emitter.rotation, _left_prev_emitter_rotation, _left_gear_dir, aiming and selected_laser == LEFT_LASER, delta)
	_right_gear_dir = _spin_gear(_right_gear, _right_emitter.rotation, _right_prev_emitter_rotation, _right_gear_dir, aiming and selected_laser == RIGHT_LASER, delta)
	_left_prev_emitter_rotation = _left_emitter.rotation
	_right_prev_emitter_rotation = _right_emitter.rotation
	_update_heat_bar(_left_heat_bar, _left_ticker, left_heat, selected_laser == LEFT_LASER)
	_update_heat_bar(_right_heat_bar, _right_ticker, right_heat, selected_laser == RIGHT_LASER)

	_dim_overlay.visible = _resume_countdown > 0.0 and not _paused and _active


func _advance_beam_animation(delta: float) -> void:
	if beam_frames.is_empty() or beam_anim_fps <= 0.0:
		return
	_beam_anim_time += delta
	var frame_index := int(_beam_anim_time * beam_anim_fps) % beam_frames.size()
	var frame_texture: Texture2D = beam_frames[frame_index]
	if frame_texture == null:
		return
	if _left_beam.texture != frame_texture:
		_left_beam.texture = frame_texture
	if _right_beam.texture != frame_texture:
		_right_beam.texture = frame_texture


func _update_beam(beam: Line2D, glow: Line2D, origin: Vector2, impact: Vector2, aligned: bool, selected: bool, laser_id: StringName) -> void:
	var is_destroyed := _failure_result_laser == laser_id
	var color := BEAM_COLOR_SUCCESS if _success_result_active else BEAM_COLOR_NORMAL
	if not aligned:
		color = BEAM_COLOR_MISALIGNED
	if is_destroyed:
		color = BEAM_COLOR_DESTROYED
	var end_point := origin.lerp(impact, 0.22) if is_destroyed else impact
	var points := PackedVector2Array([origin, end_point])
	beam.points = points
	beam.default_color = color
	glow.points = points
	glow.visible = selected and not is_destroyed


func _update_emitter(emitter: Node2D, selected: bool, destroyed: bool) -> void:
	if destroyed:
		emitter.modulate = BEAM_COLOR_MISALIGNED
	elif selected:
		emitter.modulate = SELECTED_LASER_COLOR
	else:
		emitter.modulate = Color.WHITE


# Spins the gear at a constant speed (gear_speed_multiplier x the emitter's aim
# speed) in whatever direction the emitter base is currently turning. The
# direction flips the instant the emitter reverses while the speed stays
# constant; the last direction is held while the emitter is momentarily still.
# Returns the (possibly updated) spin direction to store for next frame.
func _spin_gear(gear: Sprite2D, emitter_rotation: float, prev_rotation: float, direction: float, input_active: bool, delta: float) -> float:
	if gear == null:
		return direction
	var velocity := emitter_rotation - prev_rotation
	if absf(velocity) > 0.00001:
		direction = signf(velocity)
	var spinning := absf(velocity) > 0.00001 if Engine.is_editor_hint() else (_active and not _paused and _resume_countdown <= 0.0)
	if spinning:
		var multiplier := gear_speed_multiplier + (gear_input_boost if input_active else 0.0)
		var speed := input_speed * max_aim_angle * multiplier
		gear.rotation += direction * speed * delta
	return direction


func _update_heat_bar(bar: TextureProgressBar, ticker: Node2D, heat: float, selected: bool) -> void:
	var clamped := clampf(heat, 0.0, 1.0)
	bar.value = clamped
	var color := HEAT_COLOR_COOL
	if heat >= red_heat_threshold:
		color = HEAT_COLOR_HOT
	elif heat >= HEAT_WARM_THRESHOLD:
		color = HEAT_COLOR_WARM
	bar.tint_progress = color
	bar.modulate = SELECTED_LASER_COLOR if selected else Color.WHITE
	if ticker:
		# The bar fills bottom-to-top within size.y, then is scaled, so the
		# visible fill height is size.y * scale.y. Track the top of the fill.
		var fill_height := bar.size.y * bar.scale.y
		var bottom := bar.position.y + fill_height
		ticker.position.y = lerpf(bottom, bar.position.y, clamped)
		ticker.modulate = color


func _build_signal_line() -> void:
	if _signal_line == null:
		return
	var points := PackedVector2Array()
	var start_x := REFERENCE_SIZE.x * 0.18
	var end_x := REFERENCE_SIZE.x * 0.82
	var center_y := _artifact_center().y
	var steps := 64
	for index in range(steps + 1):
		var ratio := float(index) / float(steps)
		var x := lerpf(start_x, end_x, ratio)
		var y := center_y + sin(ratio * TAU * 7.0) * 5.0
		points.append(Vector2(x, y))
	_signal_line.points = points


# ---------------------------------------------------------------------------
# Geometry (derived from placed nodes so editor layout is authoritative).
# ---------------------------------------------------------------------------

# Aim angle = the live emitter rotation in the editor (so manual rotation drives
# the beam), or the offset-derived angle at runtime (so the aim input does).
func _left_aim_angle() -> float:
	if Engine.is_editor_hint():
		return _left_emitter.rotation
	return _left_emitter_base_rotation + left_laser_offset * max_aim_angle


func _right_aim_angle() -> float:
	if Engine.is_editor_hint():
		return _right_emitter.rotation
	# Mirrored sign: the right muzzle faces -X, so a given offset deflects the
	# beam vertically the opposite way. Negate it so W=up / S=down matches the
	# left laser (the aim input means the same thing for both lasers).
	return _right_emitter_base_rotation - right_laser_offset * max_aim_angle


func _left_origin() -> Vector2:
	if _left_emitter == null or _left_muzzle == null:
		return Vector2(REFERENCE_SIZE.x * 0.12, REFERENCE_SIZE.y * 0.5 - 8.0)
	return _left_emitter.position + _left_muzzle.position.rotated(_left_aim_angle())


func _right_origin() -> Vector2:
	if _right_emitter == null or _right_muzzle == null:
		return Vector2(REFERENCE_SIZE.x * 0.88, REFERENCE_SIZE.y * 0.5 - 8.0)
	return _right_emitter.position + _right_muzzle.position.rotated(_right_aim_angle())


# The beam fires from the muzzle along the emitter's facing direction.
func _left_forward() -> Vector2:
	if _left_muzzle == null:
		return Vector2.RIGHT
	var dir := _left_muzzle.position.rotated(_left_aim_angle())
	return dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT


func _right_forward() -> Vector2:
	if _right_muzzle == null:
		return Vector2.LEFT
	var dir := _right_muzzle.position.rotated(_right_aim_angle())
	return dir.normalized() if dir != Vector2.ZERO else Vector2.LEFT


func _beam_impact(origin: Vector2, direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return origin
	var center := _artifact_center()
	var hitbox := _get_artifact_hitbox(center)
	var inset := maxf(window_border_inset, 0.0)
	var window_rect := Rect2(Vector2(inset, inset), REFERENCE_SIZE - Vector2(inset, inset) * 2.0)
	var far_target := origin + direction * (REFERENCE_SIZE.length() + 200.0)
	return _get_laser_impact_point(origin, far_target, hitbox, window_rect)


func _artifact_center() -> Vector2:
	if _artifact == null:
		return REFERENCE_SIZE * 0.5 + Vector2(0.0, -8.0)
	return _artifact.position


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


# ---------------------------------------------------------------------------
# Labels (still built in code; anchored within the reference rect).
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Gameplay logic (unchanged).
# ---------------------------------------------------------------------------

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


func _is_left_aligned() -> bool:
	return _does_laser_hit_artifact(true)


func _is_right_aligned() -> bool:
	return _does_laser_hit_artifact(false)


func _does_laser_hit_artifact(is_left_laser: bool) -> bool:
	var origin := _left_origin() if is_left_laser else _right_origin()
	var direction := _left_forward() if is_left_laser else _right_forward()
	if direction == Vector2.ZERO:
		return false
	var center := _artifact_center()
	var hitbox := _get_artifact_hitbox(center)
	return bool(_raycast_circle(origin, direction, hitbox.get("center", center), float(hitbox.get("radius", ARTIFACT_HIT_RADIUS))).get("hit", false))


func _normalize_direction(value: float) -> float:
	return -1.0 if value < 0.0 else 1.0


func show_failure_result(reason: StringName) -> void:
	_success_result_active = false
	_failure_result_laser = LEFT_LASER if str(reason).contains("left") else RIGHT_LASER
	_play_failure_emitter_shake()
	_update_labels()
	_update_visuals()


func show_success_result() -> void:
	_failure_result_laser = &""
	_success_result_active = true
	_left_emitter_shake_offset = 0.0
	_right_emitter_shake_offset = 0.0
	_update_labels()
	_update_visuals()


func clear_result_display() -> void:
	_failure_result_laser = &""
	_success_result_active = false
	_left_emitter_shake_offset = 0.0
	_right_emitter_shake_offset = 0.0
	_update_labels()
	_update_visuals()


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
	_update_visuals()


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
