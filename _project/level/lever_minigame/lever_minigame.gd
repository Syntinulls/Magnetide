extends CanvasLayer
class_name LeverMinigame

## Lever activation minigame: a crosshair reticle sweeps left-to-right across a
## bar of green/yellow/red zones. The player presses interact as the reticle
## crosses each green zone ("PERFECT") or a flanking yellow ("CLOSE", which also
## speeds the reticle up). Pressing on red -- or letting an unresolved zone pair
## slip past -- turns every light red and fails the attempt instantly. Once the attempt
## is settled -- every pair lit, or a miss taken -- the panel stops accepting input
## while the crosshair finishes its sweep, so a decided result cannot be undone. One result
## light per green zone reports the outcome below the bar. Hitting a green or yellow
## punches that zone up in scale and lights it to full glow, where it stays for the
## rest of the attempt as the record of what was hit; hitting a red blinks every red
## zone in unison like a warning light and kicks the reticle before the panel closes.
##
## Owns the whole activation presentation: while it runs it slows
## Engine.time_scale, zooms the camera onto a focus point above the player, and
## fades in the grayscale vignette (authored on the child VignetteLayer, canvas
## layer 100 -- above the HUD, below this scene's own layer 110 so only the
## minigame escapes the grayscale). The panel is presented like a world object:
## its bottom-center is glued to the zoom focus point through the canvas
## transform each frame and its scale matches the camera zoom, so it zooms in
## with the world and ends bottom-centered on screen. All timers/movement divide
## out Engine.time_scale so the minigame plays at wall-clock speed during the
## slowdown. Instanced in level.tscn; MagnetMinigame only starts it and reacts
## to its signals.
##
## Each attempt may roll a modifier from modifier_weights (none/positive/negative
## pools; the negative pool's weight scales with threat). The rolled
## LeverModifierBehavior hooks into zone building, press handling, and the
## post-close moment; with no modifier the minigame plays exactly as authored.
## See specs/lever_minigame_modifiers_spec.md.

signal minigame_completed(success: bool)
signal pair_resolved(pair_index: int, total_pairs: int)

enum State { INACTIVE, SETUP, COUNTDOWN, PLAYING, RESULT }
enum ZoneType { GREEN, YELLOW, RED, SPECIAL }

const STRIPES_TEXTURE: Texture2D = preload("res://_project/level/lever_minigame/sprites/stripes_50.png")
const ZONE_BORDER_TEXTURE: Texture2D = preload("res://_project/common/sprites/ui_border_4px_white.png")
const LIGHT_OFF_TEXTURE: Texture2D = preload("res://_project/level/lever_minigame/sprites/light_off.png")
const LIGHT_GREEN_TEXTURE: Texture2D = preload("res://_project/level/lever_minigame/sprites/light_on_green.png")
const LIGHT_YELLOW_TEXTURE: Texture2D = preload("res://_project/level/lever_minigame/sprites/light_on_yellow.png")
const LIGHT_RED_TEXTURE: Texture2D = preload("res://_project/level/lever_minigame/sprites/light_on_red.png")
## Glow materials duplicated per zone and per result light so each one can be driven
## on its own; all their tuning lives in the .tres files, not here.
const ZONE_GLOW: ShaderMaterial = preload("res://_project/level/lever_minigame/zone_glow.tres")
const LIGHT_GLOW: ShaderMaterial = preload("res://_project/level/lever_minigame/light_glow.tres")
const ZONE_BORDER_PATCH_MARGIN := 6
## Panels bordered by the ui_border sprites inset their content by this much.
const ZONE_CONTENT_INSET := 3.0
const COUNTDOWN_STEPS := 3
const INFO_HIDE_TWEEN_TIME := 0.15

@export_group("Zones")
## Full width of a green zone as a ratio of the bar width, at min threat (stage 0).
@export var green_width_ratio: float = 0.04
## Width of each yellow zone (one per side of every green) as a ratio of the bar
## width, at min threat (stage 0).
@export var yellow_width_ratio: float = 0.06
## Zone width multiplier at max threat (stage 9), lerped from 1.0 at stage 0.
## Green and yellow shrink by the same factor so their ratio holds at every
## threat while the growing zone count doesn't crowd out the red.
@export var zone_width_scale_at_max_threat: float = 1.0 / 3.0
## Green zones at min threat (stage 0) and max threat (stage 9); scales linearly between.
@export var zones_min: int = 2
@export var zones_max: int = 5
## Minimum distance between green zone centers as a ratio of the bar width.
## Must be at least the green+yellows cluster width at every threat or yellows overlap.
@export var min_green_center_spacing_ratio: float = 0.20
## Minimum distance from a green zone center to either bar edge as a ratio of the
## bar width. Must be at least half the green+yellows cluster width.
@export var green_edge_margin_ratio: float = 0.10

@export_group("Reticle")
## Constant reticle speed as a ratio of the bar width per second.
@export var reticle_speed_ratio: float = 0.35
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
## Time for a hit green/yellow zone to flare its glow to full.
@export var zone_hit_flash_time: float = 0.06
## Scale a hit green/yellow zone bounces up to before settling back.
@export var zone_hit_scale: Vector2 = Vector2(1.45, 1.2)
## Time for the bounce out, then the elastic settle back to default scale.
@export var zone_hit_bounce_time: float = 0.09
@export var zone_hit_settle_time: float = 0.32
## Pause with the reticle halted after a miss, during which every red zone blinks,
## before the minigame closes.
@export var fail_pause_time: float = 1.6
## Blinks the red zones fit into that pause.
@export var fail_flash_count: int = 4
## How far the reticle kicks sideways on a red hit, in pixels.
@export var reticle_shake_offset: float = 10.0
## Scale the reticle punches to on that same kick.
@export var reticle_shake_scale: float = 1.35
## Duration of the whole one-off kick.
@export var reticle_shake_time: float = 0.24
## Time to linger on a successful result before closing.
@export var result_display_time: float = 0.75
## Full-strength colour of each zone: what it shows the instant it is hit, and what
## the info text is tinted with. A resting zone sits at zone_idle_darken of this.
@export var zone_color_green: Color = Color("58c05c")
@export var zone_color_yellow: Color = Color("e8c14b")
@export var zone_color_red: Color = Color("d1493f")
## How far a resting zone is darkened from its full-strength colour. The hit flash
## and the fail blink swing it back up, so a zone lighting up is carried by its own
## colour rather than by the glow -- bloom then only adds on top, and the read
## survives the Bloom video option being off.
@export_range(0.1, 1.0, 0.01) var zone_idle_darken: float = 0.82

@export_group("Activation Effects")
## Target Engine.time_scale while the minigame runs (restored on completion).
@export var activation_timescale: float = 0.01
## Real-time seconds to ease the timescale down to activation_timescale.
@export var timescale_slowdown_time: float = 1.0
## Camera zoom multiplier while the minigame runs.
@export var activation_zoom: float = 1.5
## Zoom/vignette tween-in time; the restore takes half of this.
@export var zoom_tween_time: float = 0.6
## World-space height above the player's y that the zoom focuses on (and where
## the panel's bottom-center anchors); the camera never moves horizontally.
@export var zoom_focus_offset_y: float = -150.0
## Grayscale/vignette strength during the minigame (0-1).
@export var vignette_intensity: float = 0.8

@export_group("Modifiers")
## Weighted none/positive/negative pools rolled at every start_minigame; null
## disables modifiers entirely.
@export var modifier_weights: LeverModifierWeights = null

@export_group("Scene References")
@export var player_path: NodePath

class Zone:
	var type: ZoneType
	var start_ratio: float
	var end_ratio: float
	var pair_index: int = -1
	var control: Control
	var glow: ShaderMaterial
	## Alpha 0 means "use the ZoneType color"; SPECIAL zones set their own.
	var custom_color: Color = Color.TRANSPARENT
	## Optional overlay centered in the zone, revealed together with it.
	var icon: Texture2D = null

class Pair:
	var resolved := false
	var center_ratio: float
	## Right edge of the green+yellows cluster; passing it unresolved is a miss.
	var right_edge_ratio: float
	var light: TextureRect
	var light_glow: ShaderMaterial

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
## Set once the attempt is settled -- every pair lit, or a miss taken. The crosshair
## still finishes its sweep either way; this is what stops a press during the red
## run-out past the last zone undoing a result that is already decided.
var _outcome_locked := false
var _modifier: LeverModifierBehavior = null
var _world_anchor := Vector2.ZERO
var _effects_active := false
var _camera: Camera2D = null
var _original_zoom := Vector2.ONE
var _original_offset := Vector2.ZERO
var _timescale_active := false
var _timescale_elapsed: float = 0.0
var _zoom_tween: Tween = null
var _offset_tween: Tween = null
var _vignette_tween: Tween = null
var _info_tween: Tween = null
## Every tween the minigame itself starts, kept so _process can hold them at
## wall-clock speed against the activation slowdown.
var _realtime_tweens: Array[Tween] = []

@onready var _player: Node2D = get_node_or_null(player_path) as Node2D
@onready var _vignette: ColorRect = $VignetteLayer/Vignette
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
	if _timescale_active:
		_timescale_elapsed += real_delta
		var t := clampf(_timescale_elapsed / timescale_slowdown_time, 0.0, 1.0)
		var eased_t := 1.0 - pow(1.0 - t, 2.0)
		Engine.time_scale = lerpf(1.0, activation_timescale, eased_t)
	_drive_realtime_tweens()
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
	if get_tree().paused or _state != State.PLAYING or _outcome_locked:
		return
	if event.is_action_pressed("interact"):
		_evaluate_press()


## Difficulty scales by threat level (zero-based stage index 0-9), not rarity.
func start_minigame(threat_level: int) -> void:
	var clamped_threat := clampi(threat_level, 0, ThreatManager.LEVEL_COUNT - 1)
	_reset_state()
	if modifier_weights:
		_modifier = modifier_weights.roll_modifier(clamped_threat)
	if _modifier:
		_modifier.on_minigame_started(self, clamped_threat)
	_build_zones(clamped_threat)
	_update_reticle_position()
	_begin_activation_effects()
	_update_placement()
	visible = true
	set_process(true)
	_state = State.SETUP
	if _modifier:
		show_info(_modifier.display_name, _modifier.display_color)


func cancel_minigame() -> void:
	_end_activation_effects()
	visible = false
	set_process(false)
	_state = State.INACTIVE
	_reset_state()


func get_zones() -> Array[Zone]:
	return _zones


## Carve a slice out of an existing zone, replacing it in place with up to three
## zones (left remnant, the new zone, right remnant; zero-width remnants are
## dropped) so _zones stays sorted -- _build_zone_controls derives pixel widths
## from consecutive start ratios. Only valid from modify_zones, before the zone
## controls are built. Returns the new zone.
func split_zone(zone: Zone, start_ratio: float, end_ratio: float, new_type: ZoneType) -> Zone:
	var index := _zones.find(zone)
	var new_zone := Zone.new()
	new_zone.type = new_type
	new_zone.start_ratio = clampf(start_ratio, zone.start_ratio, zone.end_ratio)
	new_zone.end_ratio = clampf(end_ratio, zone.start_ratio, zone.end_ratio)
	var pieces: Array[Zone] = []
	if new_zone.start_ratio - zone.start_ratio > 0.0:
		var left := Zone.new()
		left.type = zone.type
		left.pair_index = zone.pair_index
		left.start_ratio = zone.start_ratio
		left.end_ratio = new_zone.start_ratio
		pieces.append(left)
	pieces.append(new_zone)
	if zone.end_ratio - new_zone.end_ratio > 0.0:
		var right := Zone.new()
		right.type = zone.type
		right.pair_index = zone.pair_index
		right.start_ratio = new_zone.end_ratio
		right.end_ratio = zone.end_ratio
		pieces.append(right)
	_zones.remove_at(index)
	for piece_index in range(pieces.size()):
		_zones.insert(index + piece_index, pieces[piece_index])
	return new_zone


## The world point the camera focuses on while the minigame runs -- just above
## the screen center at the zoomed framing. Valid from start until the next
## start; modifiers use it as the origin for post-close pickups.
func get_focus_world_position() -> Vector2:
	return _world_anchor


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
	_outcome_locked = false
	_modifier = null
	# Remove immediately, not just queue_free: zones are rebuilt and revealed in
	# this same frame, and stale children would corrupt the row's child order.
	for child in _zone_row.get_children():
		_zone_row.remove_child(child)
		child.queue_free()
	for child in _lights_row.get_children():
		_lights_row.remove_child(child)
		child.queue_free()
	for tween in _realtime_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_realtime_tweens.clear()
	_info_tween = null
	_info_label.scale = Vector2.ZERO
	_reticle.scale = Vector2.ONE


## Slow time, zoom the camera onto the focus point above the player, and fade in
## the grayscale vignette. Called while the camera is still at its resting state.
func _begin_activation_effects() -> void:
	_camera = get_viewport().get_camera_2d()
	_timescale_elapsed = 0.0
	_timescale_active = true
	_effects_active = true
	if _camera:
		_original_zoom = _camera.zoom
		_original_offset = _camera.offset
		var focus_y := _player.global_position.y + zoom_focus_offset_y if _player \
			else _camera.global_position.y + _original_offset.y
		_world_anchor = Vector2(_camera.global_position.x + _original_offset.x, focus_y)
		_kill_camera_tweens()
		_zoom_tween = create_tween()
		_zoom_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_zoom_tween.tween_property(_camera, "zoom", _original_zoom * activation_zoom, zoom_tween_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_offset_tween = create_tween()
		_offset_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		var target_offset := Vector2(_original_offset.x, _world_anchor.y - _camera.global_position.y)
		_offset_tween.tween_property(_camera, "offset", target_offset, zoom_tween_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _vignette and _vignette.material:
		_vignette.visible = true
		if _vignette_tween:
			_vignette_tween.kill()
		_vignette_tween = create_tween()
		_vignette_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_vignette_tween.set_parallel(true)
		_vignette_tween.tween_property(_vignette.material, "shader_parameter/vignette_intensity", vignette_intensity, zoom_tween_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_vignette_tween.tween_property(_vignette.material, "shader_parameter/grayscale_intensity", vignette_intensity, zoom_tween_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Restore timescale, camera, and vignette. Safe to call when nothing is active.
func _end_activation_effects() -> void:
	_timescale_active = false
	Engine.time_scale = 1.0
	if not _effects_active:
		return
	_effects_active = false
	var transition_time := zoom_tween_time * 0.5
	if _camera:
		_kill_camera_tweens()
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(_camera, "zoom", _original_zoom, transition_time) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_offset_tween = create_tween()
		_offset_tween.tween_property(_camera, "offset", _original_offset, transition_time) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	if _vignette and _vignette.material:
		if _vignette_tween:
			_vignette_tween.kill()
		_vignette_tween = create_tween()
		_vignette_tween.set_parallel(true)
		_vignette_tween.tween_property(_vignette.material, "shader_parameter/vignette_intensity", 0.0, transition_time) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_vignette_tween.tween_property(_vignette.material, "shader_parameter/grayscale_intensity", 0.0, transition_time) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_vignette_tween.tween_callback(_vignette.hide).set_delay(transition_time)


func _kill_camera_tweens() -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	if _offset_tween:
		_offset_tween.kill()


func _update_placement() -> void:
	if not _effects_active or _camera == null:
		var screen_size := get_viewport().get_visible_rect().size
		offset = Vector2(screen_size.x * 0.5, screen_size.y * 0.5)
		scale = Vector2.ONE
		return
	offset = get_viewport().get_canvas_transform() * _world_anchor
	scale = _camera.zoom / _original_zoom


## The bar starts empty; zones reveal green -> yellow -> red on a beat, then the
## countdown begins.
func _process_setup(real_delta: float) -> void:
	_setup_elapsed += real_delta
	if not _greens_revealed and _setup_elapsed >= setup_delay:
		_greens_revealed = true
		_reveal_zones(ZoneType.GREEN)
		_reveal_zones(ZoneType.SPECIAL)
	if not _yellows_revealed and _setup_elapsed >= setup_delay + zone_reveal_pause:
		_yellows_revealed = true
		_reveal_zones(ZoneType.YELLOW)
	if not _reds_revealed and _setup_elapsed >= setup_delay + zone_reveal_pause * 2.0:
		_reds_revealed = true
		_reveal_zones(ZoneType.RED)
	if _setup_elapsed >= setup_delay + zone_reveal_pause * 3.0:
		_state = State.COUNTDOWN
		_countdown_digit = COUNTDOWN_STEPS
		show_info(str(COUNTDOWN_STEPS), Color.WHITE)


func _process_countdown(real_delta: float) -> void:
	_countdown_elapsed += real_delta
	if _countdown_elapsed >= countdown_step_time * COUNTDOWN_STEPS:
		_state = State.PLAYING
		show_info("Go!", zone_color_green)
		return
	var digit := COUNTDOWN_STEPS - int(_countdown_elapsed / countdown_step_time)
	if digit != _countdown_digit:
		_countdown_digit = digit
		show_info(str(digit), Color.WHITE)


func _process_playing(real_delta: float) -> void:
	var speed := reticle_speed_ratio * (1.0 + yellow_speed_penalty_ratio * _yellows_hit)
	_reticle_ratio += speed * real_delta
	if _reticle_ratio >= 1.0:
		_reticle_ratio = 1.0
		_update_reticle_position()
		_win_minigame()
		return
	_update_reticle_position()
	for pair in _pairs:
		if not pair.resolved and _reticle_ratio > pair.right_edge_ratio:
			fail_minigame("MISS", zone_color_red)
			return


func _process_result(real_delta: float) -> void:
	_result_timer += real_delta
	var wait_time := result_display_time if _game_won else fail_pause_time
	if _result_timer >= wait_time:
		_end_activation_effects()
		visible = false
		set_process(false)
		_state = State.INACTIVE
		minigame_completed.emit(_game_won)
		# After the signal: MagnetMinigame's handler has already restored player
		# input, so outside-world consequences (scrap awards, spawns) land in a
		# fully live world.
		if _modifier:
			_modifier.on_minigame_closed(self, _game_won)
			_modifier = null


func _evaluate_press() -> void:
	var zone := _zone_at_ratio(_reticle_ratio)
	if zone == null:
		return
	if _modifier and _modifier.handle_press(self, zone):
		return
	# SPECIAL zones have no arm: an unconsumed press on one is a no-op.
	match zone.type:
		ZoneType.RED:
			fail_minigame("MISS", zone_color_red)
		ZoneType.GREEN:
			_resolve_pair(zone, true)
		ZoneType.YELLOW:
			_resolve_pair(zone, false)


func _resolve_pair(zone: Zone, perfect: bool) -> void:
	var pair := _pairs[zone.pair_index]
	if pair.resolved:
		return
	pair.resolved = true
	mark_zone_hit(zone)
	if perfect:
		_light_up(pair, LIGHT_GREEN_TEXTURE)
		show_info("PERFECT", zone_color_green)
	else:
		_light_up(pair, LIGHT_YELLOW_TEXTURE)
		_yellows_hit += 1
		show_info("CLOSE", zone_color_yellow)
	pair_resolved.emit(zone.pair_index, _pairs.size())
	if _all_pairs_resolved():
		_outcome_locked = true


## Reached only with every pair resolved: an unresolved one fails the attempt as it
## slips past, so arriving at the end of the bar is itself the win condition.
func _win_minigame() -> void:
	_game_won = true
	_result_timer = 0.0
	_state = State.RESULT


func _all_pairs_resolved() -> bool:
	for pair in _pairs:
		if not pair.resolved:
			return false
	return not _pairs.is_empty()


## Public so modifiers can fail the attempt with their own text ("Boom!"); the
## presentation is always the full red-fail treatment.
func fail_minigame(info_text: String, info_color: Color) -> void:
	_outcome_locked = true
	for pair in _pairs:
		_light_up(pair, LIGHT_RED_TEXTURE)
	_blink_red_zones()
	_shake_reticle()
	show_info(info_text, info_color)
	_game_won = false
	_result_timer = 0.0
	_state = State.RESULT


func _zone_at_ratio(ratio: float) -> Zone:
	for zone in _zones:
		if ratio >= zone.start_ratio and ratio < zone.end_ratio:
			return zone
	return null


func _build_zones(threat_level: int) -> void:
	var pair_count := scale_for_threat(threat_level, zones_min, zones_max)
	var width_scale := _lerp_for_threat(threat_level, 1.0, zone_width_scale_at_max_threat)
	var yellow_width := yellow_width_ratio * width_scale
	var centers := _generate_green_centers(pair_count)
	var half_green := green_width_ratio * width_scale * 0.5
	var cursor := 0.0
	for i in range(centers.size()):
		var center: float = centers[i]
		var cluster_start := center - half_green - yellow_width
		_append_zone(ZoneType.RED, cursor, cluster_start)
		_append_zone(ZoneType.YELLOW, cluster_start, center - half_green, i)
		_append_zone(ZoneType.GREEN, center - half_green, center + half_green, i)
		_append_zone(ZoneType.YELLOW, center + half_green, center + half_green + yellow_width, i)
		cursor = center + half_green + yellow_width
		var pair := Pair.new()
		pair.center_ratio = center
		pair.right_edge_ratio = cursor
		_pairs.append(pair)
	_append_zone(ZoneType.RED, cursor, 1.0)
	# Modifiers mutate the ratio layout (insert special zones, tag icons) before
	# any controls exist, so the visual build below stays the single source of
	# pixel truth.
	if _modifier:
		_modifier.modify_zones(self, threat_level)
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
		var zone := _zones[i]
		zone.glow = ZONE_GLOW.duplicate() as ShaderMaterial
		zone.glow.set_shader_parameter(&"glow_intensity", 0.0)
		zone.control = _make_zone_control(zone, maxi(width, 1))
		_zone_row.add_child(zone.control)


func _make_zone_control(zone: Zone, width: int) -> Control:
	var glow := zone.glow
	var zone_control := Control.new()
	zone_control.custom_minimum_size = Vector2(width, 0.0)
	zone_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Zone color tints both the stripes and the border; alpha 0 until this
	# zone's reveal step during the countdown.
	zone_control.modulate = Color(_zone_idle_color(zone), 0.0)
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
	stripes.material = glow
	zone_control.add_child(stripes)
	var border := NinePatchRect.new()
	border.texture = ZONE_BORDER_TEXTURE
	border.patch_margin_left = ZONE_BORDER_PATCH_MARGIN
	border.patch_margin_top = ZONE_BORDER_PATCH_MARGIN
	border.patch_margin_right = ZONE_BORDER_PATCH_MARGIN
	border.patch_margin_bottom = ZONE_BORDER_PATCH_MARGIN
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.material = glow
	zone_control.add_child(border)
	if zone.icon:
		# Child of the zone control so it inherits the reveal alpha and the hit
		# bounce; the parent modulate also tints it toward the zone color, which
		# is acceptable for the placeholder icons.
		var icon_rect := TextureRect.new()
		icon_rect.texture = zone.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = ZONE_CONTENT_INSET
		icon_rect.offset_top = ZONE_CONTENT_INSET
		icon_rect.offset_right = -ZONE_CONTENT_INSET
		icon_rect.offset_bottom = -ZONE_CONTENT_INSET
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone_control.add_child(icon_rect)
	return zone_control


func _build_lights() -> void:
	var bar_width := _zone_row.size.x
	for pair in _pairs:
		var light := TextureRect.new()
		light.texture = LIGHT_OFF_TEXTURE
		light.stretch_mode = TextureRect.STRETCH_KEEP
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.light_glow = LIGHT_GLOW.duplicate() as ShaderMaterial
		pair.light_glow.set_shader_parameter(&"glow_intensity", 0.0)
		light.material = pair.light_glow
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


## The shade a zone rests at, derived so idle and lit can never drift apart in hue.
func _zone_idle_color(zone: Zone) -> Color:
	var lit := _zone_color(zone)
	return Color(lit.r * zone_idle_darken, lit.g * zone_idle_darken, lit.b * zone_idle_darken)


func _zone_color(zone: Zone) -> Color:
	if zone.custom_color.a > 0.0:
		return zone.custom_color
	match zone.type:
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
## update it scales back to hidden. Each call restarts the whole chain. Public
## so modifiers can announce their own events ("Bonus Hit!"); one label, last
## caller wins.
func show_info(text: String, color: Color) -> void:
	if _info_tween and _info_tween.is_valid():
		_info_tween.kill()
	_info_label.text = text
	_info_label.add_theme_color_override("font_color", color)
	_info_label.pivot_offset = _info_label.size * 0.5
	_info_label.scale = Vector2.ZERO
	_info_tween = _create_realtime_tween()
	_info_tween.tween_property(_info_label, "scale", Vector2.ONE, info_pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_info_tween.tween_interval(info_hold_time)
	_info_tween.tween_property(_info_label, "scale", Vector2.ZERO, INFO_HIDE_TWEEN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Switch a result light on. The glow drives the lit texture's own colours past full
## brightness, so each state emits in its own hue without being told which it is.
func _light_up(pair: Pair, texture: Texture2D) -> void:
	pair.light.texture = texture
	pair.light_glow.set_shader_parameter(&"glow_intensity", 1.0)


## A hit green, yellow, or special zone punches up in scale and lights to full
## strength, and stays lit for the rest of the attempt -- the lit zones are the
## visible record of what the player hit to earn the result. Red is never lit
## this way -- hitting one is a fail, not a hit.
func mark_zone_hit(zone: Zone) -> void:
	var flare := _create_realtime_tween()
	flare.tween_method(_set_zone_lit.bind(zone), 0.0, 1.0, zone_hit_flash_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	zone.control.pivot_offset = zone.control.size * 0.5
	var bounce := _create_realtime_tween()
	bounce.tween_property(zone.control, "scale", zone_hit_scale, zone_hit_bounce_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce.tween_property(zone.control, "scale", Vector2.ONE, zone_hit_settle_time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Every red zone blinks in unison for the whole fail pause, like a warning light.
## One tween drives them all so they can never drift out of step.
func _blink_red_zones() -> void:
	var blinks := maxi(fail_flash_count, 1)
	var half_period := fail_pause_time / float(blinks * 2)
	var blink := _create_realtime_tween()
	for _index in range(blinks):
		blink.tween_method(_set_red_zones_lit, 0.0, 1.0, half_period)
		blink.tween_method(_set_red_zones_lit, 1.0, 0.0, half_period)


func _set_red_zones_lit(value: float) -> void:
	for zone in _zones:
		if zone.type == ZoneType.RED:
			_set_zone_lit(value, zone)


## 0 leaves the zone at its resting shade, 1 takes it to full strength with the glow
## at full. Colour and glow move together, so the glow adds to the tell rather than
## being the whole of it.
func _set_zone_lit(value: float, zone: Zone) -> void:
	var lit := _zone_idle_color(zone).lerp(_zone_color(zone), value)
	zone.control.modulate = Color(lit, zone.control.modulate.a)
	zone.glow.set_shader_parameter(&"glow_intensity", value)


## One sharp there-and-back kick in position plus a scale punch, so a red hit lands
## physically. The reticle is halted by then, so nothing fights these tweens.
func _shake_reticle() -> void:
	var rest := _reticle.position
	var kick := Vector2(reticle_shake_offset, 0.0)
	var step := reticle_shake_time / 3.0
	var shake := _create_realtime_tween()
	shake.tween_property(_reticle, "position", rest + kick, step) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shake.tween_property(_reticle, "position", rest - kick, step) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	shake.tween_property(_reticle, "position", rest, step) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_reticle.pivot_offset = _reticle.size * 0.5
	var punch := _create_realtime_tween()
	punch.tween_property(_reticle, "scale", Vector2.ONE * reticle_shake_scale, step) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(_reticle, "scale", Vector2.ONE, reticle_shake_time - step) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## Tweens tick on scaled time, and the minigame runs under a heavy Engine.time_scale
## slowdown; every tween it starts goes through here so _drive_realtime_tweens can
## hold it at wall-clock speed.
func _create_realtime_tween() -> Tween:
	var tween := create_tween()
	tween.set_speed_scale(_realtime_speed_scale())
	_realtime_tweens.append(tween)
	return tween


func _drive_realtime_tweens() -> void:
	var speed := _realtime_speed_scale()
	for index in range(_realtime_tweens.size() - 1, -1, -1):
		var tween: Tween = _realtime_tweens[index]
		if tween == null or not tween.is_valid():
			_realtime_tweens.remove_at(index)
			continue
		tween.set_speed_scale(speed)


func _realtime_speed_scale() -> float:
	return 1.0 / Engine.time_scale if Engine.time_scale > 0.0 else 1.0


func scale_for_threat(threat_level: int, min_value: int, max_value: int) -> int:
	return int(roundf(_lerp_for_threat(threat_level, float(min_value), float(max_value))))


## Linear blend from min_value (threat stage 0) to max_value (stage 9).
func _lerp_for_threat(threat_level: int, min_value: float, max_value: float) -> float:
	var span := maxi(ThreatManager.LEVEL_COUNT - 1, 1)
	var t := clampf(float(threat_level) / float(span), 0.0, 1.0)
	return lerpf(min_value, max_value, t)
