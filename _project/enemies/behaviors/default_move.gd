extends "res://_project/enemies/behaviors/move_behavior.gd"
class_name DefaultMoveBehavior


func update_state(enemy: Enemy, _delta: float, _state_name: StringName) -> void:
	var direction := enemy.get_direction_to_target()
	enemy.set_desired_velocity(direction * enemy.get_movement_speed())
	enemy.face_current_target()
	enemy.play_enemy_animation(&"move")
