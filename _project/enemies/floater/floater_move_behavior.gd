extends MoveBehavior
class_name FloaterMoveBehavior

## Drifts straight at the target point while bobbing on a sine wave. The bob rides on the
## velocity rather than on the sprite, so the base hit shake keeps sole ownership of the
## Visual offset. The attack behavior takes over once the Floater is within attack range,
## so the bob amplitude must stay below EnemyData.attack_range or arrival can be missed.

## Peak vertical offset of the bob from the straight path, in pixels.
@export var bob_amplitude: float = 14.0
## Seconds per full bob cycle.
@export var bob_period: float = 2.0

var _bob_time: float = 0.0


func setup(enemy: Enemy) -> void:
	super.setup(enemy)
	# A random phase keeps Floaters spawned together from bobbing in lockstep.
	_bob_time = randf() * bob_period


func update_state(enemy: Enemy, delta: float, _state_name: StringName) -> void:
	_bob_time += delta
	var angular_speed := TAU / maxf(bob_period, 0.01)
	var bob_velocity := bob_amplitude * angular_speed * cos(angular_speed * _bob_time)
	var drift := enemy.get_direction_to_target() * enemy.get_movement_speed()
	enemy.set_desired_velocity(drift + Vector2(0.0, bob_velocity))
	enemy.play_enemy_animation(Enemy.ANIM_MOVE)
