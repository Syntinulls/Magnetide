extends Control
class_name LeverMinigame

## Lever activation minigame: a crosshair reticle sweeps left-to-right across a
## bar of green/yellow/red zones. The player presses interact as the reticle
## crosses each green zone ("PERFECT") or a flanking yellow ("CLOSE", which also
## speeds the reticle up). Pressing on red -- or letting an unresolved zone pair
## slip past -- turns every light red and fails the attempt instantly. One result
## light per green zone reports the outcome below the bar.
##
## The panel lives on the HUD canvas but is presented like a world object: its
## bottom-center is glued to a world anchor point (the activation zoom's focus,
## set via set_world_anchor) through the canvas transform each frame, and its
## scale matches the camera zoom, so the panel zooms in with the world. The
## camera finishes centered on the anchor, leaving the panel bottom-centered on
## screen at the zoomed scale. All timers/movement divide out Engine.time_scale
## so the minigame plays at wall-clock speed during the activation slowdown.

signal minigame_completed(success: bool)
signal pair_resolved(pair_index: int, total_pairs: int)

enum State { INACTIVE, SETUP, COUNTDOWN, PLAYING, RESULT }
enum ZoneType { GREEN, YELLOW, RED }

const STRIPES_TEXTURE: Texture2D = preload("res://_project/level/magnet_minigame/sprites/stripes_50.png")
const ZONE_BORDER_TEXTURE: Texture2D = preload("res://_project/common/sprites/ui_border_4px_white.png")
const LIGHT_OFF_TEXTURE: Texture2D = preload("res://_project/level/magnet_minigame/sprites/light_off.png")
const LIGHT_GREEN_TEXTURE: Texture2D = preload("res://_project/level/magnet_minigame/sprites/light_on_green.png")
const LIGHT_YELLOW_TEXTURE: Texture2D = preload("res://_project/level/magnet_minigame/sprites/light_on_yellow.png")
const LIGHT_RED_TEXTURE: Texture2D = preload("res://_project/level/magnet_minigame/sprites/light_on_red.png")
const ZONE_BORDER_PATCH_MARGIN := 6
## Panels bordered by the ui_border sprites inset their content by this much.
const ZONE_CONTENT_INSET := 3.0
const COUNTDOWN_STEPS := 3
const INFO_HIDE_TWEEN_TIME := 0.15

@export_group("Zones")
## Full width of a green zone as a ratio of the bar width.
@export var green_width_ratio: float = 0.04
## Width of each yellow zone (one per side of every green) as a ratio of the bar width.
@export var yellow_width_ratio: float = 0.08
## Green zones at min threat (stage 0) and max threat (stage 9); scales linearly between.
@export var zones_min: int = 2
@export var zones_max: int = 5
## Minimum distance between green zone centers as a ratio of the bar width.
## Must be at least green_width_ratio + 2 * yellow_width_ratio or yellows overlap.
@export var min_green_center_spacing_ratio: float = 0.20
## Minimum distance from a green zone center to either bar edge as a ratio of the
## bar width. Must be at least half the green+yellows cluster width.
@export var green_edge_margin_ratio: float = 0.10

@export_group("Reticle")
## Constant reticle speed as a ratio of the bar width per second.
@export var reticle_speed_ratio: float = 0.55
## Speed multiplier step per yellow hit (0.1 = 1.1x at one yellow, 1.2x at two).
@export var yellow_speed_penalty_ratio: float = 0.1

@export_group("Countdown")
## Empty-bar hold after the panel appears, before the first zones reveal.
@export var setup_delay: float = 0.5
## Pause between revealing the green, yellow, and red zone groups (and between
## the last reveal and the countdown starting).
@export var zone_reveal_pause: float = 0.5
## Real-time seconds per countdown digit (3 -> 2 -> 1).
@export var countdown_step_time: float = 0.6

@export_group("Feedback")
## Time for the info text to pop from zero to full scale.
@export var info_pop_time: float = 0.18
## Idle time before the info text scales back to hidden.
@export var info_hold_time: float = 1.5
## Pause with the reticle halted after a miss before the minigame closes.
@export var fail_pause_time: float = 0.6
## Time to linger on a successful result before closing.
@export var result_display_time: float = 1.5
@export var zone_color_green: Color = Color("58c05c")
@export var zone_color_yellow: Color = Color("e8c14b")
@export var zone_color_red: Color = Color("d1493f")

class Zone:
	var type: ZoneType
	var start_ratio: float
	var end_ratio: float
	var pair_index: int = -1
	var control: Control

class Pair:
	var resolved := false
	var center_ratio: float
	## Right edge of the green+yellows cluster; passing it unresolved is a miss.
	var right_edge_ratio: float
	var light: TextureRect

var _state: State = State.INACTIVE
var _zones: Array[Zone] = []
var _pairs: Array[Pair] = []
var _reticle_ratio: float = 0.0
var _yellows_hit: int = 0
var _setup_elapsed: float = 0.0
var _countdown_elapsed: float = 0.0
var _countdown_digit: int = 0
var _greens_revealed := false
var _yellows_revealed := false
var _reds_revealed := false
var _result_timer: float = 0.0
var _game_won := false
var _world_anchor := Vector2.ZERO
var _has_world_anchor := false
var _base_camera_zoom := Vector2.ONE
var _info_tween: Tween = null

@onready var _info_label: Label = $InfoLabel
@onready var _zone_row: HBoxContainer = $OuterPanel/InnerPanel/ZoneRow
@onready var _reticle: TextureRect = $OuterPanel/InnerPanel/Reticle
@onready var _lights_row: Control = $OuterPanel/LightsRow


func _ready() -> void:
	_info_label.scale = Vector2.ZERO
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	# Runs PROCESS_MODE_ALWAYS (to ignore the timescale slowdown), so it must
	# respect the pause menu explicitly.
	if get_tree().paused:
		return
	_update_placement()
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	# Tweens tick on scaled time; keep the info pop at wall-clock speed while
	# the timescale slowdown tweens in and out underneath it.
	if _info_tween and _info_tween.is_valid():
		_info_tween.set_speed_scale(1.0 / Engine.time_scale if Engine.time_scale > 0.0 else 1.0)
	match _state:
		State.SETUP:
			_process_setup(real_delta)
		State.COUNTDOWN:
			_process_countdown(real_delta)
		State.PLAYING:
			_process_playing(real_delta)
		State.RESULT:
			_process_result(real_delta)


func _input(event: InputEvent) -> void:
	if get_tree().paused or _state != State.PLAYING:
		return
	if event.is_action_pressed("interact"):
		_evaluate_press()


## Difficulty scales by threat level (zero-based stage index 0-9), not rarity.
func start_minigame(threat_level: int) -> void:
	var clamped_threat := clampi(threat_level, 0, ThreatManager.LEVEL_COUNT - 1)
	_reset_state()
	_build_zones(clamped_threat)
	_update_reticle_position()
	_update_placement()
	visible = true
	set_process(true)
	_state = State.SETUP


func cancel_minigame() -> void:
	visible = false
	set_process(false)
	_state = State.INACTIVE
	_reset_state()


## World point the panel's bottom-center is glued to; should be the point the
## activation zoom focuses on so the panel scales with the world around it.
## Call before start_minigame, while the camera is still at its resting zoom.
func set_world_anchor(point: Vector2) -> void:
	_world_anchor = point
	_has_world_anchor = true
	var camera := get_viewport().get_camera_2d()
	_base_camera_zoom = camera.zoom if camera else Vector2.ONE


func _reset_state() -> void:
	_zones.clear()
	_pairs.clear()
	_reticle_ratio = 0.0
	_yellows_hit = 0
	_setup_elapsed = 0.0
	_countdown_elapsed = 0.0
	_countdown_digit = 0
	_greens_revealed = false
	_yellows_revealed = false
	_reds_revealed = false
	_result_timer = 0.0
	_game_won = false
	# Remove immediately, not just queue_free: zones are rebuilt and revealed in
	# this same frame, and stale children would corrupt the row's child order.
	for child in _zone_row.get_children():
		_zone_row.remove_child(child)
		child.queue_free()
	for child in _lights_row.get_children():
		_lights_row.remove_child(child)
		child.queue_free()
	if _info_tween and _info_tween.is_valid():
		_info_tween.kill()
	_info_tween = null
	_info_label.scale = Vector2.ZERO


func _update_placement() -> void:
	var camera := get_viewport().get_camera_2d()
	if not _has_world_anchor or camera == null:
		var screen_size := get_viewport().get_visible_rect().size
		position = Vector2(screen_size.x * 0.5, screen_size.y * 0.5)
		scale = Vector2.ONE
		return
	position = get_viewport().get_canvas_transform() * _world_anchor
	scale = camera.zoom / _base_camera_zoom


## The bar starts empty; zones reveal green -> yellow -> red on a beat, then the
## countdown begins.
func _process_setup(real_delta: float) -> void:
	_setup_elapsed += real_delta
	if not _greens_revealed and _setup_elapsed >= setup_delay:
		_greens_revealed = true
		_reveal_zones(ZoneType.GREEN)
	if not _yellows_revealed and _setup_elapsed >= setup_delay + zone_reveal_pause:
		_yellows_revealed = true
		_reveal_zones(ZoneType.YELLOW)
	if not _reds_revealed and _setup_elapsed >= setup_delay + zone_reveal_pause * 2.0:
		_reds_revealed = true
		_reveal_zones(ZoneType.RED)
	if _setup_elapsed >= setup_delay + zone_reveal_pause * 3.0:
		_state = State.COUNTDOWN
		_countdown_digit = COUNTDOWN_STEPS
		_show_info(str(COUNTDOWN_STEPS), Color.WHITE)


func _process_countdown(real_delta: float) -> void:
	_countdown_elapsed += real_delta
	if _countdown_elapsed >= countdown_step_time * COUNTDOWN_STEPS:
		_state = State.PLAYING
		_show_info("Go!", zone_color_green)
		return
	var digit := COUNTDOWN_STEPS - int(_countdown_elapsed / countdown_step_time)
	if digit != _countdown_digit:
		_countdown_digit = digit
		_show_info(str(digit), Color.WHITE)


func _process_playing(real_delta: float) -> void:
	var speed := reticle_speed_ratio * (1.0 + yellow_speed_penalty_ratio * _yellows_hit)
	_reticle_ratio += speed * real_delta
	if _reticle_ratio >= 1.0:
		_reticle_ratio = 1.0
		_update_reticle_position()
		_game_won = true
		_state = State.RESULT
		return
	_update_reticle_position()
	for pair in _pairs:
		if not pair.resolved and _reticle_ratio > pair.right_edge_ratio:
			_fail_minigame()
			return


func _process_result(real_delta: float) -> void:
	_result_timer += real_delta
	var wait_time := result_display_time if _game_won else fail_pause_time
	if _result_timer >= wait_time:
		visible = false
		set_process(false)
		_state = State.INACTIVE
		minigame_completed.emit(_game_won)


func _evaluate_press() -> void:
	var zone := _zone_at_ratio(_reticle_ratio)
	if zone == null:
		return
	match zone.type:
		ZoneType.RED:
			_fail_minigame()
		ZoneType.GREEN:
			_resolve_pair(zone.pair_index, true)
		ZoneType.YELLOW:
			_resolve_pair(zone.pair_index, false)


func _resolve_pair(pair_index: int, perfect: bool) -> void:
	var pair := _pairs[pair_index]
	if pair.resolved:
		return
	pair.resolved = true
	if perfect:
		pair.light.texture = LIGHT_GREEN_TEXTURE
		_show_info("PERFECT", zone_color_green)
	else:
		pair.light.texture = LIGHT_YELLOW_TEXTURE
		_yellows_hit += 1
		_show_info("CLOSE", zone_color_yellow)
	pair_resolved.emit(pair_index, _pairs.size())


func _fail_minigame() -> void:
	for pair in _pairs:
		pair.light.texture = LIGHT_RED_TEXTURE
	_show_info("MISS", zone_color_red)
	_game_won = false
	_result_timer = 0.0
	_state = State.RESULT


func _zone_at_ratio(ratio: float) -> Zone:
	for zone in _zones:
		if ratio >= zone.start_ratio and ratio < zone.end_ratio:
			return zone
	return null


func _build_zones(threat_level: int) -> void:
	var pair_count := _scale_for_threat(threat_level, zones_min, zones_max)
	var centers := _generate_green_centers(pair_count)
	var half_green := green_width_ratio * 0.5
	var cursor := 0.0
	for i in range(centers.size()):
		var center: float = centers[i]
		var cluster_start := center - half_green - yellow_width_ratio
		_append_zone(ZoneType.RED, cursor, cluster_start)
		_append_zone(ZoneType.YELLOW, cluster_start, center - half_green, i)
		_append_zone(ZoneType.GREEN, center - half_green, center + half_green, i)
		_append_zone(ZoneType.YELLOW, center + half_green, center + half_green + yellow_width_ratio, i)
		cursor = center + half_green + yellow_width_ratio
		var pair := Pair.new()
		pair.center_ratio = center
		pair.right_edge_ratio = cursor
		_pairs.append(pair)
	_append_zone(ZoneType.RED, cursor, 1.0)
	_build_zone_controls()
	_build_lights()


func _append_zone(type: ZoneType, start_ratio: float, end_ratio: float, pair_index: int = -1) -> void:
	if end_ratio - start_ratio <= 0.0:
		return
	var zone := Zone.new()
	zone.type = type
	zone.start_ratio = start_ratio
	zone.end_ratio = end_ratio
	zone.pair_index = pair_index
	_zones.append(zone)


## Random centers honoring edge margins and minimum spacing; falls back to even
## spacing when rejection sampling can't fit every green zone.
func _generate_green_centers(pair_count: int) -> Array[float]:
	var centers: Array[float] = []
	var low := green_edge_margin_ratio
	var high := 1.0 - green_edge_margin_ratio
	var attempts := 0
	while centers.size() < pair_count and attempts < 100:
		attempts += 1
		var candidate := randf_range(low, high)
		var valid := true
		for existing in centers:
			if absf(candidate - existing) < min_green_center_spacing_ratio:
				valid = false
				break
		if valid:
			centers.append(candidate)
	if centers.size() < pair_count:
		centers.clear()
		for i in range(pair_count):
			if pair_count == 1:
				centers.append(0.5)
			else:
				centers.append(low + (high - low) * float(i) / float(pair_count - 1))
	centers.sort()
	return centers


## Zones become HBox children whose pixel widths recreate the ratio boundaries;
## the row's 1px separation is cosmetic only -- hit checks use the ratios.
func _build_zone_controls() -> void:
	var bar_width := _zone_row.size.x
	var boundaries: Array[int] = []
	for zone in _zones:
		boundaries.append(int(roundf(zone.start_ratio * bar_width)))
	boundaries.append(int(roundf(bar_width)))
	for i in range(_zones.size()):
		var width := boundaries[i + 1] - boundaries[i]
		if i < _zones.size() - 1:
			width -= 1
		_zones[i].control = _make_zone_control(_zones[i].type, maxi(width, 1))
		_zone_row.add_child(_zones[i].control)


func _make_zone_control(type: ZoneType, width: int) -> Control:
	var zone_control := Control.new()
	zone_control.custom_minimum_size = Vector2(width, 0.0)
	zone_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Zone color tints both the stripes and the border; alpha 0 until this
	# zone's reveal step during the countdown.
	zone_control.modulate = Color(_zone_color(type), 0.0)
	var stripes := TextureRect.new()
	stripes.texture = STRIPES_TEXTURE
	stripes.stretch_mode = TextureRect.STRETCH_TILE
	# Without this the TextureRect's minimum size is the 50x50 texture, and
	# anchored controls clamp to minimum -- narrow zones would spill past their
	# border instead of honoring the 3px inset.
	stripes.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stripes.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
	stripes.offset_left = ZONE_CONTENT_INSET
	stripes.offset_top = ZONE_CONTENT_INSET
	stripes.offset_right = -ZONE_CONTENT_INSET
	stripes.offset_bottom = -ZONE_CONTENT_INSET
	stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_control.add_child(stripes)
	var border := NinePatchRect.new()
	border.texture = ZONE_BORDER_TEXTURE
	border.patch_margin_left = ZONE_BORDER_PATCH_MARGIN
	border.patch_margin_top = ZONE_BORDER_PATCH_MARGIN
	border.patch_margin_right = ZONE_BORDER_PATCH_MARGIN
	border.patch_margin_bottom = ZONE_BORDER_PATCH_MARGIN
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_control.add_child(border)
	return zone_control


func _build_lights() -> void:
	var bar_width := _zone_row.size.x
	for pair in _pairs:
		var light := TextureRect.new()
		light.texture = LIGHT_OFF_TEXTURE
		light.stretch_mode = TextureRect.STRETCH_KEEP
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var light_size := LIGHT_OFF_TEXTURE.get_size()
		light.position = Vector2(
			ZONE_CONTENT_INSET + pair.center_ratio * bar_width - light_size.x * 0.5,
			(_lights_row.size.y - light_size.y) * 0.5)
		_lights_row.add_child(light)
		pair.light = light


func _reveal_zones(type: ZoneType) -> void:
	for zone in _zones:
		if zone.type == type:
			zone.control.modulate.a = 1.0


func _zone_color(type: ZoneType) -> Color:
	match type:
		ZoneType.GREEN:
			return zone_color_green
		ZoneType.YELLOW:
			return zone_color_yellow
		_:
			return zone_color_red


func _update_reticle_position() -> void:
	var bar_width := _zone_row.size.x
	_reticle.position.x = ZONE_CONTENT_INSET + _reticle_ratio * bar_width - _reticle.size.x * 0.5


## Pop the info text in at center pivot; after info_hold_time without another
## update it scales back to hidden. Each call restarts the whole chain.
func _show_info(text: String, color: Color) -> void:
	if _info_tween and _info_tween.is_valid():
		_info_tween.kill()
	_info_label.text = text
	_info_label.add_theme_color_override("font_color", color)
	_info_label.pivot_offset = _info_label.size * 0.5
	_info_label.scale = Vector2.ZERO
	_info_tween = _info_label.create_tween()
	_info_tween.tween_property(_info_label, "scale", Vector2.ONE, info_pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_info_tween.tween_interval(info_hold_time)
	_info_tween.tween_property(_info_label, "scale", Vector2.ZERO, INFO_HIDE_TWEEN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _scale_for_threat(threat_level: int, min_value: int, max_value: int) -> int:
	var span := maxi(ThreatManager.LEVEL_COUNT - 1, 1)
	var t := clampf(float(threat_level) / float(span), 0.0, 1.0)
	return int(roundf(lerpf(float(min_value), float(max_value), t)))
