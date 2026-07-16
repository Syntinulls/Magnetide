extends Resource
class_name WeaponFireBehavior


func fire(player: Node, weapon_data: Resource) -> void:
	if player == null:
		return
	if not player.has_method("get_weapon_aim_direction"):
		return
	if not player.has_method("fire_weapon_projectile"):
		return

	var aim_direction: Vector2 = player.call("get_weapon_aim_direction")
	player.call("fire_weapon_projectile", aim_direction, weapon_data)
