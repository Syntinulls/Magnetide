extends EnemyBehavior
class_name MoveBehavior


func get_initial_state(_enemy: Enemy) -> StringName:
	return &"move"


func register_states(_enemy: Enemy) -> void:
	add_state(&"move")


func on_enter_move(_enemy: Enemy) -> void:
	pass


func on_exit_move(_enemy: Enemy) -> void:
	pass
