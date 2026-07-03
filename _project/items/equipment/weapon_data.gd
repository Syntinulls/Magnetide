extends EquipmentData
class_name WeaponData
@export var damage: float = 10.0
@export var fire_rate: float = 5.0
@export var bullet_speed: float = 1800.0
@export var pierce: int = 1:
	set(value):
		pierce = maxi(value, 1)
@export var weapon_sprite: Texture2D
@export var bullet_sprite: Texture2D
@export var fire_behavior: Resource = null

@export_group("Ammo")
## Rounds available before a reload is required.
@export var magazine_size: int = 30:
	set(value):
		magazine_size = maxi(value, 1)
## Rounds consumed per shot (per trigger pull, not per pellet).
@export var ammo_consumption: int = 1:
	set(value):
		ammo_consumption = maxi(value, 1)
## Seconds to refill the magazine to full.
@export var reload_time: float = 1.5:
	set(value):
		reload_time = maxf(value, 0.0)

@export_group("Positioning")
@export var weapon_offset: Vector2 = Vector2(-15.125, 0.0)
@export var weapon_rotation: float = -0.14660765
@export var muzzle_position: Vector2 = Vector2(-55.915, -4.695)
