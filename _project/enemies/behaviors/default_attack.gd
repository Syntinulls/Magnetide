extends "res://_project/enemies/behaviors/attack_behavior.gd"
class_name DefaultAttackBehavior

var _attack_timer: float = 0.0


func can_attack(enemy: Enemy) -> bool:
	return enemy.has_valid_target() and enemy.get_distance_to_target() <= enemy.get_attack_range()


func on_enter_attack(enemy: Enemy) -> void:
	_attack_timer = enemy.get_attack_interval()
	enemy.set_desired_velocity(Vector2.ZERO)
	enemy.play_enemy_animation(&"attack")


func update_state(enemy: Enemy, delta: float, _state_name: StringName) -> void:
	enemy.set_desired_velocity(Vector2.ZERO)
	enemy.face_current_target()
	enemy.play_enemy_animation(&"attack")
	_attack_timer += delta
	if _attack_timer >= enemy.get_attack_interval():
		_attack_timer -= enemy.get_attack_interval()
		enemy.deal_damage_to_current_target()
