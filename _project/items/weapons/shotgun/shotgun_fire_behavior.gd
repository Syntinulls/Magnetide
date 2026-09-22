extends WeaponFireBehavior
class_name ShotgunFireBehavior

## Fires pellet_count projectiles fanned evenly across cone_degrees, centred on
## the aim direction.

@export var pellet_count: int = 3:
	set(value):
		pellet_count = maxi(value, 1)
@export_range(0.0, 90.0, 1.0, "degrees") var cone_degrees: float = 24.0


func fire(shooter: WeaponBehavior, weapon_data: WeaponData) -> void:
	if shooter == null:
		return

	var center_direction := shooter.get_weapon_aim_direction()
	var count := maxi(pellet_count, 1)
	if count == 1:
		shooter.fire_weapon_projectile(center_direction, weapon_data)
		return

	var cone_radians := deg_to_rad(maxf(cone_degrees, 0.0))
	for index in range(count):
		var spread_t := float(index) / float(count - 1)
		var angle := lerpf(-cone_radians * 0.5, cone_radians * 0.5, spread_t)
		shooter.fire_weapon_projectile(center_direction.rotated(angle), weapon_data)
