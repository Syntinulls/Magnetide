extends AttackBehavior
class_name WormAttackBehavior

## Interval contact damage for as long as the worm stays latched. can_attack
## gates on the latch, so the base selector holds a latched worm in ATTACK and
## never ticks its movement; damage only ever flows while latched.

var _attack_timer: float = 0.0


func can_attack(enemy: Enemy) -> bool:
	var worm := enemy as Worm
	return worm != null and worm.is_latched() and enemy.has_valid_target()


func get_initial_state(_enemy: Enemy) -> StringName:
	return &"bite"


func register_states(_enemy: Enemy) -> void:
	add_state(&"bite")


func on_enter_attack(enemy: Enemy) -> void:
	_attack_timer = enemy.get_attack_interval()
	enemy.set_desired_velocity(Vector2.ZERO)
	enemy.play_enemy_animation(&"attack")


func update_state(enemy: Enemy, delta: float, _state_name: StringName) -> void:
	enemy.set_desired_velocity(Vector2.ZERO)
	enemy.play_enemy_animation(&"attack")
	var interval := enemy.get_attack_interval()
	_attack_timer += delta
	if _attack_timer >= interval:
		_attack_timer -= interval
		enemy.deal_damage_to_current_target()
