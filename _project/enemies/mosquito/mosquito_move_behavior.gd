extends MoveBehavior
class_name MosquitoMoveBehavior

## Flies the mosquito toward its target until the Mosquito reports it is holding
## position (within hover_distance). The hold/resume hysteresis lives on the
## Mosquito itself, so this behavior only ever runs while approaching; the base
## Enemy state machine hands off to the attack behavior once holding begins.

## Approach speed multiplier applied on top of EnemyData.movement_speed.
@export var approach_speed_multiplier: float = 1.0


func update_state(enemy: Enemy, _delta: float, _state_name: StringName) -> void:
	var direction := enemy.get_direction_to_target()
	enemy.set_desired_velocity(direction * enemy.get_movement_speed() * approach_speed_multiplier)
	enemy.face_current_target()
	enemy.play_enemy_animation(&"move")
