extends Area2D
class_name Hitbox

@export var owner_path: NodePath
@export var enabled: bool = true


func get_target_owner() -> Node:
	if owner_path != NodePath():
		return get_node_or_null(owner_path)

	var node := get_parent()
	while node:
		if node.has_method("take_damage"):
			return node
		node = node.get_parent()
	return null


func is_valid_target() -> bool:
	return enabled and is_inside_tree() and get_target_owner() != null


func take_damage(amount: float, source: Node = null) -> void:
	var target_owner := get_target_owner()
	if target_owner and target_owner.has_method("take_damage"):
		target_owner.take_damage(amount, source)
