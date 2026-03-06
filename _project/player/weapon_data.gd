extends Resource
class_name WeaponData

@export var weapon_name: String = ""
@export var damage: float = 10.0
@export var fire_rate: float = 5.0
@export var bullet_speed: float = 1800.0
@export var weapon_sprite: Texture2D
@export var bullet_sprite: Texture2D

@export_group("Positioning")
@export var weapon_offset: Vector2 = Vector2(-15.125, 0.0)
@export var weapon_rotation: float = -0.14660765
@export var muzzle_position: Vector2 = Vector2(-55.915, -4.695)
