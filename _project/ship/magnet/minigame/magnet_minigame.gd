extends Node2D
class_name MagnetMinigame

enum State { COOLDOWN, WARNING, ACTIVATION, DECELERATING, LOOTING, DROPPING, ACCELERATING }

const LEVER_PULL_GENERIC_SFX := "lever_generic.ogg"
const LEVER_PULL_FINAL_SFX := "lever_pull1.ogg"
const LEVER_RELEASE_SFX := "lever_release.ogg"

@export_group("Cooldown")
## Minimum time between magnet windows in seconds.
@export var cooldown_min: float = 20.0
## Maximum time between magnet windows in seconds.
@export var cooldown_max: float = 30.0

@export_group("Warning Window")
## Minimum warning window duration in seconds.
@export var warning_duration_min: float = 8.0
## Maximum warning window duration in seconds.
@export var warning_duration_max: float = 10.0
## Fraction of warning window that shows yellow (0.0–1.0).
@export var yellow_phase_ratio: float = 0.4
## Fraction of warning window that shows orange blink (0.0–1.0).
@export var orange_phase_ratio: float = 0.3

@export_group("Ship Control")
## X position where the salvage pile spawns as a ratio of viewport width (e.g., 2.0 = 2 screens to the right).
@export var pile_spawn_x_ratio: float = 2.0
## Deceleration rate in pixels per second squared. Higher = faster stop.
@export var decel_rate: float = 400.0
## Time in seconds for the ship to accelerate back to normal speed.
@export var accel_time: float = 2.0

@export_group("Magnet Looting")
## Duration of the departure timer in seconds (how long the player can loot).
@export var departure_duration: float = 30.0
## Last X seconds before departure when new salvage stops spawning.
@export var spawn_cutoff_before_departure: float = 5.0
## Base speed items are pulled toward the magnet.
@export var magnet_pull_base_speed: float = 200.0
## Max speed items are pulled toward the magnet.
@export var magnet_pull_max_speed: float = 1500.0
## Time for pull speed to ramp from base to max.
@export var magnet_pull_ramp_time: float = 0.6
## Time between pulling new items from the pile.
@export var magnet_pull_frequency: float = 2.5

@export_group("Activation Minigame")
## Target timescale during activation minigame (0.01 = almost paused).
@export var activation_timescale: float = 0.01
## Time to slow down to activation timescale.
@export var timescale_slowdown_time: float = 0.5
## Time to speed up from activation timescale back to normal.
@export var timescale_speedup_time: float = 0.3
## X offset from lever position for player during activation (negative = left of lever).
@export var player_lever_offset_x: float = -80.0
## Camera zoom level during activation minigame (higher = more zoomed in).
@export var activation_zoom: float = 1.5
## Time to zoom in/out.
@export var zoom_tween_time: float = 0.5
@export var zoom_offset: Vector2
## Vignette/darkening intensity during activation (0-1).
@export var vignette_intensity: float = 0.6

@export_group("Advance Cutscene")
## Speed the player walks to the lever during the advance cutscene.
@export var advance_walk_speed: float = 180.0
## Turbo speed multiplier over the normal level speed.
@export var advance_turbo_speed_multiplier: float = 4.0
## Time to accelerate from normal speed up to turbo speed.
@export var advance_accel_time: float = 0.8
## Time to decelerate from turbo speed back to normal speed.
@export var advance_decel_time: float = 1.2
## Fade to/from black duration.
@export var advance_fade_time: float = 0.6
## Pause held at full black before fading back in.
@export var advance_black_hold_time: float = 0.35

@export_group("Scene References")
@export var salvage_spawner_path: NodePath
@export var ship_path: NodePath
@export var player_path: NodePath
@export var magnet_lever_path: NodePath
@export var magnet_path: NodePath
@export var camera_path: NodePath
@export var warning_icon_path: NodePath
@export var activation_minigame_path: NodePath
@export var magnet_capacity_path: NodePath
@export var activation_anchor_path: NodePath

var _state: State = State.COOLDOWN
var _spawns_frozen: bool = false
var _advancing: bool = false
var _advance_fade_rect: ColorRect = null
var _threat_manager: ThreatManager = null
var _base_level_speed: float = 0.0
var _warning_duration: float = 0.0
var _warning_elapsed: float = 0.0
var _decel_elapsed: float = 0.0
var _current_decel_time: float = 0.0
var _accel_elapsed: float = 0.0
var _drop_elapsed: float = 0.0
const DROP_DURATION: float = 1.0  # Time to wait for items to fall
var _current_pile: SalvagePile = null
var _timescale_transition_elapsed: float = 0.0
var _restoring_timescale: bool = false
var _activation_won: bool = false
var _player_original_position: Vector2 = Vector2.ZERO
var _camera: Camera2D = null
var _original_zoom: Vector2 = Vector2.ONE
var _original_camera_offset: Vector2 = Vector2.ZERO
var _zoom_tween: Tween = null
var _offset_tween: Tween = null
var _vignette_overlay: ColorRect = null
var _vignette_tween: Tween = null

var _level: Node2D = null
var _salvage_spawner: SalvageSpawner = null
var _warning_icon: WarningIcon = null
var _magnet_lever: MagnetLever = null
var _viewport_anchor: ViewportAnchor = null
var _activation_minigame: Node = null  # ActivationMinigame
var _player: Node2D = null  # Player
var _ship: Node2D = null
var _magnet: Magnet = null
var _magnet_capacity: MagnetCapacity = null
var _event_text: EventTextDisplay = null

@onready var _cooldown_timer: Timer = $CooldownTimer


func _ready() -> void:
	_level = get_parent()
	if _level and "level_speed" in _level:
		_base_level_speed = _level.level_speed
	if _level and "viewport_anchor" in _level:
		_viewport_anchor = _level.viewport_anchor

	_salvage_spawner = _resolve_node(salvage_spawner_path) as SalvageSpawner

	# Defer UI lookup to ensure GameUI nodes are ready
	call_deferred("_setup_ui_references")

	_ship = _resolve_node(ship_path) as Node2D
	_player = _resolve_node(player_path) as Node2D
	_magnet_lever = _resolve_node(magnet_lever_path) as MagnetLever
	if _magnet_lever:
		_magnet_lever.lever_flipped.connect(_on_lever_flipped)
		_magnet_lever.lever_flipped_back.connect(_on_lever_flipped_back)
		_magnet_lever.advance_confirmed.connect(_on_advance_confirmed)

	_magnet = _resolve_node(magnet_path) as Magnet
	if _magnet:
		_magnet.pull_base_speed = magnet_pull_base_speed
		_magnet.pull_max_speed = magnet_pull_max_speed
		_magnet.pull_ramp_time = magnet_pull_ramp_time
		_magnet.pull_frequency = magnet_pull_frequency
		_magnet.item_attached.connect(_on_magnet_item_attached)
		_magnet.item_removed.connect(_on_magnet_item_removed)

	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_finished)

	# Freeze the salvage spawn cycle while the threat cap is reached.
	if _level:
		_threat_manager = _level.get_node_or_null("ThreatManager") as ThreatManager
	if _threat_manager:
		_threat_manager.cap_reached.connect(_on_threat_cap_reached)
		_threat_manager.cap_raised.connect(_on_threat_cap_raised)

	# Get camera reference
	_camera = _resolve_node(camera_path) as Camera2D
	if _camera:
		_original_zoom = _camera.zoom
		_original_camera_offset = _camera.offset
	
	# Create vignette overlay
	_setup_vignette_overlay()


func _setup_ui_references() -> void:
	_warning_icon = _resolve_node(warning_icon_path) as WarningIcon
	_activation_minigame = _resolve_node(activation_minigame_path)
	_magnet_capacity = _resolve_node(magnet_capacity_path) as MagnetCapacity

	# Presentation for the warning/departure timers is now unified into the
	# top-center event text display; this icon widget keeps its phase logic but
	# is no longer shown.
	if _warning_icon:
		_warning_icon.visible = false

	if _activation_minigame:
		_activation_minigame.minigame_completed.connect(_on_activation_completed)
		_activation_minigame.marker_hit_success.connect(_on_marker_hit_success)
		var anchor := _resolve_node(activation_anchor_path) as Marker2D
		if anchor:
			_activation_minigame.set_anchor_marker(anchor)

	# Initialize ship status UI with the current magnet capacity value.
	_update_magnet_capacity_ui()
	
	# Start cooldown now that UI references are set up
	_start_cooldown()


func _resolve_node(path: NodePath) -> Node:
	if path.is_empty():
		return null
	return get_node_or_null(path)


## Resolve the shared event text display lazily (game UI may register after us).
func _get_event_text() -> EventTextDisplay:
	if _event_text == null or not is_instance_valid(_event_text):
		if Magnetide.game_ui:
			_event_text = Magnetide.game_ui.get_node_or_null("EventTextDisplay") as EventTextDisplay
	return _event_text


func _start_cooldown() -> void:
	_state = State.COOLDOWN
	if _warning_icon:
		_warning_icon.set_phase(WarningIcon.Phase.OFF)
	if _magnet_lever:
		_magnet_lever.set_available(false)
		# Lever stays visible at all times
	# No new salvage cycles while the threat cap is reached (storm decision state).
	if _spawns_frozen:
		_cooldown_timer.stop()
		return
	var interval := randf_range(cooldown_min, cooldown_max)
	_cooldown_timer.start(interval)


func _on_cooldown_finished() -> void:
	if _spawns_frozen:
		return
	_start_warning()


## Threat cap reached: stop producing new salvage piles. An active looting cycle
## is allowed to finish; pending cooldown/warning states go idle. The lever
## switches to "continue to next threat" mode (unless this is the final level).
func _on_threat_cap_reached() -> void:
	_spawns_frozen = true
	if _state == State.COOLDOWN or _state == State.WARNING:
		_cooldown_timer.stop()
		if _warning_icon:
			_warning_icon.set_phase(WarningIcon.Phase.OFF)
		var event_text := _get_event_text()
		if event_text:
			event_text.clear(&"salvage")
		if _magnet_lever:
			_magnet_lever.set_available(false)
		_state = State.COOLDOWN
	if _magnet_lever and _threat_manager and _threat_manager.can_raise_cap():
		_magnet_lever.set_advance_mode(true)


## Threat cap raised (player advanced): resume the salvage spawn cycle and revert
## the lever to normal looting use.
func _on_threat_cap_raised(_new_cap: int) -> void:
	_spawns_frozen = false
	if _magnet_lever:
		_magnet_lever.set_advance_mode(false)
	if _state == State.COOLDOWN:
		_start_cooldown()


func _on_advance_confirmed() -> void:
	if _advancing:
		return
	if _threat_manager == null or not _threat_manager.can_raise_cap():
		return
	_play_advance_cutscene()


## Transition cutscene: walk to lever, flip it, turbo-accelerate, fade to black,
## raise the threat cap, fade back, and decelerate to normal speed.
func _play_advance_cutscene() -> void:
	_advancing = true
	_set_player_input_enabled(false)
	if _magnet_lever:
		_magnet_lever.set_advance_mode(false)

	var normal_speed := _base_level_speed
	var turbo_speed := _base_level_speed * advance_turbo_speed_multiplier

	# 1. Player walks to the lever spot.
	await _walk_player_to_lever()

	# 2. Lever flips.
	if _magnet_lever:
		_play_lever_sfx(LEVER_PULL_FINAL_SFX)
		_magnet_lever.progress_rotation(1.0)
		await _wait(_magnet_lever.rotation_tween_duration + 0.1)

	# 3. Accelerate to turbo speed with the turbo thruster plume.
	if _ship and _ship.has_method("set_turbo_thrusters"):
		_ship.set_turbo_thrusters(true)
	await _tween_level_speed_to(turbo_speed, advance_accel_time)

	# 4. Fade to black, raise the cap, fade back in.
	await _advance_fade(1.0, advance_fade_time)
	await _wait(advance_black_hold_time)
	if _threat_manager:
		_threat_manager.raise_cap()
	await _advance_fade(0.0, advance_fade_time)

	# 5. Decelerate back to normal speed and restore thrusters.
	await _tween_level_speed_to(normal_speed, advance_decel_time)
	if _ship and _ship.has_method("set_turbo_thrusters"):
		_ship.set_turbo_thrusters(false)

	# 6. Resume normal gameplay.
	if _magnet_lever:
		_magnet_lever.reset_rotation()
	_set_player_input_enabled(true)
	_advancing = false


func _walk_player_to_lever() -> void:
	if _player == null or _magnet_lever == null:
		return
	if not _player.has_method("start_walk_to_ship_center_for_cutscene"):
		_position_player_at_lever()
		return

	var target_global_x := _magnet_lever.global_position.x + player_lever_offset_x
	var target_local_x := target_global_x
	var parent := _player.get_parent()
	if parent is Node2D:
		target_local_x = (parent as Node2D).to_local(Vector2(target_global_x, _player.global_position.y)).x

	_player.start_walk_to_ship_center_for_cutscene(target_local_x, advance_walk_speed)
	if _player.is_cinematic_walk_active():
		await _player.cinematic_walk_finished


func _tween_level_speed_to(target_speed: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_method(Callable(self, "_set_level_speed"), _get_level_speed(), target_speed, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _get_level_speed() -> float:
	if _level and "level_speed" in _level:
		return _level.level_speed
	return _base_level_speed


func _advance_fade(target_alpha: float, duration: float) -> void:
	_ensure_advance_fade_overlay()
	if _advance_fade_rect == null:
		return
	var tween := create_tween()
	tween.tween_property(_advance_fade_rect, "color:a", target_alpha, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _ensure_advance_fade_overlay() -> void:
	if _advance_fade_rect != null and is_instance_valid(_advance_fade_rect):
		return
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "AdvanceFadeLayer"
	canvas_layer.layer = 80
	add_child(canvas_layer)
	_advance_fade_rect = ColorRect.new()
	_advance_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_advance_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_advance_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(_advance_fade_rect)


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout


func _start_warning() -> void:
	_state = State.WARNING
	_warning_duration = randf_range(warning_duration_min, warning_duration_max)
	_warning_elapsed = 0.0
	if _warning_icon:
		_warning_icon.set_phase(WarningIcon.Phase.YELLOW)
	var event_text := _get_event_text()
	if event_text:
		event_text.show_message(&"salvage", "SALVAGE DETECTED", 30, EventTextDisplay.Style.WARNING)
	if _magnet_lever:
		_magnet_lever.set_available(true)


func _on_lever_flipped() -> void:
	if _state != State.WARNING:
		return
	if _warning_icon:
		_warning_icon.set_phase(WarningIcon.Phase.OFF)
	var event_text := _get_event_text()
	if event_text:
		event_text.clear(&"salvage")
	if _magnet_lever:
		_magnet_lever.set_available(false)
	_start_activation_minigame()


func _on_warning_expired() -> void:
	if _warning_icon:
		_warning_icon.set_phase(WarningIcon.Phase.OFF)
	var event_text := _get_event_text()
	if event_text:
		event_text.clear(&"salvage")
	if _magnet_lever:
		_magnet_lever.set_available(false)
		# Lever stays visible at all times

	if _salvage_spawner:
		_salvage_spawner.spawn_on_demand()

	_start_cooldown()


func _start_activation_minigame() -> void:
	_state = State.ACTIVATION
	# Looting cycle has begun — hold the storm-imminent trigger until the ship departs.
	if _threat_manager:
		_threat_manager.set_cap_hold(true)
	_timescale_transition_elapsed = 0.0
	_restoring_timescale = false
	
	# Set process mode to always so we can control timescale
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Disable player input during minigame
	_set_player_input_enabled(false)
	
	# Position player at lever spot
	_position_player_at_lever()
	
	# Reset lever to start position
	if _magnet_lever:
		_magnet_lever.reset_rotation()
	
	# Start the activation minigame UI (difficulty scales by current threat level)
	if _activation_minigame:
		_activation_minigame.start_minigame(_get_threat_level())
	
	# Start camera zoom and vignette effects
	_start_activation_effects()


func _on_activation_completed(success: bool) -> void:
	_activation_won = success
	_restoring_timescale = true
	_timescale_transition_elapsed = 0.0
	
	# Restore timescale and process mode
	Engine.time_scale = 1.0
	process_mode = Node.PROCESS_MODE_INHERIT
	
	# Re-enable player input
	_set_player_input_enabled(true)
	
	# End camera zoom and vignette effects
	_end_activation_effects()
	
	# Always spawn pile after minigame ends
	var spawn_x := _get_screen_width() * pile_spawn_x_ratio
	if _salvage_spawner:
		_current_pile = _salvage_spawner.spawn_on_demand(spawn_x)
	
	if success:
		# Player won - set lever to flipped state for looting abort
		if _magnet_lever:
			_magnet_lever.set_flipped(true)
		_start_deceleration()
	else:
		# Player lost - pile scrolls past, reset lever and go to cooldown
		if _magnet_lever:
			_magnet_lever.reset_rotation()
		_start_cooldown()


func _start_deceleration() -> void:
	_state = State.DECELERATING
	_decel_elapsed = 0.0
	
	# Calculate decel_time based on distance to pile
	var ship_x := _get_ship_x()
	var pile_x := _current_pile.global_position.x if _current_pile else _get_screen_width() * pile_spawn_x_ratio
	var distance := pile_x - ship_x
	if _base_level_speed > 0.0 and distance > 0.0:
		_current_decel_time = 2.0 * distance / _base_level_speed
	else:
		_current_decel_time = 1.0


## True while the ship is stopped/stopping for a looting cycle (the magnet minigame is engaged).
## Used to defer the threat storm-imminent trigger until looting finishes and the ship departs.
func is_looting_cycle_active() -> bool:
	return _state == State.ACTIVATION \
		or _state == State.DECELERATING \
		or _state == State.LOOTING \
		or _state == State.DROPPING


func _process(delta: float) -> void:
	# Defer the threat storm-imminent trigger while a looting cycle is in progress.
	if _threat_manager:
		_threat_manager.set_cap_hold(is_looting_cycle_active())

	match _state:
		State.WARNING:
			_process_warning(delta)
		State.ACTIVATION:
			_process_activation(delta)
		State.DECELERATING:
			_process_deceleration(delta)
		State.LOOTING:
			_process_looting()
		State.DROPPING:
			_process_dropping(delta)
		State.ACCELERATING:
			_process_acceleration(delta)


func _process_activation(delta: float) -> void:
	# Slow down timescale on a curve
	if not _restoring_timescale:
		_timescale_transition_elapsed += delta
		var t := clampf(_timescale_transition_elapsed / timescale_slowdown_time, 0.0, 1.0)
		# Use ease out curve for smooth slowdown
		var eased_t := 1.0 - pow(1.0 - t, 2.0)
		Engine.time_scale = lerpf(1.0, activation_timescale, eased_t)


func _process_warning(delta: float) -> void:
	_warning_elapsed += delta

	if _warning_elapsed >= _warning_duration:
		_on_warning_expired()
		return

	var ratio := _warning_elapsed / _warning_duration
	var yellow_end := yellow_phase_ratio
	var orange_end := yellow_phase_ratio + orange_phase_ratio

	if _warning_icon:
		if ratio < yellow_end:
			_warning_icon.set_phase(WarningIcon.Phase.YELLOW)
		elif ratio < orange_end:
			_warning_icon.set_phase(WarningIcon.Phase.ORANGE)
		else:
			_warning_icon.set_phase(WarningIcon.Phase.RED)


func _process_deceleration(delta: float) -> void:
	_decel_elapsed += delta
	var t := clampf(_decel_elapsed / _current_decel_time, 0.0, 1.0)
	var new_speed := lerpf(_base_level_speed, 0.0, t)
	_set_level_speed(new_speed)

	if t >= 1.0:
		_set_level_speed(0.0)
		_align_pile_to_ship()
		_start_looting()


## Current threat level (zero-based stage index) from the ThreatManager, 0 if unavailable.
func _get_threat_level() -> int:
	var lvl := Magnetide.level
	if lvl and "threat" in lvl and lvl.threat:
		return lvl.threat.threat_level
	return 0


func _start_looting() -> void:
	_state = State.LOOTING

	# Activate magnet and start pulling items
	if _magnet and _current_pile and _current_pile.pile_data:
		_magnet.activate(_current_pile.pile_data, _current_pile, _get_threat_level())
		_magnet.set_spawn_paused_for_departure(false)

	# Threat is driven only by passive time now; magnet use no longer adds threat.

	# Start departure timer, driven by the event text countdown.
	var event_text := _get_event_text()
	if event_text:
		if not event_text.countdown_finished.is_connected(_on_event_countdown_finished):
			event_text.countdown_finished.connect(_on_event_countdown_finished)
		event_text.start_countdown(
			&"departure", "DEPARTING IN", _get_current_departure_duration(), 50, EventTextDisplay.Style.NORMAL
		)

	# Make lever available so player can flip it back to abort
	if _magnet_lever:
		_magnet_lever.set_available(true)


## Seconds left on the departure countdown, read from the event text display.
func _departure_time_remaining() -> float:
	var event_text := _get_event_text()
	if event_text:
		return event_text.get_remaining(&"departure")
	return 0.0


func _process_looting() -> void:
	if not _magnet:
		return

	var time_remaining := _departure_time_remaining()
	var spawn_cutoff := maxf(spawn_cutoff_before_departure, 0.0)
	var should_pause_spawning := time_remaining <= spawn_cutoff
	_magnet.set_spawn_paused_for_departure(should_pause_spawning)


func _end_looting() -> void:
	if _state != State.LOOTING:
		return

	# Notify player to release any held items
	if _player and _player.has_method("on_looting_ended"):
		_player.on_looting_ended()

	# Stop departure timer
	var event_text := _get_event_text()
	if event_text:
		event_text.clear(&"departure")

	# Deactivate magnet - items will fall
	if _magnet:
		_magnet.deactivate()
	
	# Reset magnet capacity UI to 0
	_update_magnet_capacity_ui()

	# Flip lever back to starting position
	if _magnet_lever:
		_play_lever_sfx(LEVER_RELEASE_SFX)
		_magnet_lever.set_available(false)
		_magnet_lever.flip_back_with_tween()

	# Wait for items to drop before accelerating
	_state = State.DROPPING
	_drop_elapsed = 0.0


func _on_lever_flipped_back() -> void:
	if _state != State.LOOTING:
		return
	# Player manually aborted looting
	_end_looting()


func _on_event_countdown_finished(source: StringName) -> void:
	# Departure countdown ran out - auto-end looting.
	if source == &"departure" and _state == State.LOOTING:
		_end_looting()


func _process_dropping(delta: float) -> void:
	_drop_elapsed += delta
	if _drop_elapsed >= DROP_DURATION:
		# Items have had time to fall, now accelerate
		_state = State.ACCELERATING
		_accel_elapsed = 0.0


func _process_acceleration(delta: float) -> void:
	_accel_elapsed += delta
	var t := clampf(_accel_elapsed / accel_time, 0.0, 1.0)
	var new_speed := lerpf(0.0, _base_level_speed, t)
	_set_level_speed(new_speed)

	if t >= 1.0:
		_set_level_speed(_base_level_speed)
		_start_cooldown()


func _set_level_speed(speed: float) -> void:
	if _level and "level_speed" in _level:
		_level.level_speed = speed


func _align_pile_to_ship() -> void:
	if not _current_pile or not _current_pile.is_active:
		return
	if _ship:
		_current_pile.global_position.x = _ship.global_position.x


func _get_ship_x() -> float:
	if _ship:
		return _ship.global_position.x
	if _viewport_anchor:
		return _viewport_anchor.get_center_x()
	return 960.0


func _get_screen_width() -> float:
	if _viewport_anchor:
		return _viewport_anchor.size.x
	return get_viewport().get_visible_rect().size.x


func _get_current_departure_duration() -> float:
	if _current_pile and _current_pile.pile_data:
		return _current_pile.pile_data.get_departure_duration(departure_duration)
	return departure_duration


func _position_player_at_lever() -> void:
	if not _player or not _magnet_lever:
		return
	# Store original position to restore later if needed
	_player_original_position = _player.global_position
	# Position player to the left of the lever
	var lever_pos := _magnet_lever.global_position
	_player.global_position = Vector2(lever_pos.x + player_lever_offset_x, _player.global_position.y)


func _on_marker_hit_success(_marker_index: int, total_markers: int) -> void:
	# Progress lever rotation by 1/total_markers of the full rotation
	if _magnet_lever and total_markers > 0:
		var is_final_pull := _marker_index >= total_markers - 1
		_play_lever_sfx(LEVER_PULL_FINAL_SFX if is_final_pull else LEVER_PULL_GENERIC_SFX)
		var rotation_per_marker := 1.0 / float(total_markers)
		_magnet_lever.progress_rotation(rotation_per_marker)


func _play_lever_sfx(sound_name: String) -> void:
	if Magnetide.sfx and not sound_name.is_empty():
		Magnetide.sfx.play(sound_name)


func _set_player_input_enabled(enabled: bool) -> void:
	if _player and "input_enabled" in _player:
		_player.input_enabled = enabled


func _setup_vignette_overlay() -> void:
	# Create a BackBufferCopy to capture the screen for the shader
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	# Create the vignette overlay with shader (reads from screen texture)
	_vignette_overlay = ColorRect.new()
	_vignette_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_overlay.color = Color.TRANSPARENT
	_vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Load and apply the vignette + grayscale shader
	var shader := preload("res://_project/ship/magnet/minigame/vignette_grayscale.gdshader")
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("vignette_intensity", 0.0)
	shader_material.set_shader_parameter("grayscale_intensity", 0.0)
	shader_material.set_shader_parameter("vignette_radius", 0.4)
	shader_material.set_shader_parameter("vignette_softness", 0.4)
	_vignette_overlay.material = shader_material
	_vignette_overlay.visible = false  # Start hidden
	
	canvas_layer.add_child(_vignette_overlay)


func _start_activation_effects() -> void:
	# Calculate target offset to center camera on UI position
	# With DRAG_CENTER anchor mode, offset moves the camera center
	var target_offset: Vector2 = _original_camera_offset
	if _viewport_anchor:
		# The UI is at screen center-top (0.5, 0.35)
		# We need to offset the camera so that point becomes the center
		var screen_size := _viewport_anchor.size
		var ui_pos := Vector2(screen_size.x * 0.5, screen_size.y * 0.35)
		var screen_center := screen_size * 0.5
		# Offset = how much to move camera center from screen center to UI position
		target_offset = ui_pos - screen_center
	
	# Zoom and translate camera using offset
	if _camera:
		if _zoom_tween:
			_zoom_tween.kill()
		if _offset_tween:
			_offset_tween.kill()
		
		_zoom_tween = create_tween()
		_zoom_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		var target_zoom := _original_zoom * activation_zoom
		_zoom_tween.tween_property(_camera, "zoom", target_zoom, zoom_tween_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		
		_offset_tween = create_tween()
		_offset_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_offset_tween.tween_property(_camera, "offset", target_offset + zoom_offset, zoom_tween_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# Fade in vignette + grayscale shader effect
	if _vignette_overlay and _vignette_overlay.material:
		_vignette_overlay.visible = true
		if _vignette_tween:
			_vignette_tween.kill()
		_vignette_tween = create_tween()
		_vignette_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_vignette_tween.set_parallel(true)
		_vignette_tween.tween_property(_vignette_overlay.material, "shader_parameter/vignette_intensity", vignette_intensity, zoom_tween_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_vignette_tween.tween_property(_vignette_overlay.material, "shader_parameter/grayscale_intensity", vignette_intensity, zoom_tween_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _on_magnet_item_attached(_item: SalvageItem) -> void:
	_update_magnet_capacity_ui()


func _on_magnet_item_removed(_item: SalvageItem) -> void:
	_update_magnet_capacity_ui()


func _update_magnet_capacity_ui() -> void:
	if _magnet_capacity and _magnet:
		_magnet_capacity.set_magnet_capacity(_magnet.held_count, _magnet.hold_capacity)


func _end_activation_effects() -> void:
	var transition_time := zoom_tween_time * 0.5  # Faster transition out
	
	# Zoom and translate camera back using offset
	if _camera:
		if _zoom_tween:
			_zoom_tween.kill()
		if _offset_tween:
			_offset_tween.kill()
		
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(_camera, "zoom", _original_zoom, transition_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		
		_offset_tween = create_tween()
		_offset_tween.tween_property(_camera, "offset", _original_camera_offset, transition_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	# Fade out vignette + grayscale shader effect
	if _vignette_overlay and _vignette_overlay.material:
		if _vignette_tween:
			_vignette_tween.kill()
		_vignette_tween = create_tween()
		_vignette_tween.set_parallel(true)
		_vignette_tween.tween_property(_vignette_overlay.material, "shader_parameter/vignette_intensity", 0.0, transition_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_vignette_tween.tween_property(_vignette_overlay.material, "shader_parameter/grayscale_intensity", 0.0, transition_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_vignette_tween.tween_callback(_vignette_overlay.hide).set_delay(transition_time)


func stop_for_run_end() -> void:
	_advancing = false
	if _cooldown_timer:
		_cooldown_timer.stop()
	if _warning_icon:
		_warning_icon.set_phase(WarningIcon.Phase.OFF)
	var event_text := _get_event_text()
	if event_text:
		event_text.clear(&"salvage")
		event_text.clear(&"departure")
	if _magnet_lever:
		_magnet_lever.set_advance_mode(false)
		_magnet_lever.set_available(false)
	if _player and _player.has_method("on_looting_ended"):
		_player.on_looting_ended()
	if _magnet:
		_magnet.deactivate()
	if _activation_minigame and _activation_minigame.has_method("cancel_minigame"):
		_activation_minigame.cancel_minigame()
	Engine.time_scale = 1.0
	process_mode = Node.PROCESS_MODE_INHERIT
	_end_activation_effects()
	_set_level_speed(0.0)
	_state = State.COOLDOWN
	if _threat_manager:
		_threat_manager.set_cap_hold(false)
	set_process(false)
