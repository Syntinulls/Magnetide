extends EnemyBehavior
class_name AttackBehavior


func get_initial_state(_enemy: Enemy) -> StringName:
	return &"windup"


func register_states(_enemy: Enemy) -> void:
	add_state(&"windup")


func can_attack(_enemy: Enemy) -> bool:
	return false


func on_enter_attack(_enemy: Enemy) -> void:
	pass


func on_exit_attack(_enemy: Enemy) -> void:
	pass
