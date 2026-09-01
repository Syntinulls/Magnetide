extends Node2D
class_name MagnetMinigame

enum State { COOLDOWN, WARNING, ACTIVATION, DECELERATING, LOOTING, DROPPING, ACCELERATING }

const LEVER_PULL_GENERIC_SFX := "level/lever_generic.ogg"
const LEVER_PULL_FINAL_SFX := "level/lever_pull1.ogg"
const LEVER_RELEASE_SFX := "level/lever_release.ogg"
const DEPARTURE_TEXT := "DEPARTING"
const DEPARTURE_PRIORITY := 50

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
## X offset from lever position for player during activation (negative = left of lever).
@export var player_lever_offset_x: float = -80.0

@export_group("Scene References")
@export var salvage_spawner_path: NodePath
@export var ship_path: NodePath
@export var player_path: NodePath
@export var magnet_lever_path: NodePath
@export var magnet_path: NodePath
@export var lever_minigame_path: NodePath
@export var magnet_capacity_path: NodePath
@export var warning_icon_path: NodePath

var _state: State = State.COOLDOWN
var _spawns_frozen: bool = false
## Seconds left in the looting window. Owned here, not read back off the HUD.
var _departure_remaining: float = 0.0
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
var _player_original_position: Vector2 = Vector2.ZERO

var _level: Node2D = null
var _salvage_spawner: SalvageSpawner = null
var _magnet_lever: MagnetLever = null
var _viewport_anchor: ViewportAnchor = null
var _lever_minigame: LeverMinigame = null
var _player: Node2D = null  # Player
var _ship: Node2D = null
var _magnet: Magnet = null
var _magnet_capacity: MagnetCapacity = null
var _warning_icon: WarningIcon = null
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

	# Freeze the salvage spawn cycle while the window is open and while a storm runs.
	if _level:
		_threat_manager = _level.get_node_or_null("ThreatManager") as ThreatManager
	if _threat_manager:
		_threat_manager.window_opened.connect(_on_threat_window_opened)
		_threat_manager.level_advanced.connect(_on_threat_level_unlocked)


func _setup_ui_references() -> void:
	_warning_icon = _resolve_node(warning_icon_path) as WarningIcon
	_lever_minigame = _resolve_node(lever_minigame_path) as LeverMinigame
	_magnet_capacity = _resolve_node(magnet_capacity_path) as MagnetCapacity

	if _lever_minigame:
		_lever_minigame.minigame_completed.connect(_on_activation_completed)
		_lever_minigame.objective_resolved.connect(_on_objective_resolved)

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
	# No new salvage cycles while the interlevel window is open or a storm runs.
	if _spawns_frozen:
		_cooldown_timer.stop()
		return
	var interval := randf_range(cooldown_min, cooldown_max)
	_cooldown_timer.start(interval)


func _on_cooldown_finished() -> void:
	if _spawns_frozen:
		return
	_start_warning()


## True while a salvage cycle could be started right now: the ship is idling between
## cycles and spawning isn't frozen by the interlevel window or a storm.
func can_force_salvage_cycle() -> bool:
	return _state == State.COOLDOWN and not _spawns_frozen


## Debug entry point: skip the remaining cooldown and open the warning window now.
func force_salvage_cycle() -> void:
	if not can_force_salvage_cycle():
		return
	_cooldown_timer.stop()
	_start_warning()


## Interlevel window opened: stop producing new salvage piles. An active looting
## cycle is allowed to finish; pending cooldown/warning states go idle.
func _on_threat_window_opened(_seconds: float, _is_storm_gate: bool) -> void:
	_spawns_frozen = true
	if _state != State.COOLDOWN and _state != State.WARNING:
		return
	_cooldown_timer.stop()
	if _warning_icon:
		_warning_icon.set_phase(WarningIcon.Phase.OFF)
	var event_text := _get_event_text()
	if event_text:
		event_text.clear(&"salvage")
	if _magnet_lever:
		_magnet_lever.set_available(false)
	_state = State.COOLDOWN


## Next threat level unlocked: resume the salvage spawn cycle. Keyed to the cap
## rising rather than the window closing, because at a storm gate the window closes
## into the storm and spawning must stay frozen until that clears.
func _on_threat_level_unlocked(_new_cap: int) -> void:
	_spawns_frozen = false
	if _state == State.COOLDOWN:
		_start_cooldown()


func _start_warning() -> void:
	_state = State.WARNING
	_warning_duration = randf_range(warning_duration_min, warning_duration_max)
	_warning_elapsed = 0.0
	if _warning_icon:
		_warning_icon.set_phase(WarningIcon.Phase.YELLOW)
	var event_text := _get_event_text()
	if event_text:
		event_text.show_message(
			&"salvage", "SALVAGE DETECTED", "", 30, EventTextDisplay.Style.WARNING
		)
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
	_start_lever_minigame()


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


func _start_lever_minigame() -> void:
	_state = State.ACTIVATION
	# Looting cycle has begun — hold the storm-imminent trigger until the ship departs.
	if _threat_manager:
		_threat_manager.set_window_hold(true)

	# Keep running while the minigame slows the timescale.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Disable player input during minigame
	_set_player_input_enabled(false)

	# Position player at lever spot
	_position_player_at_lever()

	# Reset lever to start position
	if _magnet_lever:
		_magnet_lever.reset_rotation()

	# The minigame owns its own presentation (timescale, camera zoom, vignette);
	# difficulty scales by current threat level.
	if _lever_minigame:
		_lever_minigame.start_minigame(_get_threat_level())


func _on_activation_completed(success: bool) -> void:
	# The minigame restored timescale/camera/vignette before emitting.
	process_mode = Node.PROCESS_MODE_INHERIT

	# Re-enable player input
	_set_player_input_enabled(true)

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
	# This node runs PROCESS_MODE_ALWAYS during activation (to ignore the
	# timescale slowdown), so it must respect the pause menu explicitly.
	if get_tree().paused:
		return
	# Defer the threat storm-imminent trigger while a looting cycle is in progress.
	if _threat_manager:
		_threat_manager.set_window_hold(is_looting_cycle_active())

	match _state:
		State.WARNING:
			_process_warning(delta)
		State.DECELERATING:
			_process_deceleration(delta)
		State.LOOTING:
			_process_looting(delta)
		State.DROPPING:
			_process_dropping(delta)
		State.ACCELERATING:
			_process_acceleration(delta)


func _process_warning(delta: float) -> void:
	_warning_elapsed += delta

	if _warning_elapsed >= _warning_duration:
		_on_warning_expired()
		return

	# Escalate the warning icon through yellow -> orange -> red as the window runs out.
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

	_departure_remaining = _get_current_departure_duration()
	var event_text := _get_event_text()
	if event_text:
		event_text.show_message(
			&"departure",
			DEPARTURE_TEXT,
			_departure_subtext(),
			DEPARTURE_PRIORITY,
			EventTextDisplay.Style.NORMAL
		)

	# Make lever available so player can flip it back to abort
	if _magnet_lever:
		_magnet_lever.set_available(true)


func _departure_subtext() -> String:
	return "%ds" % int(ceil(maxf(_departure_remaining, 0.0)))


func _process_looting(delta: float) -> void:
	_departure_remaining = maxf(_departure_remaining - delta, 0.0)
	var event_text := _get_event_text()
	if event_text:
		event_text.set_subtext(&"departure", _departure_subtext())

	if not _magnet:
		return

	var spawn_cutoff := maxf(spawn_cutoff_before_departure, 0.0)
	_magnet.set_spawn_paused_for_departure(_departure_remaining <= spawn_cutoff)

	if _departure_remaining <= 0.0:
		_end_looting()


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


func _on_objective_resolved(objective_index: int, total_objectives: int) -> void:
	# Progress lever rotation by 1/total_objectives of the full rotation
	if _magnet_lever and total_objectives > 0:
		var is_final_pull := objective_index >= total_objectives - 1
		_play_lever_sfx(LEVER_PULL_FINAL_SFX if is_final_pull else LEVER_PULL_GENERIC_SFX)
		var rotation_per_objective := 1.0 / float(total_objectives)
		_magnet_lever.progress_rotation(rotation_per_objective)


func _play_lever_sfx(sound_name: String) -> void:
	if Magnetide.sfx and not sound_name.is_empty():
		Magnetide.sfx.play(sound_name)


func _set_player_input_enabled(enabled: bool) -> void:
	if _player and "input_enabled" in _player:
		_player.input_enabled = enabled


func _on_magnet_item_attached(_item: SalvageItem) -> void:
	_update_magnet_capacity_ui()


func _on_magnet_item_removed(_item: SalvageItem) -> void:
	_update_magnet_capacity_ui()


func _update_magnet_capacity_ui() -> void:
	if _magnet_capacity and _magnet:
		_magnet_capacity.set_magnet_capacity(_magnet.held_count, _magnet.hold_capacity)


func stop_for_run_end() -> void:
	_state = State.COOLDOWN
	set_process(false)
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
	# cancel_minigame restores timescale, camera zoom, and the vignette.
	if _lever_minigame:
		_lever_minigame.cancel_minigame()
	process_mode = Node.PROCESS_MODE_INHERIT
	_set_level_speed(0.0)
	_state = State.COOLDOWN
	if _threat_manager:
		_threat_manager.set_window_hold(false)
	set_process(false)
