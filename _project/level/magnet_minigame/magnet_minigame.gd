extends Node2D
class_name MagnetMinigame

enum State { COOLDOWN, WARNING, ACTIVATION, DECELERATING, PARKED, ACCELERATING }

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
## Time in seconds the ship stays parked above the salvage pile.
@export var park_duration: float = 5.0
## Time in seconds for the ship to accelerate back to normal speed.
@export var accel_time: float = 2.0

@export_group("Activation Minigame")
## Target timescale during activation minigame (0.01 = almost paused).
@export var activation_timescale: float = 0.01
## Time to slow down to activation timescale.
@export var timescale_slowdown_time: float = 0.5
## Time to speed up from activation timescale back to normal.
@export var timescale_speedup_time: float = 0.3
## X offset from lever position for player during activation (negative = left of lever).
@export var player_lever_offset_x: float = -80.0
## Y position of activation minigame UI as ratio of screen height (0 = top, 1 = bottom).
@export var activation_ui_y_ratio: float = 0.25
## Camera zoom level during activation minigame (higher = more zoomed in).
@export var activation_zoom: float = 1.5
## Time to zoom in/out.
@export var zoom_tween_time: float = 0.5
## Vignette/darkening intensity during activation (0-1).
@export var vignette_intensity: float = 0.6

@export_group("Warning Icon Placement")
## X position of the warning icon as a ratio of viewport width.
@export var icon_x_ratio: float = 0.95
## Y position of the warning icon as a ratio of viewport height.
@export var icon_y_ratio: float = 0.5

var _state: State = State.COOLDOWN
var _base_level_speed: float = 0.0
var _warning_duration: float = 0.0
var _warning_elapsed: float = 0.0
var _decel_elapsed: float = 0.0
var _current_decel_time: float = 0.0
var _accel_elapsed: float = 0.0
var _park_elapsed: float = 0.0
var _current_pile: SalvagePile = null
var _timescale_transition_elapsed: float = 0.0
var _restoring_timescale: bool = false
var _activation_won: bool = false
var _pending_rarity: SalvagePile.Rarity = SalvagePile.Rarity.COMMON
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
var _ui_root: Control = null

@onready var _cooldown_timer: Timer = $CooldownTimer


func _ready() -> void:
	_level = get_parent()
	if _level and "level_speed" in _level:
		_base_level_speed = _level.level_speed
	if _level and "viewport_anchor" in _level:
		_viewport_anchor = _level.viewport_anchor
	if _level and "ui_root" in _level:
		_ui_root = _level.ui_root

	_salvage_spawner = _level.get_node_or_null("SalvageSpawner") as SalvageSpawner

	_warning_icon = $WarningIcon as WarningIcon
	_activation_minigame = get_node_or_null("ActivationMinigame")
	if _activation_minigame:
		_activation_minigame.minigame_completed.connect(_on_activation_completed)
		_activation_minigame.marker_hit_success.connect(_on_marker_hit_success)
	
	# Reparent UI elements to the UI canvas for proper screen-relative positioning
	_reparent_ui_elements()

	var ship := _level.get_node_or_null("Ship")
	if ship:
		_player = ship.get_node_or_null("Player")
		_magnet_lever = ship.get_node_or_null("MagnetLever") as MagnetLever
		if _magnet_lever:
			_magnet_lever.lever_flipped.connect(_on_lever_flipped)

	if _viewport_anchor:
		_viewport_anchor.viewport_changed.connect(_on_viewport_changed)
		call_deferred("_update_icon_position")

	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_finished)

	# Get camera reference
	_camera = _level.get_node_or_null("Camera2D") as Camera2D
	if _camera:
		_original_zoom = _camera.zoom
		_original_camera_offset = _camera.offset
	
	# Create vignette overlay
	_setup_vignette_overlay()

	_start_cooldown()


func _on_viewport_changed(_size: Vector2) -> void:
	_update_icon_position()


func _update_icon_position() -> void:
	if _viewport_anchor and _warning_icon:
		_warning_icon.position = _viewport_anchor.get_position(icon_x_ratio, icon_y_ratio)


func _start_cooldown() -> void:
	_state = State.COOLDOWN
	_warning_icon.set_phase(WarningIcon.Phase.OFF)
	if _magnet_lever:
		_magnet_lever.set_available(false)
		_magnet_lever.set_handle_visible(false)
	var interval := randf_range(cooldown_min, cooldown_max)
	_cooldown_timer.start(interval)


func _on_cooldown_finished() -> void:
	_start_warning()


func _start_warning() -> void:
	_state = State.WARNING
	_warning_duration = randf_range(warning_duration_min, warning_duration_max)
	_warning_elapsed = 0.0
	_warning_icon.set_phase(WarningIcon.Phase.YELLOW)
	if _magnet_lever:
		_magnet_lever.set_available(true)
		_magnet_lever.set_handle_visible(true)


func _on_lever_flipped() -> void:
	if _state != State.WARNING:
		return
	_warning_icon.set_phase(WarningIcon.Phase.OFF)
	if _magnet_lever:
		_magnet_lever.set_available(false)
		# Keep lever visible - minigame will show it
	_start_activation_minigame()


func _on_warning_expired() -> void:
	_warning_icon.set_phase(WarningIcon.Phase.OFF)
	if _magnet_lever:
		_magnet_lever.set_available(false)
		_magnet_lever.set_handle_visible(false)

	if _salvage_spawner:
		_salvage_spawner.spawn_on_demand()

	_start_cooldown()


func _start_activation_minigame() -> void:
	_state = State.ACTIVATION
	_timescale_transition_elapsed = 0.0
	_restoring_timescale = false
	
	# Set process mode to always so we can control timescale
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Pick rarity now but don't spawn pile yet - cog represents approaching pile
	_pending_rarity = _pick_rarity()
	
	# Disable player input during minigame
	_set_player_input_enabled(false)
	
	# Position player at lever spot
	_position_player_at_lever()
	
	# Reset lever to start position and make it visible
	if _magnet_lever:
		_magnet_lever.reset_rotation()
		_magnet_lever.set_handle_visible(true)
	
	# Start the activation minigame UI
	if _activation_minigame:
		_activation_minigame.start_minigame(_pending_rarity)
		_position_activation_ui()
	
	# Start camera zoom and vignette effects
	_start_activation_effects()


func _position_activation_ui() -> void:
	if not _activation_minigame or not _viewport_anchor:
		return
	# Position the minigame UI at center of screen horizontally, configurable Y ratio
	var screen_size := _viewport_anchor.size
	_activation_minigame.position = Vector2(screen_size.x * 0.5, screen_size.y * activation_ui_y_ratio)


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
		_current_pile = _salvage_spawner.spawn_on_demand_with_rarity(spawn_x, _pending_rarity)
	
	# Hide lever and reset rotation after minigame
	if _magnet_lever:
		_magnet_lever.set_handle_visible(false)
		_magnet_lever.reset_rotation()
	
	if success:
		# Player won - decelerate to stop over pile
		_start_deceleration()
	else:
		# Player lost - pile scrolls past, go to cooldown
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


func _process(delta: float) -> void:
	match _state:
		State.WARNING:
			_process_warning(delta)
		State.ACTIVATION:
			_process_activation(delta)
		State.DECELERATING:
			_process_deceleration(delta)
		State.PARKED:
			_process_parked(delta)
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
		_state = State.PARKED
		_park_elapsed = 0.0


func _process_parked(delta: float) -> void:
	_park_elapsed += delta
	if _park_elapsed >= park_duration:
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
	var ship := _level.get_node_or_null("Ship")
	if ship:
		_current_pile.global_position.x = ship.global_position.x


func _get_ship_x() -> float:
	var ship := _level.get_node_or_null("Ship")
	if ship:
		return ship.global_position.x
	if _viewport_anchor:
		return _viewport_anchor.get_center_x()
	return 960.0


func _get_screen_width() -> float:
	if _viewport_anchor:
		return _viewport_anchor.size.x
	return get_viewport().get_visible_rect().size.x


func _pick_rarity() -> SalvagePile.Rarity:
	# Delegate to salvage spawner's rarity picking logic
	if _salvage_spawner and _salvage_spawner.has_method("_pick_rarity"):
		return _salvage_spawner._pick_rarity()
	# Fallback: simple random
	var roll := randf()
	if roll < 0.7:
		return SalvagePile.Rarity.COMMON
	elif roll < 0.9:
		return SalvagePile.Rarity.RARE
	elif roll < 0.98:
		return SalvagePile.Rarity.EPIC
	return SalvagePile.Rarity.LEGENDARY


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
		var rotation_per_marker := 1.0 / float(total_markers)
		_magnet_lever.progress_rotation(rotation_per_marker)


func _set_player_input_enabled(enabled: bool) -> void:
	if _player and "input_enabled" in _player:
		_player.input_enabled = enabled


func _reparent_ui_elements() -> void:
	if not _ui_root:
		return
	
	# Reparent warning icon to UI canvas
	if _warning_icon:
		_warning_icon.reparent(_ui_root)
	
	# Reparent activation minigame to UI canvas
	if _activation_minigame:
		_activation_minigame.reparent(_ui_root)


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
	var shader := preload("res://_project/level/magnet_minigame/vignette_grayscale.gdshader")
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
		_offset_tween.tween_property(_camera, "offset", target_offset, zoom_tween_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
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
