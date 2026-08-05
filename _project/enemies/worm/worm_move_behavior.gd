extends MoveBehavior
class_name WormMoveBehavior

## Burst locomotion: wind up in place, propel toward the current target point
## at EnemyData.movement_speed, drift to a stop under exponential damping,
## pause briefly, then wind up again. Only the windup shows the windup
## animation; propel, drift, and pause all stay on the move animation.

## Seconds the worm winds up in place before each burst.
@export var windup_time: float = 0.4
## Exponential damping applied to velocity while drifting; higher values stop
## the worm sooner after each burst.
@export var drift_damping: float = 4.0
## Speed (px/s) below which a drifting worm counts as stopped.
@export var stop_speed_threshold: float = 30.0
## Seconds the worm rests between drifting to a stop and the next windup.
@export var pause_time: float = 0.35

var _phase_timer: float = 0.0


func get_initial_state(_enemy: Enemy) -> StringName:
	return &"windup"


func register_states(_enemy: Enemy) -> void:
	add_state(&"windup")
	add_state(&"propel")
	add_state(&"drift")
	add_state(&"pause")


func on_enter_move(enemy: Enemy) -> void:
	# setup() pre-selects "windup" as the initial state, so a plain
	# request_state(&"windup") here would no-op on the first MOVE entry and skip
	# on_enter_state (timer reset + windup animation). Clear the state first so
	# re-entering MOVE (e.g. after an unlatch) always starts a fresh windup.
	_current_state = &""
	request_state(enemy, &"windup")


func on_enter_state(enemy: Enemy, state_name: StringName) -> void:
	match state_name:
		&"windup":
			_phase_timer = windup_time
			enemy.set_desired_velocity(Vector2.ZERO)
			enemy.face_current_target()
			enemy.play_enemy_animation(&"windup")
		&"propel":
			enemy.face_current_target()
			enemy.set_desired_velocity(enemy.get_direction_to_target() * enemy.get_movement_speed())
			enemy.play_enemy_animation(&"move")
		&"pause":
			_phase_timer = pause_time
			enemy.set_desired_velocity(Vector2.ZERO)


func update_state(enemy: Enemy, delta: float, state_name: StringName) -> void:
	match state_name:
		&"windup":
			enemy.set_desired_velocity(Vector2.ZERO)
			enemy.face_current_target()
			# Reasserted per tick: the base MOVE entry plays the move animation
			# after on_enter_move, which would otherwise override the windup.
			enemy.play_enemy_animation(&"windup")
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				request_state(enemy, &"propel")
		&"propel":
			request_state(enemy, &"drift")
		&"drift":
			var next_velocity: Vector2 = enemy.velocity * exp(-drift_damping * delta)
			enemy.set_desired_velocity(next_velocity)
			if next_velocity.length() <= stop_speed_threshold:
				request_state(enemy, &"pause")
		&"pause":
			enemy.set_desired_velocity(Vector2.ZERO)
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				request_state(enemy, &"windup")
