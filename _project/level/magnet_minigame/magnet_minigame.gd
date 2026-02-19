extends Node2D
class_name MagnetMinigame

enum State { COOLDOWN, WARNING, DECELERATING, PARKED, ACCELERATING }

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

var _level: Node2D = null
var _salvage_spawner: SalvageSpawner = null
var _warning_icon: WarningIcon = null
var _magnet_lever: MagnetLever = null
var _viewport_anchor: ViewportAnchor = null

@onready var _cooldown_timer: Timer = $CooldownTimer


func _ready() -> void:
	_level = get_parent()
	if _level and "level_speed" in _level:
		_base_level_speed = _level.level_speed
	if _level and "viewport_anchor" in _level:
		_viewport_anchor = _level.viewport_anchor

	_salvage_spawner = _level.get_node_or_null("SalvageSpawner") as SalvageSpawner

	_warning_icon = $WarningIcon as WarningIcon

	var ship := _level.get_node_or_null("Ship")
	if ship:
		_magnet_lever = ship.get_node_or_null("MagnetLever") as MagnetLever
		if _magnet_lever:
			_magnet_lever.lever_flipped.connect(_on_lever_flipped)

	if _viewport_anchor:
		_viewport_anchor.viewport_changed.connect(_on_viewport_changed)
		call_deferred("_update_icon_position")

	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_finished)

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


func _on_lever_flipped() -> void:
	if _state != State.WARNING:
		return
	_warning_icon.set_phase(WarningIcon.Phase.OFF)
	_spawn_pile_and_decelerate()


func _spawn_pile_and_decelerate() -> void:
	_state = State.DECELERATING
	_decel_elapsed = 0.0

	# Spawn pile at fixed x ratio position
	var spawn_x := _get_screen_width() * pile_spawn_x_ratio

	if _salvage_spawner:
		_current_pile = _salvage_spawner.spawn_on_demand(spawn_x)

	# Calculate decel_time based on distance to pile
	# Using kinematic equation: distance = v0 * t / 2 (for linear decel from v0 to 0)
	# So: t = 2 * distance / v0
	var ship_x := _get_ship_x()
	var distance := spawn_x - ship_x
	if _base_level_speed > 0.0 and distance > 0.0:
		_current_decel_time = 2.0 * distance / _base_level_speed
	else:
		_current_decel_time = 1.0  # Fallback


func _on_warning_expired() -> void:
	_warning_icon.set_phase(WarningIcon.Phase.OFF)
	if _magnet_lever:
		_magnet_lever.set_available(false)

	if _salvage_spawner:
		_salvage_spawner.spawn_on_demand()

	_start_cooldown()


func _process(delta: float) -> void:
	match _state:
		State.WARNING:
			_process_warning(delta)
		State.DECELERATING:
			_process_deceleration(delta)
		State.PARKED:
			_process_parked(delta)
		State.ACCELERATING:
			_process_acceleration(delta)


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
