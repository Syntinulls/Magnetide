extends Marker2D
class_name EnemyTargetPoint

@export var category: EnemyData.TargetCategory = EnemyData.TargetCategory.SHIP
@export var target_root_path: NodePath
@export var enabled: bool = true


func get_target_root() -> Node:
	if target_root_path != NodePath():
		return get_node_or_null(target_root_path)

	var node := get_parent()
	while node:
		if node.has_method("get_hitbox"):
			return node
		node = node.get_parent()
	return null


func get_damage_receiver() -> Hitbox:
	var target_root := get_target_root()
	if target_root and target_root.has_method("get_hitbox"):
		return target_root.get_hitbox() as Hitbox
	return null


func is_target_enabled() -> bool:
	if not enabled or not is_inside_tree():
		return false

	var damage_receiver := get_damage_receiver()
	return damage_receiver != null and damage_receiver.is_valid_target()
