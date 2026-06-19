extends "res://_project/items/equipment/weapon_fire_behavior.gd"
class_name ShotgunFireBehavior

@export var pellet_count: int = 3:
	set(value):
		pellet_count = maxi(value, 1)
@export_range(0.0, 90.0, 1.0, "degrees") var cone_degrees: float = 24.0


func fire(player: Node, weapon_data: Resource) -> void:
	if player == null:
		return
	if not player.has_method("get_weapon_aim_direction"):
		return
	if not player.has_method("fire_weapon_projectile"):
		return

	var center_direction: Vector2 = player.call("get_weapon_aim_direction")
	var count := maxi(pellet_count, 1)
	if count == 1:
		player.call("fire_weapon_projectile", center_direction, weapon_data)
		return

	var cone_radians := deg_to_rad(maxf(cone_degrees, 0.0))
	for index in range(count):
		var spread_t := float(index) / float(count - 1)
		var angle := lerpf(-cone_radians * 0.5, cone_radians * 0.5, spread_t)
		player.call("fire_weapon_projectile", center_direction.rotated(angle), weapon_data)
