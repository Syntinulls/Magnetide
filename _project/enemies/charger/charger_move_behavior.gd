extends MoveBehavior
class_name ChargerMoveBehavior

## Orbit-and-dash locomotion: approach the target until inside engage_distance,
## circle it along a random arc (random direction and length), pause, hold a
## brief windup in the charge pose while still tracking, then dash in a straight
## line along the last tracked direction for roughly twice the distance to the
## target — ending up on the far side — before damping to a stop and starting a
## new arc. Contact damage during the dash is the head DamageBox's job (the
## charge state toggles it via begin_charge/end_charge); the dash itself never
## reacts to the hit.

## Multiplier on EnemyData.movement_speed while flying toward the target.
@export var approach_speed_multiplier: float = 1.0
## Distance at which the charger stops approaching and starts orbiting. Sized
## so a player standing at ship center (hull is 920 wide) sees the orbit ring
## just past the ship's edge.
@export var engage_distance: float = 550.0
## Tangential speed (px/s) while orbiting the target.
@export var orbit_speed: float = 200.0
## Proportional gain (per second) pulling the orbit back toward the radius
## captured when the orbit began.
@export var orbit_radial_gain: float = 3.0
## Minimum arc length (px) traveled along the orbit before a dash.
@export var arc_distance_min: float = 200.0
## Maximum arc length (px) traveled along the orbit before a dash.
@export var arc_distance_max: float = 600.0
## Seconds the charger hangs still between finishing an arc and the windup.
@export var pause_time: float = 0.35
## Seconds spent in the charge pose, still tracking, before the dash launches.
@export var windup_time: float = 0.6
## Top speed (px/s) of the dash.
@export var charge_speed: float = 1170.0
## Dash acceleration (px/s^2); high enough to reach top speed well under a second.
@export var charge_acceleration: float = 3600.0
## Dash length as a multiple of the distance to the target at windup start.
## 2.0 lands the charger on the far side of the target at its starting range.
@export var charge_distance_multiplier: float = 2.0
## Failsafe seconds before a dash that hasn't covered its distance (e.g. wedged
## against terrain) brakes anyway.
@export var charge_timeout: float = 2.0
## Exponential damping applied while braking after the dash; high enough to
## stop from top speed well under a second.
@export var decel_damping: float = 8.0
## Speed (px/s) below which a braking charger counts as stopped.
@export var stop_speed_threshold: float = 30.0

var _phase_timer: float = 0.0
var _orbit_sign: float = 1.0
var _orbit_radius: float = 0.0
var _arc_remaining: float = 0.0
var _charge_direction: Vector2 = Vector2.RIGHT
var _charge_origin: Vector2 = Vector2.ZERO
var _charge_target_distance: float = 0.0
var _charge_current_speed: float = 0.0


func get_initial_state(_enemy: Enemy) -> StringName:
	return &"approach"


func register_states(_enemy: Enemy) -> void:
	add_state(&"approach")
	add_state(&"orbit")
	add_state(&"pause")
	add_state(&"windup")
	add_state(&"charge")
	add_state(&"decelerate")


func on_enter_move(enemy: Enemy) -> void:
	# Re-entering MOVE restarts the loop. An interrupted state exits properly
	# first — a dash cut short by IDLE must release the charge flag and damage
	# box — then the state is cleared so request_state can't no-op (setup()
	# pre-selects "approach").
	if _current_state != &"":
		on_exit_state(enemy, _current_state)
	_current_state = &""
	request_state(enemy, &"approach")


func on_enter_state(enemy: Enemy, state_name: StringName) -> void:
	match state_name:
		&"orbit":
			_orbit_sign = 1.0 if randf() < 0.5 else -1.0
			_arc_remaining = randf_range(arc_distance_min, arc_distance_max)
			_orbit_radius = enemy.get_distance_to_target()
		&"pause":
			_phase_timer = pause_time
			enemy.set_desired_velocity(Vector2.ZERO)
		&"windup":
			_phase_timer = windup_time
			enemy.set_desired_velocity(Vector2.ZERO)
			_charge_target_distance = charge_distance_multiplier * enemy.get_distance_to_target()
		&"charge":
			var charger := enemy as Charger
			if charger:
				charger.begin_charge()
			_phase_timer = charge_timeout
			_charge_origin = enemy.global_position
			_charge_current_speed = 0.0


func on_exit_state(enemy: Enemy, state_name: StringName) -> void:
	if state_name == &"charge":
		var charger := enemy as Charger
		if charger:
			charger.end_charge()


func update_state(enemy: Enemy, delta: float, state_name: StringName) -> void:
	match state_name:
		&"approach":
			enemy.set_desired_velocity(enemy.get_direction_to_target() * enemy.get_movement_speed() * approach_speed_multiplier)
			enemy.face_current_target()
			enemy.play_enemy_animation(&"move")
			if enemy.get_distance_to_target() <= engage_distance:
				request_state(enemy, &"orbit")
		&"orbit":
			_update_orbit(enemy, delta)
		&"pause":
			enemy.set_desired_velocity(Vector2.ZERO)
			enemy.face_current_target()
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				request_state(enemy, &"windup")
		&"windup":
			enemy.set_desired_velocity(Vector2.ZERO)
			enemy.face_current_target()
			# Still tracking: the dash direction locks only when the windup
			# ends, and follows the smoothed body facing (not the raw aim) so
			# the launch continues the turn instead of snapping onto the target.
			var charger := enemy as Charger
			var direction := charger.get_facing_direction() if charger else enemy.get_direction_to_target()
			if direction != Vector2.ZERO:
				_charge_direction = direction
			# Reasserted per tick: the base MOVE entry plays the move animation
			# after on_enter_move, which would otherwise override the charge pose.
			enemy.play_enemy_animation(&"charge")
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				request_state(enemy, &"charge")
		&"charge":
			_charge_current_speed = minf(_charge_current_speed + charge_acceleration * delta, charge_speed)
			enemy.set_desired_velocity(_charge_direction * _charge_current_speed)
			var charger := enemy as Charger
			if charger:
				charger.face_move_direction(_charge_direction)
			enemy.play_enemy_animation(&"charge")
			_phase_timer -= delta
			# Distance is measured from the dash origin, not accumulated per
			# tick. Braking starts early by the distance the exponential brake
			# will still cover (v / damping), so the dash settles at its target
			# instead of overshooting by it.
			var braking_distance := _charge_current_speed / decel_damping
			if enemy.global_position.distance_to(_charge_origin) >= _charge_target_distance - braking_distance or _phase_timer <= 0.0:
				request_state(enemy, &"decelerate")
		&"decelerate":
			var next_velocity: Vector2 = enemy.velocity * exp(-decel_damping * delta)
			enemy.set_desired_velocity(next_velocity)
			enemy.play_enemy_animation(&"charge")
			if next_velocity.length() <= stop_speed_threshold:
				if enemy.get_distance_to_target() <= engage_distance:
					request_state(enemy, &"orbit")
				else:
					request_state(enemy, &"approach")


func _update_orbit(enemy: Enemy, delta: float) -> void:
	var target_point := enemy.get_current_target_point()
	if not target_point:
		return
	var offset := enemy.global_position - target_point.global_position
	var radial := offset.normalized() if offset.length() > 1.0 else Vector2.RIGHT
	var tangent := radial.rotated(_orbit_sign * PI / 2.0)
	enemy.set_desired_velocity(tangent * orbit_speed + radial * (_orbit_radius - offset.length()) * orbit_radial_gain)
	enemy.face_current_target()
	enemy.play_enemy_animation(&"move")
	_arc_remaining -= orbit_speed * delta
	if _arc_remaining <= 0.0:
		request_state(enemy, &"pause")
	elif enemy.get_distance_to_target() > engage_distance * 1.5:
		request_state(enemy, &"approach")
