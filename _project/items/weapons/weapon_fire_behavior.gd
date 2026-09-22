extends Resource
class_name WeaponFireBehavior

## How one weapon turns a trigger pull into projectiles. WeaponBehavior owns the
## cooldown, magazine and audio and then calls fire(); subclasses decide only the
## shape of the volley. The default is a single bullet along the aim direction.


func fire(shooter: WeaponBehavior, weapon_data: WeaponData) -> void:
	if shooter == null:
		return
	shooter.fire_weapon_projectile(shooter.get_weapon_aim_direction(), weapon_data)
